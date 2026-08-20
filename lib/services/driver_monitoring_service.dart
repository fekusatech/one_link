import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'user_storage.dart';
import 'location_service.dart';

class DriverMonitoringService {
  static const String baseUrl = 'https://apipi.greenenergiutama.co.id';
  static DriverMonitoringService? _instance;
  static DriverMonitoringService get instance =>
      _instance ??= DriverMonitoringService._internal();

  DriverMonitoringService._internal();

  DateTime? _lastCaptureTime;
  bool _isCapturing = false;
  final ValueNotifier<String?> activeMonitoringStatusNotifier =
      ValueNotifier<String?>(null);
  int _totalCaptures = 0;

  /// Check active monitoring status from server and capture dual photos if active
  Future<void> checkAndExecuteMonitoring() async {
    if (_isCapturing) return;

    try {
      final userId = await UserStorage.getUserId();
      final email = await UserStorage.getUserEmail();
      if (userId == null && email.isEmpty) return;

      final url = Uri.parse(
        '$baseUrl/api/driver/monitoring-status?driver_id=${userId ?? ""}&email=${Uri.encodeComponent(email)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (_) {
          return;
        }

        if (data is! Map<String, dynamic>) return;
        final bool isActive = data['is_active'] == 1 || data['is_active'] == true;
        final int intervalMinutes = (data['interval_minutes'] as num?)?.toInt() ?? 5;

        if (isActive) {
          final now = DateTime.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          activeMonitoringStatusNotifier.value =
              '📷 MONITORING FOTO AKTIF (Interval: ${intervalMinutes}m) | Cek: $timeStr (Upload: $_totalCaptures)';

          if (_lastCaptureTime == null ||
              now.difference(_lastCaptureTime!).inMinutes >= intervalMinutes) {
            final success = await _performDualCameraCapture(userId.toString());
            if (success) {
              _totalCaptures++;
            }
            _lastCaptureTime = DateTime.now();
            final lastTimeStr =
                '${_lastCaptureTime!.hour.toString().padLeft(2, '0')}:${_lastCaptureTime!.minute.toString().padLeft(2, '0')}:${_lastCaptureTime!.second.toString().padLeft(2, '0')}';
            activeMonitoringStatusNotifier.value =
                '🟢 FOTO DUAL-CAMERA TERKIRIM! ($lastTimeStr) | Total Upload: $_totalCaptures';
          }
        } else {
          activeMonitoringStatusNotifier.value = null;
        }
      }
    } catch (e) {
      debugPrint('📷 Monitoring status check error: $e');
    }
  }

  /// Perform dual camera capture (Front & Back camera) + GPS location
  Future<bool> _performDualCameraCapture(String driverId) async {
    _isCapturing = true;
    File? frontPhoto;
    File? backPhoto;
    bool success = false;

    try {
      debugPrint('📷 Starting dual-camera monitoring capture for driver $driverId...');
      final position = await LocationService.getCurrentLocation();
      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // 1. Back Camera Capture (Road/Cargo view)
        final backCamDesc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        backPhoto = await _takeSinglePhoto(backCamDesc, 'back');

        // 2. Front Camera Capture (Cabin/Driver view)
        final frontCamDesc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        frontPhoto = await _takeSinglePhoto(frontCamDesc, 'front');
      }

      if (frontPhoto != null || backPhoto != null) {
        success = await _uploadMonitoringPayload(
          driverId: driverId,
          lat: lat,
          lng: lng,
          frontPhoto: frontPhoto,
          backPhoto: backPhoto,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during monitoring dual camera capture: $e');
    } finally {
      _isCapturing = false;
      // Clean up temporary photo files
      try {
        if (frontPhoto != null && await frontPhoto.exists()) {
          await frontPhoto.delete();
        }
        if (backPhoto != null && await backPhoto.exists()) {
          await backPhoto.delete();
        }
      } catch (_) {}
    }
    return success;
  }

  /// Take a single silent camera photo using camera controller
  Future<File?> _takeSinglePhoto(CameraDescription camera, String tag) async {
    CameraController? controller;
    try {
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      final image = await controller.takePicture();

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/mon_${tag}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(image.path);
      return await file.copy(targetPath);
    } catch (e) {
      debugPrint('❌ Error taking $tag camera photo: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Upload captured monitoring log to server
  Future<bool> _uploadMonitoringPayload({
    required String driverId,
    required double lat,
    required double lng,
    File? frontPhoto,
    File? backPhoto,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/driver/upload-monitoring-log');
      final request = http.MultipartRequest('POST', uri);

      request.fields['driver_id'] = driverId;
      request.fields['lat'] = lat.toString();
      request.fields['lng'] = lng.toString();
      request.fields['captured_at'] = DateTime.now().toIso8601String();

      if (frontPhoto != null && await frontPhoto.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo_front', frontPhoto.path),
        );
      }

      if (backPhoto != null && await backPhoto.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo_back', backPhoto.path),
        );
      }

      debugPrint('📡 Uploading monitoring payload to $uri...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint('✅ Monitoring photo log uploaded successfully: ${response.body}');
        return true;
      } else {
        debugPrint('❌ Monitoring photo log upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Monitoring upload network error: $e');
      return false;
    }
  }
}
