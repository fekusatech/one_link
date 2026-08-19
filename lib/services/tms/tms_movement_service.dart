import 'package:dio/dio.dart';
import '../../models/tms/movement_model.dart';
import '../geu/geu_api_client.dart';

class TmsMovementService {
  /// GET /api-tms/movements/ - Daftar pergerakan armada / fleet movement
  static Future<List<MovementItem>> getMovements({
    int? driverId,
    String? progress,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (driverId != null) 'driver_id': driverId,
        if (progress != null) 'progress': progress,
      };

      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/movements/',
        queryParameters: queryParams,
      );

      final dynamic data = response.data;
      List<dynamic> list = [];

      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] != null) {
        if (data['data'] is List) {
          list = data['data'];
        } else if (data['data']['items'] != null && data['data']['items'] is List) {
          list = data['data']['items'];
        }
      }

      return list.map((item) => MovementItem.fromJson(item)).toList();
    } catch (e) {
      print('❌ Error fetching movements: $e');
      rethrow;
    }
  }

  /// GET /api-tms/movements/:id - Detail movement
  static Future<MovementItem> getMovementById(int id) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/movements/$id',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonData = {};

      if (data is Map<String, dynamic>) {
        if (data['data'] != null && data['data'] is Map<String, dynamic>) {
          jsonData = data['data'];
        } else {
          jsonData = data;
        }
      }

      return MovementItem.fromJson(jsonData);
    } catch (e) {
      print('❌ Error fetching movement detail #$id: $e');
      rethrow;
    }
  }

  /// POST /api-tms/movements/:id/loadings - Milestone loading (pemuatan muatan)
  static Future<bool> submitLoading({
    required int movementId,
    required double odometer,
    String? notes,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/movements/$movementId/loadings',
        data: {
          'odometer': odometer,
          'notes': notes ?? '',
          'tgl_loading': DateTime.now().toIso8601String(),
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error submitting loading #$movementId: $e');
      rethrow;
    }
  }

  /// POST /api-tms/movements/:id/unloadings - Milestone unloading (pembongkaran muatan)
  static Future<bool> submitUnloading({
    required int movementId,
    required double odometer,
    String? notes,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/movements/$movementId/unloadings',
        data: {
          'odometer': odometer,
          'notes': notes ?? '',
          'tgl_unloading': DateTime.now().toIso8601String(),
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error submitting unloading #$movementId: $e');
      rethrow;
    }
  }

  /// POST /api-tms/movements/:id/attachments - Upload foto bukti operasional movement
  static Future<bool> uploadAttachment({
    required int movementId,
    required String filePath,
    required String type,
    String? notes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': type,
        'notes': notes ?? '',
        'file': await MultipartFile.fromFile(filePath),
      });

      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api-tms/movements/$movementId/attachments',
        data: formData,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error uploading attachment for movement #$movementId: $e');
      rethrow;
    }
  }
}
