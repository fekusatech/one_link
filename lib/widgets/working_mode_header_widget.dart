import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/user_storage.dart';
import '../services/location_tracking_service.dart';
import '../services/driver_monitoring_service.dart';
import 'working_mode_preflight_dialog.dart';

class WorkingModeHeaderWidget extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const WorkingModeHeaderWidget({super.key, this.onStatusChanged});

  @override
  State<WorkingModeHeaderWidget> createState() => _WorkingModeHeaderWidgetState();
}

class _WorkingModeHeaderWidgetState extends State<WorkingModeHeaderWidget> {
  bool _isWorkingMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final active = await UserStorage.isWorkingModeActive();
    if (mounted) {
      setState(() {
        _isWorkingMode = active;
        _loading = false;
      });
    }
  }

  Future<void> _toggleWorkingMode() async {
    if (_isWorkingMode) {
      // Turn OFF Mode Bekerja
      await UserStorage.setWorkingModeActive(false);
      await LocationTrackingService.instance.stopTracking();
      DriverMonitoringService.instance.activeMonitoringStatusNotifier.value = null;
      setState(() {
        _isWorkingMode = false;
      });
      if (widget.onStatusChanged != null) widget.onStatusChanged!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👁️ Mode Lihat Histori Only Aktif (GPS & Kamera Matikan). Baterai HP Hemat!'),
            backgroundColor: AppColors.darkGrey,
          ),
        );
      }
    } else {
      // Open Pre-flight Permission Checklist dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const WorkingModePreflightDialog(),
      );

      if (result == true) {
        setState(() {
          _isWorkingMode = true;
        });
        await LocationTrackingService.instance.startTrackingWithoutPermissionCheck();
        if (widget.onStatusChanged != null) widget.onStatusChanged!();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🟢 Mode Bekerja AKTIF! Sensor GPS & Kamera mulai dipantau.'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isWorkingMode ? Colors.green.shade50 : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isWorkingMode ? Colors.green.shade300 : AppColors.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isWorkingMode ? Colors.green.shade100 : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isWorkingMode ? Icons.radar_rounded : Icons.visibility_outlined,
                  color: _isWorkingMode ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isWorkingMode ? Colors.green : Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isWorkingMode ? 'Mode Bekerja Aktif' : 'Mode Lihat Histori (Off-Shift)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isWorkingMode ? Colors.green.shade900 : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isWorkingMode
                          ? 'Pengiriman lokasi GPS & dual-camera monitoring aktif.'
                          : 'Sensor HP mati (0% baterai drain). Bebas akses histori.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWorkingMode ? AppColors.accentOrange : AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
              onPressed: _toggleWorkingMode,
              icon: Icon(
                _isWorkingMode ? Icons.stop_circle_rounded : Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isWorkingMode ? '⏹️ Selesai Bekerja (Clock Out)' : '🚀 Mulai Bekerja (Clock In)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
