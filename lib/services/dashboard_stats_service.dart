import '../models/api_response.dart';
import '../models/dashboard_stats_model.dart';
import 'user_storage.dart';
import 'geu/geu_api_client.dart';

class DashboardStatsService {
  /// Fetch dashboard statistics
  static Future<ApiResponse<DashboardStats>> getDashboardStats({
    int? picId,
  }) async {
    try {
      // If no picId provided, use current user's ID
      if (picId == null) {
        picId = await UserStorage.getUserId();
      }

      // go-rest-api exposes supplier analytics under /api/suppliers. The
      // legacy /api-supplier route was removed from the deployed API.
      final response = await (await GeuApiClient.instance).get(
        '/api/suppliers/dashboard-stats',
        queryParameters: {if (picId != null) 'pic_id': picId},
      );

      print('📊 Dashboard Stats Response Status: ${response.statusCode}');
      print('📊 Dashboard Stats Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = Map<String, dynamic>.from(response.data as Map);

        final data = responseData['data'];
        return ApiResponse<DashboardStats>(
          status: responseData['status'] == 'success',
          message: responseData['message']?.toString() ?? '',
          data: data is Map<String, dynamic>
              ? DashboardStats.fromJson(data)
              : data is Map
              ? DashboardStats.fromJson(Map<String, dynamic>.from(data))
              : null,
        );
      } else {
        return ApiResponse<DashboardStats>(
          status: false,
          message: 'Failed to get dashboard statistics: ${response.statusCode}',
          data: null,
        );
      }
    } catch (e) {
      print('❌ Error fetching dashboard statistics: $e');
      return ApiResponse<DashboardStats>(
        status: false,
        message: 'Network error: $e',
        data: null,
      );
    }
  }
}
