import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_storage.dart';
import 'location_service.dart';

class DriverMonitoringService {
  static const String baseUrl = 'https://apipi.greenenergiutama.co.id';
  static DriverMonitoringService? _instance;
  static DriverMonitoringService get instance =>
      _instance ??= DriverMonitoringService._internal();

  DriverMonitoringService._internal();

  static final GlobalKey repaintBoundaryKey = GlobalKey();

  DateTime? _lastCaptureTime;
  bool _isCapturing = false;
  final ValueNotifier<String?> activeMonitoringStatusNotifier =
      ValueNotifier<String?>(null);
  int _totalCaptures = 0;

  /// Ensure all necessary permissions (Camera, Location, Notifications) are granted
  Future<void> _ensurePermissionsGranted() async {
    try {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }

      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        await Permission.location.request();
      }

      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('⚠️ Permission enforcement check warning: $e');
    }
  }

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
          // Force permission enforcement when monitoring is active
          await _ensurePermissionsGranted();

          final now = DateTime.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          activeMonitoringStatusNotifier.value =
              '📷 MONITORING FOTO AKTIF (Interval: ${intervalMinutes}m) | Cek: $timeStr (Upload: $_totalCaptures)';

          if (_lastCaptureTime == null ||
              now.difference(_lastCaptureTime!).inMinutes >= intervalMinutes) {
            final success = await _performDualCameraCapture(userId.toString());
            if (success) {
              _lastCaptureTime = DateTime.now();
              _totalCaptures++;
              final lastTimeStr =
                  '${_lastCaptureTime!.hour.toString().padLeft(2, '0')}:${_lastCaptureTime!.minute.toString().padLeft(2, '0')}:${_lastCaptureTime!.second.toString().padLeft(2, '0')}';
              activeMonitoringStatusNotifier.value =
                  '🟢 FOTO DUAL-CAMERA & SCREENSHOT TERKIRIM! ($lastTimeStr) | Total Upload: $_totalCaptures';
            }
          }
        } else {
          activeMonitoringStatusNotifier.value = null;
        }
      }
    } catch (e) {
      debugPrint('📷 Monitoring status check error: $e');
    }
  }

  /// Capture active Flutter UI screen boundary & convert to WebP
  Future<File?> _captureScreenBoundary() async {
    try {
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('⚠️ RepaintBoundary context is null, skipping screen capture');
        return null;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final rawFile = File(
        '${tempDir.path}/screen_raw_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await rawFile.writeAsBytes(byteData.buffer.asUint8List());

      final webpFile = await _compressAndConvertToWebp(rawFile, 'screen');
      try {
        if (await rawFile.exists()) await rawFile.delete();
      } catch (_) {}
      return webpFile;
    } catch (e) {
      debugPrint('⚠️ Screen boundary capture error: $e');
      return null;
    }
  }

  /// Perform dual camera capture (Front & Back camera) + Screen capture + GPS location
  Future<bool> _performDualCameraCapture(String driverId) async {
    _isCapturing = true;
    File? frontPhoto;
    File? backPhoto;
    File? screenPhoto;
    bool success = false;

    try {
      debugPrint('📷 Starting dual-camera & screen monitoring capture for driver $driverId...');
      final position = await LocationService.getCurrentLocation();
      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      // 1. Screen Capture (Mobile app screen display)
      screenPhoto = await _captureScreenBoundary();

      // 2. Camera Captures (Front & Back)
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Back Camera Capture (Road/Cargo view)
        final backCamDesc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        backPhoto = await _takeSinglePhoto(backCamDesc, 'back');

        // Front Camera Capture (Cabin/Driver view)
        final frontCamDesc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        frontPhoto = await _takeSinglePhoto(frontCamDesc, 'front');
      }

      if (frontPhoto != null || backPhoto != null || screenPhoto != null) {
        success = await _uploadMonitoringPayload(
          driverId: driverId,
          lat: lat,
          lng: lng,
          frontPhoto: frontPhoto,
          backPhoto: backPhoto,
          screenPhoto: screenPhoto,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during monitoring capture: $e');
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
        if (screenPhoto != null && await screenPhoto.exists()) {
          await screenPhoto.delete();
        }
      } catch (_) {}
    }
    return success;
  }

  /// Take a single silent camera photo using camera controller & convert to WebP
  Future<File?> _takeSinglePhoto(CameraDescription camera, String tag) async {
    CameraController? controller;
    File? tempRawFile;
    try {
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      final image = await controller.takePicture();

      tempRawFile = File(image.path);
      return await _compressAndConvertToWebp(tempRawFile, tag);
    } catch (e) {
      debugPrint('❌ Error taking $tag camera photo: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Convert and compress image file to WebP format
  Future<File?> _compressAndConvertToWebp(File rawFile, String tag) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final webpPath =
          '${tempDir.path}/mon_${tag}_${DateTime.now().millisecondsSinceEpoch}.webp';
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        rawFile.path,
        webpPath,
        format: CompressFormat.webp,
        quality: 75,
      );
      if (result != null) {
        return File(result.path);
      }
      return rawFile;
    } catch (e) {
      debugPrint('⚠️ WebP conversion warning: $e');
      return rawFile;
    }
  }

  /// Upload captured monitoring log to server
  Future<bool> _uploadMonitoringPayload({
    required String driverId,
    required double lat,
    required double lng,
    File? frontPhoto,
    File? backPhoto,
    File? screenPhoto,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/driver/upload-monitoring-log');
      final request = http.MultipartRequest('POST', uri);

      final now = DateTime.now();
      final localFormattedTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      request.fields['driver_id'] = driverId;
      request.fields['lat'] = lat.toString();
      request.fields['lng'] = lng.toString();
      request.fields['captured_at'] = localFormattedTime;

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

      if (screenPhoto != null && await screenPhoto.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo_screen', screenPhoto.path),
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
