import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/api_response.dart';
import '../../models/geographic_models.dart';
import '../../models/supplier_model.dart';
import '../geu/geu_api_client.dart';

class SupplierApiService {
  static String _safeSupplierDiagnostic(Object? value) {
    var message = value?.toString() ?? '';
    message = message
        .replaceAll(
          RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAll(RegExp(r'\b(?:\+?62|0)8\d{7,12}\b'), '[PHONE]')
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '[EMAIL]',
        )
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    return message.length <= 200 ? message : '${message.substring(0, 200)}…';
  }

  static String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') || s.contains('connection')) {
      return 'Tidak ada koneksi internet.';
    }
    if (s.contains('timeout')) return 'Koneksi lambat, coba lagi.';
    if (s.contains('401')) return 'Sesi berakhir. Silakan masuk kembali.';
    if (s.contains('403')) return 'Anda tidak punya akses untuk data ini.';
    if (s.contains('409')) return 'Data supplier sudah terdaftar (duplikat).';
    return 'Gagal memuat data. Coba lagi.';
  }

  static Future<ApiResponse<Map<String, dynamic>>> getDropdownOptions() async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/suppliers/dropdowns');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memuat data dropdown',
        );
      }
      return ApiResponse(
        status: true,
        message: '',
        data: body['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<List<City>>> getCities(int provinceId) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/suppliers/cities/$provinceId');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memuat kota',
        );
      }
      final list = (body['data'] as List? ?? [])
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(status: true, message: '', data: list);
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<List<District>>> getDistricts(int cityId) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/suppliers/districts/$cityId');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memuat kecamatan',
        );
      }
      final list = (body['data'] as List? ?? [])
          .map((e) => District.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(status: true, message: '', data: list);
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<List<Village>>> getVillages(int districtId) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/suppliers/villages/$districtId');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memuat desa',
        );
      }
      final list = (body['data'] as List? ?? [])
          .map((e) => Village.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(status: true, message: '', data: list);
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getEmployees({
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get(
        '/api/suppliers/employees',
        queryParameters: {
          'search': search,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memuat karyawan',
        );
      }
      return ApiResponse(
        status: true,
        message: '',
        data: body['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> createSupplier(
    Supplier supplier,
  ) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.post('/api/suppliers/', data: supplier.toJson());
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        debugPrint(
          '[POO_CREATE] failed http=${res.statusCode ?? 0} '
          'api_status=${body['status'] ?? 'missing'} '
          'api_code=${body['code'] ?? 'missing'} '
          'message="${_safeSupplierDiagnostic(body['message'])}"',
        );
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal menambahkan supplier',
        );
      }
      debugPrint('[POO_CREATE] success http=${res.statusCode ?? 0}');
      return ApiResponse(
        status: true,
        message: body['message']?.toString() ?? 'Supplier berhasil ditambahkan',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      debugPrint(
        '[POO_CREATE] network_error type=${e.type.name} '
        'http=${e.response?.statusCode ?? 0} '
        'message="${_safeSupplierDiagnostic(_friendlyError(e))}"',
      );
      return ApiResponse(status: false, message: _friendlyError(e));
    } catch (e) {
      debugPrint('[POO_CREATE] client_error type=${e.runtimeType}');
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateSupplier(
    int id,
    Supplier supplier,
  ) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.put(
        '/api/suppliers/$id',
        data: supplier.toUpdateJson(),
      );
      final body = res.data as Map<String, dynamic>;
      final msg = body['message']?.toString() ?? '';
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: msg.isEmpty ? 'Gagal memperbarui supplier' : msg,
        );
      }
      final needsApproval = msg.toLowerCase().contains('approval');
      return ApiResponse(
        status: true,
        message: needsApproval
            ? 'Perubahan dikirim untuk persetujuan atasan.'
            : (msg.isEmpty ? 'Supplier berhasil diperbarui' : msg),
        data: body['data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Supplier>> getSupplierDetail(int id) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/suppliers/$id');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success' || body['data'] == null) {
        return ApiResponse(
          status: false,
          message:
              body['message']?.toString() ?? 'Gagal memuat detail supplier',
        );
      }
      return ApiResponse(
        status: true,
        message: '',
        data: Supplier.fromJson(body['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> toggleSupplierStatus(
    int id,
  ) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.put('/api/suppliers/$id/toggle-status');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message:
              body['message']?.toString() ?? 'Gagal mengubah status supplier',
        );
      }
      return ApiResponse(
        status: true,
        message: body['message']?.toString() ?? 'Status berhasil diubah',
        data: body['data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> validateAccount({
    required String nomorRek,
    required String bank,
    required String namaRek,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.post(
        '/api/suppliers/validate-account',
        data: {
          'nomor_rek': nomorRek,
          // Go menuntut `bank_code`, bukan `bank` — mengirim nama key yang
          // salah membuat request ditolak 400 "nomor_rek and bank_code are
          // required" sebelum sempat memvalidasi apa pun.
          'bank_code': bank,
          'nama_rek': namaRek,
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        return ApiResponse(
          status: false,
          message: body['message']?.toString() ?? 'Gagal memvalidasi rekening',
        );
      }

      // Rekening yang tidak ditemukan tetap dibalas HTTP 200 + status
      // "success" — penandanya ada di data.valid (lihat komentar di
      // ValidateSupplierAccount pada go-rest-api: sengaja begitu supaya
      // frontend tidak masuk block catch). Jadi status HTTP saja TIDAK cukup;
      // tanpa cek ini nomor rekening ngawur akan lolos sebagai valid, dan itu
      // rekening tujuan pembayaran supplier.
      final data = body['data'] as Map<String, dynamic>?;
      final isValid = data?['valid'] == true;
      if (!isValid) {
        return ApiResponse(
          status: false,
          message: body['message']?.toString().isNotEmpty == true
              ? body['message'].toString()
              : 'Rekening tidak valid atau tidak ditemukan',
          data: data,
        );
      }

      return ApiResponse(status: true, message: '', data: data);
    } catch (e) {
      return ApiResponse(status: false, message: _friendlyError(e));
    }
  }
}
