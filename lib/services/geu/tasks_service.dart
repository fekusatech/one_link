import 'geu_api_client.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TaskProgress {
  final int total, completed, pending, overdue;
  const TaskProgress({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
  });
  factory TaskProgress.fromJson(Map data) => TaskProgress(
    total: (data['total'] ?? 0) as int,
    completed: (data['completed'] ?? 0) as int,
    pending: (data['pending'] ?? 0) as int,
    overdue: (data['overdue'] ?? 0) as int,
  );
}

class CrmTask {
  final int supplierId;
  final String supplierName, phone, status;
  final bool overdue, gpsMissing;
  // Real fields from t_cro_assignment_items/t_roe_assignment_items — go-rest-api's
  // TaskItem already returns these, the old model just never read them.
  final String assigneeName; // cro_name or ro_name, whichever this row's type is
  final DateTime? contactedAt;
  final String notes;
  final String lastOrderDate; // YYYY-MM-DD or '' — full detail (nominal, chart) comes from /api/suppliers/:id
  const CrmTask({
    required this.supplierId,
    required this.supplierName,
    required this.phone,
    required this.status,
    required this.overdue,
    required this.gpsMissing,
    this.assigneeName = '',
    this.contactedAt,
    this.notes = '',
    this.lastOrderDate = '',
  });

  bool get hasBeenContacted => contactedAt != null || notes.trim().isNotEmpty;

  factory CrmTask.fromJson(Map d) => CrmTask(
    supplierId: (d['supplier_id'] ?? 0) as int,
    supplierName: (d['supplier_name'] ?? '-').toString(),
    phone: (d['supplier_phone'] ?? '').toString(),
    status: (d['status'] ?? 'pending').toString(),
    overdue: d['is_overdue'] == true,
    gpsMissing: d['gps_missing'] == true,
    assigneeName: (d['type'] == 'roe' ? d['ro_name'] : d['cro_name'])
            ?.toString() ??
        '',
    contactedAt: d['contacted_at'] != null
        ? DateTime.tryParse(d['contacted_at'].toString())
        : null,
    notes: (d['notes'] ?? '').toString(),
    lastOrderDate: (d['last_order_date'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'supplier_phone': phone,
    'status': status,
    'is_overdue': overdue,
    'gps_missing': gpsMissing,
    'cro_name': assigneeName,
    'contacted_at': contactedAt?.toIso8601String(),
    'notes': notes,
    'last_order_date': lastOrderDate,
  };
}

/// From GET /api-crm/tasks/supplier/:supplierId/detail — address/PIC/zona
/// context for the task detail sheet. Order history (nominal, last order,
/// chart) is a separate call to SupplierListService.getSupplierOrderSummary,
/// same endpoint the map's supplier sheet already uses.
class SupplierTaskDetail {
  final int supplierId;
  final String supplierName, picName, phone, alamat;
  final String? zonaName;
  final List<String> jadwalHari;

  const SupplierTaskDetail({
    required this.supplierId,
    required this.supplierName,
    required this.picName,
    required this.phone,
    required this.alamat,
    this.zonaName,
    this.jadwalHari = const [],
  });

  factory SupplierTaskDetail.fromJson(Map<String, dynamic> json) {
    return SupplierTaskDetail(
      supplierId: (json['supplier_id'] as num?)?.toInt() ?? 0,
      supplierName: json['supplier_name']?.toString() ?? '-',
      picName: json['pic_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '',
      zonaName: (json['zona_name'] as String?)?.trim().isNotEmpty == true
          ? json['zona_name'] as String
          : null,
      jadwalHari:
          (json['jadwal_hari'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }
}

class TaskList {
  final List<CrmTask> items;
  final bool hasMore;
  final DateTime? cachedAt;
  const TaskList(this.items, this.hasMore, {this.cachedAt});
}

class TasksService {
  static const _itemsCacheKey = 'geu_tasks_items_cache';
  static const _itemsCacheAtKey = 'geu_tasks_items_cache_at';
  static Future<TaskProgress> progress({
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final r = await (await GeuApiClient.instance).get(
      '/api-crm/tasks/progress',
      queryParameters: {
        if (dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo.isNotEmpty) 'date_to': dateTo,
      },
    );
    final d = r.data;
    if (r.statusCode != 200 || d is! Map)
      throw Exception('Progres tugas tidak dapat dimuat.');
    return TaskProgress.fromJson(d['data'] is Map ? d['data'] : d);
  }

  static Future<TaskList> items({
    int page = 1,
    String status = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
    bool overdueOnly = false,
  }) async {
    final isDefaultQuery = status.isEmpty &&
        search.isEmpty &&
        dateFrom.isEmpty &&
        dateTo.isEmpty &&
        !overdueOnly;
    try {
      final r = await (await GeuApiClient.instance).get(
        '/api-crm/tasks/items',
        queryParameters: {
          'page': page,
          'limit': 20,
          if (status.isNotEmpty) 'status': status,
          if (search.isNotEmpty) 'search': search,
          if (dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo.isNotEmpty) 'date_to': dateTo,
          if (overdueOnly) 'overdue_only': 'true',
        },
      );
      final d = r.data;
      if (r.statusCode != 200 || d is! Map)
        throw Exception('Daftar tugas tidak dapat dimuat.');
      final body = d['data'] is Map ? d['data'] as Map : d;
      final entries = body['data'] is List ? body['data'] as List : const [];
      final pagination = body['pagination'] as Map?;
      final result = TaskList(
        entries.whereType<Map>().map(CrmTask.fromJson).toList(),
        pagination?['total_pages'] != null &&
            (page < (pagination!['total_pages'] as num)),
      );
      if (page == 1 && isDefaultQuery) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _itemsCacheKey,
          jsonEncode(result.items.map((item) => item.toJson()).toList()),
        );
        await prefs.setInt(
          _itemsCacheAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      return result;
    } catch (_) {
      if (page != 1 || !isDefaultQuery) rethrow;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemsCacheKey);
      if (raw == null) rethrow;
      final rows = jsonDecode(raw) as List;
      return TaskList(
        rows.whereType<Map>().map(CrmTask.fromJson).toList(),
        false,
        cachedAt: DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(_itemsCacheAtKey) ?? 0,
        ),
      );
    }
  }

  static Future<SupplierTaskDetail?> supplierDetail(int supplierId) async {
    try {
      final r = await (await GeuApiClient.instance).get(
        '/api-crm/tasks/supplier/$supplierId/detail',
      );
      final d = r.data;
      if (r.statusCode != 200 || d is! Map || d['data'] is! Map) return null;
      return SupplierTaskDetail.fromJson(d['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
