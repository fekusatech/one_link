import 'package:flutter/material.dart';
import '../models/surat_jalan.dart';
import '../services/geu/surat_jalan_service.dart';
import 'navigation_screen.dart';
import 'pickup_process_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Mobile-first redesign: one gradient summary card (status/tanggal/driver/
/// progress) instead of 3 separate boxy cards, and each supplier is its own
/// self-contained card with photo/TTD thumbnails inline + a direct
/// "Lanjutkan" button when that item still needs work — no more scrolling
/// past two disconnected "all photos"/"all signatures" galleries at the
/// bottom to figure out which photo belongs to which supplier.
class SuratJalanDetailScreen extends StatefulWidget {
  final SuratJalan suratJalan;

  const SuratJalanDetailScreen({super.key, required this.suratJalan});

  @override
  State<SuratJalanDetailScreen> createState() => _SuratJalanDetailScreenState();
}

class _SuratJalanDetailScreenState extends State<SuratJalanDetailScreen> {
  late SuratJalan _current = widget.suratJalan;

  bool get _headerFinished => _current.status == 'done' || _current.status == 'cancel';

  // Pull-to-refresh: re-fetch this exact SJ (fresh photos/GPS/TTD/status —
  // e.g. after coming back from PickupProcessScreen) instead of relying on
  // whatever was hydrated when the driver first opened the card.
  Future<void> _refresh() async {
    try {
      final fresh = await GeuSuratJalanService.getById(int.parse(_current.suratJalanId));
      if (mounted) setState(() => _current = fresh);
    } catch (_) {
      // keep showing what we already have rather than blanking the screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          _current.kode,
          style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
        actions: [
          // Was gated on status == 'progress' only, so the map button
          // vanished for anything else (e.g. 'pickup' — partially done) even
          // though the SJ clearly wasn't finished yet. Any non-final status
          // should still offer navigation.
          if (!_headerFinished)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NavigationScreen(suratJalan: _current)),
              ),
              icon: const Icon(Icons.map_outlined, color: AppColors.primaryGreen),
              tooltip: 'Buka Navigasi',
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Detail Supplier', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${_current.suratJalanDetail.length}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_current.suratJalanDetail.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('Tidak ada detail supplier', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              )
            else
              ..._current.suratJalanDetail.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSupplierCard(context, e.value, e.key),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Hero summary card ─────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D3E), Color(0xFF2E7D5B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _current.kode,
                      style: AppTextStyles.h5.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pickup: ${_current.kodePickup}',
                      style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.75)),
                    ),
                  ],
                ),
              ),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _heroMeta(Icons.calendar_today, _current.tanggalFormatted),
              if (_current.driverName != '-' && _current.driverName.isNotEmpty) _heroMeta(Icons.person_outline, _current.driverName),
              if (_current.plat != '-' && _current.plat.isNotEmpty) _heroMeta(Icons.local_shipping_outlined, _current.plat),
              if (_current.gudangName != '-' && _current.gudangName.isNotEmpty) _heroMeta(Icons.warehouse_outlined, _current.gudangName),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.75))),
              Text(
                '${_current.progress.completedItems}/${_current.progress.totalItems} selesai (${_current.progress.percentage}%)',
                style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _current.progress.percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.85)),
        const SizedBox(width: 5),
        Text(text, style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.95))),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Text(
        _getStatusText(),
        style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Per-supplier card ──────────────────────────────────────
  Widget _buildSupplierCard(BuildContext context, SuratJalanDetail detail, int index) {
    final statusColor = _getDetailStatusColor(detail.status);
    final photos = detail.photoUrls.isNotEmpty
        ? detail.photoUrls
        : (detail.fotoUrl != null && detail.fotoUrl!.isNotEmpty ? [detail.fotoUrl!] : const <String>[]);
    final canContinue = detail.status != 'done' && detail.status != 'cancel' && !_headerFinished;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.supplierName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        detail.supplierAlamat,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    detail.status.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniStat('Order', '${detail.qtyOrder} ${detail.satuan}')),
                Expanded(child: _miniStat('Real', '${detail.qtyReal} ${detail.satuan}')),
                Expanded(child: _miniStat('WO', detail.workOrderKode)),
              ],
            ),
            if (photos.isNotEmpty || (detail.ttdUrl?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...photos.map((url) => _thumb(context, url, Icons.image)),
                    if (detail.ttdUrl != null && detail.ttdUrl!.isNotEmpty)
                      _thumb(context, detail.ttdUrl!, Icons.draw, isSignature: true),
                  ],
                ),
              ),
            ],
            if (canContinue) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PickupProcessScreen(suratJalan: _current, supplierIndex: index),
                      ),
                    );
                    // Coming back from the process screen almost always
                    // means something changed (photo/GPS/TTD/status).
                    _refresh();
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Lanjutkan Pengambilan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _thumb(BuildContext context, String url, IconData fallbackIcon, {bool isSignature = false}) {
    return GestureDetector(
      onTap: () => _previewImage(context, url),
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
          color: isSignature ? Colors.white : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  url,
                  fit: isSignature ? BoxFit.contain : BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.backgroundGrey,
                    alignment: Alignment.center,
                    child: Icon(fallbackIcon, color: AppColors.grey, size: 20),
                  ),
                ),
              ),
              if (isSignature)
                Positioned(
                  left: 2,
                  top: 2,
                  child: Icon(Icons.draw, size: 12, color: AppColors.primaryGreen.withOpacity(0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (_current.status.toLowerCase()) {
      case 'done':
        return 'SELESAI';
      case 'pickup':
        return 'PROSES';
      case 'progress':
        return 'BELUM MULAI';
      case 'cancel':
      case 'cancelled':
        return 'BATAL';
      default:
        return _current.status.toUpperCase();
    }
  }

  Color _getDetailStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return AppColors.success;
      case 'pickup':
        return AppColors.warning;
      case 'cancel':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }
}
