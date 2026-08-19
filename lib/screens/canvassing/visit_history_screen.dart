import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/geu_api_client.dart';
import '../../services/geu/visit_planner_service.dart';
import '../../services/geu/visit_sync_service.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final List<VisitHistoryItem> _items = [];
  late DateTimeRange _range;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _page = 1;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final nextPage = more ? _page + 1 : 1;
      final result = await VisitPlannerService.getVisitHistory(
        from: _range.start,
        until: _range.end,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (more) {
          _items.addAll(result.items);
        } else {
          _items
            ..clear()
            ..addAll(result.items);
        }
        _page = nextPage;
        _hasMore = result.hasMore;
        _cachedAt = result.cachedAt;
      });
    } catch (error) {
      if (mounted && !more) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Filter riwayat kunjungan',
      saveText: 'Terapkan',
    );
    if (selected == null || !mounted) return;
    setState(() => _range = selected);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat Kunjungan')),
    body: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dateFilter(),
          const SizedBox(height: 12),
          _pendingCard(),
          if (_cachedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Data tersimpan • diperbarui ${_format(_cachedAt!)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 72),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorCard()
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: Center(
                child: Text(
                  'Belum ada riwayat kunjungan pada ${_rangeLabel()}.',
                ),
              ),
            )
          else
            ..._items.map(_visitCard),
          if (_hasMore)
            TextButton.icon(
              onPressed: _loadingMore ? null : () => _load(more: true),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Muat lainnya'),
            ),
        ],
      ),
    ),
  );

  Widget _dateFilter() => OutlinedButton.icon(
    onPressed: _chooseRange,
    icon: const Icon(Icons.date_range_outlined),
    label: Text(_rangeLabel()),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryGreen,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  Widget _pendingCard() => FutureBuilder(
    future: VisitSyncService.pendingItems(),
    builder: (_, snapshot) {
      final pending = snapshot.data?.length ?? 0;
      if (pending == 0) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$pending kunjungan menunggu dikirim',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    },
  );

  Widget _errorCard() => Center(
    child: Column(
      children: [
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Coba lagi')),
      ],
    ),
  );

  Widget _visitCard(VisitHistoryItem item) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _showDetails(item),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.supplierName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_statusLabel(item.status)} • ${_formatText(item.checkedInAt)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (item.workOrderIds.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _workOrderChip(item.workOrderIds),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );

  Future<void> _showDetails(VisitHistoryItem item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VisitDetailSheet(item: item),
      );

  Widget _workOrderChip(String ids) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'WO ${ids.replaceAll(',', ', WO ')}',
      style: const TextStyle(
        color: AppColors.primaryGreen,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  String _rangeLabel() => '${_date(_range.start)} — ${_date(_range.end)}';
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _format(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String _formatText(String value) => value.isEmpty
      ? 'Waktu tidak tersedia'
      : value.replaceFirst('T', ' ').split('.').first;
  String _statusLabel(String status) => status.toLowerCase() == 'checked_out'
      ? 'Selesai'
      : status.toLowerCase() == 'checked_in'
      ? 'Sedang dikunjungi'
      : status;
}

class _VisitDetailSheet extends StatelessWidget {
  const _VisitDetailSheet({required this.item});
  final VisitHistoryItem item;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .72,
    minChildSize: .45,
    maxChildSize: .94,
    builder: (_, controller) => Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Detail Kunjungan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            item.supplierName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (item.supplierPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                item.supplierPhone,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 18),
          _section('Check-in'),
          _detailRow('Waktu', _formatText(item.checkedInAt)),
          _detailRow('Alamat', item.address),
          _detailRow(
            'Koordinat',
            _coordinates(item.checkinLat, item.checkinLng),
          ),
          if (item.checkoutAtOrEmpty.isNotEmpty) ...[
            const SizedBox(height: 14),
            _section('Check-out'),
            _detailRow('Waktu', _formatText(item.checkedOutAt)),
            _detailRow('Alamat', item.checkoutAddress),
            _detailRow(
              'Koordinat',
              _coordinates(item.checkoutLat, item.checkoutLng),
            ),
            if (item.durationMinutes != null)
              _detailRow('Durasi', '${item.durationMinutes} menit'),
          ],
          if (item.workOrderIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _section('Work Order'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.workOrderIds
                  .split(',')
                  .where((id) => id.trim().isNotEmpty)
                  .map((id) => Chip(label: Text('WO #${id.trim()}')))
                  .toList(),
            ),
          ],
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _section('Catatan'),
            Text(item.notes),
          ],
          if (item.checkinPhoto != null || item.checkoutPhoto != null) ...[
            const SizedBox(height: 20),
            _section('Foto kunjungan'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _photo('Check-in', item.checkinPhoto)),
                const SizedBox(width: 10),
                Expanded(child: _photo('Check-out', item.checkoutPhoto)),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.primaryGreen,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '-' : value)),
      ],
    ),
  );

  Widget _photo(String label, String? path) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: path == null
              ? Container(
                  color: AppColors.backgroundGrey,
                  child: const Icon(
                    Icons.photo_outlined,
                    color: AppColors.grey,
                  ),
                )
              : Image.network(
                  _photoUrl(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.backgroundGrey,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
      ),
    ],
  );

  String _photoUrl(String path) => path.startsWith('http')
      ? path
      : '${GeuApiClient.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
  String _coordinates(double? lat, double? lng) => lat == null || lng == null
      ? '-'
      : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  String _formatText(String value) => value.isEmpty
      ? 'Waktu tidak tersedia'
      : value.replaceFirst('T', ' ').split('.').first;
}

extension on VisitHistoryItem {
  String get checkoutAtOrEmpty => checkedOutAt;
}
