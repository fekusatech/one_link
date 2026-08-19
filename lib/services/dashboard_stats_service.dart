import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';
import '../models/api_response.dart';
import '../models/dashboard_stats_model.dart';
import 'user_storage.dart';

class DashboardStatsService {
  static const String baseUrl = AppConfig.serverDomain;

  /// Fetch dashboard statistics
  static Future<ApiResponse<DashboardStats>> getDashboardStats({
    int? picId,
  }) async {
    try {
      final token = await UserStorage.getToken();

      // If no picId provided, use current user's ID
      if (picId == null) {
        picId = await UserStorage.getUserId();
      }

      String url = '$baseUrl/api-supplier/dashboard-stats';
      if (picId != null) {
        url += '?pic_id=$picId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Dashboard Stats Response Status: ${response.statusCode}');
      print('📊 Dashboard Stats Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        return ApiResponse<DashboardStats>.fromJson(
          responseData,
          (data) => DashboardStats.fromJson(data),
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
