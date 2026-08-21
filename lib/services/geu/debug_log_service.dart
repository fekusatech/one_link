import 'package:dio/dio.dart';

import '../file_logger_service.dart';
import 'geu_api_client.dart';
import 'geu_auth_service.dart';

/// Sends today's on-device debug log (see FileLoggerService) to the server
/// for support/debugging — a driver taps a button, no automatic uploads.
class DebugLogService {
  static Future<String> sendTodayLog() async {
    await FileLoggerService.instance.flush();
    final file = FileLoggerService.instance.todayLogFile;
    if (file == null) {
      return 'Belum ada log hari ini untuk dikirim.';
    }

    try {
      await GeuAuthService.ensureSession();
      final dio = await GeuApiClient.instance;
      final form = FormData.fromMap({
        'log_file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      });
      final res = await dio.post('/api/debug-log/upload', data: form);
      final data = res.data;
      if (data is Map && data['status'] == 'error') {
        return 'Gagal mengirim log: ${data['message'] ?? 'unknown error'}';
      }
      return 'Log hari ini berhasil dikirim.';
    } on DioException catch (e) {
      return 'Gagal mengirim log: ${e.message ?? e.toString()}';
    } catch (e) {
      return 'Gagal mengirim log: $e';
    }
  }
}
