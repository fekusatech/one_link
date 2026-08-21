import 'geu_api_client.dart';

/// GET /api/settings/{key} (go-rest-api). Read-only. Tuning values must come
/// from the API; callers handle a missing/invalid value explicitly.
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

  static Future<double?> getDouble(String key) async {
    final raw = await getByKey(key);
    if (raw == null) return null;
    final value = double.tryParse(raw);
    return value != null && value > 0 ? value : null;
  }
}
