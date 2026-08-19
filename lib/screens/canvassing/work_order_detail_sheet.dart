import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/geu/work_order_service.dart';
import '../../utils/wa_format.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await WorkOrderService.detail(widget.id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

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
          : _buildContent(_detail!),
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
      if (wo.createdAt != null)
        _row(
          'Dibuat pada',
          '${_formatDate(wo.createdAt!.toIso8601String())} ${wo.createdAt!.hour.toString().padLeft(2, '0')}:${wo.createdAt!.minute.toString().padLeft(2, '0')}',
        ),
      if (wo.hargaRevisit != null) ...[
        const Divider(height: 24),
        _row('Harga sebelumnya', _formatMoney(wo.hargaSebelumnya)),
        _row('Harga revisit', _formatMoney(wo.hargaRevisit)),
        if (wo.persenTurun != null)
          _row('Turun', '${wo.persenTurun!.toStringAsFixed(1)}%'),
      ],
    ],
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
