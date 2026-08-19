import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';
import '../models/api_response.dart';
import '../models/supplier_detail_model.dart';
import 'user_storage.dart';

class SupplierDetailService {
  static const String baseUrl = AppConfig.serverDomain;

  /// Fetch supplier detail by ID
  static Future<ApiResponse<SupplierDetail>> getSupplierDetail(
    String id,
  ) async {
    try {
      final token = await UserStorage.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api-supplier/detail/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📋 Supplier Detail Response Status: ${response.statusCode}');
      print('📋 Supplier Detail Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        return ApiResponse<SupplierDetail>.fromJson(
          responseData,
          (data) => SupplierDetail.fromJson(data),
        );
      } else {
        return ApiResponse<SupplierDetail>(
          status: false,
          message: 'Failed to get supplier detail: ${response.statusCode}',
          data: null,
        );
      }
    } catch (e) {
      print('❌ Error fetching supplier detail: $e');
      return ApiResponse<SupplierDetail>(
        status: false,
        message: 'Network error: $e',
        data: null,
      );
    }
  }

  /// Fetch supplier detail by current logged-in user ID
  static Future<ApiResponse<SupplierDetail>>
  getCurrentUserSupplierDetail() async {
    try {
      final userId = await UserStorage.getUserId();

      if (userId == null) {
        return ApiResponse<SupplierDetail>(
          status: false,
          message: 'User ID not found. Please login again.',
          data: null,
        );
      }

      return await getSupplierDetail(userId.toString());
    } catch (e) {
      print('❌ Error fetching current user supplier detail: $e');
      return ApiResponse<SupplierDetail>(
        status: false,
        message: 'Error getting user supplier data: $e',
        data: null,
      );
    }
  }
}
