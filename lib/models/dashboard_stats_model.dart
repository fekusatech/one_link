// Dashboard Statistics Model
class DashboardStats {
  final int totalSuppliers;
  final int activeSuppliers;
  final int newThisMonth;

  DashboardStats({
    required this.totalSuppliers,
    required this.activeSuppliers,
    required this.newThisMonth,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSuppliers:
          int.tryParse(json['total_suppliers']?.toString() ?? '0') ?? 0,
      activeSuppliers:
          int.tryParse(json['active_suppliers']?.toString() ?? '0') ?? 0,
      // The active Go response supplies new_today. Keep the established
      // property name to avoid breaking consumers, but never fabricate a
      // monthly number from a daily metric.
      newThisMonth:
          int.tryParse(
            json['new_today']?.toString() ??
                json['new_this_month']?.toString() ??
                '0',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_suppliers': totalSuppliers,
      'active_suppliers': activeSuppliers,
      'new_this_month': newThisMonth,
    };
  }
}
