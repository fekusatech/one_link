import 'geu_api_client.dart';
import 'visit_planner_service.dart' show WorkOrderStatus;

class WorkOrderListItem {
  final int id;
  final String kode;
  final int supplierId;
  final String supplierName;
  final String supplierPhone;
  final String tgl;
  final String statusName;
  final bool close;

  const WorkOrderListItem({
    required this.id,
    required this.kode,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.tgl,
    required this.statusName,
    required this.close,
  });

  factory WorkOrderListItem.fromJson(Map<String, dynamic> json) =>
      WorkOrderListItem(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        kode: (json['kode'] ?? '-').toString(),
        supplierId: int.tryParse('${json['supplier_id'] ?? 0}') ?? 0,
        supplierName: (json['supplier_name'] ?? '-').toString(),
        supplierPhone: (json['supplier_phone'] ?? '').toString(),
        tgl: (json['tgl'] ?? '').toString(),
        statusName: (json['status_name'] ?? '-').toString(),
        close: json['close'] == true,
      );
}

class WorkOrderListPage {
  final List<WorkOrderListItem> items;
  final bool hasNext;
  const WorkOrderListPage({required this.items, required this.hasNext});
}

/// Full detail (GET /api/work-orders/:id) — mirrors the web's WorkOrderDetail
/// response shown behind the "view" (eye) icon.
class WorkOrderDetail {
  final int id;
  final String kode;
  final int supplierId;
  final String supplierName;
  final String supplierKode;
  final String supplierPhone;
  final String tgl;
  final String callAt;
  final String statusKode;
  final String statusName;
  final bool close;
  final String? type;
  final double? hargaRevisit;
  final double? hargaSebelumnya;
  final double? persenTurun;
  final String picName;
  final String creatorName;
  final DateTime? createdAt;

  const WorkOrderDetail({
    required this.id,
    required this.kode,
    required this.supplierId,
    required this.supplierName,
    required this.supplierKode,
    required this.supplierPhone,
    required this.tgl,
    required this.callAt,
    required this.statusKode,
    required this.statusName,
    required this.close,
    required this.type,
    required this.hargaRevisit,
    required this.hargaSebelumnya,
    required this.persenTurun,
    required this.picName,
    required this.creatorName,
    required this.createdAt,
  });

  factory WorkOrderDetail.fromJson(Map<String, dynamic> json) =>
      WorkOrderDetail(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        kode: (json['kode'] ?? '-').toString(),
        supplierId: int.tryParse('${json['supplier_id'] ?? 0}') ?? 0,
        supplierName: (json['supplier_name'] ?? '-').toString(),
        supplierKode: (json['supplier_kode'] ?? '').toString(),
        supplierPhone: (json['supplier_phone'] ?? '').toString(),
        tgl: (json['tgl'] ?? '').toString(),
        callAt: (json['call_at'] ?? '').toString(),
        statusKode: (json['status_kode'] ?? '').toString(),
        statusName: (json['status_name'] ?? '-').toString(),
        close: json['close'] == true,
        type: json['type']?.toString(),
        hargaRevisit: (json['harga_revisit'] as num?)?.toDouble(),
        hargaSebelumnya: (json['harga_sebelumnya'] as num?)?.toDouble(),
        persenTurun: (json['persen_turun'] as num?)?.toDouble(),
        picName: (json['pic_name'] ?? '').toString(),
        creatorName: (json['creator_name'] ?? '').toString(),
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );
}

/// Generic Work Order creation — POST /api/work-orders, guarded by
/// crm-create-work-order (or tms-create-work-order). Distinct from
/// VisitPlannerService.createWorkOrder, which hits the visit-planner-scoped
/// /api/visit-planner/work-order/store endpoint gated by visit-planner
/// permissions that CRO users (self-assign only, no crm-read-visit-planner)
/// don't hold.
class WorkOrderService {
  static Future<WorkOrderListPage> list({
    int page = 1,
    String search = '',
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get(
      '/api/work-orders',
      queryParameters: {
        'page': page,
        'limit': 20,
        if (search.isNotEmpty) 'search': search,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! Map) {
      throw Exception(
        GeuApiClient.responseMessage(body) ?? 'Daftar WO tidak dapat dimuat.',
      );
    }
    final pageData = Map<String, dynamic>.from(data);
    final pagination = pageData['pagination'] as Map?;
    return WorkOrderListPage(
      items: (pageData['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => WorkOrderListItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasNext: pagination?['has_next'] == true,
    );
  }

  static Future<WorkOrderDetail> detail(int id) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/work-orders/$id');
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! Map) {
      throw Exception(
        GeuApiClient.responseMessage(body) ?? 'Detail WO tidak dapat dimuat.',
      );
    }
    return WorkOrderDetail.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<WorkOrderStatus>> statuses() async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/work-orders/statuses');
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List) {
      throw Exception('Status WO tidak dapat dimuat.');
    }
    return data
        .whereType<Map>()
        .map((e) => WorkOrderStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<String> create({
    required int supplierId,
    required DateTime tgl,
    int? statusId,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/work-orders',
      data: {
        'supplier_id': supplierId,
        'tgl':
            '${tgl.year.toString().padLeft(4, '0')}-${tgl.month.toString().padLeft(2, '0')}-${tgl.day.toString().padLeft(2, '0')}',
        if (statusId != null) 'status_id': statusId,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    final ok = response.statusCode == 200 || response.statusCode == 201;
    if (!ok || data is! Map) {
      throw Exception(
        GeuApiClient.responseMessage(body) ?? 'Gagal membuat WO.',
      );
    }
    return (data['kode'] ?? '-').toString();
  }
}
