class MovementItem {
  final int id;
  final String? kode;
  final String? tgl;
  final int? ptuId;
  final String? ptuName;
  final String? dariGudang;
  final String? tujuanGudang;
  final int? fleetId;
  final String? fleetName;
  final String? fleetPlat;
  final int? driverId;
  final String? driverName;
  final int? templateId;
  final double totalBiaya;
  final String progress;
  final double totalQty;
  final double totalSysQty;
  final String? approvedAt;
  final String? approvedName;
  final String? confirmedAt;
  final String? confirmedName;

  MovementItem({
    required this.id,
    this.kode,
    this.tgl,
    this.ptuId,
    this.ptuName,
    this.dariGudang,
    this.tujuanGudang,
    this.fleetId,
    this.fleetName,
    this.fleetPlat,
    this.driverId,
    this.driverName,
    this.templateId,
    required this.totalBiaya,
    required this.progress,
    required this.totalQty,
    required this.totalSysQty,
    this.approvedAt,
    this.approvedName,
    this.confirmedAt,
    this.confirmedName,
  });

  factory MovementItem.fromJson(Map<String, dynamic> json) {
    return MovementItem(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      kode: json['kode'] as String?,
      tgl: json['tgl'] as String?,
      ptuId: json['ptu_id'] != null ? (json['ptu_id'] is int ? json['ptu_id'] : int.tryParse('${json['ptu_id']}')) : null,
      ptuName: json['ptu_name'] as String?,
      dariGudang: json['dari_gudang'] as String?,
      tujuanGudang: json['tujuan_gudang'] as String?,
      fleetId: json['fleet_id'] != null ? (json['fleet_id'] is int ? json['fleet_id'] : int.tryParse('${json['fleet_id']}')) : null,
      fleetName: json['fleet_name'] as String?,
      fleetPlat: json['fleet_plat'] as String?,
      driverId: json['driver_id'] != null ? (json['driver_id'] is int ? json['driver_id'] : int.tryParse('${json['driver_id']}')) : null,
      driverName: json['driver_name'] as String?,
      templateId: json['template_id'] != null ? (json['template_id'] is int ? json['template_id'] : int.tryParse('${json['template_id']}')) : null,
      totalBiaya: double.tryParse('${json['total_biaya']}') ?? 0.0,
      progress: json['progress'] ?? 'draft',
      totalQty: double.tryParse('${json['total_qty']}') ?? 0.0,
      totalSysQty: double.tryParse('${json['total_sys_qty']}') ?? 0.0,
      approvedAt: json['approved_at'] as String?,
      approvedName: json['approved_name'] as String?,
      confirmedAt: json['confirmed_at'] as String?,
      confirmedName: json['confirmed_name'] as String?,
    );
  }
}

class MovementDetail {
  final int id;
  final int movementId;
  final int gudangFromId;
  final String? gudangFromName;
  final String? storageFromName;
  final double? storageTerisi;
  final double? storageMax;
  final String? toGudangName;
  final String? toStorageName;
  final double quantity;
  final double qtySystem;
  final String? tglLoading;
  final String? tglUnloading;
  final String? transitStatus;
  final String? sjKode;
  final String? sjGeneratedAt;
  final String? statusSj;

  MovementDetail({
    required this.id,
    required this.movementId,
    required this.gudangFromId,
    this.gudangFromName,
    this.storageFromName,
    this.storageTerisi,
    this.storageMax,
    this.toGudangName,
    this.toStorageName,
    required this.quantity,
    required this.qtySystem,
    this.tglLoading,
    this.tglUnloading,
    this.transitStatus,
    this.sjKode,
    this.sjGeneratedAt,
    this.statusSj,
  });

  factory MovementDetail.fromJson(Map<String, dynamic> json) {
    return MovementDetail(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      movementId: json['movement_id'] is int ? json['movement_id'] : int.parse('${json['movement_id']}'),
      gudangFromId: json['gudang_from_id'] is int ? json['gudang_from_id'] : int.parse('${json['gudang_from_id'] ?? 0}'),
      gudangFromName: json['gudang_from_name'] as String?,
      storageFromName: json['storage_from_name'] as String?,
      storageTerisi: json['storage_terisi'] != null ? double.tryParse('${json['storage_terisi']}') : null,
      storageMax: json['storage_max'] != null ? double.tryParse('${json['storage_max']}') : null,
      toGudangName: json['to_gudang_name'] as String?,
      toStorageName: json['to_storage_name'] as String?,
      quantity: double.tryParse('${json['quantity']}') ?? 0.0,
      qtySystem: double.tryParse('${json['qty_system']}') ?? 0.0,
      tglLoading: json['tgl_loading'] as String?,
      tglUnloading: json['tgl_unloading'] as String?,
      transitStatus: json['transit_status'] as String?,
      sjKode: json['sj_kode'] as String?,
      sjGeneratedAt: json['sj_generated_at'] as String?,
      statusSj: json['status_sj'] as String?,
    );
  }
}
