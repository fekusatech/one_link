import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/geu/pickup_service.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});
  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> workOrders = [], warehouses = [];
  Map<String, dynamic>? selected;
  int? warehouseId;
  DateTime? date;
  bool loading = false;
  bool online = true;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  @override
  void initState() {
    super.initState();
    _warehouses();
    _checkOnline();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _warehouses() async {
    try {
      warehouses = await PickupService.warehouses();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _checkOnline() async {
    final value = await PickupService.isOnline();
    if (mounted) setState(() => online = value);
  }

  Future<void> _search() async {
    final query = search.text.trim();
    final request = ++_searchRequest;
    if (query.length < 2) {
      if (mounted)
        setState(() {
          workOrders = [];
          loading = false;
        });
      return;
    }
    setState(() => loading = true);
    try {
      final result = await PickupService.searchWorkOrders(query);
      if (mounted && request == _searchRequest) {
        setState(() => workOrders = result);
      }
    } finally {
      if (mounted && request == _searchRequest) setState(() => loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  String _formatDate(dynamic raw) {
    final value = '$raw'.trim();
    if (value.isEmpty || value == 'null') return '-';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')} ${_months[parsed.month - 1]} ${parsed.year}';
  }

  Future<void> _submit() async {
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request pickup hanya tersedia saat online.'),
        ),
      );
      return;
    }
    if (selected == null || warehouseId == null || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih WO, gudang, dan tanggal pickup.')),
      );
      return;
    }
    final supplierId = int.tryParse('${selected!['supplier_id']}') ?? 0;
    final bankReason = await PickupService.validateSupplierBank(supplierId);
    if (bankReason != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$bankReason Perbaiki data supplier melalui CRM web.',
            ),
          ),
        );
      }
      return;
    }
    final days = await PickupService.supplierSchedule(supplierId);
    if (days.isNotEmpty &&
        !days.any(
          (d) => d.toLowerCase().contains(
            [
              'senin',
              'selasa',
              'rabu',
              'kamis',
              'jumat',
              'sabtu',
              'minggu',
            ][date!.weekday - 1],
          ),
        )) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tanggal tidak sesuai jadwal zona: ${days.join(', ')}',
            ),
          ),
        );
      return;
    }
    await PickupService.create(
      date:
          '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      warehouseId: warehouseId!,
      workOrderId: int.tryParse('${selected!['id']}') ?? 0,
      supplierId: supplierId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request pickup berhasil dibuat.')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Request Pickup')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: search,
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            _searchDebounce?.cancel();
            _search();
          },
          decoration: InputDecoration(
            labelText: 'Cari Work Order',
            hintText: 'Ketik kode WO atau nama supplier (min. 2 karakter)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      search.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                  ),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (!loading && search.text.trim().length < 2)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Ketik minimal 2 karakter untuk mencari WO yang tersedia.',
            ),
          ),
        if (!loading && search.text.trim().length >= 2 && workOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Tidak ada WO milik Anda yang berstatus A1/A3 dan belum menjadi Pickup.',
            ),
          ),
        ...workOrders.map(
          (wo) => RadioListTile<Map<String, dynamic>>(
            value: wo,
            groupValue: selected,
            onChanged: (v) => setState(() => selected = v),
            title: Text(
              '${wo['kode'] ?? '-'} • ${wo['supplier_name'] ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if ('${wo['supplier_kode'] ?? ''}'.isNotEmpty)
                  'Kode supplier: ${wo['supplier_kode']}',
                if ('${wo['supplier_phone'] ?? ''}'.isNotEmpty)
                  'Telp: ${wo['supplier_phone']}',
                'Tanggal WO: ${_formatDate(wo['tgl'] ?? wo['date'])}',
                if ('${wo['status_name'] ?? wo['status_wo'] ?? ''}'.isNotEmpty)
                  'Status: ${wo['status_name'] ?? wo['status_wo']}',
              ].join(' • '),
            ),
          ),
        ),
        if (selected != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => selected = null),
              icon: const Icon(Icons.close),
              label: const Text('Hapus pilihan WO'),
            ),
          ),
        DropdownButtonFormField<int>(
          value: warehouseId,
          decoration: const InputDecoration(labelText: 'Gudang'),
          items: warehouses
              .map(
                (g) => DropdownMenuItem(
                  value: int.tryParse('${g['id']}'),
                  child: Text('${g['name']}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => warehouseId = v),
        ),
        ListTile(
          title: Text(
            date == null
                ? 'Pilih tanggal pickup'
                : 'Tanggal: ${date!.day}/${date!.month}/${date!.year}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: c,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: date ?? DateTime.now(),
            );
            if (d != null) setState(() => date = d);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: online ? _submit : null,
          child: Text(
            online ? 'Kirim Request Pickup' : 'Butuh koneksi internet',
          ),
        ),
      ],
    ),
  );
}
