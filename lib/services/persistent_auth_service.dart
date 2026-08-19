import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PersistentAuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userPhoneKey = 'user_phone';
  static const String _userEmailKey = 'user_email';
  static const String _tokenExpiryKey = 'token_expiry';

  static PersistentAuthService? _instance;
  static PersistentAuthService get instance =>
      _instance ??= PersistentAuthService._();

  PersistentAuthService._();

  SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage();

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Simpan data login ke persistent storage
  Future<bool> saveLoginData({
    required String token,
    required String userId,
    required String userName,
    required String userPhone,
    required String userEmail,
    required String tokenExpiry,
  }) async {
    try {
      await _initPrefs();

      await Future.wait([
        _prefs!.setString(_userIdKey, userId),
        _prefs!.setString(_userNameKey, userName),
        _prefs!.setString(_userPhoneKey, userPhone),
        _prefs!.setString(_userEmailKey, userEmail),
        _prefs!.setString(_tokenExpiryKey, tokenExpiry),
      ]);
      await _secureStorage.write(key: _tokenKey, value: token);

      print('✅ Auth data saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving auth data: $e');
      return false;
    }
  }

  /// Ambil token yang tersimpan
  Future<String?> getToken() async {
    await _initPrefs();
    final secure = await _secureStorage.read(key: _tokenKey);
    if (secure != null) return secure;
    // One-time migration from legacy plaintext preferences.
    final legacy = _prefs!.getString(_tokenKey);
    if (legacy != null) {
      await _secureStorage.write(key: _tokenKey, value: legacy);
      await _prefs!.remove(_tokenKey);
    }
    return legacy;
  }

  /// Ambil user ID yang tersimpan
  Future<String?> getUserId() async {
    await _initPrefs();
    return _prefs!.getString(_userIdKey);
  }

  /// Ambil user name yang tersimpan
  Future<String?> getUserName() async {
    await _initPrefs();
    return _prefs!.getString(_userNameKey);
  }

  /// Ambil user phone yang tersimpan
  Future<String?> getUserPhone() async {
    await _initPrefs();
    return _prefs!.getString(_userPhoneKey);
  }

  /// Ambil user email yang tersimpan
  Future<String?> getUserEmail() async {
    await _initPrefs();
    return _prefs!.getString(_userEmailKey);
  }

  /// Ambil token expiry yang tersimpan
  Future<String?> getTokenExpiry() async {
    await _initPrefs();
    return _prefs!.getString(_tokenExpiryKey);
  }

  /// Cek apakah user sudah login dan token masih valid
  Future<bool> isLoggedIn() async {
    try {
      await _initPrefs();

      final token = await getToken();
      final tokenExpiry = _prefs!.getString(_tokenExpiryKey);

      if (token == null || tokenExpiry == null) {
        print('🔍 No token or expiry found');
        return false;
      }

      // Parse expiry date
      final expiryDate = DateTime.tryParse(tokenExpiry);
      if (expiryDate == null) {
        print('🔍 Invalid expiry date format');
        return false;
      }

      // Cek apakah token sudah expired
      final isExpired = DateTime.now().isAfter(expiryDate);
      if (isExpired) {
        print('🔍 Token expired, clearing auth data');
        await clearAuthData();
        return false;
      }

      print('✅ User is logged in with valid token');
      return true;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  /// Hapus semua data auth (logout)
  Future<bool> clearAuthData() async {
    try {
      await _initPrefs();

      await Future.wait([
        _prefs!.remove(_userIdKey),
        _prefs!.remove(_userNameKey),
        _prefs!.remove(_userPhoneKey),
        _prefs!.remove(_userEmailKey),
        _prefs!.remove(_tokenExpiryKey),
      ]);
      await _secureStorage.delete(key: _tokenKey);

      print('✅ Auth data cleared successfully');
      return true;
    } catch (e) {
      print('❌ Error clearing auth data: $e');
      return false;
    }
  }

  /// Ambil semua data user yang tersimpan
  Future<Map<String, String?>> getUserData() async {
    await _initPrefs();

    return {
      'token': await getToken(),
      'userId': _prefs!.getString(_userIdKey),
      'userName': _prefs!.getString(_userNameKey),
      'userPhone': _prefs!.getString(_userPhoneKey),
      'userEmail': _prefs!.getString(_userEmailKey),
      'tokenExpiry': _prefs!.getString(_tokenExpiryKey),
    };
  }

  /// Cek apakah token akan expired dalam waktu tertentu (dalam hari)
  Future<bool> willExpireSoon({int days = 7}) async {
    try {
      await _initPrefs();

      final tokenExpiry = _prefs!.getString(_tokenExpiryKey);
      if (tokenExpiry == null) return false;

      final expiryDate = DateTime.tryParse(tokenExpiry);
      if (expiryDate == null) return false;

      final warningDate = DateTime.now().add(Duration(days: days));
      return expiryDate.isBefore(warningDate);
    } catch (e) {
      print('❌ Error checking token expiry: $e');
      return false;
    }
  }

  /// Update hanya token (untuk refresh token)
  Future<bool> updateToken({
    required String newToken,
    required String newExpiry,
  }) async {
    try {
      await _initPrefs();

      await Future.wait([_prefs!.setString(_tokenExpiryKey, newExpiry)]);
      await _secureStorage.write(key: _tokenKey, value: newToken);

      print('✅ Token updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating token: $e');
      return false;
    }
  }
}
