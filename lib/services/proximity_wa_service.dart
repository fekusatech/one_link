import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/surat_jalan.dart';
import '../services/geu/surat_jalan_service.dart';
import '../services/local_notify_service.dart';
import '../services/user_storage.dart';
import '../utils/wa_format.dart';

/// [ProximityWaService] — banner muncul INSTAN saat driver me-load dashboard,
/// menggunakan data Surat Jalan REAL dari API (GeuSuratJalanService).
/// Memiliki penanganan anti-spam (`_dismissedKeys`): jika banner ditutup
/// atau tombol WA ditap, banner untuk supplier/SJ tersebut TIDAK akan
/// muncul lagi selama sesi ini.
class ProximityWaService {
  ProximityWaService._internal();
  static final ProximityWaService instance = ProximityWaService._internal();

  bool _isRunning = false;
  OverlayEntry? _overlayEntry;
  final Set<String> _dismissedKeys = {};

  /// Start monitoring. Panggil saat driver login / dashboard terbuka.
  void start(BuildContext context) {
    // Disabled per user request
    debugPrint('🛰️ ProximityWaService is currently disabled');
    return;
  }

  void stop() {
    _isRunning = false;
    _dismissOverlay();
    debugPrint('🛰️ ProximityWaService stopped');
  }

  void resetSession() {
    _dismissedKeys.clear();
    _dismissOverlay();
  }

  /// Ambil SJ aktif pertama (status != done/cancel) beserta detail aktif
  /// pertamanya, lalu tampilkan banner (kecuali sudah pernah ditutup/dimark).
  Future<void> _showFirstSuratJalanBanner(BuildContext context) async {
    try {
      final sjList = await GeuSuratJalanService.listTodayHydrated();
      debugPrint('🧪 [ProximityWA] got ${sjList.length} SJ');

      for (final sj in sjList) {
        if (sj.status == 'done' || sj.status == 'cancel') continue;

        SuratJalanDetail? first;
        for (final d in sj.suratJalanDetail) {
          if (d.status != 'done' && d.status != 'cancel') {
            first = d;
            break;
          }
        }
        if (first == null) continue;

        final key = '${sj.suratJalanId}_${first.suratJalanDetailId}';
        if (_dismissedKeys.contains(key)) {
          debugPrint('🧪 [ProximityWA] key $key already dismissed/notified, skipping');
          continue;
        }

        debugPrint(
          '🧪 [ProximityWA] candidate: key=$key ${sj.kode} -> ${first.supplierName} '
          'phone="${first.supplierPhone}"',
        );

        if (!context.mounted) return;
        _showFloatingBanner(context, sj, first, key);
        LocalNotifyService.instance.showNearSupplier(
          supplierName: first.supplierName,
          noSuratJalan: sj.kode,
        );
        return; // hanya 1 banner per sesi
      }

      debugPrint('🧪 [ProximityWA] no un-dismissed active SJ found');
    } catch (e) {
      debugPrint('🧪 [ProximityWA] check error: $e');
    }
  }

  void _showFloatingBanner(
    BuildContext context,
    SuratJalan sj,
    SuratJalanDetail detail,
    String key,
  ) {
    _dismissOverlay();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => _ProximityBanner(
        suratJalan: sj,
        detail: detail,
        onClose: () => _dismissOverlay(key),
        onWa: () => _launchWa(context, sj, detail, key),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _dismissOverlay([String? key]) {
    if (key != null) {
      _dismissedKeys.add(key);
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _launchWa(
    BuildContext context,
    SuratJalan sj,
    SuratJalanDetail detail,
    String key,
  ) async {
    final user = await UserStorage.getUser();
    final driverName = user?['userName']?.toString() ?? 'Driver';

    final message = WaFormat.generateProximityMessage(
      supplierName: detail.supplierName,
      driverName: driverName,
      noSuratJalan: sj.kode,
    );

    debugPrint('🧪 [ProximityWA] WA to ${detail.supplierPhone}');
    final ok = await WaFormat.launchWhatsApp(
      phone: detail.supplierPhone,
      message: message,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor WhatsApp supplier tidak tersedia / tidak valid.'),
          backgroundColor: AppColors.accentOrange,
        ),
      );
    }
    _dismissOverlay(key);
  }
}

class _ProximityBanner extends StatelessWidget {
  final SuratJalan suratJalan;
  final SuratJalanDetail detail;
  final VoidCallback onClose;
  final VoidCallback onWa;

  const _ProximityBanner({
    required this.suratJalan,
    required this.detail,
    required this.onClose,
    required this.onWa,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: AppColors.white,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: AppColors.primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dekat ${detail.supplierName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suratJalan.kode,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onWa,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text(
                        'Hubungi via WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
