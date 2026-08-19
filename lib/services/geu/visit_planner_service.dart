import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/geu/visit_planner_models.dart';
import 'geu_api_client.dart';

class VisitPlannerException implements Exception {
  final String message;
  VisitPlannerException(this.message);
  @override
  String toString() => message;
}

/// GET /api/visit-planner/mission/today + friends (go-rest-api). Read-cached
/// to shared_preferences per PRD A1 — served stale with a timestamp when
/// offline, refreshed opportunistically when online.
class VisitPlannerService {
  static const _cacheKey = 'geu_mission_today_cache';
  static const _cacheAtKey = 'geu_mission_today_cache_at';

  static Future<TodaysMission> getTodaysMission({
    bool forceRefresh = false,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/visit-planner/mission/today');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        throw VisitPlannerException(
          body['message'] ?? 'Gagal memuat mission hari ini',
        );
      }
      final mission = TodaysMission.fromJson(
        body['data'] as Map<String, dynamic>,
      );
      await _saveCache(mission);
      return mission;
    } catch (e) {
      if (e is VisitPlannerException) rethrow;
      final cached = await _loadCache();
      if (cached != null) return cached;
      throw VisitPlannerException(
        'Tidak ada koneksi dan belum ada data tersimpan.',
      );
    }
  }

  static Future<void> _saveCache(TodaysMission mission) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(mission.toJson()));
    await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<TodaysMission?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final cachedAtMs = prefs.getInt(_cacheAtKey);
    final mission = TodaysMission.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return mission.withCachedAt(
      cachedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs)
          : DateTime.now(),
    );
  }
}
