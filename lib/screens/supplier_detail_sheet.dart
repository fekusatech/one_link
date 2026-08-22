import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/supplier_list_model.dart';
import '../models/supplier_order_history.dart';
import '../services/supplier_list_service.dart';
import '../widgets/order_history_widgets.dart';

/// Detail for a row in Daftar Supplier — the row itself carries almost
/// everything already (SupplierListItem came straight from the same
/// GET /api/suppliers/ list this screen renders), so the master-data
/// section shows instantly with nothing to load. Only order history (total
/// setor, last order, mini chart) needs its own call, to
/// GET /api/suppliers/:id — same endpoint the map and task detail sheets
/// already use.
Future<void> showSupplierDetailSheet(
  BuildContext context,
  SupplierListItem supplier,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SupplierDetailSheet(supplier: supplier),
  );
}

class _SupplierDetailSheet extends StatefulWidget {
  final SupplierListItem supplier;
  const _SupplierDetailSheet({required this.supplier});

  @override
  State<_SupplierDetailSheet> createState() => _SupplierDetailSheetState();
}

class _SupplierDetailSheetState extends State<_SupplierDetailSheet> {
  bool _loadingHistory = true;
  SupplierOrderSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final id = int.tryParse(widget.supplier.id) ?? 0;
    final summary = id == 0
        ? null
        : await SupplierListService.getSupplierOrderSummary(id);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name,
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (s.kode != null && s.kode!.isNotEmpty) _chip(s.kode!),
                  if (s.jenisName != null && s.jenisName!.isNotEmpty)
                    _chip(s.jenisName!),
                  if (s.kategoriName != null && s.kategoriName!.isNotEmpty)
                    _chip(s.kategoriName!),
                ],
              ),
              const SizedBox(height: 14),

              _sectionTitle('Kontak & Lokasi'),
              if (s.phone != null && s.phone!.isNotEmpty)
                _row(Icons.phone_outlined, s.phone!),
              _buildWaStatus(),
              if (s.alamat != null && s.alamat!.isNotEmpty)
                _row(Icons.location_on_outlined, s.alamat!),
              if (_locationLine(s) != null)
                _row(Icons.map_outlined, _locationLine(s)!),
              if (s.karyawan != null && s.karyawan!.isNotEmpty)
                _row(
                  Icons.badge_outlined,
                  '${s.karyawan}${s.jabatan != null && s.jabatan!.isNotEmpty ? ' • ${s.jabatan}' : ''}',
                ),

              if (s.price != null ||
                  (s.jenisUco?.isNotEmpty ?? false) ||
                  (s.siklus?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 14),
                _sectionTitle('Komoditas'),
                if (s.price != null)
                  _row(
                    Icons.sell_outlined,
                    '${formatRupiah(s.price!)}'
                    '${s.priceSatuanName != null && s.priceSatuanName!.isNotEmpty ? ' / ${s.priceSatuanName}' : ''}',
                  ),
                if (s.jenisUco != null && s.jenisUco!.isNotEmpty)
                  _row(Icons.water_drop_outlined, s.jenisUco!),
                if (s.siklus != null && s.siklus!.isNotEmpty)
                  _row(Icons.event_repeat_outlined, 'Siklus ${s.siklus}'),
                if (s.poin != null)
                  _row(Icons.stars_outlined, '${s.poin} poin'),
              ],

              if ((s.namaRek?.isNotEmpty ?? false) ||
                  (s.nomorRek?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 14),
                _sectionTitle('Rekening'),
                _row(
                  Icons.account_balance_outlined,
                  [
                    if (s.bankRekName != null && s.bankRekName!.isNotEmpty)
                      s.bankRekName,
                    if (s.nomorRek != null && s.nomorRek!.isNotEmpty)
                      s.nomorRek,
                  ].whereType<String>().join(' • '),
                ),
                if (s.namaRek != null && s.namaRek!.isNotEmpty)
                  _row(Icons.person_outline, 'a.n. ${s.namaRek}'),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _sectionTitle('Riwayat Setor Minyak'),
              _buildOrderHistory(),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _sectionTitle('Riwayat Follow Up'),
              _buildFollowupHistory(),
            ],
          ),
        ),
      ),
    );
  }

  String? _locationLine(SupplierListItem s) {
    final parts = [
      s.desaName,
      s.kecamatanName,
      s.kotaName,
      s.provinsiName,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  Widget _buildOrderHistory() {
    if (_loadingHistory) return const OrderHistorySkeleton();

    final summary = _summary;
    if (summary == null || !summary.hasHistory) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada riwayat setor minyak.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          Icons.history_outlined,
          'Terakhir setor ${_formatDate(summary.lastOrderDate)}'
          '${summary.lastOrderNominal != null ? ' • ${formatRupiah(summary.lastOrderNominal!)}' : ''}',
        ),
        _row(
          Icons.receipt_long_outlined,
          '${summary.totalOrderCount}x setor • total ${formatRupiah(summary.totalOrderNominal)}',
        ),
        if (summary.recentOrders.length >= 2) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: RecentOrdersChart(orders: summary.recentOrders),
          ),
        ],
      ],
    );
  }

  Widget _buildWaStatus() {
    if (_loadingHistory) return const SizedBox.shrink();
    final summary = _summary;
    if (summary == null || summary.waValid == null)
      return const SizedBox.shrink();

    final valid = summary.waValid!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.error_outline,
            size: 15,
            color: valid ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              valid
                  ? 'WA valid'
                  : 'WA tidak valid'
                        '${summary.waInvalidReason != null && summary.waInvalidReason!.isNotEmpty ? ': ${summary.waInvalidReason}' : ''}',
              style: TextStyle(
                color: valid ? AppColors.success : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowupHistory() {
    if (_loadingHistory) return const OrderHistorySkeleton();

    final followups = _summary?.recentFollowups ?? const [];
    if (followups.isEmpty && (_summary?.followupCount ?? 0) == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada riwayat follow up.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((_summary?.followupCount ?? 0) > 0)
          _row(
            Icons.chat_bubble_outline,
            'Sudah di-chat ${_summary!.followupCount} kali',
          ),
        for (final f in followups) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                f.confirmedSent
                    ? Icons.chat_bubble_outline
                    : Icons.error_outline,
                size: 16,
                color: f.confirmedSent
                    ? AppColors.primaryGreen
                    : AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDateTime(f.createdAt)}'
                      '${f.userName.isNotEmpty ? ' • ${f.userName}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      f.confirmedSent
                          ? (f.message ?? 'Pesan WA terkirim.')
                          : 'Tidak terkirim'
                                '${f.invalidReason != null && f.invalidReason!.isNotEmpty ? ': ${f.invalidReason}' : ''}',
                      style: TextStyle(
                        color: f.confirmedSent
                            ? AppColors.textSecondary
                            : AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    ),
  );

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryGreen,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _row(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
