import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/checkin_photo_service.dart';
import '../../services/geu/crm_permission_service.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/haversine.dart';
import '../../services/geu/settings_service.dart';

class CheckoutDraft {
  final GpsFix fix;
  final CapturedVisitPhoto photo;
  final String notes;
  const CheckoutDraft({
    required this.fix,
    required this.photo,
    required this.notes,
  });
}

Future<CheckoutDraft?> showCheckoutDialog(
  BuildContext context,
  MissionItem item,
) => showModalBottomSheet<CheckoutDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CheckoutSheet(item: item),
);

class _CheckoutSheet extends StatefulWidget {
  final MissionItem item;
  const _CheckoutSheet({required this.item});
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _notes = TextEditingController();
  GpsFix? _fix;
  CapturedVisitPhoto? _photo;
  String? _error;
  bool _loading = true, _capturing = false;
  double? _maxDistanceKm;
  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await CrmPermissionService.ensureLocation(context))
        throw GpsException('Izin lokasi diperlukan untuk check-out.');
      final results = await Future.wait([
        GpsService.getCurrentFix(),
        SettingsService.getDouble('visit_checkin_max_distance_km'),
      ]);
      final fix = results[0] as GpsFix;
      final maxDistance = results[1] as double?;
      if (maxDistance == null) {
        throw GpsException('Radius checkout belum tersedia dari server.');
      }
      if (mounted)
        setState(() {
          _fix = fix;
          _maxDistanceKm = maxDistance;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  double? get _distanceKm {
    if (_fix == null || widget.item.lat == null || widget.item.lng == null) {
      return null;
    }
    return haversineDistanceKm(
      _fix!.latitude,
      _fix!.longitude,
      widget.item.lat!,
      widget.item.lng!,
    );
  }

  bool get _withinRadius =>
      _distanceKm == null ||
      (_maxDistanceKm != null && _distanceKm! <= _maxDistanceKm!);

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      if (!await CrmPermissionService.ensureCamera(context))
        throw StateError('Izin kamera diperlukan untuk foto check-out.');
      final photo = await CheckinPhotoService.capture(type: 'checkout');
      if (mounted) setState(() => _photo = photo);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check-out — ${widget.item.supplierName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!, style: const TextStyle(color: AppColors.error)),
                TextButton(
                  onPressed: _loadLocation,
                  child: const Text('Coba lagi'),
                ),
              ],
            )
          else ...[
            Text(
              'GPS: ±${_fix!.accuracyMeters.round()} m',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (_distanceKm != null) ...[
              const SizedBox(height: 4),
              Text(
                'Jarak dari supplier: ${(_distanceKm! * 1000).round()} m (maks. ${((_maxDistanceKm ?? 0) * 1000).round()} m)',
                style: TextStyle(
                  color: _withinRadius ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (!_withinRadius) ...[
              const SizedBox(height: 8),
              const Text(
                'Anda berada di luar radius checkout. Mendekatlah ke lokasi supplier.',
                style: TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan kunjungan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _capturing ? null : _capture,
              icon: _capturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _photo == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle_outline,
                    ),
              label: Text(
                _photo == null
                    ? 'Ambil foto check-out *'
                    : 'Foto siap (${(_photo!.bytes / 1024).ceil()} KB)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _photo == null || !_withinRadius
                    ? null
                    : () => Navigator.pop(
                        context,
                        CheckoutDraft(
                          fix: _fix!,
                          photo: _photo!,
                          notes: _notes.text.trim(),
                        ),
                      ),
                child: const Text('Konfirmasi Check-out'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
