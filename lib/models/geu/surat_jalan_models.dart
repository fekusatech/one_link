import '../surat_jalan.dart';

/// Raw shapes returned by the new Go API (apipi.greenenergiutama.co.id,
/// /api-tms/surat-jalan/*). Kept separate from the legacy `SuratJalan`
/// model (lib/models/surat_jalan.dart) because the field sets genuinely
/// differ; `toLegacy()` below adapts them so the existing driver screens
/// (dashboard, detail, navigation, pickup process) keep working unchanged.

const _indoMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
];

/// The list endpoint sends plain "YYYY-MM-DD" while the raw header model
/// (GetByID) sends full RFC3339 ("YYYY-MM-DDT00:00:00Z") — this handles
/// both and always returns a human date ("14 Ags 2026"), never a raw
/// timestamp string, so screens never need to know which shape they got.
String formatIndoDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final datePart = raw.split('T').first;
  final parts = datePart.split('-');
  if (parts.length != 3) return raw;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null || month < 1 || month > 12) {
    return raw;
  }
  return '${day.toString().padLeft(2, '0')} ${_indoMonths[month - 1]} $year';
}

class GeuPagination {
  final int currentPage;
  final int perPage;
  final int totalRecords;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  GeuPagination({
    required this.currentPage,
    required this.perPage,
    required this.totalRecords,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory GeuPagination.fromJson(Map<String, dynamic> json) {
    return GeuPagination(
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      totalRecords: json['total_records'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      hasNext: json['has_next'] ?? false,
      hasPrev: json['has_prev'] ?? false,
    );
  }
}

/// GET /api-tms/surat-jalan (list item) — shallow summary, no per-supplier
/// detail (backend does NOT embed `t_surat_jalan_detail` rows here).
class GeuSuratJalanListItem {
  final int id;
  final String? kode;
  final String? tgl;
  final int? pickupId;
  final String? kodePickup;
  final String status;
  final String? gudangName;
  final String? driverName;
  final String? fleetPlat;
  final double qtyReal;
  final String? satuanName;
  final int totalSupplier;
  final int selesaiSupplier;

  GeuSuratJalanListItem({
    required this.id,
    this.kode,
    this.tgl,
    this.pickupId,
    this.kodePickup,
    required this.status,
    this.gudangName,
    this.driverName,
    this.fleetPlat,
    required this.qtyReal,
    this.satuanName,
    required this.totalSupplier,
    required this.selesaiSupplier,
  });

  factory GeuSuratJalanListItem.fromJson(Map<String, dynamic> json) {
    return GeuSuratJalanListItem(
      id: json['id'] ?? 0,
      kode: json['kode']?.toString(),
      tgl: json['tgl']?.toString(),
      pickupId: json['pickup_id'],
      kodePickup: json['kode_pickup']?.toString(),
      status: json['status']?.toString() ?? 'progress',
      gudangName: json['gudang_name']?.toString(),
      driverName: json['driver_name']?.toString(),
      fleetPlat: json['fleet_plat']?.toString(),
      qtyReal: (json['qty_real'] as num?)?.toDouble() ?? 0,
      satuanName: json['satuan_name']?.toString(),
      totalSupplier: json['total_supplier'] ?? 0,
      selesaiSupplier: json['selesai_supplier'] ?? 0,
    );
  }

  /// Adapts to the legacy card shape used by dashboard_screen.dart /
  /// pickup_history_screen.dart. `suratJalanDetail` is intentionally left
  /// empty here — the list endpoint doesn't carry per-supplier rows; call
  /// GeuSuratJalanService.getById() when the user opens a card to get the
  /// fully-hydrated object (with real supplier names, photos, etc).
  SuratJalan toLegacy() {
    final percentage = totalSupplier > 0
        ? ((selesaiSupplier / totalSupplier) * 100).round()
        : 0;
    return SuratJalan(
      suratJalanId: id.toString(),
      kode: kode ?? '-',
      tanggal: tgl ?? '',
      tanggalFormatted: formatIndoDate(tgl),
      status: status,
      kodePickup: kodePickup ?? '-',
      driverName: driverName ?? '-',
      plat: fleetPlat ?? '-',
      gudangName: gudangName ?? '-',
      gudangGps: '',
      supplierNames: '-',
      totalSuppliers: totalSupplier.toString(),
      totalQty: qtyReal.toString(),
      totalQtyReal: qtyReal.toString(),
      totalLiter: qtyReal.toString(),
      totalHarga: '0',
      progress: Progress(
        totalItems: totalSupplier.toString(),
        completedItems: selesaiSupplier.toString(),
        pickupItems: '0',
        cancelledItems: '0',
        percentage: percentage,
        statusSummary: StatusSummary(
          done: selesaiSupplier.toString(),
          pickup: '0',
          pending: 0,
          cancelled: '0',
        ),
      ),
      createdAt: '',
      updatedAt: '',
      suratJalanDetail: const [],
    );
  }
}

/// GET /api-tms/surat-jalan/:id -> "header" (raw t_surat_jalan row, GORM
/// model JSON tags incl. nested `pickup`).
class GeuSuratJalanHeader {
  final int id;
  final String? kode;
  final String? tgl;
  final int? pickupId;
  final String status;
  final Map<String, dynamic>? pickup;

  GeuSuratJalanHeader({
    required this.id,
    this.kode,
    this.tgl,
    this.pickupId,
    required this.status,
    this.pickup,
  });

  factory GeuSuratJalanHeader.fromJson(Map<String, dynamic> json) {
    return GeuSuratJalanHeader(
      id: json['id'] ?? 0,
      kode: json['kode']?.toString(),
      tgl: json['tgl']?.toString(),
      pickupId: json['pickup_id'],
      status: json['status']?.toString() ?? 'progress',
      pickup: json['pickup'] is Map
          ? Map<String, dynamic>.from(json['pickup'])
          : null,
    );
  }

  String get kodePickup => pickup?['kode']?.toString() ?? '-';
  int? get driverId => pickup?['driver_id'];
  int? get fleetId => pickup?['fleet_id'];
}

/// One row of GET /api-tms/surat-jalan/:id -> "details".
class GeuSuratJalanDetail {
  final int id;
  final int? suratJalanId;
  final int? pickupDetailId;
  final String? supplierName;
  final String? supplierAlamat;
  final double qtyPlan;
  final double qtyReal;
  final String status;
  final String? keteranganCancel;
  final String? gps;
  final String? foto;
  final String? supplierGps;
  final String? woKode;
  final String? picName;
  final String? kemasanPlanName;
  final String? satuanName;
  final String? ttd;
  final String? fotoAt;
  final String? ttdAt;
  final int photoCount;
  /// Liter-per-kemasan conversion factor (m_kemasan.tot_liter) — powers the
  /// "Per Kemasan" / "Per Liter" toggle on the confirm screen, same as
  /// totLiter in application/views/surat-jalan/detail_form.php (web).
  final double totLiter;
  /// Populated separately via GeuSuratJalanService.getDetailPhotos() when
  /// photoCount > 0 — `foto` above is the legacy singular column, which the
  /// multi-photo upload flow never backfills (see getById() in
  /// surat_jalan_service.dart), so it's usually null even when real photos
  /// exist.
  final List<String> photoUrls;

  GeuSuratJalanDetail({
    required this.id,
    this.suratJalanId,
    this.pickupDetailId,
    this.supplierName,
    this.supplierAlamat,
    required this.qtyPlan,
    required this.qtyReal,
    required this.status,
    this.keteranganCancel,
    this.gps,
    this.foto,
    this.supplierGps,
    this.woKode,
    this.picName,
    this.kemasanPlanName,
    this.satuanName,
    this.ttd,
    this.fotoAt,
    this.ttdAt,
    required this.photoCount,
    this.totLiter = 1,
    this.photoUrls = const [],
  });

  GeuSuratJalanDetail copyWithPhotoUrls(List<String> urls) => GeuSuratJalanDetail(
        id: id,
        suratJalanId: suratJalanId,
        pickupDetailId: pickupDetailId,
        supplierName: supplierName,
        supplierAlamat: supplierAlamat,
        qtyPlan: qtyPlan,
        qtyReal: qtyReal,
        status: status,
        keteranganCancel: keteranganCancel,
        gps: gps,
        foto: foto,
        supplierGps: supplierGps,
        woKode: woKode,
        picName: picName,
        kemasanPlanName: kemasanPlanName,
        satuanName: satuanName,
        ttd: ttd,
        fotoAt: fotoAt,
        ttdAt: ttdAt,
        photoCount: photoCount,
        totLiter: totLiter,
        photoUrls: urls,
      );

  factory GeuSuratJalanDetail.fromJson(Map<String, dynamic> json) {
    return GeuSuratJalanDetail(
      id: json['id'] ?? 0,
      suratJalanId: json['surat_jalan_id'],
      pickupDetailId: json['pickup_detail_id'],
      supplierName: json['supplier_name']?.toString(),
      supplierAlamat: json['supplier_alamat']?.toString(),
      qtyPlan: (json['qty_plan'] as num?)?.toDouble() ?? 0,
      qtyReal: (json['qty_real'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'progress',
      keteranganCancel: json['keterangan_cancel']?.toString(),
      gps: json['gps']?.toString(),
      foto: json['foto']?.toString(),
      supplierGps: json['supplier_gps']?.toString(),
      woKode: json['wo_kode']?.toString(),
      picName: json['pic_name']?.toString(),
      kemasanPlanName: json['kemasan_plan_name']?.toString(),
      satuanName: json['satuan_name']?.toString(),
      ttd: json['ttd']?.toString(),
      fotoAt: json['foto_at']?.toString(),
      ttdAt: json['ttd_at']?.toString(),
      photoCount: json['photo_count'] ?? 0,
      totLiter: (json['tot_liter'] as num?)?.toDouble() ?? 1,
    );
  }

  SuratJalanDetail toLegacy() {
    return SuratJalanDetail(
      suratJalanDetailId: id.toString(),
      supplierName: supplierName ?? '-',
      supplierAlamat: supplierAlamat ?? '-',
      workOrderKode: woKode ?? '-',
      qtyOrder: qtyPlan.toString(),
      qtyReal: qtyReal.toString(),
      harga: '0',
      satuan: kemasanPlanName ?? satuanName ?? '-',
      status: status,
      supplierGps: supplierGps ?? '',
      suratJalanDetailGps: gps ?? '',
      // `foto`/`ttd` here are already full URLs (backend resolves them via
      // ResolveFilemanagerURL) — SuratJalanDetail.fotoUrl/ttdUrl only add a
      // domain when the value looks like a bare relative path, so a full
      // URL passes through untouched.
      foto: foto,
      ttd: ttd,
      fotoAt: fotoAt,
      ttdAt: ttdAt,
      totLiter: totLiter,
      photoUrls: photoUrls,
    );
  }
}

/// GET /api-tms/surat-jalan/detail/:detailId/photos (one row).
class GeuSuratJalanPhoto {
  final int id;
  final int suratJalanDetailId;
  final String? filename;
  final String filePath;
  final String? photoType;
  final String? description;
  final String? uploadAt;
  final String deleteStatus;

  GeuSuratJalanPhoto({
    required this.id,
    required this.suratJalanDetailId,
    this.filename,
    required this.filePath,
    this.photoType,
    this.description,
    this.uploadAt,
    required this.deleteStatus,
  });

  factory GeuSuratJalanPhoto.fromJson(Map<String, dynamic> json) {
    return GeuSuratJalanPhoto(
      id: json['id'] ?? 0,
      suratJalanDetailId: json['surat_jalan_detail_id'] ?? 0,
      filename: json['filename']?.toString(),
      filePath: json['file_path']?.toString() ?? '',
      photoType: json['photo_type']?.toString(),
      description: json['description']?.toString(),
      uploadAt: json['upload_at']?.toString(),
      deleteStatus: json['delete_status']?.toString() ?? 'none',
    );
  }
}

/// Builds a fully-hydrated legacy `SuratJalan` (header + real detail rows)
/// from a GET /api-tms/surat-jalan/:id response — used once the driver taps
/// a card, so the existing detail/navigation/process screens get the same
/// richness the old API used to embed directly in the list response.
SuratJalan buildLegacySuratJalan(
  GeuSuratJalanHeader header,
  List<GeuSuratJalanDetail> details,
) {
  final total = details.length;
  final done = details.where((d) => d.status == 'done').length;
  final percentage = total > 0 ? ((done / total) * 100).round() : 0;
  final totalQty = details.fold<double>(0, (sum, d) => sum + d.qtyPlan);
  final totalQtyReal = details.fold<double>(0, (sum, d) => sum + d.qtyReal);
  final supplierNames = details
      .map((d) => d.supplierName)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .join(', ');

  return SuratJalan(
    suratJalanId: header.id.toString(),
    kode: header.kode ?? '-',
    tanggal: header.tgl ?? '',
    tanggalFormatted: header.tgl ?? '',
    status: header.status,
    kodePickup: header.kodePickup,
    driverName: '-',
    plat: '-',
    gudangName: '-',
    gudangGps: '',
    supplierNames: supplierNames.isEmpty ? '-' : supplierNames,
    totalSuppliers: total.toString(),
    totalQty: totalQty.toString(),
    totalQtyReal: totalQtyReal.toString(),
    totalLiter: totalQtyReal.toString(),
    totalHarga: '0',
    progress: Progress(
      totalItems: total.toString(),
      completedItems: done.toString(),
      pickupItems: details.where((d) => d.status == 'pickup').length.toString(),
      cancelledItems: details.where((d) => d.status == 'cancel').length.toString(),
      percentage: percentage,
      statusSummary: StatusSummary(
        done: done.toString(),
        pickup: details.where((d) => d.status == 'pickup').length.toString(),
        pending: details.where((d) => d.status == 'progress').length,
        cancelled: details.where((d) => d.status == 'cancel').length.toString(),
      ),
    ),
    createdAt: '',
    updatedAt: '',
    suratJalanDetail: details.map((d) => d.toLegacy()).toList(),
  );
}
