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
  final String? type;
  final String? visitStatus;
  final bool visitHasAnomaly;
  final String? pickupKode;

  const WorkOrderListItem({
    required this.id,
    required this.kode,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.tgl,
    required this.statusName,
    required this.close,
    this.type,
    this.visitStatus,
    this.visitHasAnomaly = false,
    this.pickupKode,
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
        type: json['type']?.toString(),
        visitStatus: json['visit_status']?.toString(),
        visitHasAnomaly: json['visit_has_anomaly'] == true,
        pickupKode: json['pickup_kode']?.toString(),
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
  final String? pickupKode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.pickupKode,
    required this.createdAt,
    this.updatedAt,
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
        pickupKode: json['pickup_kode']?.toString(),
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse('${json['updated_at']}'),
      );
}

/// One entry in the WO list's PIC filter - mirrors crm-react's PICOption
/// (GET /api/work-orders/pics).
class WorkOrderPic {
  final int id;
  final String name;
  const WorkOrderPic({required this.id, required this.name});

  factory WorkOrderPic.fromJson(Map<String, dynamic> json) => WorkOrderPic(
    id: int.tryParse('${json['id'] ?? 0}') ?? 0,
    name: (json['name'] ?? '-').toString(),
  );
}

/// Filters for [WorkOrderService.list] - mirrors crm-react's WO table filter
/// bar (date range, status, type, PIC) so field sales can find "WO hari ini"
/// or "WO yang masih Open" without scrolling everything.
class WorkOrderFilters {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? statusId;
  final String? type; // 'revisit' | 'cro' | 'regular'
  final int? picId;
  final int? supplierId;

  const WorkOrderFilters({
    this.dateFrom,
    this.dateTo,
    this.statusId,
    this.type,
    this.picId,
    this.supplierId,
  });

  bool get isEmpty =>
      dateFrom == null &&
      dateTo == null &&
      statusId == null &&
      type == null &&
      picId == null &&
      supplierId == null;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery() => {
    if (dateFrom != null) 'date_from': _iso(dateFrom!),
    if (dateTo != null) 'date_to': _iso(dateTo!),
    if (statusId != null) 'status_id': statusId,
    if (type != null) 'type': type,
    if (picId != null) 'pic_id': picId,
    if (supplierId != null) 'supplier_id': supplierId,
  };
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
    WorkOrderFilters filters = const WorkOrderFilters(),
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get(
      '/api/work-orders',
      queryParameters: {
        'page': page,
        'limit': 20,
        if (search.isNotEmpty) 'search': search,
        ...filters.toQuery(),
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

  static Future<List<WorkOrderPic>> pics({String search = ''}) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get(
      '/api/work-orders/pics',
      queryParameters: {if (search.isNotEmpty) 'search': search},
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List) {
      throw Exception('Daftar PIC tidak dapat dimuat.');
    }
    return data
        .whereType<Map>()
        .map((e) => WorkOrderPic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<WorkOrderCreateResult> create({
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
    return WorkOrderCreateResult(
      id: int.tryParse('${data['id'] ?? 0}') ?? 0,
      kode: (data['kode'] ?? '-').toString(),
    );
  }

  static Future<List<WorkOrderAttachment>> listAttachments(int id) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/work-orders/$id/attachments');
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List) {
      throw Exception('Lampiran tidak dapat dimuat.');
    }
    return data
        .whereType<Map>()
        .map((e) => WorkOrderAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// [photoBase64] should already be a compressed data: URI - this method
  /// doesn't compress, unlike CheckinPhotoService (chat/call screenshots
  /// aren't camera-only proof photos, so they go through a lighter picker).
  static Future<WorkOrderAttachment> uploadAttachment({
    required int workOrderId,
    required String type,
    required String photoBase64,
    String? notes,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/work-orders/$workOrderId/attachments',
      data: {
        'type': type,
        'photo_base64': photoBase64,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    final ok = response.statusCode == 200 || response.statusCode == 201;
    if (!ok || data is! Map) {
      throw Exception(
        GeuApiClient.responseMessage(body) ?? 'Gagal upload lampiran.',
      );
    }
    return WorkOrderAttachment.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> deleteAttachment(int attachmentId) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.delete(
      '/api/work-orders/attachments/$attachmentId',
    );
    if (response.statusCode != 200) {
      throw Exception(
        GeuApiClient.responseMessage(response.data) ?? 'Gagal hapus lampiran.',
      );
    }
  }
}

class WorkOrderCreateResult {
  final int id;
  final String kode;
  const WorkOrderCreateResult({required this.id, required this.kode});
}

/// Optional evidence (chat screenshot, call proof, etc.) attached to a WO -
/// never required to create/update one.
class WorkOrderAttachment {
  final int id;
  final int workOrderId;
  final String type; // chat_screenshot | call_proof | other
  final String filePath;
  final String? notes;
  final String creatorName;
  final DateTime? createdAt;

  const WorkOrderAttachment({
    required this.id,
    required this.workOrderId,
    required this.type,
    required this.filePath,
    this.notes,
    required this.creatorName,
    this.createdAt,
  });

  factory WorkOrderAttachment.fromJson(Map<String, dynamic> json) =>
      WorkOrderAttachment(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        workOrderId: int.tryParse('${json['work_order_id'] ?? 0}') ?? 0,
        type: (json['type'] ?? 'other').toString(),
        filePath: (json['file_path'] ?? '').toString(),
        notes: json['notes']?.toString(),
        creatorName: (json['creator_name'] ?? '').toString(),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse('${json['created_at']}'),
      );

  static String typeLabel(String type) {
    switch (type) {
      case 'chat_screenshot':
        return 'Screenshot Chat';
      case 'call_proof':
        return 'Bukti Telpon';
      default:
        return 'Lainnya';
    }
  }
}
