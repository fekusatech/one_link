import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission UX scoped to CRM check-in only. Nothing runs from splash, so
/// the existing TMS tracking permission flow remains untouched.
class CrmPermissionService {
  static Future<bool> ensureLocation(BuildContext context) =>
      _ensure(context, Permission.locationWhenInUse, 'Lokasi',
          'Lokasi diperlukan untuk memvalidasi jarak check-in ke supplier.');

  static Future<bool> ensureCamera(BuildContext context) => _ensure(
      context, Permission.camera, 'Kamera',
      'Kamera diperlukan untuk mengambil foto bukti check-in. Foto dari galeri tidak digunakan.');

  static Future<bool> _ensure(
    BuildContext context,
    Permission permission,
    String title,
    String explanation,
  ) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) return _showSettings(context, title, explanation);
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Izinkan $title'),
        content: Text(explanation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (approved != true) return false;
    final requested = await permission.request();
    if (requested.isGranted) return true;
    if (!context.mounted) return false;
    if (requested.isPermanentlyDenied) return _showSettings(context, title, explanation);
    return false;
  }

  static Future<bool> _showSettings(BuildContext context, String title, String explanation) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Izin $title ditolak'),
        content: Text('$explanation Aktifkan izin ini melalui Pengaturan aplikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Buka Pengaturan')),
        ],
      ),
    );
    if (open == true) await openAppSettings();
    return false;
  }
}
