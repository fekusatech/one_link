import '../../models/tms/tms_notification_model.dart';
import '../geu/geu_api_client.dart';

class TmsNotificationService {
  /// GET /api-tms/notifications/ - Mengambil kotak masuk notifikasi
  static Future<TmsNotificationInbox> getNotifications() async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/notifications/',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonData = {};

      if (data is Map<String, dynamic>) {
        if (data['data'] != null && data['data'] is Map<String, dynamic>) {
          jsonData = data['data'];
        } else {
          jsonData = data;
        }
      }

      return TmsNotificationInbox.fromJson(jsonData);
    } catch (e) {
      print('❌ Error fetching TMS notifications: $e');
      // Return empty fallback on error
      return TmsNotificationInbox(items: [], unreadCount: 0);
    }
  }

  /// POST /api-tms/notifications/read-all - Tandai semua notifikasi telah dibaca
  static Future<bool> markAllAsRead() async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/notifications/read-all',
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
      return false;
    }
  }
}
