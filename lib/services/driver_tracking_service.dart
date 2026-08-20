import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'user_storage.dart';

class DriverTrackingService {
  static const String baseUrl = AppConfig.serverDomain;
  static const String trackingEndpoint = '/driver_tracking/save_location';
  
  static DriverTrackingService? _instance;
  static DriverTrackingService get instance => _instance ??= DriverTrackingService._internal();
  
  DriverTrackingService._internal();
  
  /// Send location data to tracking API
  Future<bool> sendLocationUpdate(Position position) async {
    try {
      final payload = await _buildLocationPayload(position);
      final token = await UserStorage.getToken();
      
      print('📡 Sending location update: ${payload['latitude']}, ${payload['longitude']}');
      
      final response = await http.post(
        Uri.parse('$baseUrl$trackingEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Location sent successfully');
        return true;
      } else {
        print('❌ Failed to send location: ${response.statusCode} - ${response.body}');
        return false;
      }
      
    } catch (e) {
      print('❌ Location tracking API error: $e');
      return false;
    }
  }
  
  /// Build location payload according to API specification
  Future<Map<String, dynamic>> _buildLocationPayload(Position position) async {
    final user = await UserStorage.getUser();
    final userId = await UserStorage.getUserId();
    final deviceInfo = await _getDeviceInfo();
    final batteryLevel = await _getBatteryLevel();
    final appVersion = await _getAppVersion();
    
    return {
      'karyawan_id': userId?.toString() ?? '0',
      'email': user?['email'] ?? 'unknown@example.com',
      'jabatan_name': user?['jabatan_name'] ?? user?['role'] ?? 'Driver',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed > 0 ? position.speed : null,
      'heading': position.heading > 0 ? position.heading : null,
      'altitude': position.altitude != 0 ? position.altitude : null,
      'timestamp': position.timestamp.toUtc().toIso8601String(),
      'battery_level': batteryLevel,
      'app_version': appVersion,
      'device_info': '$deviceInfo | App $appVersion',
      'timestamp_ms': position.timestamp.millisecondsSinceEpoch,
    };
  }

  /// Get app version string
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return 'v${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      return 'v1.1.6';
    }
  }
  
  /// Get device information string
  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} (${androidInfo.model}) - '
               '${androidInfo.brand} ${androidInfo.device}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion} (${iosInfo.model}) - ${iosInfo.name}';
      } else {
        return 'Unknown Device';
      }
    } catch (e) {
      return 'Device Info Unavailable';
    }
  }
  
  /// Get battery level percentage
  Future<int?> _getBatteryLevel() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      return level;
    } catch (e) {
      print('Failed to get battery level: $e');
      return null;
    }
  }
  
  /// Send batch location updates (for offline sync)
  Future<bool> sendBatchLocationUpdates(List<Position> positions) async {
    if (positions.isEmpty) return true;
    
    try {
      final List<Map<String, dynamic>> payloads = [];
      
      for (final position in positions) {
        final payload = await _buildLocationPayload(position);
        payloads.add(payload);
      }
      
      final token = await UserStorage.getToken();
      
      print('📡 Sending ${payloads.length} location updates in batch');
      
      final response = await http.post(
        Uri.parse('$baseUrl$trackingEndpoint/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'locations': payloads}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Batch location updates sent successfully');
        return true;
      } else {
        print('❌ Failed to send batch updates: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      print('❌ Batch location update error: $e');
      return false;
    }
  }
  
  /// Test connection to tracking API
  Future<bool> testConnection() async {
    try {
      final token = await UserStorage.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/driver_tracking/test'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}