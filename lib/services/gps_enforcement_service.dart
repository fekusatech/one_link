import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_storage.dart';
import 'location_tracking_service.dart';

class GpsEnforcementService {
  static final GpsEnforcementService _instance =
      GpsEnforcementService._internal();
  static GpsEnforcementService get instance => _instance;

  GpsEnforcementService._internal();

  Timer? _enforcementTimer;
  bool _isEnforcing = false;

  /// Start enforcing GPS consent and permissions
  void startEnforcement() {
    if (_isEnforcing) return;

    _isEnforcing = true;

    // Check every 30 seconds
    _enforcementTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkGpsCompliance(),
    );

    // Initial check
    _checkGpsCompliance();
  }

  /// Stop enforcement
  void stopEnforcement() {
    _isEnforcing = false;
    _enforcementTimer?.cancel();
    _enforcementTimer = null;
  }

  /// Check if GPS compliance is maintained
  Future<void> _checkGpsCompliance() async {
    try {
      // 1. Check if mandatory GPS consent is still given
      final hasConsent = await UserStorage.hasMandatoryGpsConsent();
      if (!hasConsent) {
        await _enforceExit('GPS consent revoked');
        return;
      }

      // 2. Check if location permission is still granted
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        await _enforceExit('Location permission denied');
        return;
      }

      // 3. Check if location services are enabled
      final serviceEnabled = await Permission.location.serviceStatus;
      if (!serviceEnabled.isEnabled) {
        await _enforceExit('Location services disabled');
        return;
      }

      // 4. Ensure tracking is still active
      if (!LocationTrackingService.instance.isTracking) {
        // Try to restart tracking
        final success = await LocationTrackingService.instance
            .startTrackingWithoutPermissionCheck();
        if (!success) {
          await _enforceExit('GPS tracking stopped');
          return;
        }
      }
    } catch (e) {
      print('GPS enforcement check failed: $e');
      // Don't exit on errors, just log them
    }
  }

  /// Force exit app due to GPS compliance violation
  Future<void> _enforceExit(String reason) async {
    print('GPS Enforcement: Exiting app - $reason');

    // Stop enforcement to prevent multiple exits
    stopEnforcement();

    // Force close the app
    await SystemNavigator.pop();
  }

  /// Check if app can continue running
  Future<bool> canContinueRunning() async {
    try {
      // Check mandatory GPS consent
      final hasConsent = await UserStorage.hasMandatoryGpsConsent();
      if (!hasConsent) return false;

      // Check location permission
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) return false;

      // Check location services
      final serviceEnabled = await Permission.location.serviceStatus;
      if (!serviceEnabled.isEnabled) return false;

      return true;
    } catch (e) {
      print('Error checking GPS compliance: $e');
      return false;
    }
  }

  /// Get detailed compliance status
  Future<GpsComplianceStatus> getComplianceStatus() async {
    try {
      final hasConsent = await UserStorage.hasMandatoryGpsConsent();
      final locationStatus = await Permission.location.status;
      final serviceEnabled = await Permission.location.serviceStatus;
      final isTracking = LocationTrackingService.instance.isTracking;

      return GpsComplianceStatus(
        hasConsent: hasConsent,
        hasPermission: locationStatus.isGranted,
        serviceEnabled: serviceEnabled.isEnabled,
        isTracking: isTracking,
        isCompliant:
            hasConsent &&
            locationStatus.isGranted &&
            serviceEnabled.isEnabled &&
            isTracking,
      );
    } catch (e) {
      return GpsComplianceStatus(
        hasConsent: false,
        hasPermission: false,
        serviceEnabled: false,
        isTracking: false,
        isCompliant: false,
        error: e.toString(),
      );
    }
  }
}

/// GPS compliance status data class
class GpsComplianceStatus {
  final bool hasConsent;
  final bool hasPermission;
  final bool serviceEnabled;
  final bool isTracking;
  final bool isCompliant;
  final String? error;

  const GpsComplianceStatus({
    required this.hasConsent,
    required this.hasPermission,
    required this.serviceEnabled,
    required this.isTracking,
    required this.isCompliant,
    this.error,
  });

  @override
  String toString() {
    return 'GpsComplianceStatus('
        'consent: $hasConsent, '
        'permission: $hasPermission, '
        'service: $serviceEnabled, '
        'tracking: $isTracking, '
        'compliant: $isCompliant'
        '${error != null ? ', error: $error' : ''})';
  }
}
