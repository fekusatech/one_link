import 'geu_api_client.dart';

/// Submits a request to access this device after a device-lock conflict
/// during login (see [DeviceLockConflictException] in geu_auth_service.dart).
/// Public endpoint — no session/cookie required, since the user isn't
/// logged in yet when they hit this.
class DeviceLockRequestService {
  static Future<void> submit(String conflictToken, String reason) async {
    final dio = await GeuApiClient.instance;
    final res = await dio.post(
      '/api-auth/device-lock/access-requests',
      data: {'conflict_token': conflictToken, 'reason': reason},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception(body['message'] ?? 'Gagal mengirim pengajuan');
    }
  }
}
