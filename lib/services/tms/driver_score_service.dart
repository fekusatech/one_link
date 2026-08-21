import 'package:flutter/foundation.dart';
import '../../models/tms/driver_score_model.dart';
import '../geu/geu_api_client.dart';

class DriverScoreService {
  DriverScoreService._internal();
  static final DriverScoreService instance = DriverScoreService._internal();

  /// Fetch driver safety & driving score from Go API — a real calculation
  /// derived from the driver's own GPS trail (t_driver_tracking), see
  /// go-rest-api's driving_analysis.go. Returns null on failure so the UI
  /// can show a real "couldn't load" state instead of fabricated numbers.
  Future<DriverScoreData?> getMyScore() async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get('/api-tms/driver-score/my-score');
      final body = response.data as Map<String, dynamic>;

      if (body['status'] == 'success' && body['data'] != null) {
        return DriverScoreData.fromJson(body['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ DriverScoreService.getMyScore error: $e');
    }
    return null;
  }

  /// Fetch the per-day score history (default last 14 days, server caps at 60).
  Future<List<DriverScoreHistoryDay>> getHistory({int days = 14}) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/driver-score/history',
        queryParameters: {'days': days},
      );
      final body = response.data as Map<String, dynamic>;

      if (body['status'] == 'success' && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        final days = data['days'] as List<dynamic>? ?? [];
        return days
            .map((e) => DriverScoreHistoryDay.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ DriverScoreService.getHistory error: $e');
    }
    return [];
  }
}
