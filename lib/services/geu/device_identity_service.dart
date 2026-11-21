import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable, app-install scoped identifier used by the API's mobile device lock.
class DeviceIdentityService {
  DeviceIdentityService._();

  static const _storageKey = 'geu_installation_device_id';
  static const _uuid = Uuid();
  static Future<String>? _deviceIdFuture;
  static Future<String>? _descriptionFuture;

  static Future<String> getDeviceId() =>
      _deviceIdFuture ??= _loadOrCreateDeviceId();

  /// Sent as the `User-Agent` on every GeuApiClient request so the admin
  /// device-lock list (geu-onelogin/app/admin/device-lock/page.tsx) shows the
  /// real phone instead of Dio's generic default UA, which its browser-only
  /// regex parser can't read at all ("Browser/OS tidak dikenal"). No real
  /// hardware serial is obtainable on modern Android/iOS without special
  /// permissions, so `getDeviceId()` (this install's own UUID) stands in for
  /// it here, same one already used as the device-lock key.
  static Future<String> getDeviceDescription() =>
      _descriptionFuture ??= _buildDeviceDescription();

  static Future<String> _buildDeviceDescription() async {
    final appVersion = await _appVersion();
    final deviceId = await getDeviceId();
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return 'OneLink-Mobile/$appVersion (Android ${info.version.release}; '
            'SDK ${info.version.sdkInt}; ${info.manufacturer} ${info.model}; '
            'id $deviceId)';
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return 'OneLink-Mobile/$appVersion (iOS ${info.systemVersion}; '
            '${info.model} ${info.name}; id $deviceId)';
      }
    } catch (_) {}
    return 'OneLink-Mobile/$appVersion (id $deviceId)';
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<String> _loadOrCreateDeviceId() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = preferences.getString(_storageKey)?.trim();
      if (existing != null && existing.isNotEmpty) return existing;

      final deviceId = _uuid.v4();
      final saved = await preferences.setString(_storageKey, deviceId);
      if (!saved) {
        throw StateError('Identitas perangkat tidak dapat disimpan.');
      }
      return deviceId;
    } catch (_) {
      _deviceIdFuture = null;
      rethrow;
    }
  }
}
