import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../persistent_auth_service.dart';
import '../user_storage.dart';
import 'geu_api_client.dart';

class GeuUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;

  GeuUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
  });

  factory GeuUser.fromJson(Map<String, dynamic> json) {
    return GeuUser(
      id: json['id'] ?? json['user_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      permissions:
          (json['permissions'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }

  bool hasPermission(String slug) => permissions.contains(slug);
}

/// Auth against the new Go REST API (doc.md). Session lives in httpOnly
/// cookies managed by GeuApiClient; this only caches the profile locally
/// so the UI knows who's logged in without a network round-trip.
class GeuAuthService {
  static const _keyLoggedIn = 'geu_logged_in';
  static const _keyUserId = 'geu_user_id';
  static const _keyName = 'geu_user_name';
  static const _keyEmail = 'geu_user_email';
  static const _keyRoles = 'geu_roles';
  static const _keyPermissions = 'geu_permissions';

  static const _secureKeyEmail = 'geu_cred_email';
  static const _secureKeyPassword = 'geu_cred_password';
  static const _storage = FlutterSecureStorage();

  static Future<GeuUser> login(
    String email,
    String password, {
    bool rememberCredentials = true,
  }) async {
    // A main-app login may switch accounts without visiting the Canvassing
    // logout screen. Never allow the previous account's persisted cookies or
    // cached profile to survive that transition.
    await GeuApiClient.clearSession();
    await _clearCachedProfile();
    final dio = await GeuApiClient.instance;
    final res = await dio.post(
      '/api-auth/login',
      data: {'email': email, 'password': password},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception(body['message'] ?? 'Login gagal');
    }

    final data = body['data'] as Map<String, dynamic>;
    final user = GeuUser(
      id: data['user_id'] ?? 0,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      roles: (data['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      permissions:
          (data['permissions'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
    await _saveProfile(user);
    if (rememberCredentials) {
      // Encrypted (Keystore/Keychain), not plaintext — lets ensureSession()
      // silently re-open a Canvassing session on every app start, including
      // for users who auto-login via a still-valid main-app token and never
      // pass through a password field.
      await _storage.write(key: _secureKeyEmail, value: email);
      await _storage.write(key: _secureKeyPassword, value: password);
    }
    return user;
  }

  /// Driver session, isolated from the main-app login (same pattern as
  /// Canvassing): sends a WhatsApp OTP to `phone` via the Go API's own
  /// otp/request endpoint. This does NOT touch the driver's existing PHP
  /// session — it only prepares a fresh Go cookie session for TMS calls
  /// (Surat Jalan, etc).
  static Future<void> requestDriverOtp(String phone) async {
    final dio = await GeuApiClient.instance;
    final res = await dio.post(
      '/api-auth/otp/request',
      data: {'phone': phone},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception(body['message'] ?? 'Gagal mengirim kode OTP');
    }
  }

  /// Verifies the OTP sent by [requestDriverOtp] and opens a Go API session
  /// (httpOnly cookies) for the current device, same as [login].
  static Future<GeuUser> verifyDriverOtp(String phone, String code) async {
    await GeuApiClient.clearSession();
    await _clearCachedProfile();
    final dio = await GeuApiClient.instance;
    final res = await dio.post(
      '/api-auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception(body['message'] ?? 'Kode OTP salah atau sudah kedaluwarsa');
    }

    final data = body['data'] as Map<String, dynamic>;
    final user = GeuUser(
      id: data['user_id'] ?? 0,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      roles: (data['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      permissions:
          (data['permissions'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
    await _saveProfile(user);
    return user;
  }

  /// Completes the browser-based One Login handoff. The value received by the
  /// app is a single-use, short-lived code — never a Google credential or JWT
  /// in the deep-link URL.
  static Future<GeuUser> loginWithSsoCode(String code) async {
    if (code.trim().isEmpty) {
      throw Exception('Kode login tidak ditemukan. Silakan coba lagi.');
    }

    await GeuApiClient.clearSession();
    await _clearCachedProfile();
    final dio = await GeuApiClient.instance;
    final res = await dio.post(
      '/api-auth/sso/exchange',
      data: {'code': code},
      options: Options(headers: {'X-Client-Type': 'mobile'}),
    );

    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success' || body['data'] is! Map) {
      throw Exception(body['message'] ?? 'Login Google tidak dapat diselesaikan.');
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final user = GeuUser.fromJson(data);
    final tokenData = data['tokens'];
    final accessData = tokenData is Map ? tokenData['access'] : null;
    final token = accessData is Map ? accessData['token']?.toString() ?? '' : '';
    final expiresAt = accessData is Map
        ? accessData['expires']?.toString() ?? ''
        : '';

    if (token.isEmpty || expiresAt.isEmpty) {
      throw Exception('Sesi login belum tersedia. Perbarui layanan dan coba lagi.');
    }

    await _saveProfile(user);
    await _saveMainAppSession(user, token, expiresAt);
    return user;
  }

  static Future<void> _saveMainAppSession(
    GeuUser user,
    String token,
    String expiresAt,
  ) async {
    final groups = user.roles.map((role) => {'name': role}).toList();
    await UserStorage.saveUser(
      user: {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': '',
        'groups': groups,
      },
      token: token,
    );
    await PersistentAuthService.instance.saveLoginData(
      token: token,
      userId: user.id.toString(),
      userName: user.name,
      userPhone: '',
      userEmail: user.email,
      tokenExpiry: expiresAt,
    );
  }

  /// Call opportunistically at app start (after the main app's own
  /// auto-login). No-ops if a session is already valid; otherwise retries
  /// login with the securely cached credentials, if any exist.
  static Future<bool> ensureSession() async {
    if (await checkAuth() != null) return true;
    final email = await _storage.read(key: _secureKeyEmail);
    final password = await _storage.read(key: _secureKeyPassword);
    if (email == null || password == null) return false;
    try {
      await login(email, password);
      return true;
    } catch (_) {
      // stay logged out of Canvassing; its screens show a clear error
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      final dio = await GeuApiClient.instance;
      await dio.post('/api-auth/logout');
    } catch (_) {
      // best-effort; clear local state regardless
    }
    await GeuApiClient.clearSession();
    await _storage.delete(key: _secureKeyEmail);
    await _storage.delete(key: _secureKeyPassword);
    await _clearCachedProfile();
  }

  static Future<void> _clearCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyLoggedIn),
      prefs.remove(_keyUserId),
      prefs.remove(_keyName),
      prefs.remove(_keyEmail),
      prefs.remove(_keyRoles),
      prefs.remove(_keyPermissions),
    ]);
  }

  /// Hits /api-auth/me to confirm the cached session is still valid
  /// server-side, refreshing the cached profile in the process.
  static Future<GeuUser?> checkAuth() async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api-auth/me');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success' || body['data'] == null) {
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final roles =
          (data['groups'] as List?)
              ?.map((g) => (g as Map<String, dynamic>)['name'].toString())
              .toList() ??
          [];
      final user = GeuUser(
        id: data['id'] ?? 0,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        roles: roles,
        permissions:
            (data['permissions'] as List?)?.map((e) => e.toString()).toList() ??
            [],
      );
      await _saveProfile(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Local-only check (no network) — whether a previous login was cached.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<GeuUser?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyLoggedIn) ?? false)) return null;
    return GeuUser(
      id: int.tryParse(prefs.getString(_keyUserId) ?? '') ?? 0,
      name: prefs.getString(_keyName) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
      roles: prefs.getStringList(_keyRoles) ?? [],
      permissions: prefs.getStringList(_keyPermissions) ?? [],
    );
  }

  static Future<void> _saveProfile(GeuUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyLoggedIn, true),
      prefs.setString(_keyUserId, user.id.toString()),
      prefs.setString(_keyName, user.name),
      prefs.setString(_keyEmail, user.email),
      prefs.setStringList(_keyRoles, user.roles),
      prefs.setStringList(_keyPermissions, user.permissions),
    ]);
  }
}
