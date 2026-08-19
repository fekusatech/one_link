import 'dart:async';
import 'package:geolocator/geolocator.dart';

class GpsException implements Exception {
  final String message;
  GpsException(this.message);
  @override
  String toString() => message;
}

/// A single high-accuracy fix, with the metadata FR-VP-06/07 need for the
/// check-in dialog: accuracy (to warn/block on a bad fix) and mock-location
/// detection (sent to the server as metadata, never blocked client-side —
/// NFR-SC-12).
class GpsFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isMocked;
  final DateTime timestamp;

  GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isMocked,
    required this.timestamp,
  });
}

/// CRM-side GPS acquisition (Visit Planner check-in/out). Separate from the
/// TMS-side lib/services/location_service.dart on purpose — that one is
/// tuned for continuous driver tracking (10s timeout, LatLng-only); this one
/// is a single on-demand fix with the accuracy/mock metadata check-in needs.
class GpsService {
  static Future<GpsFix> getCurrentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw GpsException('GPS tidak aktif. Aktifkan lokasi di pengaturan perangkat.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw GpsException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw GpsException(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
      );
    }

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException catch (_) {
      throw GpsException('Gagal mendapat lokasi dalam ${timeout.inSeconds} detik. Coba lagi.');
    } catch (e) {
      throw GpsException('Gagal mengambil lokasi: $e');
    }

    return GpsFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      isMocked: position.isMocked,
      timestamp: position.timestamp,
    );
  }
}
