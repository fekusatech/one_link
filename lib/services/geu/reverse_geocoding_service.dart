import 'dart:async';
import 'package:dio/dio.dart';

/// Best-effort address lookup for visit payloads. It never blocks a critical
/// check-in/out: an offline or rate-limited lookup falls back to coordinates.
class ReverseGeocodingService {
  static DateTime? _lastRequestAt;

  static Future<({String? province, String? city, String? district})>
  resolveAdministrativeRegion(double latitude, double longitude) async {
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
              'format': 'jsonv2',
              'zoom': 18,
              'addressdetails': 1,
              'accept-language': 'id',
            },
          );
      final rawAddress = response.data is Map
          ? (response.data as Map)['address']
          : null;
      if (rawAddress is! Map) {
        return (province: null, city: null, district: null);
      }
      final address = Map<String, dynamic>.from(rawAddress);
      return (
        province: _firstAddressValue(address, const ['state', 'province']),
        city: _firstAddressValue(address, const [
          'city',
          'town',
          'municipality',
          'county',
        ]),
        district: _firstAddressValue(address, const [
          'district',
          'city_district',
          'subdistrict',
        ]),
      );
    } catch (_) {
      return (province: null, city: null, district: null);
    }
  }

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

  /// Returns the nearest village, town, city, or regency without exposing the
  /// province/postcode as the primary location label.
  static Future<String> resolveLocality(
    double latitude,
    double longitude,
  ) async {
    final fallback = 'Lokasi sekitar';
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
              'zoom': 14,
              'addressdetails': 1,
              'accept-language': 'id',
            },
          );
      final data = response.data;
      final rawAddress = data is Map ? data['address'] : null;
      if (rawAddress is! Map) return fallback;
      final address = Map<String, dynamic>.from(rawAddress);
      final village = _firstAddressValue(address, const [
        'village',
        'hamlet',
        'suburb',
      ]);
      final locality = _firstAddressValue(address, const [
        'city',
        'town',
        'municipality',
        'county',
        'city_district',
        'state_district',
      ]);
      if (village != null && locality != null && village != locality) {
        return '$village, $locality';
      }
      return village ?? locality ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String? _firstAddressValue(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
