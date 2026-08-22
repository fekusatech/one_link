import 'package:flutter/material.dart';
import '../../services/geu/pickup_service.dart';
import 'pickup_detail_screen.dart';
import 'pickup_request_screen.dart';

class PickupListScreen extends StatefulWidget {
  const PickupListScreen({super.key});
  @override
  State<PickupListScreen> createState() => _PickupListScreenState();
}

class _PickupListScreenState extends State<PickupListScreen> {
  List<PickupSummary> items = [];
  bool loading = true;
  String status = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final v = await PickupService.list(status: status);
      if (mounted) setState(() => items = v);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Pickup'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Request pickup',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PickupRequestScreen()),
            );
            await load();
          },
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final x = items[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      x.code,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          '${x.date} • ${x.warehouse}',
                          if (x.zone != '-') 'Zona: ${x.zone}',
                          if (x.supplierNames.isNotEmpty)
                            'Supplier: ${x.supplierNames}',
                          if (x.totalPickup.isNotEmpty) x.totalPickup,
                          if (x.driver.isNotEmpty) 'Driver: ${x.driver}',
                          if (x.fleet.isNotEmpty) 'Armada: ${x.fleet}',
                          if (x.address.isNotEmpty) x.address,
                          if (x.statusLabel.isNotEmpty)
                            'Tahap: ${x.statusLabel}',
                          'Pembayaran: ${_paymentLabel(x.paymentStatus)}',
                          'Uji quality: ${x.ujiQualityCode.isEmpty ? 'Belum ada' : x.ujiQualityCode}',
                          'In stock: ${x.inStockCode.isEmpty ? 'Belum ada' : x.inStockCode}',
                          'Bukti transfer: ${x.paymentProof.isEmpty ? 'Belum ada' : 'Tersedia'}',
                        ].join('\n'),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Text(x.status),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PickupDetailScreen(id: x.id),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );

  String _paymentLabel(String value) {
    switch (value.toLowerCase()) {
      case 'lunas':
      case 'paid':
        return 'Sudah dibayar';
      case 'pending':
        return 'Menunggu pembayaran';
      case 'cancelled':
      case 'batal':
        return 'Dibatalkan';
      default:
        return value.isEmpty ? 'Belum dibayar' : value;
    }
  }
}
