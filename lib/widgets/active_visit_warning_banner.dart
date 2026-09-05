import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/geu/active_visit_service.dart';
import '../services/geu/visit_sync_service.dart';
import '../screens/canvassing/sync_status_screen.dart';

/// Shows a warning wherever the RO might act on it — not just deep inside
/// Mission Today — because a checkout that failed to sync leaves the visit
/// open server-side and silently blocks the RO's NEXT check-in anywhere
/// (backend: "You already have an active check-in, please check out first").
/// Nothing else in the app surfaces that until the blocked check-in itself
/// confuses the RO, so this banner is deliberately shown on both Visit Plan
/// and the Sales Dashboard.
///
/// There is no background retry loop anywhere in the app — sync only runs
/// when a screen explicitly asks for it — so a stuck item can otherwise sit
/// with zero visible progress until the RO happens to reopen the app. The
/// manual "Sync Sekarang" button here exists specifically to give the RO an
/// action instead of an indefinite, silent wait.
class ActiveVisitWarningBanner extends StatefulWidget {
  const ActiveVisitWarningBanner({super.key});

  @override
  State<ActiveVisitWarningBanner> createState() =>
      _ActiveVisitWarningBannerState();
}

class _ActiveVisitWarningBannerState extends State<ActiveVisitWarningBanner> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await VisitSyncService.syncNow();
      // syncNow() only drains the local queue; re-check with the server
      // directly so the banner reflects reality even if the stuck item was
      // a hard 'conflict' that syncNow() can't retry on its own.
      await ActiveVisitService.restore();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveVisitState>(
      valueListenable: ActiveVisitService.current,
      builder: (_, state, __) {
        if (!state.isActive) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: state.syncFailed
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.accentOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                state.syncFailed ? Icons.error_outline : Icons.place_outlined,
                color: state.syncFailed
                    ? AppColors.error
                    : AppColors.accentOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.syncFailed
                          ? 'Check-out di ${state.supplierName ?? "supplier"} gagal terkirim ke server. Anda TIDAK bisa check-in baru sampai ini diselesaikan.'
                          : state.isPendingLocal
                          ? 'Check-in tersimpan di perangkat dan menunggu sinkronisasi. Tidak ada percobaan otomatis di latar belakang — pakai tombol di bawah untuk mencoba sekarang.'
                          : 'Anda sedang check-in di lokasi supplier${state.supplierName != null ? ' (${state.supplierName})' : ''}.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _syncing ? null : _syncNow,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: Text(
                            _syncing ? 'Menyinkronkan...' : 'Sync Sekarang',
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SyncStatusScreen(),
                            ),
                          ),
                          child: const Text('Lihat Detail'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
