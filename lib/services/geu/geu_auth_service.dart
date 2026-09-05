import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../persistent_auth_service.dart';
import '../user_storage.dart';
import 'geu_api_client.dart';
import 'push_notification_service.dart';

/// One entry in the account switcher — every account ever successfully
/// logged into on this device. Password lives in the same OS-encrypted
/// secure vault ensureSession() already trusts for the single "current"
/// account; this just keeps one per remembered account instead of one slot
/// total.
class SavedAccount {
  final String email;
  final String password;
  final String name;

  const SavedAccount({
    required this.email,
    required this.password,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'name': name,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    email: json['email']?.toString() ?? '',
    password: json['password']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

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
  static const _secureKeyAccounts = 'geu_saved_accounts';
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

    // Extract auth_token JWT from Set-Cookie header if present
    String jwtToken = '';
    final rawCookies = res.headers['set-cookie'] ?? [];
    for (var header in rawCookies) {
      if (header.contains('auth_token=')) {
        final match = RegExp(r'auth_token=([^;]+)').firstMatch(header);
        if (match != null) {
          jwtToken = match.group(1) ?? '';
          break;
        }
      }
    }

    await UserStorage.saveUser(
      user: {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'groups': user.roles,
        'roles': user.roles,
      },
      token: jwtToken,
    );

    if (rememberCredentials) {
      await _storage.write(key: _secureKeyEmail, value: email);
      await _storage.write(key: _secureKeyPassword, value: password);
      // Server-confirmed email/name (not the raw, possibly differently-cased
      // input) so the switcher list and the "current account" comparison
      // it does against getCachedUser() always match on the same casing.
      await _rememberAccount(
        SavedAccount(email: user.email, password: password, name: user.name),
      );
    }
    unawaited(PushNotificationService.registerToken());
    return user;
  }

  /// Every account this device has ever logged into, most-recently-used
  /// first — the account switcher's data source.
  static Future<List<SavedAccount>> getSavedAccounts() async {
    final raw = await _storage.read(key: _secureKeyAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _rememberAccount(SavedAccount account) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere(
      (a) => a.email.toLowerCase() == account.email.toLowerCase(),
    );
    accounts.insert(0, account);
    await _storage.write(
      key: _secureKeyAccounts,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Removes an account from the switcher only — does not touch its actual
  /// session server-side. Use when a saved password stops working (changed
  /// server-side) or the user explicitly wants it off this device's list.
  static Future<void> forgetSavedAccount(String email) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.email.toLowerCase() == email.toLowerCase());
    await _storage.write(
      key: _secureKeyAccounts,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Switches the active session to [email] using its remembered password
  /// — a full login (clears the old session first), just without retyping
  /// anything. Throws if the account isn't saved, or the saved password no
  /// longer works (changed server-side since it was remembered).
  static Future<GeuUser> switchToAccount(String email) async {
    final accounts = await getSavedAccounts();
    final account = accounts.firstWhere(
      (a) => a.email.toLowerCase() == email.toLowerCase(),
      orElse: () =>
          throw Exception('Akun tidak ditemukan di perangkat ini.'),
    );
    return login(account.email, account.password);
  }

  /// Refresh & cache the current user's avatar from the Go API.
  ///
  /// login() only caches {id, name, email, groups, roles} — nothing calls
  /// this again after that, and the legacy PHP `driver_tracking/get_profile`
  /// endpoint some screens used to poll for the avatar is dead now that
  /// apipi.greenenergiutama.co.id serves only the Go API (404). GET
  /// /api-auth/me is the real replacement (model.User.Profile already
  /// includes `avatar`). Any screen showing a profile photo should call
  /// this once and fall back to whatever's already cached in UserStorage.
  static Future<String?> syncAvatar() async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api-auth/me');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') return null;

      final data = body['data'] as Map<String, dynamic>?;
      final avatar = data?['avatar']?.toString().trim();
      if (avatar == null || avatar.isEmpty) return null;

      final user = await UserStorage.getUser();
      final token = await UserStorage.getToken();
      if (user != null && token != null) {
        await UserStorage.saveUser(
          user: {...user, 'avatar': avatar, 'avatar_path': avatar},
          token: token,
        );
      }
      return avatar;
    } catch (_) {
      return null;
    }
  }

  /// Driver session, isolated from the main-app login (same pattern as
  /// Canvassing): sends a WhatsApp OTP to `phone` via the Go API's own
  /// otp/request endpoint. This does NOT touch the driver's existing PHP
  /// session — it only prepares a fresh Go cookie session for TMS calls
  /// (Surat Jalan, etc).
  static Future<void> requestDriverOtp(String phone) async {
    final dio = await GeuApiClient.instance;
    final res = await dio.post('/api-auth/otp/request', data: {'phone': phone});
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
      throw Exception(
        body['message'] ?? 'Kode OTP salah atau sudah kedaluwarsa',
      );
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
      throw Exception(
        body['message'] ?? 'Login Google tidak dapat diselesaikan.',
      );
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final user = GeuUser.fromJson(data);
    final tokenData = data['tokens'];
    final accessData = tokenData is Map ? tokenData['access'] : null;
    final token = accessData is Map
        ? accessData['token']?.toString() ?? ''
        : '';
    final expiresAt = accessData is Map
        ? accessData['expires']?.toString() ?? ''
        : '';

    if (token.isEmpty || expiresAt.isEmpty) {
      throw Exception(
        'Sesi login belum tersedia. Perbarui layanan dan coba lagi.',
      );
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

  /// Re-open the current developer session using credentials stored in the
  /// secure vault. This deliberately skips the valid-session shortcut used by
  /// [ensureSession], so it behaves like a fresh login without a form.
  static Future<bool> reloginWithStoredCredentials() async {
    try {
      final dio = await GeuApiClient.instance;
      final refreshed = await dio.post('/api-auth/refresh');
      if (refreshed.statusCode == 200) {
        final user = await checkAuth();
        if (user != null) return true;
      }
    } catch (_) {
      // Fall through to the secure credential path below.
    }
    final email = await _storage.read(key: _secureKeyEmail);
    final password = await _storage.read(key: _secureKeyPassword);
    if (email == null ||
        password == null ||
        email.isEmpty ||
        password.isEmpty) {
      return false;
    }
    try {
      await login(email, password, rememberCredentials: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    // Must happen before clearSession() — deactivating needs the still-valid
    // session to identify which user's token to turn off.
    await PushNotificationService.deactivateToken();
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
