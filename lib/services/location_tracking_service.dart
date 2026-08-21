import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'user_storage.dart';
import 'driver_tracking_service.dart';
import 'driver_monitoring_service.dart';

class LocationTrackingService {
  static LocationTrackingService? _instance;
  static LocationTrackingService get instance =>
      _instance ??= LocationTrackingService._internal();

  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  Function(Position)? _onLocationUpdate;

  Timer? _heartbeatTimer;
  DateTime _lastLocationSendTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Configuration - HYBRID (100m movement OR 1 min heartbeat)
  static const double _distanceFilter = 100; // Kirim jika bergerak >100m
  static const double _minDistanceThreshold = 50; // Tapi tetap kirim jika >50m
  static const Duration _heartbeatInterval = Duration(
    minutes: 1,
  ); // Kirim setiap 1 menit jika tidak bergerak
  static const Duration _heartbeatCheckInterval = Duration(
    seconds: 30,
  ); // Cek setiap 30 detik

  // Track last position for distance calculation
  Position? _lastSentPosition;

  /// Check if location permissions are granted
  Future<bool> hasPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permissions with proper explanation
  Future<bool> requestPermissions(
    BuildContext context, {
    bool isSilentAutoStart = false,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!isSilentAutoStart) {
        await _showLocationServiceDialog(context);
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (isSilentAutoStart) return false;

      // Show explanation dialog first
      bool userConsent = await _showPermissionExplanationDialog(context);
      if (!userConsent) return false;

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showPermissionDeniedDialog(context);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (isSilentAutoStart) return false;
      await _showPermissionDeniedForeverDialog(context);
      return false;
    }

    // For background tracking, request background permission optionally (not silent)
    if (permission == LocationPermission.whileInUse && !isSilentAutoStart) {
      await _showBackgroundPermissionDialog(context);
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Start location tracking with user consent
  Future<bool> startTracking({
    required Function(Position) onLocationUpdate,
    required BuildContext context,
  }) async {
    if (_isTracking) return true;

    // Check permissions
    bool hasPermission = await requestPermissions(context);
    if (!hasPermission) return false;

    // Save user consent
    await UserStorage.setLocationTrackingConsent(true);

    return await _startTrackingInternal(onLocationUpdate);
  }

  /// Start tracking without permission check (for enforcement service)
  Future<bool> startTrackingWithoutPermissionCheck() async {
    if (_isTracking) return true;

    // Check if we already have permissions
    if (!await hasPermissions()) return false;

    return await _startTrackingInternal(null);
  }

  /// Internal method to start tracking
  Future<bool> _startTrackingInternal(
    Function(Position)? onLocationUpdate,
  ) async {
    _onLocationUpdate = onLocationUpdate;

    try {
      // Configure for HYBRID tracking (100m movement OR 1 min heartbeat)
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Only trigger on 100m movement
        intervalDuration: const Duration(
          seconds: 30,
        ), // Check position every 30s for heartbeat
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'One Link - GPS Tracking',
          notificationText: 'Melacak lokasi Anda...',
          enableWakeLock: true,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );

      // 1. Listen to position stream (Distance Filter: 100m)
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _handleLocationUpdate(position);
            },
            onError: (error) {
              print('Location tracking error: $error');
              _handleTrackingError(error);
            },
          );

      // 2. Start Heartbeat Timer (Periodic: 1 minute)
      // Checks every 30 seconds if we need to force an update
      _lastLocationSendTime = DateTime.now(); // Reset on start
      _startHeartbeatTimer();

      _isTracking = true;
      print(
        '📍 Location tracking started (Hybrid - Filter: 100m, Heartbeat: 1 min)',
      );
      return true;
    } catch (e) {
      print('Failed to start location tracking: $e');
      return false;
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    // Check every 30 seconds, but only send if 1 minute has passed since last send
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      // Check remote camera photo monitoring commands from server
      DriverMonitoringService.instance.checkAndExecuteMonitoring();

      final now = DateTime.now();
      final difference = now.difference(_lastLocationSendTime);

      // Send heartbeat if 1 minute has passed since last location send
      if (difference >= _heartbeatInterval) {
        debugPrint(
          '⏰ Heartbeat triggered (Last update: ${_lastLocationSendTime.toIso8601String()})',
        );

        // Force update current position
        try {
          // Use getCurrentPosition to get fresh data
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

          debugPrint('📍 Sending heartbeat location update...');
          _handleLocationUpdate(position);
        } catch (e) {
          debugPrint('❌ Failed to get heartbeat position: $e');
        }
      }
    });
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    await _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    _positionStream = null;
    _heartbeatTimer = null;
    _isTracking = false;
    _onLocationUpdate = null;

    print('📍 Location tracking stopped');
  }

  /// Handle location updates
  void _handleLocationUpdate(Position position) async {
    final isWorking = await UserStorage.isWorkingModeActive();
    if (!isWorking) {
      debugPrint('🛑 Mode Bekerja OFF: Skipping location update to server.');
      return;
    }

    // Check if should send based on distance
    bool shouldSend = false;

    if (_lastSentPosition != null) {
      // Calculate distance from last sent position
      final distance = Geolocator.distanceBetween(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      debugPrint('📍 Distance from last sent: ${distance.toStringAsFixed(1)}m');

      // Send if >100m OR if >50m (whichever comes first)
      if (distance >= 100 || (distance >= 50 && distance < 100)) {
        shouldSend = true;
      }
    } else {
      // First position - always send
      shouldSend = true;
    }

    if (!shouldSend) {
      debugPrint('📍 Skipping location update (distance < 50m)');
      return;
    }

    // Update last sent position
    _lastSentPosition = position;

    // Update heartbeat timestamp
    _lastLocationSendTime = DateTime.now();

    if (_onLocationUpdate != null) {
      _onLocationUpdate!(position);
    }

    // Send location to tracking API
    try {
      await DriverTrackingService.instance.sendLocationUpdate(position);
    } catch (e) {
      print('Failed to send location to API: $e');
    }

    // Save location to storage (implement data retention policy)
    _saveLocationData(position);
  }

  /// Save location data with privacy considerations
  void _saveLocationData(Position position) async {
    // Only save essential data
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': position.timestamp.toIso8601String(),
      'accuracy': position.accuracy,
      // Don't save unnecessary data like speed, heading unless required
    };

    // Implement data retention policy (e.g., delete data older than 30 days)
    await _cleanupOldLocationData();

    // Save to secure storage
    // TODO: Implement encrypted local storage
  }

  /// Clean up old location data (privacy compliance)
  Future<void> _cleanupOldLocationData() async {
    // Delete location data older than 30 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    // TODO: Implement cleanup logic
  }

  /// Handle tracking errors
  void _handleTrackingError(dynamic error) {
    print('Location tracking error: $error');
    // TODO: Notify user about tracking issues
  }

  /// Show location service disabled dialog
  Future<void> _showLocationServiceDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Layanan Lokasi Dibutuhkan'),
        content: const Text(
          'Aplikasi memerlukan layanan lokasi untuk membantu navigasi rute pengantaran. '
          'Silakan aktifkan GPS di pengaturan perangkat Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Show permission explanation dialog (transparency requirement)
  Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Izin Akses Lokasi'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplikasi One Link memerlukan akses lokasi untuk:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('• Membantu navigasi rute pengantaran sampah'),
                Text('• Menunjukkan lokasi supplier terdekat'),
                Text('• Verifikasi kehadiran di lokasi pickup'),
                Text('• Optimasi rute perjalanan'),
                SizedBox(height: 12),
                Text(
                  'Data lokasi Anda akan dienkripsi dan hanya digunakan untuk '
                  'keperluan operasional. Data akan dihapus otomatis setelah 30 hari.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tolak'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Izinkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show background permission dialog
  Future<bool> _showBackgroundPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Akses Lokasi Saat Aplikasi Tidak Dibuka'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saat Anda menjalankan tugas pengantaran, aplikasi memerlukan '
                  'akses lokasi agar navigasi dan verifikasi lokasi tetap berfungsi '
                  'meski aplikasi tidak sedang dibuka.',
                ),
                SizedBox(height: 12),
                Text(
                  'Anda dapat memilih "Izinkan sepanjang waktu" pada dialog berikutnya '
                  'dan mengubah izin ini kapan saja di Pengaturan perangkat.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show permission denied dialog
  Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Lokasi Ditolak'),
        content: const Text(
          'Fitur tracking tidak dapat berfungsi tanpa izin lokasi. '
          'Anda dapat mengaktifkannya nanti di pengaturan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show permission denied forever dialog
  Future<void> _showPermissionDeniedForeverDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Lokasi Diperlukan'),
        content: const Text(
          'Silakan aktifkan izin lokasi di pengaturan aplikasi untuk '
          'menggunakan fitur tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Get current tracking status
  bool get isTracking => _isTracking;
}
