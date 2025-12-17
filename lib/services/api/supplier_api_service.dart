import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/api_response.dart';
import '../../models/dropdown_models.dart';
import '../../models/geographic_models.dart';
import '../../models/supplier_model.dart';
import 'base_api_service.dart';

class SupplierApiService extends ApiService {
  // Get all dropdown options in one call
  static Future<ApiResponse<Map<String, dynamic>>> getDropdownOptions() async {
    try {
      final response = await ApiService.get('/api-supplier/dropdown-options');
      return _handleResponse(response, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get provinces
  static Future<ApiResponse<List<Province>>> getProvinces() async {
    try {
      final response = await ApiService.get('/api-supplier/provinces');
      return _handleListResponse(response, Province.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get cities by province
  static Future<ApiResponse<List<City>>> getCities(int provinceId) async {
    try {
      final response = await ApiService.get('/api-supplier/cities/$provinceId');
      return _handleListResponse(response, City.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get districts by city
  static Future<ApiResponse<List<District>>> getDistricts(int cityId) async {
    try {
      final response = await ApiService.get('/api-supplier/districts/$cityId');
      return _handleListResponse(response, District.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get villages by district
  static Future<ApiResponse<List<Village>>> getVillages(int districtId) async {
    try {
      final response = await ApiService.get(
        '/api-supplier/villages/$districtId',
      );
      return _handleListResponse(response, Village.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get supplier types
  static Future<ApiResponse<List<JenisSupplier>>> getJenisSupplier() async {
    try {
      final response = await ApiService.get('/api-supplier/jenis-supplier');
      return _handleListResponse(response, JenisSupplier.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get supplier categories
  static Future<ApiResponse<List<KategoriSupplier>>>
  getKategoriSupplier() async {
    try {
      final response = await ApiService.get('/api-supplier/kategori-supplier');
      return _handleListResponse(response, KategoriSupplier.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get employees
  static Future<ApiResponse<List<Employee>>> getEmployees() async {
    try {
      final response = await ApiService.get('/api-supplier/employees');
      return _handleListResponse(response, Employee.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get banks
  static Future<ApiResponse<List<Bank>>> getBanks() async {
    try {
      final response = await ApiService.get('/api-supplier/banks');
      return _handleListResponse(response, Bank.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get units
  static Future<ApiResponse<List<Satuan>>> getSatuan() async {
    try {
      final response = await ApiService.get('/api-supplier/satuan');
      return _handleListResponse(response, Satuan.fromJson);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Create supplier
  static Future<ApiResponse<Map<String, dynamic>>> createSupplier(
    Supplier supplier,
  ) async {
    try {
      final response = await ApiService.post(
        '/api-supplier/create',
        supplier.toJson(),
      );
      return _handleResponse(response, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get supplier list with pagination
  static Future<ApiResponse<SupplierListResponse>> getSupplierList({
    int page = 1,
    int limit = 25,
    String search = '',
    String status = '',
    String category = '',
  }) async {
    try {
      String endpoint = '/api-supplier/list?page=$page&limit=$limit';

      if (search.isNotEmpty) {
        endpoint += '&search=$search';
      }
      if (status.isNotEmpty) {
        endpoint += '&status=$status';
      }
      if (category.isNotEmpty) {
        endpoint += '&category=$category';
      }

      final response = await ApiService.get(endpoint);
      return _handleResponse(
        response,
        (data) => SupplierListResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Get supplier detail
  static Future<ApiResponse<Supplier>> getSupplierDetail(int id) async {
    try {
      final response = await ApiService.get('/api-supplier/detail/$id');
      return _handleResponse(
        response,
        (data) => Supplier.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Update supplier
  static Future<ApiResponse<Map<String, dynamic>>> updateSupplier(
    int id,
    Supplier supplier,
  ) async {
    try {
      final response = await ApiService.put(
        '/api-supplier/update/$id',
        supplier.toJson(),
      );
      return _handleResponse(response, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Toggle supplier status
  static Future<ApiResponse<Map<String, dynamic>>> toggleSupplierStatus(
    int id,
  ) async {
    try {
      final response = await ApiService.put(
        '/api-supplier/toggle-status/$id',
        {},
      );
      return _handleResponse(response, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Validate bank account (Optional BIFast validation)
  static Future<ApiResponse<Map<String, dynamic>>> validateAccount({
    required String nomorRek,
    required String bank,
    required String namaRek,
  }) async {
    try {
      final response = await ApiService.post('/api-supplier/validate-account', {
        'nomor_rek': nomorRek,
        'bank': bank,
        'nama_rek': namaRek,
      });
      return _handleResponse(response, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse(status: false, message: 'Network error: $e');
    }
  }

  // Helper methods
  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) fromJson,
  ) {
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

  static ApiResponse<List<T>> _handleListResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data['status'] == true && data['data'] is List) {
          final List<T> items = (data['data'] as List)
              .map((item) => fromJson(item as Map<String, dynamic>))
              .toList();

          return ApiResponse<List<T>>(
            status: true,
            message: data['message'],
            data: items,
          );
        } else {
          return ApiResponse<List<T>>(
            status: false,
            message: data['message'] ?? 'No data found',
          );
        }
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
}
