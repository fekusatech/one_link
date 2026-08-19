import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/geu/geu_api_client.dart';
import '../services/user_storage.dart';
import '../services/persistent_auth_service.dart';

class ImpersonationService {
  static const String _keyImpersonating = 'is_impersonating';
  static const String _keyOriginalAdminUser = 'original_admin_user_data';

  /// Cek apakah sedang dalam mode impersonate / force login
  static Future<bool> isImpersonating() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyImpersonating) ?? false;
  }

  /// Cek apakah user memiliki hak akses Admin atau sedang Impersonating
  static Future<bool> canImpersonate() async {
    final active = await isImpersonating();
    if (active) return true;

    final user = await UserStorage.getUser();
    if (user == null) return false;

    final groups = user['groups'] as List<dynamic>? ?? user['roles'] as List<dynamic>? ?? [];
    final rolesStr = groups
        .map((g) => g is Map ? g['name']?.toString().toLowerCase() ?? '' : g.toString().toLowerCase())
        .join(' ');

    return rolesStr.contains('admin') ||
        rolesStr.contains('superadmin') ||
        rolesStr.contains('developer') ||
        rolesStr.contains('it');
  }

  /// Ambil data admin asli yang melakukan impersonate
  static Future<Map<String, dynamic>?> getOriginalAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyOriginalAdminUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Pindah login ke User ID target (Force Login / Impersonate)
  static Future<bool> impersonateTargetUser({
    required int targetUserId,
  }) async {
    try {
      final dio = await GeuApiClient.instance;

      // Simpan data admin asli jika belum dalam mode impersonate
      final alreadyImpersonating = await isImpersonating();
      if (!alreadyImpersonating) {
        final currentAdmin = await UserStorage.getUser();
        if (currentAdmin != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyImpersonating, true);
          await prefs.setString(_keyOriginalAdminUser, jsonEncode(currentAdmin));
        }
      }

      // Panggil API Backend /api-admin/impersonate
      final res = await dio.post(
        '/api-admin/impersonate',
        data: {'user_id': targetUserId},
      );

      final body = res.data as Map<String, dynamic>;
      final isSuccess = res.statusCode == 200 && (body['status'] == 'success' || body['code'] == 200);

      if (isSuccess) {
        Map<String, dynamic> targetData = {};
        if (body['data'] is Map<String, dynamic>) {
          targetData = Map<String, dynamic>.from(body['data']);
        }

        final userMap = {
          'id': targetData['id'] ?? targetUserId,
          'name': targetData['name'] ?? 'User #$targetUserId',
          'email': targetData['email'] ?? '',
          'phone': targetData['phone'] ?? '',
          'groups': targetData['roles'] ?? targetData['groups'] ?? [],
          'roles': targetData['roles'] ?? targetData['groups'] ?? [],
        };

        await UserStorage.saveUser(user: userMap, token: '');
        await PersistentAuthService.instance.saveLoginData(
          token: '',
          userId: userMap['id'].toString(),
          userName: userMap['name'].toString(),
          userPhone: userMap['phone'].toString(),
          userEmail: userMap['email'].toString(),
          tokenExpiry: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        );

        // Preserve location consent so consent dialog doesn't prompt again
        await UserStorage.setLocationTrackingConsent(true);
        await UserStorage.setMandatoryGpsConsentGiven(true);

        // Reset API client instance so new session cookies take immediate effect
        GeuApiClient.resetClient();

        return true;
      }

      final errorMsg = body['message']?.toString() ?? 'Gagal login sebagai user #$targetUserId';
      throw Exception(errorMsg);
    } on DioException catch (e) {
      final msg = e.response?.data is Map && e.response?.data['message'] != null
          ? e.response?.data['message']
          : e.message;
      print('❌ Error during impersonate force login: $msg');
      throw Exception(msg ?? 'Gagal login sebagai user #$targetUserId');
    } catch (e) {
      print('❌ Error during impersonate force login: $e');
      rethrow;
    }
  }

  /// Keluar dari mode impersonate & kembali ke Akun Admin Asli
  static Future<bool> exitImpersonation() async {
    try {
      final originalAdmin = await getOriginalAdmin();
      final prefs = await SharedPreferences.getInstance();

      if (originalAdmin != null) {
        final adminId = originalAdmin['id'];
        final dio = await GeuApiClient.instance;

        // Panggil API backend untuk switch kembali ke Admin ID
        await dio.post(
          '/api-admin/impersonate',
          data: {'user_id': adminId},
        );

        // Restore session data admin di penyimpanan lokal
        await UserStorage.saveUser(user: originalAdmin, token: '');
        await PersistentAuthService.instance.saveLoginData(
          token: '',
          userId: adminId.toString(),
          userName: originalAdmin['name']?.toString() ?? 'Admin',
          userPhone: originalAdmin['phone']?.toString() ?? '',
          userEmail: originalAdmin['email']?.toString() ?? '',
          tokenExpiry: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        );
      }

      // Bersihkan flag impersonate & reset client
      await prefs.remove(_keyImpersonating);
      await prefs.remove(_keyOriginalAdminUser);
      GeuApiClient.resetClient();

      return true;
    } catch (e) {
      print('❌ Error exiting impersonation mode: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonating);
      await prefs.remove(_keyOriginalAdminUser);
      GeuApiClient.resetClient();
      return false;
    }
  }
}
