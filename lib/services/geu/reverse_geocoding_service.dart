import 'dart:async';
import 'package:dio/dio.dart';

/// Best-effort address lookup for visit payloads. It never blocks a critical
/// check-in/out: an offline or rate-limited lookup falls back to coordinates.
class ReverseGeocodingService {
  static DateTime? _lastRequestAt;

  static Future<String> resolve(double latitude, double longitude) async {
    final fallback =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    try {
      final last = _lastRequestAt;
      if (last != null) {
        final remaining =
            const Duration(seconds: 1) - DateTime.now().difference(last);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      _lastRequestAt = DateTime.now();
      final response =
          await Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 5),
              headers: {'User-Agent': 'OneLinkCRM/1.0 (field-visit)'},
            ),
          ).get(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'lat': latitude,
              'lon': longitude,
              'format': 'json',
              'zoom': 18,
              'addressdetails': 1,
              'accept-language': 'id',
            },
          );
      final data = response.data;
      final displayName = data is Map
          ? data['display_name']?.toString().trim()
          : null;
      return displayName == null || displayName.isEmpty
          ? fallback
          : displayName;
    } catch (_) {
      return fallback;
    }
  }
}
