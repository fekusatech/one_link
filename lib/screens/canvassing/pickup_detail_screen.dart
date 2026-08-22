import 'package:flutter/material.dart';
import '../../services/geu/pickup_service.dart';

class PickupDetailScreen extends StatefulWidget {
  final int id;
  const PickupDetailScreen({super.key, required this.id});
  @override
  State<PickupDetailScreen> createState() => _PickupDetailScreenState();
}

class _PickupDetailScreenState extends State<PickupDetailScreen> {
  Map<String, dynamic>? data;
  bool _busy = false;

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '${value ?? '-'}';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _paymentLabel(dynamic value) {
    switch ('$value'.toLowerCase()) {
      case 'lunas':
      case 'paid':
        return 'Sudah dibayar';
      case 'pending':
        return 'Menunggu pembayaran';
      default:
        return value == null || '$value'.isEmpty ? 'Belum dibayar' : '$value';
    }
  }

  Widget _statusTile(
    IconData icon,
    String label,
    String value, {
    bool ok = false,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: ok ? Colors.green : Colors.grey[700]),
    title: Text(label),
    subtitle: Text(value),
  );

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    data = await PickupService.detail(widget.id);
    if (mounted) setState(() {});
  }

  bool get _isPending {
    final h = Map<String, dynamic>.from(data?['header'] as Map? ?? {});
    return ['assman', 'finance', 'gudang'].any((x) => h['approve_$x'] != 1);
  }

  Future<void> _editBasic() async {
    final h = Map<String, dynamic>.from(data!['header'] as Map? ?? {});
    final currentDate = '${h['tgl_plan'] ?? h['tgl'] ?? ''}';
    final controller = TextEditingController(text: currentDate);
    final newDate = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Dasar Pickup'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tanggal (YYYY-MM-DD)'),
          readOnly: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: DateTime.tryParse(currentDate) ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) {
              controller.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (newDate == null || newDate.isEmpty || newDate == currentDate) return;
    setState(() => _busy = true);
    try {
      await PickupService.updateBasic(id: widget.id, date: newDate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pickup diperbarui.')));
      await load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestChange() async {
    var type = 'update';
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajukan Perubahan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'update', label: Text('Ubah')),
                  ButtonSegment(value: 'delete', label: Text('Hapus')),
                ],
                selected: {type},
                onSelectionChanged: (value) =>
                    setDialogState(() => type = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: type == 'delete'
                      ? 'Alasan penghapusan *'
                      : 'Perubahan yang diminta *',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: notes.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || notes.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await PickupService.submitChangeRequest(
        id: widget.id,
        type: type,
        notes: notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan perubahan terkirim, menunggu approval.'),
        ),
      );
      await load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (data == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final h = Map<String, dynamic>.from(data!['header'] as Map? ?? {});
    return Scaffold(
      appBar: AppBar(title: Text('${h['kode'] ?? 'Detail Pickup'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _formatDate(h['tgl_plan'] ?? h['tgl']),
            style: Theme.of(c).textTheme.titleMedium,
          ),
          Text('${h['gudang_name'] ?? '-'} • ${h['zona_nama'] ?? '-'}'),
          const SizedBox(height: 16),
          const Text(
            'Ringkasan pickup',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _statusTile(
            Icons.flag_outlined,
            'Status pickup',
            '${h['status_label'] ?? h['status'] ?? '-'}',
          ),
          _statusTile(
            Icons.payments_outlined,
            'Pembayaran',
            _paymentLabel(h['payment_status']),
            ok: '${h['payment_status']}'.toLowerCase() == 'lunas',
          ),
          _statusTile(
            Icons.fact_check_outlined,
            'Uji quality',
            '${h['uji_quality_code'] ?? 'Belum ada'}',
            ok:
                h['uji_quality_code'] != null &&
                '${h['uji_quality_code']}'.isNotEmpty,
          ),
          _statusTile(
            Icons.inventory_2_outlined,
            'In stock',
            '${h['in_stock_code'] ?? 'Belum ada'}',
            ok:
                h['in_stock_code'] != null &&
                '${h['in_stock_code']}'.isNotEmpty,
          ),
          _statusTile(
            Icons.receipt_long_outlined,
            'Bukti transfer',
            h['payment_proof'] == null || '${h['payment_proof']}'.isEmpty
                ? 'Belum tersedia'
                : 'Tersedia',
            ok:
                h['payment_proof'] != null &&
                '${h['payment_proof']}'.isNotEmpty,
          ),
          const Divider(),
          const Text(
            'Supplier & Work Order',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...((data!['items'] as List? ?? const []).map((item) {
            final row = Map<String, dynamic>.from(item as Map);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text('${row['supplier_name'] ?? '-'}'),
              subtitle: Text(
                'WO: ${row['work_order_kode'] ?? '-'} • '
                'Qty: ${row['qty'] ?? 0} ${row['satuan_name'] ?? ''}',
              ),
            );
          })),
          const SizedBox(height: 8),
          const Text(
            'Progres approval',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...['assman', 'finance', 'gudang'].map(
            (x) => ListTile(
              leading: Icon(
                h['approve_$x'] == 1
                    ? Icons.check_circle
                    : Icons.pending_outlined,
              ),
              title: Text(x.toUpperCase()),
              subtitle: Text('${h['approve_${x}_name'] ?? 'Menunggu'}'),
            ),
          ),
          if (_isPending) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : _editBasic,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Update Dasar (tanpa approval)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _requestChange,
              icon: const Icon(Icons.rule_folder_outlined),
              label: const Text('Ajukan Perubahan / Hapus'),
            ),
          ],
        ],
      ),
    );
  }
}
