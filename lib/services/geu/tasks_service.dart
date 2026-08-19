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
  const CrmTask({
    required this.supplierId,
    required this.supplierName,
    required this.phone,
    required this.status,
    required this.overdue,
    required this.gpsMissing,
  });
  factory CrmTask.fromJson(Map d) => CrmTask(
    supplierId: (d['supplier_id'] ?? 0) as int,
    supplierName: (d['supplier_name'] ?? '-').toString(),
    phone: (d['supplier_phone'] ?? '').toString(),
    status: (d['status'] ?? 'pending').toString(),
    overdue: d['is_overdue'] == true,
    gpsMissing: d['gps_missing'] == true,
  );
  Map<String, dynamic> toJson() => {
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'supplier_phone': phone,
    'status': status,
    'is_overdue': overdue,
    'gps_missing': gpsMissing,
  };
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
  static Future<TaskProgress> progress() async {
    final r = await (await GeuApiClient.instance).get(
      '/api-crm/tasks/progress',
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
  }) async {
    try {
      final r = await (await GeuApiClient.instance).get(
        '/api-crm/tasks/items',
        queryParameters: {
          'page': page,
          'limit': 20,
          if (status.isNotEmpty) 'status': status,
          if (search.isNotEmpty) 'search': search,
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
      if (page == 1 && status.isEmpty && search.isEmpty) {
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
      if (page != 1 || status.isNotEmpty || search.isNotEmpty) rethrow;
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
}
