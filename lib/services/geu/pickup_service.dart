import 'geu_api_client.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class PickupSummary {
  final int id;
  final String code, date, warehouse, zone, status;
  const PickupSummary({
    required this.id,
    required this.code,
    required this.date,
    required this.warehouse,
    required this.zone,
    required this.status,
  });
  factory PickupSummary.fromJson(Map d) => PickupSummary(
    id: int.tryParse('${d['id'] ?? 0}') ?? 0,
    code: '${d['kode'] ?? '-'}',
    date: '${d['tgl_plan'] ?? d['tgl'] ?? '-'}',
    warehouse: '${d['gudang_name'] ?? '-'}',
    zone: '${d['zona_nama'] ?? '-'}',
    status: '${d['status'] ?? '-'}',
  );
}

class PickupService {
  static Future<bool> isOnline() async {
    try {
      return (await InternetAddress.lookup(
        'apipi.greenenergiutama.co.id',
      )).isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  static Future<String?> validateSupplierBank(int supplierId) async {
    final response = await (await GeuApiClient.instance).post(
      '/api-crm/pickups/check-supplier-rekening',
      data: {'supplier_id': supplierId},
    );
    final body = response.data;
    if (response.statusCode != 200 || body is! Map)
      return 'Validasi rekening tidak dapat dilakukan.';
    final data = body['data'] is Map ? body['data'] as Map : body;
    if (data['valid'] == true) return null;
    return (data['reason'] ??
            data['warning'] ??
            'Data rekening supplier belum lengkap.')
        .toString();
  }

  static Future<List<Map<String, dynamic>>> warehouses() async {
    const cacheKey = 'geu_pickup_dropdowns';
    const cacheAtKey = 'geu_pickup_dropdowns_at';
    try {
      final response = await (await GeuApiClient.instance).get(
        '/api/suppliers/dropdowns',
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map) throw Exception();
      final items =
          data['gudang'] as List? ??
          (data['data'] as Map?)?['gudang'] as List? ??
          const [];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(items));
      await prefs.setInt(cacheAtKey, DateTime.now().millisecondsSinceEpoch);
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      final cachedAt = prefs.getInt(cacheAtKey) ?? 0;
      if (raw == null ||
          DateTime.now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(cachedAt))
                  .inHours >
              24)
        rethrow;
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }

  static Future<List<Map<String, dynamic>>> searchWorkOrders(
    String search,
  ) async {
    final response = await (await GeuApiClient.instance).get(
      '/api-tms/pickups/work-orders',
      queryParameters: {'search': search},
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List)
      throw Exception('Work order tidak dapat dimuat.');
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<String>> supplierSchedule(int supplierId) async {
    final response = await (await GeuApiClient.instance).get(
      '/api-crm/pickups/supplier-zona/$supplierId',
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List)
      throw Exception('Jadwal zona tidak dapat dimuat.');
    return data.map((item) => item.toString()).toList();
  }

  static Future<void> create({
    required String date,
    required int warehouseId,
    required int workOrderId,
    required int supplierId,
  }) async {
    final response = await (await GeuApiClient.instance).post(
      '/api-crm/pickups/',
      data: {
        'tgl': date,
        'gudang_id': warehouseId,
        'type': 'pickup',
        'details': [
          {
            'work_order_id': workOrderId,
            'supplier_id': supplierId,
            'satuan_id': 1,
            'qty': 1,
          },
        ],
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201)
      throw Exception('Request pickup gagal dibuat.');
  }

  static Future<Map<String, dynamic>> detail(int id) async {
    final response = await (await GeuApiClient.instance).get(
      '/api-crm/pickups/$id',
    );
    final data = response.data;
    if (response.statusCode != 200 || data is! Map)
      throw Exception('Detail pickup tidak dapat dimuat.');
    return Map<String, dynamic>.from(
      data['data'] is Map ? data['data'] as Map : data,
    );
  }

  /// Body fields follow the naming used by [create] (tgl/gudang_id) — the
  /// exact schema for PATCH .../basic isn't in doc.md, confirm with backend
  /// before relying on this in production.
  static Future<void> updateBasic({
    required int id,
    String? date,
    int? warehouseId,
  }) async {
    final response = await (await GeuApiClient.instance).patch(
      '/api-crm/pickups/$id/basic',
      data: {
        if (date != null) 'tgl': date,
        if (warehouseId != null) 'gudang_id': warehouseId,
      },
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        (body is Map && body['status'] == 'error')) {
      throw Exception(
        (body is Map ? body['message'] : null)?.toString() ??
            'Pickup gagal diperbarui.',
      );
    }
  }

  /// Same caveat as [updateBasic]: request schema for POST
  /// .../change-request isn't documented, this is a best-effort shape
  /// (type + notes) consistent with the rest of the API's conventions.
  static Future<void> submitChangeRequest({
    required int id,
    required String type,
    required String notes,
  }) async {
    final response = await (await GeuApiClient.instance).post(
      '/api-crm/pickups/$id/change-request',
      data: {'type': type, 'notes': notes},
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        (body is Map && body['status'] == 'error')) {
      throw Exception(
        (body is Map ? body['message'] : null)?.toString() ??
            'Pengajuan perubahan gagal dikirim.',
      );
    }
  }

  static Future<List<PickupSummary>> list({String status = ''}) async {
    final r = await (await GeuApiClient.instance).get(
      '/api-crm/pickups',
      queryParameters: {
        'page': 1,
        'limit': 20,
        if (status.isNotEmpty) 'status': status,
      },
    );
    final body = r.data;
    final data = GeuApiClient.unwrapData(body);
    if (r.statusCode != 200 || data is! Map)
      throw Exception('Daftar pickup tidak dapat dimuat.');
    final items = data['data'] is List ? data['data'] as List : const [];
    return items.whereType<Map>().map(PickupSummary.fromJson).toList();
  }
}
