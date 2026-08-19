import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/geu/visit_sync_models.dart';
import '../../services/geu/visit_sync_service.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  List<VisitSyncItem> _items = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await VisitSyncService.allItems();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _sendNow() async {
    setState(() => _sending = true);
    try {
      await VisitSyncService.syncNow();
      await _reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Antrean sinkronisasi diperbarui.')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Status Sinkronisasi'),
      actions: [
        IconButton(
          onPressed: _sending ? null : _sendNow,
          icon: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          tooltip: 'Coba kirim sekarang',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 220),
                Center(child: Text('Tidak ada antrean sinkronisasi.')),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summary(),
                const SizedBox(height: 16),
                ..._items
                    .where((item) => item.state != VisitSyncState.succeeded)
                    .map(_itemCard),
                if (_items.every(
                  (item) => item.state == VisitSyncState.succeeded,
                ))
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 36),
                      child: Text('Semua data sudah tersinkronisasi.'),
                    ),
                  ),
              ],
            ),
    ),
  );

  Widget _summary() {
    final pending = _items
        .where(
          (item) =>
              item.state == VisitSyncState.pending ||
              item.state == VisitSyncState.retrying,
        )
        .length;
    final conflict = _items
        .where((item) => item.state == VisitSyncState.conflict)
        .length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync_outlined, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              conflict > 0
                  ? '$conflict data perlu ditinjau.'
                  : pending > 0
                  ? '$pending data menunggu dikirim.'
                  : 'Semua data sudah terkirim.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _sending ? null : _sendNow,
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(VisitSyncItem item) {
    final conflict = item.state == VisitSyncState.conflict;
    final retrying = item.state == VisitSyncState.retrying;
    final color = conflict
        ? AppColors.error
        : retrying
        ? AppColors.accentOrange
        : AppColors.primaryGreen;
    final title = item.action == VisitSyncAction.checkin
        ? 'Check-in'
        : 'Check-out';
    final status = conflict
        ? 'Perlu tindakan'
        : retrying
        ? 'Menunggu percobaan berikutnya'
        : 'Siap dikirim';
    final nextAttempt = retrying
        ? '\nCoba lagi ${_formatDate(item.nextAttemptAt)}'
        : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              conflict ? Icons.error_outline : Icons.cloud_upload_outlined,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title · $status',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Percobaan ${item.attempts}$nextAttempt${item.lastError == null ? '' : '\n${item.lastError}'}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (conflict)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.tonal(
                        onPressed: () async {
                          await VisitSyncService.retryConflict(item.id);
                          await _reload();
                        },
                        child: const Text('Perbaiki & ulangi'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
