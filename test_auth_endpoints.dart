import 'dart:convert';
import 'package:http/http.dart' as http;

// Quick test script for auth endpoints
void main() async {
  await testAuthEndpoints();
}

Future<void> testAuthEndpoints() async {
  const baseUrl = 'https://greenenergiutama.co.id';
  const phoneNumber = '082140647578';

  final endpoints = [
    '$baseUrl/login',
    '$baseUrl/api/login',
    '$baseUrl/auth/login',
    '$baseUrl/api/auth/login',
    '$baseUrl/api/auth/request-otp',
    '$baseUrl/api/otp/request',
    '$baseUrl/otp/request',
  ];

  print('🔍 Testing Auth Endpoints');
  print('=' * 50);

  for (final endpoint in endpoints) {
    print('\n🔄 Testing: $endpoint');

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

      print('📡 Status: ${response.statusCode}');
      print('📏 Body Length: ${response.body.length}');
      print('📋 Headers: ${response.headers}');

      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          print(
            '📄 Body (JSON): ${const JsonEncoder.withIndent('  ').convert(data)}',
          );
        } catch (e) {
          print('📄 Body (Raw): "${response.body}"');
        }
      } else {
        print('📄 Body: EMPTY');
      }

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        print('✅ POTENTIAL WORKING ENDPOINT!');
      }
    } catch (e) {
      print('❌ Error: $e');
    }

    print('-' * 30);
  }

  print('\n🏁 Test Complete');
}
