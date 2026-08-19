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
  @override
  void initState() {
    super.initState();
    _warehouses();
    _checkOnline();
  }

  @override
  void dispose() {
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
    setState(() => loading = true);
    try {
      workOrders = await PickupService.searchWorkOrders(search.text);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Cari Work Order',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        ...workOrders.map(
          (wo) => RadioListTile<Map<String, dynamic>>(
            value: wo,
            groupValue: selected,
            onChanged: (v) => setState(() => selected = v),
            title: Text('${wo['kode'] ?? '-'}'),
            subtitle: Text('${wo['supplier_name'] ?? '-'}'),
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
