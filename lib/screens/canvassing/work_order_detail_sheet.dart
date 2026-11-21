import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/haversine.dart';
import '../../services/geu/visit_planner_service.dart';
import '../../services/geu/work_order_service.dart';
import '../../utils/wa_format.dart';
import '../../widgets/gps_map_preview.dart';
import 'work_order_attachment_picker.dart';
import 'work_order_list_screen.dart';

/// Detail view for a single WO — the mobile equivalent of the "eye" icon on
/// crm-react's Work Order table.
Future<void> showWorkOrderDetailSheet(BuildContext context, int id) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WorkOrderDetailSheet(id: id),
  );
}

class _WorkOrderDetailSheet extends StatefulWidget {
  final int id;
  const _WorkOrderDetailSheet({required this.id});

  @override
  State<_WorkOrderDetailSheet> createState() => _WorkOrderDetailSheetState();
}

class _WorkOrderDetailSheetState extends State<_WorkOrderDetailSheet> {
  WorkOrderDetail? _detail;
  String? _error;
  List<VisitHistoryItem>? _visits;
  bool _loadingVisits = true;
  List<WorkOrderAttachment>? _attachments;
  bool _loadingAttachments = true;
  String? _currentUserName;
  // WorkOrderAttachmentPicker reports its full running staged list on every
  // change (it's built for the deferred-upload create-WO flow) - here we
  // upload immediately, so this tracks how many of those items have already
  // been sent to avoid re-uploading the same photo on the next add.
  int _stagedUploadedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVisits();
    _loadAttachments();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await GeuAuthService.getCachedUser();
    if (mounted) setState(() => _currentUserName = user?.name);
  }

  Future<void> _loadAttachments() async {
    try {
      final attachments = await WorkOrderService.listAttachments(widget.id);
      if (mounted) setState(() => _attachments = attachments);
    } catch (_) {
      // Optional section — the WO detail itself is still shown if this fails.
    } finally {
      if (mounted) setState(() => _loadingAttachments = false);
    }
  }

  Future<void> _addAttachments(List<StagedAttachment> staged) async {
    if (staged.length <= _stagedUploadedCount) {
      // A remove happened rather than an add - nothing new to upload, and
      // an already-uploaded item can only be removed server-side (below),
      // not through the picker's own staged list.
      return;
    }
    final newItems = staged.sublist(_stagedUploadedCount);
    _stagedUploadedCount = staged.length;
    for (final attachment in newItems) {
      try {
        await WorkOrderService.uploadAttachment(
          workOrderId: widget.id,
          type: attachment.type,
          photoBase64: attachment.base64DataUri,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal unggah bukti: $error')),
          );
        }
      }
    }
    await _loadAttachments();
  }

  Future<void> _deleteAttachment(WorkOrderAttachment attachment) async {
    try {
      await WorkOrderService.deleteAttachment(attachment.id);
      await _loadAttachments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus bukti: $error')),
        );
      }
    }
  }

  void _previewAttachment(WorkOrderAttachment attachment) =>
      _previewPhoto(attachment.filePath);

  // Shared by attachment thumbs and checkin/checkout visit photos - tap to
  // preview full-screen with pinch-to-zoom.
  void _previewPhoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image(
            image: _photoImage(url),
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.broken_image_outlined, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  /// Checkin/checkout visit photos may arrive as an inline base64 blob
  /// (`data:...;base64,` prefixed or bare) when R2 isn't configured
  /// server-side, rather than as a fetchable URL — Image.network can't load
  /// those, so this routes to Image.memory instead. Attachment file paths
  /// are always real URLs and pass straight through to NetworkImage.
  ImageProvider _photoImage(String path) {
    if (path.startsWith('http')) return NetworkImage(path);
    final base64Part = path.startsWith('data:') && path.contains(',')
        ? path.substring(path.indexOf(',') + 1)
        : path;
    try {
      return MemoryImage(base64Decode(base64Part));
    } catch (_) {
      return NetworkImage(path);
    }
  }

  Future<void> _load() async {
    try {
      final detail = await WorkOrderService.detail(widget.id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _loadVisits() async {
    try {
      final visits = await VisitPlannerService.getVisitsForWorkOrder(
        widget.id,
      );
      if (mounted) setState(() => _visits = visits);
    } catch (_) {
      // Optional section — the WO detail itself is still shown if this fails.
    } finally {
      if (mounted) setState(() => _loadingVisits = false);
    }
  }

  String _formatDateTime(String iso) {
    if (iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${_formatDate(iso)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openMaps(double lat, double lng) async {
    final launched = await launchUrl(
      Uri.parse('https://maps.google.com/?q=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka peta.')),
      );
    }
  }

  Widget _mapsLink(double lat, double lng) => Padding(
    padding: const EdgeInsets.only(left: 22, top: 2),
    child: InkWell(
      onTap: () => _openMaps(lat, lng),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 13, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            'Buka di Maps',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _openWa(String phone) async {
    final launched = await launchUrl(
      Uri.parse(waUrl(phone)),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp tidak tersedia di perangkat ini.'),
        ),
      );
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final fromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return 'Rp$buffer';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _error != null
          ? SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            )
          : _detail == null
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(child: _buildContent(_detail!)),
    ),
  );

  Widget _buildContent(WorkOrderDetail wo) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              wo.kode,
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (wo.close ? AppColors.success : AppColors.accentOrange)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              wo.statusName,
              style: AppTextStyles.caption.copyWith(
                color: wo.close ? AppColors.success : AppColors.accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _row('Supplier', wo.supplierName),
      if (wo.supplierKode.isNotEmpty) _row('Kode supplier', wo.supplierKode),
      if (wo.supplierPhone.isNotEmpty)
        _rowWidget(
          'Telepon',
          InkWell(
            onTap: () => _openWa(wo.supplierPhone),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 15,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 5),
                Text(
                  wo.supplierPhone,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      _row('Tanggal WO', _formatDate(wo.tgl)),
      if (wo.callAt.isNotEmpty)
        _row('Jadwal follow-up', _formatDate(wo.callAt)),
      if (wo.type != null && wo.type!.isNotEmpty) _row('Tipe', wo.type!),
      if (wo.picName.isNotEmpty) _row('PIC', wo.picName),
      if (wo.creatorName.isNotEmpty) _row('Dibuat oleh', wo.creatorName),
      if (wo.pickupKode != null && wo.pickupKode!.isNotEmpty)
        _row('Kode Pickup', wo.pickupKode!),
      if (wo.createdAt != null)
        _row(
          'Dibuat pada',
          '${_formatDate(wo.createdAt!.toIso8601String())} ${wo.createdAt!.hour.toString().padLeft(2, '0')}:${wo.createdAt!.minute.toString().padLeft(2, '0')}',
        ),
      if (wo.updatedAt != null)
        _row(
          'Terakhir update',
          '${_formatDate(wo.updatedAt!.toIso8601String())} ${wo.updatedAt!.hour.toString().padLeft(2, '0')}:${wo.updatedAt!.minute.toString().padLeft(2, '0')}',
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderListScreen(
              initialFilters: WorkOrderFilters(supplierId: wo.supplierId),
              titleOverride: 'WO - ${wo.supplierName}',
            ),
          ),
        ),
        icon: const Icon(Icons.history, size: 16),
        label: const Text('Lihat WO lain dari supplier ini'),
      ),
      if (wo.hargaRevisit != null) ...[
        const Divider(height: 24),
        _row('Harga sebelumnya', _formatMoney(wo.hargaSebelumnya)),
        _row('Harga revisit', _formatMoney(wo.hargaRevisit)),
        if (wo.persenTurun != null)
          _row('Turun', '${wo.persenTurun!.toStringAsFixed(1)}%'),
      ],
      const Divider(height: 24),
      Text(
        'Bukti Chat/Telpon',
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      _buildAttachments(),
      const Divider(height: 24),
      Text(
        'Riwayat Check-in/Check-out',
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      _buildVisitHistory(),
    ],
  );

  Widget _buildAttachments() {
    if (_loadingAttachments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final attachments = _attachments ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Belum ada bukti chat/telpon untuk WO ini.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attachment in attachments)
                _attachmentThumb(attachment),
            ],
          ),
        const SizedBox(height: 4),
        WorkOrderAttachmentPicker(onChanged: _addAttachments),
      ],
    );
  }

  Widget _attachmentThumb(WorkOrderAttachment attachment) {
    final isOwner =
        _currentUserName != null &&
        _currentUserName!.isNotEmpty &&
        attachment.creatorName == _currentUserName;
    return GestureDetector(
      onTap: () => _previewAttachment(attachment),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              attachment.filePath,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 84,
                height: 84,
                color: AppColors.lightGrey,
                child: const Icon(Icons.broken_image_outlined, size: 20),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                WorkOrderAttachment.typeLabel(attachment.type),
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
          if (isOwner)
            Positioned(
              right: -6,
              top: -6,
              child: IconButton(
                icon: const Icon(
                  Icons.cancel,
                  size: 20,
                  color: AppColors.error,
                ),
                onPressed: () => _deleteAttachment(attachment),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitHistory() {
    if (_loadingVisits) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final visits = _visits ?? const [];
    if (visits.isEmpty) {
      return Text(
        'Belum ada riwayat check-in/check-out untuk WO ini.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (final visit in visits) ...[
          _buildVisitCard(visit),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // Mirrors erpmysql's "Data Check-in & Check-out Kunjungan" modal and
  // crm-react's WO detail sheet - same anomaly signals, same wording.
  List<String> _anomalyReasons(VisitHistoryItem visit) {
    final reasons = <String>[];
    if (visit.checkinTimeAnomalous) {
      reasons.add(
        'Waktu check-in tidak wajar (selisih jam HP dengan server terlalu jauh)',
      );
    }
    if (visit.checkoutTimeAnomalous) {
      reasons.add(
        'Waktu check-out tidak wajar (selisih jam HP dengan server terlalu jauh)',
      );
    }
    if (visit.checkoutDurationAnomalous) {
      reasons.add('Durasi kunjungan kurang dari 1 menit');
    }
    if (visit.isMockLocation) {
      reasons.add('Lokasi terdeteksi menggunakan GPS palsu (mock location)');
    }
    if (visit.checkinLat != null &&
        visit.checkinLng != null &&
        visit.checkoutLat != null &&
        visit.checkoutLng != null) {
      final displacementM =
          haversineDistanceKm(
            visit.checkinLat!,
            visit.checkinLng!,
            visit.checkoutLat!,
            visit.checkoutLng!,
          ) *
          1000;
      // 500m mirrors erpmysql's detail modal and crm-react's WO detail
      // sheet - GPS drift of a few tens of meters between checkin/checkout
      // is normal and isn't worth flagging.
      if (displacementM > 500) {
        reasons.add(
          'Titik checkin dan checkout berjauhan (${displacementM.toStringAsFixed(1)} meter)',
        );
      }
    }
    return reasons;
  }

  Widget _anomalyBanner(VisitHistoryItem visit) {
    final reasons = _anomalyReasons(visit);
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Anomali terdeteksi',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                '• $reason',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(VisitHistoryItem visit) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _anomalyBanner(visit),
        Row(
          children: [
            const Icon(
              Icons.circle,
              size: 8,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              visit.status == 'checked_out' ? 'Selesai' : 'Sedang berlangsung',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.login,
              size: 16,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Check-in ${_formatDateTime(visit.checkedInAt)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (visit.address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              visit.address,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (visit.checkinLat != null && visit.checkinLng != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: GpsMapPreview(
              latitude: visit.checkinLat!,
              longitude: visit.checkinLng!,
              markerColor: AppColors.primaryGreen,
            ),
          ),
          _mapsLink(visit.checkinLat!, visit.checkinLng!),
        ],
        // distance_from_supplier is computed at checkin time, so it belongs
        // with the checkin block, not the checkout summary below.
        if (visit.distanceFromSupplier != null)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Text(
              '${visit.distanceFromSupplier!.toStringAsFixed(0)} m dari supplier',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (visit.checkedOutAt.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.logout,
                size: 16,
                color: AppColors.accentOrange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Check-out ${_formatDateTime(visit.checkedOutAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (visit.checkoutAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                visit.checkoutAddress,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (visit.checkoutLat != null && visit.checkoutLng != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: GpsMapPreview(
                latitude: visit.checkoutLat!,
                longitude: visit.checkoutLng!,
                markerColor: AppColors.accentOrange,
              ),
            ),
            _mapsLink(visit.checkoutLat!, visit.checkoutLng!),
          ],
          if (visit.durationMinutes != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                'Durasi ${visit.durationMinutes} menit',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (visit.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                'Catatan: ${visit.notes}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'Belum check-out',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (visit.checkinPhoto != null || visit.checkoutPhoto != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (visit.checkinPhoto != null)
                Expanded(child: _photoThumb(visit.checkinPhoto!)),
              if (visit.checkinPhoto != null && visit.checkoutPhoto != null)
                const SizedBox(width: 8),
              if (visit.checkoutPhoto != null)
                Expanded(child: _photoThumb(visit.checkoutPhoto!)),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _photoThumb(String url) => GestureDetector(
    onTap: () => _previewPhoto(url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Image(
          image: _photoImage(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.lightGrey,
            child: const Icon(Icons.broken_image_outlined, size: 20),
          ),
        ),
      ),
    ),
  );

  Widget _row(String label, String value) => _rowWidget(
    label,
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _rowWidget(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );
}
