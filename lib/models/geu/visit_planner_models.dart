/// Mirrors src/response/visitplanner/*.go (go-rest-api) field-for-field —
/// see MissionItem/TodaysMission structs there.
class MissionItem {
  final int planDetailId;
  final int supplierId;
  final int? scannedPlaceId;
  final String supplierName;
  final String supplierPhone;
  final String supplierJenis;
  final String address;
  final double? lat;
  final double? lng;
  final String status;
  final int? workOrderId;
  final int sortOrder;

  MissionItem({
    required this.planDetailId,
    required this.supplierId,
    this.scannedPlaceId,
    required this.supplierName,
    required this.supplierPhone,
    required this.supplierJenis,
    required this.address,
    this.lat,
    this.lng,
    required this.status,
    this.workOrderId,
    required this.sortOrder,
  });

  factory MissionItem.fromJson(Map<String, dynamic> json) {
    double? lat, lng;
    final gps = json['gps'] as String?;
    if (gps != null && gps.contains(',')) {
      final parts = gps.split(',');
      lat = double.tryParse(parts[0].trim());
      lng = double.tryParse(parts[1].trim());
    }
    return MissionItem(
      planDetailId: json['plan_detail_id'] ?? 0,
      supplierId: json['supplier_id'] ?? 0,
      scannedPlaceId: json['scanned_place_id'],
      supplierName: json['supplier_name'] ?? '',
      supplierPhone: json['supplier_phone'] ?? '',
      supplierJenis: json['supplier_jenis'] ?? '',
      address: json['address'] ?? '',
      lat: lat,
      lng: lng,
      status: json['status'] ?? 'PENDING',
      workOrderId: json['work_order_id'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  bool get hasCoordinates => lat != null && lng != null;
}

class TodaysMission {
  final int planId;
  final String visitDate;
  final List<MissionItem> items;
  // Set when this data came from local cache rather than a fresh network
  // response — surfaced in the UI per PRD A1 ("data per <waktu>").
  final DateTime? cachedAt;

  TodaysMission({
    required this.planId,
    required this.visitDate,
    required this.items,
    this.cachedAt,
  });

  factory TodaysMission.fromJson(Map<String, dynamic> json) {
    return TodaysMission(
      planId: json['plan_id'] ?? 0,
      visitDate: json['visit_date'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => MissionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'visit_date': visitDate,
    'items': items
        .map(
          (i) => {
            'plan_detail_id': i.planDetailId,
            'supplier_id': i.supplierId,
            'scanned_place_id': i.scannedPlaceId,
            'supplier_name': i.supplierName,
            'supplier_phone': i.supplierPhone,
            'supplier_jenis': i.supplierJenis,
            'address': i.address,
            'gps': i.hasCoordinates ? '${i.lat},${i.lng}' : null,
            'status': i.status,
            'work_order_id': i.workOrderId,
            'sort_order': i.sortOrder,
          },
        )
        .toList(),
  };

  TodaysMission withCachedAt(DateTime time) => TodaysMission(
    planId: planId,
    visitDate: visitDate,
    items: items,
    cachedAt: time,
  );
}
