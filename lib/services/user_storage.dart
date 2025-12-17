import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserStorage {
  static const String _keyUser = 'user_data';
  static const String _keyToken = 'auth_token';
  static const String _keyPhone = 'user_phone';

  // Save user data after login
  static Future<void> saveUser({
    required Map<String, dynamic> user,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user));
    await prefs.setString(_keyToken, token);
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
    return prefs.getString(_keyToken);
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
    final user = await getUser();
    return user?['id'];
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

  // Clear all user data (logout)
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyPhone);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
