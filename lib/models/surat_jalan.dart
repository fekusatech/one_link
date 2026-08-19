import 'dart:convert';
import '../config/app_config.dart';

class SuratJalanResponse {
  final String status;
  final int code;
  final String message;
  final SuratJalanData data;
  final String timestamp;

  SuratJalanResponse({
    required this.status,
    required this.code,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  factory SuratJalanResponse.fromJson(Map<String, dynamic> json) {
    return SuratJalanResponse(
      status: json['status'],
      code: json['code'],
      message: json['message'],
      data: SuratJalanData.fromJson(json['data']),
      timestamp: json['timestamp'],
    );
  }
}

class SuratJalanData {
  final List<SuratJalan> suratJalan;
  final int totalCount;
  final FiltersApplied filtersApplied;

  SuratJalanData({
    required this.suratJalan,
    required this.totalCount,
    required this.filtersApplied,
  });

  factory SuratJalanData.fromJson(Map<String, dynamic> json) {
    return SuratJalanData(
      suratJalan:
          (json['surat_jalan'] as List?)
              ?.map((item) => SuratJalan.fromJson(item))
              .toList() ??
          [],
      totalCount: json['total_count'] ?? 0,
      filtersApplied: FiltersApplied.fromJson(json['filters_applied'] ?? {}),
    );
  }
}

class SuratJalan {
  final String suratJalanId;
  final String kode;
  final String tanggal;
  final String tanggalFormatted;
  final String status;
  final String kodePickup;
  final String driverName;
  final String plat;
  final String gudangName;
  final String gudangGps;
  final String supplierNames;
  final String totalSuppliers;
  final String totalQty;
  final String totalQtyReal;
  final String totalLiter;
  final String totalHarga;
  final Progress progress;
  final String createdAt;
  final String updatedAt;
  final List<SuratJalanDetail> suratJalanDetail;

  SuratJalan({
    required this.suratJalanId,
    required this.kode,
    required this.tanggal,
    required this.tanggalFormatted,
    required this.status,
    required this.kodePickup,
    required this.driverName,
    required this.plat,
    required this.gudangName,
    required this.gudangGps,
    required this.supplierNames,
    required this.totalSuppliers,
    required this.totalQty,
    required this.totalQtyReal,
    required this.totalLiter,
    required this.totalHarga,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    required this.suratJalanDetail,
  });

  factory SuratJalan.fromJson(Map<String, dynamic> json) {
    return SuratJalan(
      suratJalanId: json['surat_jalan_id']?.toString() ?? '',
      kode: json['kode']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      tanggalFormatted: json['tanggal_formatted']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      kodePickup: json['kode_pickup']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? '',
      plat: json['plat']?.toString() ?? '',
      gudangName: json['gudang_name']?.toString() ?? '',
      gudangGps: json['gudang_gps']?.toString() ?? '',
      supplierNames: json['supplier_names']?.toString() ?? '',
      totalSuppliers: json['total_suppliers']?.toString() ?? '0',
      totalQty: json['total_qty']?.toString() ?? '0',
      totalQtyReal: json['total_qty_real']?.toString() ?? '0',
      totalLiter: json['total_liter']?.toString() ?? '0',
      totalHarga: json['total_harga']?.toString() ?? '0',
      progress: Progress.fromJson(json['progress'] ?? {}),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      suratJalanDetail:
          ((json['surat_jalan_detail'] as List?)
              ?.map((item) => SuratJalanDetail.fromJson(item))
              .toList()) ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surat_jalan_id': suratJalanId,
      'kode': kode,
      'tanggal': tanggal,
      'tanggal_formatted': tanggalFormatted,
      'status': status,
      'kode_pickup': kodePickup,
      'driver_name': driverName,
      'plat': plat,
      'gudang_name': gudangName,
      'gudang_gps': gudangGps,
      'supplier_names': supplierNames,
      'total_suppliers': totalSuppliers,
      'total_qty': totalQty,
      'total_qty_real': totalQtyReal,
      'total_liter': totalLiter,
      'total_harga': totalHarga,
      'progress': progress.toJson(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'surat_jalan_detail': suratJalanDetail.map((d) => d.toJson()).toList(),
    };
  }
}

class Progress {
  final String totalItems;
  final String completedItems;
  final String pickupItems;
  final String cancelledItems;
  final int percentage;
  final StatusSummary statusSummary;

  Progress({
    required this.totalItems,
    required this.completedItems,
    required this.pickupItems,
    required this.cancelledItems,
    required this.percentage,
    required this.statusSummary,
  });

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      totalItems: json['total_items']?.toString() ?? '0',
      completedItems: json['completed_items']?.toString() ?? '0',
      pickupItems: json['pickup_items']?.toString() ?? '0',
      cancelledItems: json['cancelled_items']?.toString() ?? '0',
      percentage: json['percentage']?.toInt() ?? 0,
      statusSummary: StatusSummary.fromJson(json['status_summary'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_items': totalItems,
      'completed_items': completedItems,
      'pickup_items': pickupItems,
      'cancelled_items': cancelledItems,
      'percentage': percentage,
      'status_summary': statusSummary.toJson(),
    };
  }
}

class StatusSummary {
  final String done;
  final String pickup;
  final int pending;
  final String cancelled;

  StatusSummary({
    required this.done,
    required this.pickup,
    required this.pending,
    required this.cancelled,
  });

  factory StatusSummary.fromJson(Map<String, dynamic> json) {
    return StatusSummary(
      done: json['done']?.toString() ?? '0',
      pickup: json['pickup']?.toString() ?? '0',
      pending: json['pending']?.toInt() ?? 0,
      cancelled: json['cancelled']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'done': done,
      'pickup': pickup,
      'pending': pending,
      'cancelled': cancelled,
    };
  }
}

class SuratJalanDetail {
  final String suratJalanDetailId;
  final String supplierName;
  final String supplierAlamat;
  final String workOrderKode;
  final String qtyOrder;
  final String qtyReal;
  final String harga;
  final String satuan;
  final String status;
  final String supplierGps;
  final String? supplierGpsUser;
  final String suratJalanDetailGps;
  final String? foto;
  final String? photosData;
  final String? fotoAt;
  final String? ttd;
  final String? ttdAt;
  /// Liter-per-kemasan conversion factor (only populated when this object
  /// came from GeuSuratJalanDetail.toLegacy() — the old PHP API never had
  /// an equivalent field). 1 means "already in liter" / unknown.
  final double totLiter;
  /// All uploaded photos for this item (resolved URLs), fetched separately
  /// from `foto` above — see GeuSuratJalanService.getById(). Empty for
  /// data that came from the old PHP API path.
  final List<String> photoUrls;

  SuratJalanDetail({
    required this.suratJalanDetailId,
    required this.supplierName,
    required this.supplierAlamat,
    required this.workOrderKode,
    required this.qtyOrder,
    required this.qtyReal,
    required this.harga,
    required this.satuan,
    required this.status,
    required this.supplierGps,
    this.supplierGpsUser,
    required this.suratJalanDetailGps,
    this.foto,
    this.photosData,
    this.fotoAt,
    this.ttd,
    this.ttdAt,
    this.totLiter = 1,
    this.photoUrls = const [],
  });

  factory SuratJalanDetail.fromJson(Map<String, dynamic> json) {
    return SuratJalanDetail(
      suratJalanDetailId: json['surat_jalan_detail_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      supplierAlamat: json['supplier_alamat']?.toString() ?? '',
      workOrderKode: json['work_order_kode']?.toString() ?? '',
      qtyOrder: json['qty_order']?.toString() ?? '0',
      qtyReal: json['qty_real']?.toString() ?? '0',
      harga: json['harga']?.toString() ?? '0',
      satuan: json['satuan']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      supplierGps: json['supplier_gps']?.toString() ?? '',
      supplierGpsUser: json['supplier_gps_user']?.toString(),
      suratJalanDetailGps: json['surat_jalan_detail_gps']?.toString() ?? '',
      foto: json['foto']?.toString(),
      photosData: json['photos_data']?.toString(),
      fotoAt: json['foto_at']?.toString(),
      ttd: json['ttd']?.toString(),
      ttdAt: json['ttd_at']?.toString(),
    );
  }

  // Helper methods untuk URL lengkap
  String? get fotoUrl {
    if (foto == null || foto!.isEmpty) return null;

    // Go API (ResolveFilemanagerURL) sudah mengembalikan URL absolut penuh
    // (baik ke erp.greenenergiutama.co.id maupun langsung ke R2) — kalau
    // dicek startsWith('filemanager/') doang, URL absolut ini lolos ke
    // cabang else di bawah dan didobel-prefix jadi
    // "erp.../filemanager/foto-pengambilan/https://...", yang otomatis
    // gagal dimuat (NetworkImage: empty file). Selalu pass-through kalau
    // sudah http(s).
    if (foto!.startsWith('http://') || foto!.startsWith('https://')) {
      return foto;
    }

    // Jika foto sudah berupa path lengkap (dimulai dengan filemanager/),
    // maka hanya tambahkan domain
    if (foto!.startsWith('filemanager/')) {
      return '${AppConfig.serverDomain}/$foto';
    }

    // Jika hanya nama file, tambahkan path lengkap
    return '${AppConfig.serverDomain}/filemanager/foto-pengambilan/$foto';
  }

  String? get ttdUrl {
    if (ttd == null || ttd!.isEmpty) return null;

    // Sama seperti fotoUrl di atas — URL absolut dari Go API harus
    // pass-through, jangan didobel-prefix.
    if (ttd!.startsWith('http://') || ttd!.startsWith('https://')) {
      return ttd;
    }

    // Jika ttd sudah berupa path lengkap (dimulai dengan filemanager/),
    // maka hanya tambahkan domain
    if (ttd!.startsWith('filemanager/')) {
      return '${AppConfig.serverDomain}/$ttd';
    }

    // Jika hanya nama file, tambahkan path lengkap
    return '${AppConfig.serverDomain}/filemanager/ttd/$ttd';
  }

  Map<String, dynamic> toJson() {
    return {
      'surat_jalan_detail_id': suratJalanDetailId,
      'supplier_name': supplierName,
      'supplier_alamat': supplierAlamat,
      'work_order_kode': workOrderKode,
      'qty_order': qtyOrder,
      'qty_real': qtyReal,
      'harga': harga,
      'satuan': satuan,
      'status': status,
      'supplier_gps': supplierGps,
      'supplier_gps_user': supplierGpsUser,
      'surat_jalan_detail_gps': suratJalanDetailGps,
      'foto': foto,
      'photos_data': photosData,
      'foto_at': fotoAt,
      'ttd': ttd,
      'ttd_at': ttdAt,
      'tot_liter': totLiter,
      'photo_urls': photoUrls,
    };
  }
}

class FiltersApplied {
  final String userId;
  final String status;
  final String date;

  FiltersApplied({
    required this.userId,
    required this.status,
    required this.date,
  });

  factory FiltersApplied.fromJson(Map<String, dynamic> json) {
    return FiltersApplied(
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}
