import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AuthService {
  static const String baseUrl = 'https://greenenergiutama.co.id';

  /// Save authentication response to auth.json file for debugging
  static Future<void> saveAuthResponseToFile(Map<String, dynamic> response) async {
    try {
      // Get application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/auth.json');
      
      // Add timestamp to response
      final responseWithTimestamp = {
        ...response,
        'saved_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
      };
      
      // Write to file with pretty formatting
      final jsonString = const JsonEncoder.withIndent('  ').convert(responseWithTimestamp);
      await file.writeAsString(jsonString);
      
      print('✅ Auth response saved to: ${file.path}');
      print('📄 File size: ${jsonString.length} characters');
    } catch (e) {
      print('❌ Error saving auth response to file: $e');
    }
  }

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
      
      // Debug: Test multiple endpoints
      final endpoints = [
        '$baseUrl/login',
        '$baseUrl/api/login',
        '$baseUrl/auth/login', 
        '$baseUrl/api/auth/login',
      ];

      for (final endpoint in endpoints) {
        print('🔄 Trying endpoint: $endpoint');
        
        try {
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({'phone': phoneNumber, 'requestotp': 'true'}),
              )
              .timeout(const Duration(seconds: 10));

          print('📡 [$endpoint] Status: ${response.statusCode}');
          print('📄 [$endpoint] Body: "${response.body}"');
          print('📋 [$endpoint] Headers: ${response.headers}');
          print('📏 [$endpoint] Body length: ${response.body.length}');

          if (response.statusCode == 200) {
            if (response.body.isEmpty) {
              print('⚠️ [$endpoint] Empty response body');
              continue; // Try next endpoint
            }

            try {
              final responseData = jsonDecode(response.body);
              if (responseData['status'] == 'success') {
                print('✅ Success with endpoint: $endpoint');
                return {'success': true, 'data': responseData['data']};
              } else {
                return {
                  'success': false,
                  'message': responseData['message'] ?? 'Terjadi kesalahan',
                };
              }
            } catch (jsonError) {
              print('❌ [$endpoint] JSON Parse Error: $jsonError');
              print('Raw response: "${response.body}"');
              continue; // Try next endpoint
            }
          } else {
            print('⚠️ [$endpoint] HTTP ${response.statusCode}');
          }
        } catch (endpointError) {
          print('❌ Error with endpoint $endpoint: $endpointError');
          continue; // Try next endpoint
        }
      }

      // If no endpoint works, return error
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Semua endpoint tidak tersedia.',
      };
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
      print('Response headers: ${response.headers}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        // Check if response body is empty
        if (response.body.isEmpty) {
          print('⚠️ Empty response body received');
          return {
            'success': false,
            'message': 'Server mengembalikan response kosong. Silakan coba lagi.',
          };
        }

        // Check if response is valid JSON
        try {
          final responseData = jsonDecode(response.body);
          
          // Save complete response to auth.json file
          await saveAuthResponseToFile(responseData);
          
          if (responseData['status'] == 'success') {
            return {'success': true, 'data': responseData['data']};
          } else {
            return {
              'success': false,
              'message': responseData['message'] ?? 'Kode OTP salah',
            };
          }
        } catch (jsonError) {
          print('❌ JSON Parse Error: $jsonError');
          print('Raw response: "${response.body}"');
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
      print('Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Koneksi gagal. Silakan coba lagi. Error: $e',
      };
    }
  }
}
