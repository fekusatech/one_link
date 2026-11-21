import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

/// Device-level security posture: root/jailbreak and fake-GPS *capability*.
///
/// This is a different signal than the live per-fix `position.isMocked`
/// check used for checkin/checkout and continuous tracking (gps_service.dart,
/// location_tracking_service.dart, fake_gps_alert_service.dart) - that one
/// tells you a specific GPS fix was mocked. safe_device's isMockLocation
/// checks the device's current mock-location state directly (Android:
/// whether a mock-location app is actively set), so the two can disagree
/// slightly, and that's expected - they're checking different things.
///
/// Never throws - any plugin failure (unsupported platform, missing
/// permission) is treated as "unknown," never surfaced as a false negative
/// or a blocker. This mirrors the checkin/checkout mock-location posture:
/// detect and report, never block.
class DeviceSecurityResult {
  final bool? isRooted;
  final bool? isMockLocationActive;
  final bool? isRealDevice;
  final String? error;

  const DeviceSecurityResult({
    this.isRooted,
    this.isMockLocationActive,
    this.isRealDevice,
    this.error,
  });

  bool get hasRisk => isRooted == true || isMockLocationActive == true;
}

class DeviceSecurityService {
  static DeviceSecurityResult? lastResult;

  static Future<DeviceSecurityResult> check() async {
    bool? isRooted;
    bool? isMockLocationActive;
    bool? isRealDevice;
    String? error;

    try {
      isRooted = await SafeDevice.isJailBroken;
    } catch (e) {
      debugPrint('⚠️ Root check failed: $e');
    }
    try {
      isMockLocationActive = await SafeDevice.isMockLocation;
    } catch (e) {
      debugPrint('⚠️ Mock location check failed: $e');
    }
    try {
      isRealDevice = await SafeDevice.isRealDevice;
    } catch (e) {
      debugPrint('⚠️ Real device check failed: $e');
    }

    if (isRooted == null && isMockLocationActive == null && isRealDevice == null) {
      error = 'Pemeriksaan keamanan perangkat tidak tersedia di perangkat ini.';
    }

    final result = DeviceSecurityResult(
      isRooted: isRooted,
      isMockLocationActive: isMockLocationActive,
      isRealDevice: isRealDevice,
      error: error,
    );
    lastResult = result;
    return result;
  }
}
