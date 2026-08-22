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

class SupplierOrderSummary {
  final int totalOrderCount;
  final double totalOrderNominal;
  final DateTime? lastOrderDate;
  final double? lastOrderNominal;
  final double? lastOrderQtyKg;
  final List<SupplierOrderHistoryItem> recentOrders;

  const SupplierOrderSummary({
    required this.totalOrderCount,
    required this.totalOrderNominal,
    this.lastOrderDate,
    this.lastOrderNominal,
    this.lastOrderQtyKg,
    this.recentOrders = const [],
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
          .map((e) => SupplierOrderHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasHistory => totalOrderCount > 0;
}
