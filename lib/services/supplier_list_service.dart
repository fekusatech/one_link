import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';
import '../models/api_response.dart';
import '../models/supplier_list_model.dart';
import 'user_storage.dart';

class SupplierListService {
  static const String baseUrl = AppConfig.serverDomain;

  /// Fetch supplier list with filter by pic_id and date
  static Future<ApiResponse<SupplierListResponse>> getSupplierList({
    int page = 1,
    int limit = 10,
    int? picId,
    String? search,
    String? date, // Format: YYYY-MM-DD
  }) async {
    try {
      final token = await UserStorage.getToken();

      // If no picId provided, use current user's ID
      if (picId == null) {
        picId = await UserStorage.getUserId();
      }

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (picId != null) {
        queryParams['pic_id'] = picId.toString();
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final uri = Uri.parse(
        '$baseUrl/api-supplier/list',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📋 Supplier List Response Status: ${response.statusCode}');
      print('📋 Supplier List Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Create SupplierListResponse directly from the API data structure
        final supplierListResponse = SupplierListResponse.fromJson(
          responseData,
        );

        return ApiResponse<SupplierListResponse>(
          status: responseData['status'] ?? false,
          message: responseData['message'] ?? '',
          data: supplierListResponse,
        );
      } else {
        return ApiResponse<SupplierListResponse>(
          status: false,
          message: 'Failed to get supplier list: ${response.statusCode}',
          data: null,
        );
      }
    } catch (e) {
      print('❌ Error fetching supplier list: $e');
      return ApiResponse<SupplierListResponse>(
        status: false,
        message: 'Network error: $e',
        data: null,
      );
    }
  }

  /// Get supplier list for current logged-in user
  static Future<ApiResponse<SupplierListResponse>> getCurrentUserSupplierList({
    int page = 1,
    int limit = 10,
    String? search,
    String? date,
  }) async {
    try {
      final userId = await UserStorage.getUserId();

      if (userId == null) {
        return ApiResponse<SupplierListResponse>(
          status: false,
          message: 'User ID not found. Please login again.',
          data: null,
        );
      }

      return await getSupplierList(
        page: page,
        limit: limit,
        picId: userId,
        search: search,
        date: date,
      );
    } catch (e) {
      print('❌ Error fetching current user supplier list: $e');
      return ApiResponse<SupplierListResponse>(
        status: false,
        message: 'Error getting user supplier list: $e',
        data: null,
      );
    }
  }

  /// Get suppliers for dashboard with default 1 month filter
  static Future<ApiResponse<SupplierListResponse>> getDashboardSuppliers({
    int limit = 50,
  }) async {
    try {
      // Calculate 1 month ago date
      final now = DateTime.now();
      final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
      final dateFilter = _formatDate(oneMonthAgo);

      return await getCurrentUserSupplierList(limit: limit, date: dateFilter);
    } catch (e) {
      print('❌ Error fetching dashboard suppliers: $e');
      return ApiResponse<SupplierListResponse>(
        status: false,
        message: 'Error getting dashboard suppliers: $e',
        data: null,
      );
    }
  }

  /// Get suppliers for specific date (for calendar)
  static Future<ApiResponse<SupplierListResponse>> getSuppliersByDate({
    required DateTime date,
    int limit = 100,
  }) async {
    try {
      final dateFilter = _formatDate(date);

      return await getCurrentUserSupplierList(limit: limit, date: dateFilter);
    } catch (e) {
      print('❌ Error fetching suppliers by date: $e');
      return ApiResponse<SupplierListResponse>(
        status: false,
        message: 'Error getting suppliers by date: $e',
        data: null,
      );
    }
  }

  /// Helper method to format date as YYYY-MM-DD
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
