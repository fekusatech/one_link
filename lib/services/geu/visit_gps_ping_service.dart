import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geu_api_client.dart';
import 'visit_gps_mode_service.dart';

class VisitGpsPingService {
  static const _bufferKey = 'geu_visit_gps_buffer';
  static StreamSubscription<Position>? _subscription;
  static DateTime? _lastSentAt;
  static Position? _lastSent;

  static Future<void> start() async {
    if (_subscription != null || await VisitGpsModeService.isManualOffline())
      return;
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 50,
      ),
    ).listen(_handle);
    await flush();
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> _handle(Position point) async {
    if (await VisitGpsModeService.isManualOffline()) return;
    if (_lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) < const Duration(seconds: 60))
      return;
    if (_lastSent != null &&
        Geolocator.distanceBetween(
              _lastSent!.latitude,
              _lastSent!.longitude,
              point.latitude,
              point.longitude,
            ) <
            50)
      return;
    await _sendOrBuffer({
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
    _lastSentAt = DateTime.now();
    _lastSent = point;
  }

  static Future<void> _sendOrBuffer(Map<String, dynamic> point) async {
    try {
      await (await GeuApiClient.instance).post(
        '/api/visit-planner/gps/batch',
        data: {
          'points': [point],
        },
      );
    } catch (_) {
      await _append(point);
    }
  }

  static Future<void> flush() async {
    if (await VisitGpsModeService.isManualOffline()) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bufferKey);
    if (raw == null) return;
    final points = (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    try {
      for (var index = 0; index < points.length; index += 20) {
        await (await GeuApiClient.instance).post(
          '/api/visit-planner/gps/batch',
          data: {'points': points.skip(index).take(20).toList()},
        );
      }
      await prefs.remove(_bufferKey);
    } catch (_) {}
  }

  static Future<void> _append(Map<String, dynamic> point) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_bufferKey);
    final points = existing == null
        ? <dynamic>[]
        : jsonDecode(existing) as List;
    points.add(point);
    await prefs.setString(
      _bufferKey,
      jsonEncode(
        points.length > 200 ? points.sublist(points.length - 200) : points,
      ),
    );
  }
}
