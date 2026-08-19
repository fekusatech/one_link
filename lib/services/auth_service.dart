import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.serverDomain;
  static const String loginEndpoint = '/api/login';

  // Update profile (placeholder method)
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      // TODO: Implement actual API call
      /*
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      );

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

      // Temporary return for placeholder
      return {
        'success': false,
        'message': 'Update profile not implemented yet',
      };
    } catch (e) {
      print('Error updating profile: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login with Email
  static Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      // The backend currently only supports OTP login, but this is the UI implementation for email
      final endpoint = '$baseUrl/api/login';
      final body = {'email': email, 'password': password};

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return {
            'success': false,
            'message':
                'Server mengembalikan response kosong. Silakan coba lagi.',
          };
        }

        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            return {'success': true, 'data': responseData['data']};
          } else {
            return {
              'success': false,
              'message': responseData['message'] ?? 'Email atau password salah',
            };
          }
        } catch (jsonError) {
          return {
            'success': false,
            'message': 'Format response server tidak valid. Silakan coba lagi.',
          };
        }
      } else {
        if (response.body.isEmpty) {
          return {
            'success': false,
            'message': 'Server error ${response.statusCode}: Response kosong',
          };
        }

        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Email atau password salah',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal. Silakan coba lagi.'};
    }
  }

  // Request OTP
  static Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    try {
      // Debug: Test multiple endpoints
      final endpoints = [
        '$baseUrl/login',
        '$baseUrl/api/login',
        '$baseUrl/auth/login',
        '$baseUrl/api/auth/login',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'User-Agent':
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
                },
                body: jsonEncode({'phone': phoneNumber, 'requestotp': 'true'}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            if (response.body.isEmpty) {
              continue; // Try next endpoint
            }

            try {
              final responseData = jsonDecode(response.body);
              if (responseData['status'] == 'success') {
                return {'success': true, 'data': responseData['data']};
              } else {
                return {
                  'success': false,
                  'message': responseData['message'] ?? 'Terjadi kesalahan',
                };
              }
            } catch (jsonError) {
              continue; // Try next endpoint
            }
          } else {}
        } catch (endpointError) {
          continue; // Try next endpoint
        }
      }

      // If no endpoint works, return error
      return {
        'success': false,
        'message':
            'Tidak dapat terhubung ke server. Semua endpoint tidak tersedia.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal. Silakan coba lagi.'};
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(
    String otp,
    String sessionToken,
  ) async {
    try {
      final body = {'otp': otp, 'session_token': sessionToken};

      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/api/login',
            ), // Fix: Use same endpoint as request OTP
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Check if response body is empty
        if (response.body.isEmpty) {
          return {
            'success': false,
            'message':
                'Server mengembalikan response kosong. Silakan coba lagi.',
          };
        }

        // Check if response is valid JSON
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            return {'success': true, 'data': responseData['data']};
          } else {
            return {
              'success': false,
              'message': responseData['message'] ?? 'Kode OTP salah',
            };
          }
        } catch (jsonError) {
          return {
            'success': false,
            'message': 'Format response server tidak valid. Silakan coba lagi.',
          };
        }
      } else {
        if (response.body.isEmpty) {
          return {
            'success': false,
            'message': 'Server error ${response.statusCode}: Response kosong',
          };
        }

        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Kode OTP salah',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal. Silakan coba lagi.'};
    }
  }
}
