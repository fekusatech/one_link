import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../models/surat_jalan.dart';
import '../../models/geu/surat_jalan_models.dart';
import 'geu_api_client.dart';
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
  /// Fetch live tracking positions of all active drivers (Admin view)
  static Future<List<TrackingLiveItem>> getLiveTracking() async {
    try {
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

      // Hydrate per-surat-jalan detail to get full stops & GPS
      final List<SuratJalan> hydrated = await Future.wait<SuratJalan>(
        listItems.map((s) async {
          try {
            return await GeuSuratJalanService.getById(int.parse(s.suratJalanId));
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
