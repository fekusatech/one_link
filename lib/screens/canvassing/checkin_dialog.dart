import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/checkin_photo_service.dart';
import '../../services/geu/crm_permission_service.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/haversine.dart';
import '../../services/geu/settings_service.dart';

/// Result of a completed check-in dialog — the sync-engine task (separate,
/// still on Task Handler) is what actually POSTs this to
/// /api/visits/checkin; this dialog only handles the GPS/distance gate.
class CheckinDraft {
  final GpsFix fix;
  final double distanceKm;
  final bool confirmFar;
  final CapturedVisitPhoto photo;

  CheckinDraft({
    required this.fix,
    required this.distanceKm,
    required this.confirmFar,
    required this.photo,
  });
}

/// FR-VP-08/09: haversine distance against the supplier's cached coordinates
/// (works offline), hard-blocked for regular users outside radius, override
/// available for privileged roles (developer/superuser — same group-name
/// match as src/service/crm/sales_visit_service.go server-side). FR-VP-06:
/// low-accuracy fixes need an explicit acknowledgement, not blocked outright.
Future<CheckinDraft?> showCheckinDialog(
  BuildContext context,
  MissionItem item,
) {
  if (!item.hasCoordinates) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supplier ini belum punya koordinat GPS.')),
    );
    return Future.value(null);
  }
  return showModalBottomSheet<CheckinDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CheckinSheet(item: item),
  );
}

const _defaultMaxDistanceKm = 0.5;
const _accuracyWarnThresholdM = 100.0;
const _privilegedKeywords = ['developer', 'superuser', 'super'];

class _CheckinSheet extends StatefulWidget {
  final MissionItem item;
  const _CheckinSheet({required this.item});

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  bool _loading = true;
  String? _error;
  GpsFix? _fix;
  double _maxDistanceKm = _defaultMaxDistanceKm;
  bool _isPrivileged = false;
  bool _confirmFarChecked = false;
  bool _lowAccuracyAcknowledged = false;
  CapturedVisitPhoto? _photo;
  bool _capturingPhoto = false;
  bool _photoHandedOff = false;

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void dispose() {
    // A cancelled sheet must not leave proof photos orphaned on the device.
    // Once handed to the queue, VisitSyncService owns its lifecycle instead.
    final photo = _photo;
    if (!_photoHandedOff && photo != null) {
      File(photo.file.path).delete().catchError((_) => photo.file);
    }
    super.dispose();
  }

  Future<void> _acquire() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await CrmPermissionService.ensureLocation(context)) {
        throw GpsException('Izin lokasi diperlukan untuk check-in.');
      }
      final results = await Future.wait([
        GpsService.getCurrentFix(),
        SettingsService.getDouble(
          'visit_checkin_max_distance_km',
          _defaultMaxDistanceKm,
        ),
        GeuAuthService.getCachedUser(),
      ]);
      final fix = results[0] as GpsFix;
      final maxDistance = results[1] as double;
      final user = results[2] as GeuUser?;
      final privileged = (user?.roles ?? []).any(
        (role) =>
            _privilegedKeywords.any((kw) => role.toLowerCase().contains(kw)),
      );
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _maxDistanceKm = maxDistance;
        _isPrivileged = privileged;
        _confirmFarChecked = false;
        _lowAccuracyAcknowledged = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _distanceKm {
    final fix = _fix!;
    return haversineDistanceKm(
      fix.latitude,
      fix.longitude,
      widget.item.lat!,
      widget.item.lng!,
    );
  }

  bool get _withinRadius => _distanceKm <= _maxDistanceKm;
  bool get _accuracyOk => _fix!.accuracyMeters <= _accuracyWarnThresholdM;

  bool get _canConfirm {
    if (_photo == null || _capturingPhoto) return false;
    if (!_accuracyOk && !_lowAccuracyAcknowledged) return false;
    if (_withinRadius) return true;
    return _isPrivileged && _confirmFarChecked;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check-in — ${widget.item.supplierName}',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              SizedBox(height: 12),
              Text('Mengambil lokasi GPS...'),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _acquire,
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    final distanceM = (_distanceKm * 1000).round();
    final maxDistanceM = (_maxDistanceKm * 1000).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(
          'Jarak ke lokasi',
          '$distanceM m (maks $maxDistanceM m)',
          valueColor: _withinRadius ? AppColors.success : AppColors.error,
        ),
        _infoRow(
          'Akurasi GPS',
          '±${_fix!.accuracyMeters.round()} m',
          valueColor: _accuracyOk ? AppColors.success : AppColors.warning,
        ),
        if (_fix!.isMocked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '⚠ Lokasi terdeteksi dari mock provider — dicatat untuk audit.',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ),
        const SizedBox(height: 16),
        if (!_accuracyOk) _lowAccuracyWarning(),
        if (!_withinRadius) _distanceWarning(),
        _photoSection(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canConfirm
                ? () {
                    _photoHandedOff = true;
                    Navigator.pop(
                      context,
                      CheckinDraft(
                        fix: _fix!,
                        distanceKm: _distanceKm,
                        confirmFar: !_withinRadius,
                        photo: _photo!,
                      ),
                    );
                  }
                : null,
            child: const Text('Konfirmasi Check-in'),
          ),
        ),
      ],
    );
  }

  Widget _photoSection() {
    final photo = _photo;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: photo == null
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            photo == null
                ? Icons.photo_camera_outlined
                : Icons.check_circle_outline,
            color: photo == null ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              photo == null
                  ? 'Foto check-in wajib diambil dari kamera.'
                  : 'Foto tersimpan (${(photo.bytes / 1024).ceil()} KB, WebP).',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: _capturingPhoto ? null : _capturePhoto,
            child: Text(photo == null ? 'Ambil Foto' : 'Ulangi'),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto() async {
    setState(() => _capturingPhoto = true);
    try {
      if (!await CrmPermissionService.ensureCamera(context)) {
        throw StateError('Izin kamera diperlukan untuk foto check-in.');
      }
      final photo = await CheckinPhotoService.capture();
      if (!mounted) return;
      final previous = _photo;
      if (previous != null) {
        await File(
          previous.file.path,
        ).delete().catchError((_) => previous.file);
      }
      setState(() => _photo = photo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _capturingPhoto = false);
    }
  }

  Widget _lowAccuracyWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Akurasi GPS rendah (>${_accuracyWarnThresholdM.round()}m). Coba di area terbuka untuk hasil lebih baik.',
            style: AppTextStyles.bodyMedium,
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _acquire,
                  child: const Text('Coba Lagi'),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _lowAccuracyAcknowledged,
                  onChanged: (v) =>
                      setState(() => _lowAccuracyAcknowledged = v ?? false),
                  title: const Text(
                    'Tetap lanjutkan',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _distanceWarning() {
    if (!_isPrivileged) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Anda terlalu jauh dari lokasi supplier. Check-in diblokir. Mendekatlah ke lokasi lalu coba lagi.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anda berada di luar radius yang diizinkan.',
            style: AppTextStyles.bodyMedium,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _confirmFarChecked,
            onChanged: (v) => setState(() => _confirmFarChecked = v ?? false),
            title: const Text(
              'Saya konfirmasi berada jauh dari titik',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {required Color valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
