import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
import '../services/user_storage.dart';

class WorkingModePreflightDialog extends StatefulWidget {
  const WorkingModePreflightDialog({super.key});

  @override
  State<WorkingModePreflightDialog> createState() => _WorkingModePreflightDialogState();
}

class _WorkingModePreflightDialogState extends State<WorkingModePreflightDialog> {
  bool _checking = true;
  bool _gpsGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    _runPreflightCheck();
  }

  Future<void> _runPreflightCheck() async {
    setState(() {
      _checking = true;
    });

    // 1. Check GPS Permission
    LocationPermission locationPerm = await Geolocator.checkPermission();
    if (locationPerm == LocationPermission.denied) {
      locationPerm = await Geolocator.requestPermission();
    }
    bool gpsOk = locationPerm == LocationPermission.always || locationPerm == LocationPermission.whileInUse;

    // 2. Check Camera Permission
    PermissionStatus cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      cameraStatus = await Permission.camera.request();
    }
    bool cameraOk = cameraStatus.isGranted;

    // 3. Check Notification Permission
    PermissionStatus notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      notifStatus = await Permission.notification.request();
    }
    bool notifOk = notifStatus.isGranted || notifStatus.isLimited;

    if (mounted) {
      setState(() {
        _gpsGranted = gpsOk;
        _cameraGranted = cameraOk;
        _notificationGranted = notifOk;
        _checking = false;
      });
    }
  }

  bool get _allPermissionsGranted => _gpsGranted && _cameraGranted && _notificationGranted;

  Future<void> _activateWorkingMode() async {
    await UserStorage.setWorkingModeActive(true);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.playlist_add_check_circle, color: AppColors.primaryGreen, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemeriksaan Mode Bekerja',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Verifikasi izin sensor HP',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_checking) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primaryGreen),
                      SizedBox(height: 12),
                      Text('Memeriksa sensor GPS & Kamera...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildPermissionRow(
                icon: Icons.location_on_rounded,
                title: 'Akses Lokasi GPS',
                subtitle: 'Presisi posisi driver & surat jalan',
                isGranted: _gpsGranted,
                onRequest: () async {
                  await Geolocator.requestPermission();
                  _runPreflightCheck();
                },
              ),
              const SizedBox(height: 10),
              _buildPermissionRow(
                icon: Icons.camera_alt_rounded,
                title: 'Akses Kamera Dual-Cam',
                subtitle: 'Monitoring keselamatan berkendara',
                isGranted: _cameraGranted,
                onRequest: () async {
                  await Permission.camera.request();
                  _runPreflightCheck();
                },
              ),
              const SizedBox(height: 10),
              _buildPermissionRow(
                icon: Icons.notifications_active_rounded,
                title: 'Akses Notifikasi & Alert',
                subtitle: 'Pengingat otomatis jam 17:00',
                isGranted: _notificationGranted,
                onRequest: () async {
                  await Permission.notification.request();
                  _runPreflightCheck();
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allPermissionsGranted ? AppColors.primaryGreen : AppColors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _allPermissionsGranted ? _activateWorkingMode : _runPreflightCheck,
                      child: Text(
                        _allPermissionsGranted ? '🚀 Aktifkan' : 'Cek Ulang',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isGranted ? Colors.green.shade200 : Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: isGranted ? Colors.green.shade700 : Colors.amber.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isGranted)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
          else
            InkWell(
              onTap: onRequest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Izinkan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
