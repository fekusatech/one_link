import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/tms/settlement_model.dart';
import '../geu/geu_api_client.dart';

class TmsSettlementService {
  /// GET /api-tms/settlement-mapping/ - Daftar settlement Uang Jalan
  static Future<List<SettlementMappingItem>> getSettlements({
    int? driverId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (driverId != null) 'driver_id': driverId,
        if (status != null) 'status': status,
      };

      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/settlement-mapping/',
        queryParameters: queryParams,
      );

      final dynamic data = response.data;
      List<dynamic> list = [];

      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] != null) {
        if (data['data'] is List) {
          list = data['data'];
        } else if (data['data'] is Map && data['data']['data'] != null && data['data']['data'] is List) {
          list = data['data']['data'];
        } else if (data['data'] is Map && data['data']['items'] != null && data['data']['items'] is List) {
          list = data['data']['items'];
        }
      }

      return list.map((item) => SettlementMappingItem.fromJson(item)).toList();
    } catch (e) {
      print('❌ Error fetching settlements: $e');
      rethrow;
    }
  }

  /// GET /api-tms/settlement-mapping/:id - Detail settlement
  static Future<SettlementDetailFull> getSettlementById(int id) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/settlement-mapping/$id',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonData = {};

      if (data is Map<String, dynamic>) {
        if (data['calculation'] != null) {
          jsonData = data;
        } else if (data['data'] != null && data['data'] is Map<String, dynamic>) {
          jsonData = data['data'];
        } else {
          jsonData = data;
        }
      }

      return SettlementDetailFull.fromJson(jsonData);
    } catch (e) {
      print('❌ Error fetching settlement detail #$id: $e');
      rethrow;
    }
  }

  /// POST /api-tms/settlement-mapping/:id/settlements/submit - Kirim pengajuan settlement driver
  static Future<bool> submitSettlementBulk({
    required int calculationId,
    required double actualFuelCost,
    required double actualParkingCost,
    required double actualTollCost,
    required double actualDriverCost,
    required double actualVehicleOperationalCost,
    required double actualOtherCosts,
    required double actualNonReceiptCost,
    String? alasanNonReceipt,
    String? settlementNotes,
    required double distanceTraveled,
    required List<SettlementItemEntry> items,
  }) async {
    try {
      final formData = FormData.fromMap({
        'execution_date': DateTime.now().toIso8601String().substring(0, 10),
        'actual_fuel_cost': actualFuelCost,
        'actual_parking_cost': actualParkingCost,
        'actual_toll_cost': actualTollCost,
        'actual_driver_cost': actualDriverCost,
        'actual_vehicle_operational_cost': actualVehicleOperationalCost,
        'actual_other_costs': actualOtherCosts,
        'actual_non_receipt_cost': actualNonReceiptCost,
        'alasan_non_receipt': alasanNonReceipt ?? '',
        'settlement_notes': settlementNotes ?? '',
        'distance_traveled': distanceTraveled,
        'items_json': jsonEncode(items.map((i) => i.toJson()).toList()),
      });

      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/settlement-mapping/$calculationId/settlements/submit',
        data: formData,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error submitting settlement #$calculationId: $e');
      rethrow;
    }
  }

  /// POST /api-tms/other-costs/:id/realizations - Kirim realisasi biaya operasional tambahan
  static Future<bool> createOtherCostRealization({
    required int costId,
    required double amount,
    required String notes,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/other-costs/$costId/realizations',
        data: {
          'amount': amount,
          'notes': notes,
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error creating other cost realization #$costId: $e');
      rethrow;
    }
  }
}
