import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'emergency_shake_service.dart';
import 'proximity_wa_service.dart';

class UserStorage {
  static const String _keyUser = 'user_data';
  static const String _keyToken = 'auth_token';
  static const String _keyPhone = 'user_phone';
  static const _secureStorage = FlutterSecureStorage();

  // Save user data after login
  static Future<void> saveUser({
    required Map<String, dynamic> user,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user));
    await _secureStorage.write(key: _keyToken, value: token);
    await prefs.setString(_keyPhone, user['phone'] ?? '');
  }

  // Get user data
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyUser);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = await _secureStorage.read(key: _keyToken);
    if (secure != null) return secure;
    final legacy = prefs.getString(_keyToken);
    if (legacy != null) {
      await _secureStorage.write(key: _keyToken, value: legacy);
      await prefs.remove(_keyToken);
    }
    return legacy;
  }

  // Get user name
  static Future<String> getUserName() async {
    final user = await getUser();
    return user?['name'] ?? 'User';
  }

  // Get user phone
  static Future<String> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone) ?? '';
  }

  // Get user ID
  static Future<int?> getUserId() async {
    try {
      final user = await getUser();
      if (user?['id'] != null) {
        final id = user!['id'];
        if (id is int) {
          return id;
        } else if (id is String) {
          return int.tryParse(id);
        } else {
          return int.tryParse(id.toString());
        }
      }
      return null;
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  // Get user email
  static Future<String> getUserEmail() async {
    final user = await getUser();
    return user?['email'] ?? '';
  }

  // Get user company
  static Future<String> getUserCompany() async {
    final user = await getUser();
    return user?['company'] ?? '';
  }

  // Get user groups
  static Future<List<dynamic>?> getUserGroups() async {
    final user = await getUser();
    return user?['groups'];
  }

  // Location tracking consent management
  static const String _keyLocationConsent = 'location_tracking_consent';
  static const String _keyLocationConsentDate = 'location_consent_date';
  static const String _keyMandatoryGpsConsent = 'mandatory_gps_consent_given';
  static const String _keyAppFirstRun = 'app_first_run';

  static Future<void> setLocationTrackingConsent(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocationConsent, consent);
    await prefs.setString(
      _keyLocationConsentDate,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> hasLocationTrackingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocationConsent) ?? false;
  }

  static Future<DateTime?> getLocationConsentDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_keyLocationConsentDate);
    return dateString != null ? DateTime.parse(dateString) : null;
  }

  // Mandatory GPS consent management
  static Future<void> setMandatoryGpsConsentGiven(bool given) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMandatoryGpsConsent, given);
    await prefs.setString(
      _keyLocationConsentDate,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> hasMandatoryGpsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMandatoryGpsConsent) ?? false;
  }

  // App first run management
  static Future<void> setAppFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppFirstRun, false);
  }

  static Future<bool> isAppFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAppFirstRun) ?? true; // Default true for first run
  }

  // Clear all user data (logout)
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await _secureStorage.delete(key: _keyToken);
    await prefs.remove(_keyPhone);

    // Stop emergency shake listener on logout
    EmergencyShakeService.instance.stopListening();
    // Stop proximity WA listener on logout
    ProximityWaService.instance.stop();
    ProximityWaService.instance.resetSession();

    // Clear all user-scoped cached Surat Jalan data
    final keys = prefs.getKeys().where((k) => k.startsWith('tms_cached_today_surat_jalan_json_')).toList();
    for (var k in keys) {
      await prefs.remove(k);
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Working Mode (Shift Tracking) State ──
  static const String _keyWorkingMode = 'is_working_mode_active';

  static Future<bool> isWorkingModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWorkingMode) ?? true; // Default true (features enabled)
  }

  static Future<void> setWorkingModeActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWorkingMode, active);
  }
}
