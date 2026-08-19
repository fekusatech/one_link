import 'geu_api_client.dart';

/// GET /api/settings/{key} (go-rest-api). Read-only, best-effort — callers
/// supply a sensible default since these are tuning knobs, not required data.
class SettingsService {
  static Future<String?> getByKey(String key) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/settings/$key');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') return null;
      final value = body['data'];
      if (value is String && value.isNotEmpty) return value;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<double> getDouble(String key, double fallback) async {
    final raw = await getByKey(key);
    if (raw == null) return fallback;
    return double.tryParse(raw) ?? fallback;
  }
}
