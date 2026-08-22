/// Order-history slice of GET /api/suppliers/:id — the part the supplier
/// detail bottom sheet needs (last order, lifetime totals, recent orders
/// for the mini chart). See go-rest-api's SupplierDetail/attachOrderHistory.
class SupplierOrderHistoryItem {
  final DateTime date;
  final double nominal;
  final double qtyKg;

  const SupplierOrderHistoryItem({
    required this.date,
    required this.nominal,
    required this.qtyKg,
  });

  factory SupplierOrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return SupplierOrderHistoryItem(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0,
      qtyKg: (json['qty_kg'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One row of GET /api/suppliers/:id's `recent_followups` — a WA follow-up
/// attempt a field rep confirmed (sent ok, or not, with a reason). See
/// go-rest-api's FollowupLogItem/attachFollowupHistory.
class SupplierFollowupLogItem {
  final int id;
  final String userName;
  final String channel;
  final String? message;
  final bool confirmedSent;
  final String? invalidReason;
  final DateTime createdAt;

  const SupplierFollowupLogItem({
    required this.id,
    required this.userName,
    required this.channel,
    this.message,
    required this.confirmedSent,
    this.invalidReason,
    required this.createdAt,
  });

  factory SupplierFollowupLogItem.fromJson(Map<String, dynamic> json) {
    return SupplierFollowupLogItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userName: (json['user_name'] ?? '').toString(),
      channel: (json['channel'] ?? 'whatsapp').toString(),
      message: json['message']?.toString(),
      confirmedSent: json['confirmed_sent'] == true,
      invalidReason: json['invalid_reason']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SupplierOrderSummary {
  final int totalOrderCount;
  final double totalOrderNominal;
  final DateTime? lastOrderDate;
  final double? lastOrderNominal;
  final double? lastOrderQtyKg;
  final List<SupplierOrderHistoryItem> recentOrders;
  final bool? waValid;
  final String? waInvalidReason;
  final DateTime? waCheckedAt;
  final int followupCount;
  final List<SupplierFollowupLogItem> recentFollowups;

  const SupplierOrderSummary({
    required this.totalOrderCount,
    required this.totalOrderNominal,
    this.lastOrderDate,
    this.lastOrderNominal,
    this.lastOrderQtyKg,
    this.recentOrders = const [],
    this.waValid,
    this.waInvalidReason,
    this.waCheckedAt,
    this.followupCount = 0,
    this.recentFollowups = const [],
  });

  factory SupplierOrderSummary.fromJson(Map<String, dynamic> json) {
    return SupplierOrderSummary(
      totalOrderCount: json['total_order_count'] ?? 0,
      totalOrderNominal: (json['total_order_nominal'] as num?)?.toDouble() ?? 0,
      lastOrderDate: json['last_order_date'] != null
          ? DateTime.tryParse(json['last_order_date'].toString())
          : null,
      lastOrderNominal: (json['last_order_nominal'] as num?)?.toDouble(),
      lastOrderQtyKg: (json['last_order_qty_kg'] as num?)?.toDouble(),
      recentOrders: (json['recent_orders'] as List<dynamic>? ?? [])
          .map(
            (e) => SupplierOrderHistoryItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      waValid: json['wa_valid'] == null
          ? null
          : json['wa_valid'] == 1 || json['wa_valid'] == true,
      waInvalidReason: json['wa_invalid_reason']?.toString(),
      waCheckedAt: json['wa_checked_at'] != null
          ? DateTime.tryParse(json['wa_checked_at'].toString())
          : null,
      followupCount: (json['followup_count'] as num?)?.toInt() ?? 0,
      recentFollowups: (json['recent_followups'] as List<dynamic>? ?? [])
          .map(
            (e) => SupplierFollowupLogItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get hasHistory => totalOrderCount > 0;
}
