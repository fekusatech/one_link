import '../models/api_response.dart';
import '../models/supplier_list_model.dart';
import '../models/supplier_order_history.dart';
import 'user_storage.dart';
import 'geu/geu_api_client.dart';

class SupplierListService {
  /// Order-history slice of a supplier's full detail (last order date,
  /// lifetime totals, recent orders for a mini chart) — used by the
  /// "Detail Supplier" map-marker sheet. Only existing m_supplier rows
  /// resolve here; scanned/prospect pins never have a real id to call this
  /// with.
  static Future<SupplierOrderSummary?> getSupplierOrderSummary(int id) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get('/api/suppliers/$id');
      final body = response.data as Map<String, dynamic>;
      if (body['status'] != 'success' || body['data'] == null) return null;
      return SupplierOrderSummary.fromJson(body['data'] as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching supplier order summary: $e');
      return null;
    }
  }

  /// Records whether a WA follow-up actually reached the supplier — the
  /// confirmation shown right after a rep returns from the WhatsApp app.
  /// [message] is the default generated follow-up text (logged for the
  /// "Riwayat Follow Up" history even though the rep may have edited it
  /// inside WhatsApp before sending). Returns true on success.
  static Future<bool> updateWaStatus(
    int supplierId, {
    required bool valid,
    String? reason,
    String? message,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.put(
        '/api/suppliers/$supplierId/wa-status',
        data: {
          'valid': valid,
          if (reason != null) 'reason': reason,
          if (message != null) 'message': message,
        },
      );
      final body = response.data;
      return body is Map && body['status'] == 'success';
    } catch (e) {
      print('❌ Error updating WA status: $e');
      return false;
    }
  }

  /// Fetch supplier list with filter by pic_id and date
  static Future<ApiResponse<SupplierListResponse>> getSupplierList({
    int page = 1,
    int limit = 10,
    int? picId,
    String? search,
    String? date, // Format: YYYY-MM-DD
  }) async {
    try {
      // If no picId provided, use current user's ID
      if (picId == null) {
        picId = await UserStorage.getUserId();
      }

      // go-rest-api's current supplier endpoint is cursor based. Keep this
      // service's page-shaped return type for existing mobile screens.
      final queryParams = <String, String>{'limit': limit.toString()};

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (date != null && date.isNotEmpty) {
        queryParams['date_from'] = date;
      }

      final response = await (await GeuApiClient.instance).get(
        '/api/suppliers/',
        queryParameters: queryParams,
      );

      print('📋 Supplier List Response Status: ${response.statusCode}');
      print('📋 Supplier List Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = Map<String, dynamic>.from(response.data as Map);

        final payload = responseData['data'];
        final supplierListResponse = payload is Map<String, dynamic>
            ? SupplierListResponse.fromJson(payload)
            : payload is Map
            ? SupplierListResponse.fromJson(Map<String, dynamic>.from(payload))
            : SupplierListResponse(
                data: const [],
                total: 0,
                currentPage: page,
                lastPage: page,
              );

        return ApiResponse<SupplierListResponse>(
          status: responseData['status'] == 'success',
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
