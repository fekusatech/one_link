import 'package:flutter/material.dart';
import 'user_storage.dart';
import 'location_tracking_service.dart';

class MandatoryGpsService {
  static MandatoryGpsService? _instance;
  static MandatoryGpsService get instance =>
      _instance ??= MandatoryGpsService._internal();

  MandatoryGpsService._internal();

  /// Check if user needs to go through mandatory GPS consent flow
  Future<bool> needsMandatoryGpsConsent() async {
    bool isLoggedIn = await UserStorage.isLoggedIn();
    if (!isLoggedIn) return false;

    // Check if user has already given mandatory consent
    bool hasConsent = await UserStorage.hasMandatoryGpsConsent();
    if (hasConsent) return false;

    // Check if system location permissions are ALREADY granted on device (whileInUse or always)
    bool systemGranted = await hasSystemLocationPermissions();
    if (systemGranted) {
      await UserStorage.setLocationTrackingConsent(true);
      await UserStorage.setMandatoryGpsConsentGiven(true);
      return false; // Already granted in Android system, skip popup!
    }

    return false; // Never block logged-in user on app launch after force stop!
  }

  /// Check if app can proceed to main screens
  Future<bool> canProceedToMain() async {
    bool isLoggedIn = await UserStorage.isLoggedIn();

    if (!isLoggedIn) {
      return false; // Must login first
    }

    bool hasConsent = await UserStorage.hasMandatoryGpsConsent();
    if (hasConsent) return true;

    bool systemGranted = await hasSystemLocationPermissions();
    if (systemGranted) {
      await UserStorage.setLocationTrackingConsent(true);
      await UserStorage.setMandatoryGpsConsentGiven(true);
      return true;
    }

    return false;
  }

  /// Grant mandatory GPS consent and start tracking
  Future<bool> grantMandatoryConsent(BuildContext context) async {
    try {
      // Request location permissions
      bool hasPermissions = await LocationTrackingService.instance
          .requestPermissions(context);

      if (hasPermissions) {
        // Save consent
        await UserStorage.setLocationTrackingConsent(true);
        await UserStorage.setMandatoryGpsConsentGiven(true);

        // Auto-start tracking
        bool trackingStarted = await LocationTrackingService.instance
            .startTracking(
              context: context,
              onLocationUpdate: (position) {
                // Location updates handled by service
              },
            );

        return trackingStarted;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if location tracking is currently active
  bool isTrackingActive() {
    return LocationTrackingService.instance.isTracking;
  }

  /// Force stop all tracking (used when user denies consent)
  Future<void> revokeConsent() async {
    await LocationTrackingService.instance.stopTracking();
    await UserStorage.setLocationTrackingConsent(false);
    await UserStorage.setMandatoryGpsConsentGiven(false);
  }

  /// Check if GPS permissions are currently granted in system
  Future<bool> hasSystemLocationPermissions() async {
    return await LocationTrackingService.instance.hasPermissions();
  }

  /// Validate that everything is properly configured
  Future<bool> validateGpsSetup() async {
    try {
      bool hasConsent = await UserStorage.hasMandatoryGpsConsent();
      bool hasPermissions = await hasSystemLocationPermissions();
      bool isTracking = isTrackingActive();

      // All three must be true for valid setup
      return hasConsent && hasPermissions && isTracking;
    } catch (e) {
      return false;
    }
  }

  /// Get GPS setup status for debugging
  Future<Map<String, bool>> getGpsStatus() async {
    return {
      'hasConsent': await UserStorage.hasMandatoryGpsConsent(),
      'hasPermissions': await hasSystemLocationPermissions(),
      'isTracking': isTrackingActive(),
      'canProceed': await canProceedToMain(),
    };
  }

  /// Reset all GPS related data (use with caution)
  Future<void> resetGpsData() async {
    await revokeConsent();
    // This will force user to go through consent flow again
  }
}
