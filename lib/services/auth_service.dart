import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://erp.greenenergiutama.co.id/api';

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> userData,
  ) async {
    try {
      print('Updating profile: $userData');

      // TODO: Implement actual API call when endpoint is available
      // For now, just return success
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay

      return {'success': true, 'message': 'Profile updated successfully'};

      /* Uncomment when API is ready:
      final token = await UserStorage.getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return {'success': true, 'data': responseData['data']};
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Update profile failed',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
      */
    } catch (e) {
      print('Error updating profile: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Request OTP
  static Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    try {
      print('Requesting OTP for: $phoneNumber');
      print('URL: $baseUrl/login');

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': phoneNumber, 'requestotp': 'true'}),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return {'success': true, 'data': responseData['data']};
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Terjadi kesalahan',
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Terjadi kesalahan',
        };
      }
    } catch (e) {
      print('Error requesting OTP: $e');
      return {
        'success': false,
        'message': 'Koneksi gagal. Silakan coba lagi. Error: $e',
      };
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(
    String otp,
    String sessionToken,
  ) async {
    try {
      final body = {'otp': otp, 'session_token': sessionToken};

      print('Verifying OTP');
      print('URL: $baseUrl/login');
      print('Body: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return {'success': true, 'data': responseData['data']};
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Kode OTP salah',
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Kode OTP salah',
        };
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Koneksi gagal. Silakan coba lagi. Error: $e',
      };
    }
  }
}
