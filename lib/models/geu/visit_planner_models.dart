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

class VisitHistoryPage {
  final List<VisitHistoryItem> items;
  final bool hasMore;
  final DateTime? cachedAt;

  const VisitHistoryPage({
    required this.items,
    required this.hasMore,
    this.cachedAt,
  });

  factory VisitHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['data'] ?? json['results'] ?? [];
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : json;
    return VisitHistoryPage(
      items: (rawItems as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                VisitHistoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      hasMore:
          pagination['has_more'] == true ||
          (_asInt(pagination['current_page']) <
              _asInt(
                pagination['total_pages'] ?? pagination['last_page'],
                fallback: 1,
              )),
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'has_more': hasMore,
  };

  VisitHistoryPage withCachedAt(DateTime value) =>
      VisitHistoryPage(items: items, hasMore: hasMore, cachedAt: value);
}

class VisitHistoryItem {
  final int id;
  final String supplierName;
  final String status;
  final String checkedInAt;
  final String checkedOutAt;
  final String address;
  final int supplierId;
  final String supplierPhone;
  final double? checkinLat;
  final double? checkinLng;
  final String? checkinPhoto;
  final double? checkoutLat;
  final double? checkoutLng;
  final String checkoutAddress;
  final String? checkoutPhoto;
  final int? durationMinutes;
  final double? distanceFromSupplier;
  final String workOrderIds;
  final String notes;

  const VisitHistoryItem({
    required this.id,
    required this.supplierName,
    required this.status,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.address,
    required this.supplierId,
    required this.supplierPhone,
    this.checkinLat,
    this.checkinLng,
    this.checkinPhoto,
    this.checkoutLat,
    this.checkoutLng,
    required this.checkoutAddress,
    this.checkoutPhoto,
    this.durationMinutes,
    this.distanceFromSupplier,
    required this.workOrderIds,
    required this.notes,
  });

  factory VisitHistoryItem.fromJson(Map<String, dynamic> json) =>
      VisitHistoryItem(
        id: _asInt(json['id'] ?? json['visit_id']),
        supplierName: (json['supplier_name'] ?? json['name'] ?? '-').toString(),
        supplierId: _asInt(json['supplier_id']),
        supplierPhone: (json['supplier_phone'] ?? '').toString(),
        checkinLat: _asDouble(json['checkin_lat']),
        checkinLng: _asDouble(json['checkin_lng']),
        checkinPhoto: _nullableText(json['checkin_photo']),
        checkoutLat: _asDouble(json['checkout_lat']),
        checkoutLng: _asDouble(json['checkout_lng']),
        checkoutAddress: (json['checkout_address'] ?? '').toString(),
        checkoutPhoto: _nullableText(json['checkout_photo']),
        durationMinutes: _nullableInt(json['duration_minutes']),
        distanceFromSupplier: _asDouble(json['distance_from_supplier']),
        workOrderIds: (json['work_order_ids'] ?? '').toString(),
        notes: (json['notes'] ?? '').toString(),
        status: (json['status'] ?? 'SELESAI').toString(),
        checkedInAt:
            (json['checked_in_at'] ??
                    json['checkin_at'] ??
                    json['created_at'] ??
                    '')
                .toString(),
        checkedOutAt: (json['checked_out_at'] ?? json['checkout_at'] ?? '')
            .toString(),
        address: (json['address'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'supplier_name': supplierName,
    'status': status,
    'checked_in_at': checkedInAt,
    'checked_out_at': checkedOutAt,
    'address': address,
    'supplier_id': supplierId,
    'supplier_phone': supplierPhone,
    'checkin_lat': checkinLat,
    'checkin_lng': checkinLng,
    'checkin_photo': checkinPhoto,
    'checkout_lat': checkoutLat,
    'checkout_lng': checkoutLng,
    'checkout_address': checkoutAddress,
    'checkout_photo': checkoutPhoto,
    'duration_minutes': durationMinutes,
    'distance_from_supplier': distanceFromSupplier,
    'work_order_ids': workOrderIds,
    'notes': notes,
  };
}

int _asInt(dynamic value, {int fallback = 0}) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

int? _nullableInt(dynamic value) => value == null ? null : _asInt(value);

double? _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
