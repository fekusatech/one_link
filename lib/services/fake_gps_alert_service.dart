import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'location_tracking_service.dart';

/// Warns the user in-app when the location currently being sent to the
/// server is flagged as mock/fake GPS (LocationTrackingService.
/// isMockLocationNotifier, sourced from geolocator's native Android
/// mock-provider check - see gps_service.dart for the same detection used
/// on checkin/checkout).
///
/// This never blocks anything - the location keeps being sent (tagged as
/// mock) regardless of whether the user dismisses this dialog. It's a
/// nudge + a heads-up that the flag is recorded, not an enforcement gate
/// like GpsEnforcementService.
class FakeGpsAlertService {
  static FakeGpsAlertService? _instance;
  static FakeGpsAlertService get instance =>
      _instance ??= FakeGpsAlertService._internal();

  FakeGpsAlertService._internal();

  VoidCallback? _listener;
  DateTime? _lastShownAt;

  // Re-nag every 5 minutes while mock location is still active.
  static const _cooldown = Duration(minutes: 5);

  // Event-driven: bereaksi saat notifier berubah/terisi fix baru, tanpa timer.
  void start(BuildContext context) {
    stop();
    final notifier = LocationTrackingService.instance.isMockLocationNotifier;
    _listener = () => _check(context);
    notifier.addListener(_listener!);
    _check(context);
  }

  void stop() {
    if (_listener != null) {
      LocationTrackingService.instance.isMockLocationNotifier
          .removeListener(_listener!);
      _listener = null;
    }
  }

  void _check(BuildContext context) {
    if (!LocationTrackingService.instance.isMockLocationNotifier.value) {
      return;
    }
    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < _cooldown) {
      return;
    }
    if (!context.mounted) return;
    _lastShownAt = now;
    showFakeGpsDialog(context);
  }

  static Future<void> showFakeGpsDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Terdeteksi Fake GPS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Lokasi yang dikirim dari HP Anda terdeteksi berasal dari aplikasi '
          'GPS palsu (fake GPS / mock location). Mohon matikan aplikasi '
          'tersebut dan gunakan lokasi asli perangkat.\n\n'
          'Setiap lokasi yang terdeteksi fake GPS tetap tercatat ke sistem '
          'dan dapat memengaruhi penilaian performa Anda.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Mengerti',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
