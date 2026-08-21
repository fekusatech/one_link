import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'user_storage.dart';
import 'location_tracking_service.dart';
import 'driver_monitoring_service.dart';

class ShiftReminderService {
  static ShiftReminderService? _instance;
  static ShiftReminderService get instance => _instance ??= ShiftReminderService._internal();

  ShiftReminderService._internal();

  Timer? _timer;
  bool _alertShownToday = false;
  int _lastAlertDay = -1;

  void start(BuildContext context) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkShiftEnd(context);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkShiftEnd(BuildContext context) async {
    final now = DateTime.now();

    // Reset daily alert flag at midnight
    if (_lastAlertDay != now.day) {
      _alertShownToday = false;
      _lastAlertDay = now.day;
    }

    final isWorking = await UserStorage.isWorkingModeActive();
    if (!isWorking) return;

    // Check if device clock is at or after 17:00 (5 PM)
    if (now.hour >= 17 && !_alertShownToday) {
      _alertShownToday = true;
      if (context.mounted) {
        showShiftEndDialog(context);
      }
    }
  }

  static Future<void> showShiftEndDialog(BuildContext context) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.access_time_filled_rounded, color: AppColors.accentOrange, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jam $timeStr - Selesai Bekerja?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('Pengingat Akhir Jam Kerja', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'Waktu kerja standar telah berakhir. Apakah tugas Anda hari ini sudah selesai?\n\n'
          'Matikan Mode Bekerja untuk menghentikan pengiriman GPS & kamera agar baterai HP tetap awet & dingin.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('⏳ Lanjut Lembur', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await UserStorage.setWorkingModeActive(false);
              await LocationTrackingService.instance.stopTracking();
              DriverMonitoringService.instance.activeMonitoringStatusNotifier.value = null;
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🛑 Mode Bekerja dimatikan. Pengiriman lokasi & sensor dihentikan!'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              }
            },
            child: const Text('⏹️ Matikan Mode Bekerja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
