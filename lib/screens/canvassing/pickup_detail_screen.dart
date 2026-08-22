import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    try {
      data = await PickupService.detail(widget.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _maps(dynamic value) => (value is List ? value : const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  String _url(dynamic value) => PickupService.resolveMediaUrl(value);

  Future<void> _previewImage(String url, {String title = 'Bukti'}) async {
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Foto tidak dapat dimuat', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAndShare(String url, String filename, String phone) async {
    if (url.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${dir.path}/$safeName';
      await Dio().download(url, path);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Bukti transaksi pickup ${data?['header']?['kode'] ?? ''}'
            '${phone.trim().isEmpty ? '' : ' untuk supplier $phone'}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh bukti: $error')),
        );
      }
    }
  }

  Future<String?> _askSupplierPhone(String initialPhone) async {
    final controller = TextEditingController(text: initialPhone);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bagikan bukti transfer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor supplier (opsional)',
            hintText: '08xxxxxxxxxx',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _photoStrip(List<dynamic> photos, {String title = 'Foto'}) {
    final urls = photos
        .map(_url)
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => GestureDetector(
          onTap: () => _previewImage(urls[index], title: title),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              urls[index], width: 76, height: 76, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 76, height: 76, color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _operationalEvidence(Map<String, dynamic> h) {
    final quality = _maps(data?['uji_quality']);
    final stock = _maps(data?['in_stock']);
    final payments = _maps(data?['payment_history']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        const Text('Bukti operasional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _evidenceSection(
          icon: Icons.fact_check_outlined,
          title: 'Uji quality',
          empty: quality.isEmpty,
          children: quality.map((q) {
            final details = _maps(q['details']);
            final photos = q['photos'] is List ? q['photos'] as List : const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${q['kode'] ?? 'Uji quality'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_formatDate(q['tgl']), style: TextStyle(color: Colors.grey.shade700)),
                  ...details.map((d) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${d['supplier_name'] ?? '-'} • ${d['keputusan'] ?? '-'}\n'
                        'FFA ${d['ffa'] ?? '-'}  |  Moisture ${d['moisture'] ?? '-'}  |  Impurities ${d['impurities'] ?? '-'}'),
                  )),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _photoStrip(photos, title: 'Foto uji quality'),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
        _evidenceSection(
          icon: Icons.inventory_2_outlined,
          title: 'In stock',
          empty: stock.isEmpty,
          children: stock.map((s) {
            final details = _maps(s['details']);
            final photos = <dynamic>[];
            for (final d in details) {
              if (d['photos'] is List) photos.addAll(d['photos'] as List);
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['kode'] ?? 'In stock'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_formatDate(s['tgl'])),
                  ...details.map((d) => Text('Qty ${d['quantity'] ?? 0} kg${d['keterangan'] == null ? '' : ' • ${d['keterangan']}'}')),
                  if (photos.isNotEmpty) ...[const SizedBox(height: 8), _photoStrip(photos, title: 'Foto in stock')],
                ]),
              ),
            );
          }).toList(),
        ),
        _evidenceSection(
          icon: Icons.payments_outlined,
          title: 'Riwayat pembayaran',
          empty: payments.isEmpty,
          children: payments.map((p) {
            final proof = _url(p['bukti_transfer']);
            final details = _maps(p['details']);
            final phone = (data?['items'] is List && (data!['items'] as List).isNotEmpty)
                ? '${(data!['items'] as List).first['supplier_phone'] ?? ''}' : '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${p['kode'] ?? 'Pembayaran'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Chip(label: Text(_paymentLabel(p['status']))),
                  ]),
                  Text('${_formatDate(p['tgl'])} • ${_money(p['actual_amount'])}'),
                  ...details.map((d) {
                    final workOrders = '${d['work_order_codes'] ?? ''}'.trim();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${d['supplier_name'] ?? '-'} • ${_money(d['total_harga'])} • ${_paymentLabel(d['status'])}'
                        '${workOrders.isEmpty ? '' : '\nWO: $workOrders'}',
                      ),
                    );
                  }),
                  if (p['notes'] != null && '${p['notes']}'.trim().isNotEmpty) Text('${p['notes']}'),
                  if (proof.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(onPressed: () => _previewImage(proof, title: 'Bukti transfer'), icon: const Icon(Icons.visibility_outlined), label: const Text('Lihat')),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                final selectedPhone = await _askSupplierPhone(phone);
                                if (selectedPhone == null || !mounted) return;
                                setState(() => _busy = true);
                                try {
                                  await _downloadAndShare(
                                    proof,
                                    '${p['kode'] ?? 'bukti'}.jpg',
                                    selectedPhone,
                                  );
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download & share'),
                      ),
                    ]),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _processTimeline() {
    final timeline = _maps(data?['process_timeline']);
    final suratJalan = _maps(data?['surat_jalan']);
    if (timeline.isEmpty && suratJalan.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 28),
      const Text('Process Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      ...timeline.map((event) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline, color: Color(0xFF1E5A49)),
            title: Text('${event['title'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if ('${event['date'] ?? ''}'.trim().isNotEmpty) _formatDateTime(event['date']),
              if ('${event['subtitle'] ?? ''}'.trim().isNotEmpty) '${event['subtitle']}',
              if ('${event['description'] ?? ''}'.trim().isNotEmpty) '${event['description']}',
            ].join('\n')),
          )),
      ...suratJalan.map((sj) {
        final photos = sj['photos'] is List ? sj['photos'] as List : const [];
        if (photos.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Foto Surat Jalan ${sj['kode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _photoStrip(photos, title: 'Foto Surat Jalan'),
            ]),
          ),
        );
      }),
    ]);
  }

  String _formatDateTime(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    return '${parsed.day.toString().padLeft(2, '0')} ${_monthName(parsed.month)} ${parsed.year} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ][month];

  Widget _evidenceSection({required IconData icon, required String title, required bool empty, required List<Widget> children}) =>
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(icon, color: const Color(0xFF1E5A49)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: empty ? const Text('Belum tersedia') : null,
        initiallyExpanded: !empty,
        children: children,
      );

  String _money(dynamic value) {
    final number = num.tryParse('$value');
    if (number == null) return '-';
    return 'Rp ${number.toStringAsFixed(0)}';
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
          _processTimeline(),
          _operationalEvidence(h),
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
