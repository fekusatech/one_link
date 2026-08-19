import 'package:dio/dio.dart';
import 'geu/geu_api_client.dart';

/// Response model for dashboard access from Go API
class DashboardAccess {
  final bool driver;
  final bool sales;
  final bool admin;
  final bool allowed;

  DashboardAccess({
    required this.driver,
    required this.sales,
    required this.admin,
    required this.allowed,
  });

  factory DashboardAccess.fromJson(Map<String, dynamic> json) {
    return DashboardAccess(
      driver: json['driver'] ?? false,
      sales: json['sales'] ?? false,
      admin: json['admin'] ?? false,
      allowed: json['allowed'] ?? false,
    );
  }
}

/// Service to fetch dashboard access from Go API
class DashboardAccessService {
  /// Fetch user's dashboard access from Go API
  static Future<DashboardAccess?> fetchDashboardAccess() async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api-auth/my-dashboard-access');
      final body = res.data as Map<String, dynamic>;

      if (body['status'] != 'success' || body['data'] == null) {
        print(
          '⚠️ Dashboard access request did not succeed '
          '(http ${res.statusCode}): ${body['message'] ?? body}',
        );
        return null;
      }

      final data = body['data'] as Map<String, dynamic>;
      return DashboardAccess.fromJson(data);
    } catch (e) {
      print('⚠️ Failed to fetch dashboard access: $e');
      return null;
    }
  }
}
