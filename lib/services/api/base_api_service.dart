import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/api_response.dart';

// Base API Service
class ApiService {
  static const String baseURL = 'https://erp.greenenergiutama.co.id';
  // For production use: 'https://erp.greenenergiutama.co.id'

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<ApiResponse<T>> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) fromJson,
  ) async {
    try {
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.fromJson(data, fromJson);
      } else {
        return ApiResponse<T>(
          status: false,
          message: data['message'] ?? 'HTTP Error ${response.statusCode}',
          errors: data['errors'],
        );
      }
    } catch (e) {
      return ApiResponse<T>(
        status: false,
        message: 'Error parsing response: $e',
      );
    }
  }

  static Future<ApiResponse<List<T>>> _handleListResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data['status'] == true && data['data'] is List) {
          final List<T> items = (data['data'] as List)
              .map((item) => fromJson(item as Map<String, dynamic>))
              .toList();
          return ApiResponse<List<T>>(
            status: data['status'],
            message: data['message'] ?? 'Success',
            data: items,
          );
        }
        return ApiResponse<List<T>>(
          status: data['status'] ?? false,
          message: data['message'] ?? 'Unknown error',
        );
      } else {
        return ApiResponse<List<T>>(
          status: false,
          message: data['message'] ?? 'HTTP Error ${response.statusCode}',
          errors: data['errors'],
        );
      }
    } catch (e) {
      return ApiResponse<List<T>>(
        status: false,
        message: 'Error parsing response: $e',
      );
    }
  }

  // Generic GET request
  static Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$baseURL$endpoint');
    print('GET Request: $uri');

    try {
      final response = await http.get(uri, headers: headers);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('GET Request failed: $e');
      rethrow;
    }
  }

  // Generic POST request
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseURL$endpoint');
    print('POST Request: $uri');
    print('POST Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(body),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('POST Request failed: $e');
      rethrow;
    }
  }

  // Generic PUT request
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseURL$endpoint');
    print('PUT Request: $uri');
    print('PUT Body: ${json.encode(body)}');

    try {
      final response = await http.put(
        uri,
        headers: headers,
        body: json.encode(body),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('PUT Request failed: $e');
      rethrow;
    }
  }
}
