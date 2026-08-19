class SettlementMappingItem {
  final int id;
  final String? kode;
  final String? tglKalkulasi;
  final int gudangId;
  final String? gudangName;
  final int? driverId;
  final String? driverName;
  final double? totalCostPlanned;
  final double? totalCostActual;
  final double? varianceAmount;
  final String? financeStatus;
  final String? settlementStatus;
  final double? totalDistance;
  final double? costPerKm;
  final double? costPerPickup;
  final SettlementCostData? costData;
  final SettlementRouteData? routeData;

  SettlementMappingItem({
    required this.id,
    this.kode,
    this.tglKalkulasi,
    required this.gudangId,
    this.gudangName,
    this.driverId,
    this.driverName,
    this.totalCostPlanned,
    this.totalCostActual,
    this.varianceAmount,
    this.financeStatus,
    this.settlementStatus,
    this.totalDistance,
    this.costPerKm,
    this.costPerPickup,
    this.costData,
    this.routeData,
  });

  factory SettlementMappingItem.fromJson(Map<String, dynamic> json) {
    return SettlementMappingItem(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      kode: json['kode'] as String?,
      tglKalkulasi: json['tgl_kalkulasi'] as String?,
      gudangId: json['gudang_id'] is int ? json['gudang_id'] : int.parse('${json['gudang_id'] ?? 0}'),
      gudangName: json['gudang_name'] as String?,
      driverId: json['driver_id'] != null ? (json['driver_id'] is int ? json['driver_id'] : int.tryParse('${json['driver_id']}')) : null,
      driverName: json['driver_name'] as String?,
      totalCostPlanned: json['total_cost_planned'] != null ? double.tryParse('${json['total_cost_planned']}') : null,
      totalCostActual: json['total_cost_actual'] != null ? double.tryParse('${json['total_cost_actual']}') : null,
      varianceAmount: json['variance_amount'] != null ? double.tryParse('${json['variance_amount']}') : null,
      financeStatus: json['finance_status'] as String?,
      settlementStatus: json['settlement_status'] as String?,
      totalDistance: json['total_distance'] != null ? double.tryParse('${json['total_distance']}') : null,
      costPerKm: json['cost_per_km'] != null ? double.tryParse('${json['cost_per_km']}') : null,
      costPerPickup: json['cost_per_pickup'] != null ? double.tryParse('${json['cost_per_pickup']}') : null,
      costData: json['cost_data'] != null ? SettlementCostData.fromJson(json['cost_data']) : null,
      routeData: json['route_data'] != null ? SettlementRouteData.fromJson(json['route_data']) : null,
    );
  }
}

class SettlementCostData {
  final double bbmRatio;
  final double fuelPrice;
  final double tollCost;
  final double parkingCost;
  final double alkonCost;
  final double dwCost;
  final double miscCost;
  final double fuelCost;
  final double totalCost;

  SettlementCostData({
    required this.bbmRatio,
    required this.fuelPrice,
    required this.tollCost,
    required this.parkingCost,
    required this.alkonCost,
    required this.dwCost,
    required this.miscCost,
    required this.fuelCost,
    required this.totalCost,
  });

  factory SettlementCostData.fromJson(Map<String, dynamic> json) {
    return SettlementCostData(
      bbmRatio: double.tryParse('${json['bbm_ratio']}') ?? 0.0,
      fuelPrice: double.tryParse('${json['fuel_price']}') ?? 0.0,
      tollCost: double.tryParse('${json['toll_cost']}') ?? 0.0,
      parkingCost: double.tryParse('${json['parking_cost']}') ?? 0.0,
      alkonCost: double.tryParse('${json['alkon_cost']}') ?? 0.0,
      dwCost: double.tryParse('${json['dw_cost']}') ?? 0.0,
      miscCost: double.tryParse('${json['misc_cost']}') ?? 0.0,
      fuelCost: double.tryParse('${json['fuel_cost']}') ?? 0.0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0.0,
    );
  }
}

class SettlementRouteData {
  final double totalDistance;
  final int pickupCount;
  final double totalWeight;
  final int? driverId;
  final String? driverName;

  SettlementRouteData({
    required this.totalDistance,
    required this.pickupCount,
    required this.totalWeight,
    this.driverId,
    this.driverName,
  });

  factory SettlementRouteData.fromJson(Map<String, dynamic> json) {
    return SettlementRouteData(
      totalDistance: double.tryParse('${json['total_distance']}') ?? 0.0,
      pickupCount: json['pickup_count'] is int ? json['pickup_count'] : int.tryParse('${json['pickup_count']}') ?? 0,
      totalWeight: double.tryParse('${json['total_weight']}') ?? 0.0,
      driverId: json['driver_id'] != null ? (json['driver_id'] is int ? json['driver_id'] : int.tryParse('${json['driver_id']}')) : null,
      driverName: json['driver_name'] as String?,
    );
  }
}

class SettlementDetailFull {
  final SettlementMappingItem calculation;
  final SettlementData? settlement;

  SettlementDetailFull({
    required this.calculation,
    this.settlement,
  });

  factory SettlementDetailFull.fromJson(Map<String, dynamic> json) {
    return SettlementDetailFull(
      calculation: SettlementMappingItem.fromJson(json['calculation']),
      settlement: json['settlement'] != null ? SettlementData.fromJson(json['settlement']) : null,
    );
  }
}

class SettlementData {
  final int id;
  final double actualFuelCost;
  final double actualParkingCost;
  final double actualTollCost;
  final double actualDriverCost;
  final double actualVehicleOperationalCost;
  final double actualOtherCosts;
  final double totalActualCost;
  final double plannedTotalCost;
  final double varianceAmount;
  final double variancePercentage;
  final String status;
  final double distanceTraveled;
  final String? buktiFuelPath;
  final String? buktiTollPath;
  final String? buktiParkingPath;
  final String? buktiOtherPath;
  final double actualNonReceiptCost;
  final String? alasanNonReceipt;
  final String? buktiNonReceiptPath;
  final String? settlementNotes;
  final String? rejectionReason;
  final List<SettlementItemEntry> settlementItems;

  SettlementData({
    required this.id,
    required this.actualFuelCost,
    required this.actualParkingCost,
    required this.actualTollCost,
    required this.actualDriverCost,
    required this.actualVehicleOperationalCost,
    required this.actualOtherCosts,
    required this.totalActualCost,
    required this.plannedTotalCost,
    required this.varianceAmount,
    required this.variancePercentage,
    required this.status,
    required this.distanceTraveled,
    this.buktiFuelPath,
    this.buktiTollPath,
    this.buktiParkingPath,
    this.buktiOtherPath,
    required this.actualNonReceiptCost,
    this.alasanNonReceipt,
    this.buktiNonReceiptPath,
    this.settlementNotes,
    this.rejectionReason,
    this.settlementItems = const [],
  });

  factory SettlementData.fromJson(Map<String, dynamic> json) {
    var itemsList = <SettlementItemEntry>[];
    if (json['settlement_items'] != null && json['settlement_items'] is List) {
      itemsList = (json['settlement_items'] as List)
          .map((i) => SettlementItemEntry.fromJson(i))
          .toList();
    }

    return SettlementData(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      actualFuelCost: double.tryParse('${json['actual_fuel_cost']}') ?? 0.0,
      actualParkingCost: double.tryParse('${json['actual_parking_cost']}') ?? 0.0,
      actualTollCost: double.tryParse('${json['actual_toll_cost']}') ?? 0.0,
      actualDriverCost: double.tryParse('${json['actual_driver_cost']}') ?? 0.0,
      actualVehicleOperationalCost: double.tryParse('${json['actual_vehicle_operational_cost']}') ?? 0.0,
      actualOtherCosts: double.tryParse('${json['actual_other_costs']}') ?? 0.0,
      totalActualCost: double.tryParse('${json['total_actual_cost']}') ?? 0.0,
      plannedTotalCost: double.tryParse('${json['planned_total_cost']}') ?? 0.0,
      varianceAmount: double.tryParse('${json['variance_amount']}') ?? 0.0,
      variancePercentage: double.tryParse('${json['variance_percentage']}') ?? 0.0,
      status: json['status'] ?? 'pending',
      distanceTraveled: double.tryParse('${json['distance_traveled']}') ?? 0.0,
      buktiFuelPath: json['bukti_fuel_path'] as String?,
      buktiTollPath: json['bukti_toll_path'] as String?,
      buktiParkingPath: json['bukti_parking_path'] as String?,
      buktiOtherPath: json['bukti_other_path'] as String?,
      actualNonReceiptCost: double.tryParse('${json['actual_non_receipt_cost']}') ?? 0.0,
      alasanNonReceipt: json['alasan_non_receipt'] as String?,
      buktiNonReceiptPath: json['bukti_non_receipt_path'] as String?,
      settlementNotes: json['settlement_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      settlementItems: itemsList,
    );
  }
}

class SettlementItemEntry {
  final String category;
  final double amount;
  final String notes;
  final String? fileName;
  final String? fileData;
  final bool rejected;

  SettlementItemEntry({
    required this.category,
    required this.amount,
    required this.notes,
    this.fileName,
    this.fileData,
    this.rejected = false,
  });

  factory SettlementItemEntry.fromJson(Map<String, dynamic> json) {
    return SettlementItemEntry(
      category: json['category'] ?? '',
      amount: double.tryParse('${json['amount']}') ?? 0.0,
      notes: json['notes'] ?? '',
      fileName: json['file_name'] as String?,
      fileData: json['file_data'] as String?,
      rejected: json['rejected'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'notes': notes,
      if (fileName != null) 'file_name': fileName,
      if (fileData != null) 'file_data': fileData,
      'rejected': rejected,
    };
  }
}
