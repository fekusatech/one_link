import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../models/surat_jalan.dart';
import '../../models/geu/surat_jalan_models.dart';
import 'geu_api_client.dart';
import 'geu_auth_service.dart';
import 'surat_jalan_service.dart';

class TrackingLiveItem {
  final int id;
  final String karyawanId;
  final String email;
  final String name;
  final String jabatanName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final DateTime? lastUpdate;
  final String status; // 'online', 'idle', 'offline'
  final bool isMonitoring;
  final String? vehiclePlat;

  TrackingLiveItem({
    required this.id,
    required this.karyawanId,
    required this.email,
    required this.name,
    required this.jabatanName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    this.lastUpdate,
    required this.status,
    this.isMonitoring = false,
    this.vehiclePlat,
  });

  factory TrackingLiveItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['last_update'] != null) {
      try {
        parsedDate = DateTime.parse(json['last_update'].toString());
      } catch (_) {}
    }

    return TrackingLiveItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      karyawanId: json['karyawan_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? json['email']?.toString() ?? 'Driver',
      jabatanName: json['jabatan_name']?.toString() ?? 'Driver',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] is int
          ? json['battery_level']
          : int.tryParse(json['battery_level']?.toString() ?? ''),
      lastUpdate: parsedDate,
      status: json['status']?.toString().toLowerCase() ?? 'offline',
      isMonitoring: json['is_monitoring'] == true || json['is_monitoring'] == 1,
      vehiclePlat: json['vehicle_plat']?.toString() ?? json['fleet_plat']?.toString(),
    );
  }
}

class TrackingHistoryItem {
  final double latitude;
  final double longitude;
  final double? speed;
  final DateTime? createdAt;

  TrackingHistoryItem({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.createdAt,
  });

  factory TrackingHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return TrackingHistoryItem(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble(),
      createdAt: parsedDate,
    );
  }
}

class GeuDriverTrackingService {
  /// Send a GPS location update — replaces the old, unauthenticated
  /// DriverTrackingService.sendLocationUpdate() (lib/services/
  /// driver_tracking_service.dart, POST /driver_tracking/save_location).
  /// That legacy PHP path now 404s: apipi.greenenergiutama.co.id routes
  /// everything to the Go API these days, and it was never migrated. This
  /// hits POST /api-tms/tracking/update instead — driver identity comes
  /// from the session token (see UpdateLocationRequest in the Go API), not
  /// from fields in the body, so there's no karyawan_id/email to send.
  static Future<bool> updateLocation(Position position) async {
    try {
      await GeuAuthService.ensureSession();
      final dio = await GeuApiClient.instance;
      final res = await dio.post(
        '/api-tms/tracking/update',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          if (position.speed > 0) 'speed': position.speed,
          if (position.heading > 0) 'heading': position.heading,
          if (position.altitude != 0) 'altitude': position.altitude,
          'battery_level': await _getBatteryLevel(),
          'device_info': await _getDeviceInfo(),
        },
      );
      final data = res.data;
      if (data is Map && data['status'] == 'error') {
        debugPrint('⚠️ Failed to update location: ${data['message']}');
        return false;
      }
      return true;
    } on DioException catch (e) {
      debugPrint('⚠️ Error updating location: $e');
      return false;
    } catch (e) {
      debugPrint('⚠️ Unexpected error in updateLocation: $e');
      return false;
    }
  }

  static Future<int?> _getBatteryLevel() async {
    try {
      return await Battery().batteryLevel;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return 'Android ${info.version.release} (${info.model}) - ${info.brand} ${info.device}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return 'iOS ${info.systemVersion} (${info.model}) - ${info.name}';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch live tracking positions of all active drivers (Admin view)
  static Future<List<TrackingLiveItem>> getLiveTracking() async {
    try {
      await GeuAuthService.ensureSession();
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api-tms/tracking/live');
      final data = res.data;

      if (data is Map && data['status'] == 'error') {
        throw Exception(data['message'] ?? 'Gagal memuat live tracking');
      }

      final items = (data is Map ? data['data'] : data) as List? ?? [];
      return items
          .map((e) => TrackingLiveItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('⚠️ Error fetching live tracking: $e');
      return [];
    } catch (e) {
      debugPrint('⚠️ Unexpected error in getLiveTracking: $e');
      return [];
    }
  }

  /// Fetch historical GPS route points for a driver on a specific date (YYYY-MM-DD)
  static Future<List<TrackingHistoryItem>> getRouteHistory({
    required String karyawanId,
    required String date,
  }) async {
    try {
      await GeuAuthService.ensureSession();
      final dio = await GeuApiClient.instance;
      final res = await dio.get(
        '/api-tms/tracking/history',
        queryParameters: {
          'karyawan_id': karyawanId,
          'date': date,
        },
      );
      final data = res.data;
      if (data is Map && data['status'] == 'error') {
        throw Exception(data['message'] ?? 'Gagal memuat histori rute');
      }

      final items = (data is Map ? data['data'] : data) as List? ?? [];
      return items
          .map((e) => TrackingHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('⚠️ Error fetching route history: $e');
      return [];
    } catch (e) {
      debugPrint('⚠️ Unexpected error in getRouteHistory: $e');
      return [];
    }
  }

  /// Fetch Surat Jalan list for driver/gudang with full details (stops, GPS, status)
  static Future<List<SuratJalan>> getDriverSuratJalan({
    required String dateFrom,
    required String dateTo,
    String? driverId,
  }) async {
    try {
      await GeuAuthService.ensureSession();
      final dio = await GeuApiClient.instance;
      final res = await dio.get(
        '/api-tms/surat-jalan',
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
          if (driverId != null && driverId.isNotEmpty) 'driver_id': driverId,
          'limit': 100,
        },
      );

      final data = res.data;
      final items = (data is Map && data['data'] != null
          ? (data['data'] is Map ? data['data']['data'] : data['data'])
          : null) as List? ?? [];

      final listItems = items
          .map((e) => GeuSuratJalanListItem.fromJson(Map<String, dynamic>.from(e)).toLegacy())
          .toList();

      // Hydrate per-surat-jalan detail to get full stops & GPS. getById()'s
      // header doesn't carry driver/fleet/gudang name (only driver_id, from
      // the raw Pickup relation) — merge those back from the list item,
      // which already has them from the List endpoint's JOINs.
      final List<SuratJalan> hydrated = await Future.wait<SuratJalan>(
        listItems.map((s) async {
          try {
            final full = await GeuSuratJalanService.getById(int.parse(s.suratJalanId));
            return GeuSuratJalanService.mergeListFields(base: full, listItem: s);
          } catch (_) {
            return s;
          }
        }),
      );

      return hydrated;
    } catch (e) {
      debugPrint('⚠️ Error fetching driver surat jalan: $e');
      return [];
    }
  }
}
