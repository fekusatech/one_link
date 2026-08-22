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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
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

  List<PickupSummary> get _visibleItems {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final text = [
        item.code,
        item.supplierNames,
        item.driver,
        item.fleet,
        item.warehouse,
        item.zone,
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || text.contains(query);
      final normalized = '${item.statusLabel} ${item.status}'.toLowerCase();
      final matchesStatus = status.isEmpty || normalized.contains(status);
      return matchesQuery && matchesStatus;
    }).toList();
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
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari kode, supplier, driver...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('Semua', ''),
              _filterChip('Pending', 'pending'),
              _filterChip('Approved', 'approved'),
              _filterChip('Pickup', 'pickup'),
              _filterChip('Selesai', 'done'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: loading
                ? ListView(children: const [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ])
                : _visibleItems.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 180),
                        Center(child: Text('Pickup tidak ditemukan')),
                      ])
                    : ListView.builder(
              itemCount: _visibleItems.length,
              itemBuilder: (_, i) {
                final x = _visibleItems[i];
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PickupDetailScreen(id: x.id),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  x.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _statusBadge(_statusText(x)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 15, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(_formatDate(x.date),
                                  style: TextStyle(color: Colors.grey.shade700)),
                              if (_hasValue(x.warehouse)) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.warehouse_outlined,
                                    size: 15, color: Colors.grey.shade600),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(x.warehouse,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade700)),
                                ),
                              ],
                            ],
                          ),
                          if (_hasValue(x.supplierNames)) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.storefront_outlined,
                                    size: 18, color: const Color(0xFF1E5A49)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(x.supplierNames,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_hasValue(x.totalPickup))
                                _infoChip(Icons.inventory_2_outlined, x.totalPickup),
                              if (_hasValue(x.driver))
                                _infoChip(Icons.person_outline, x.driver),
                              if (_hasValue(x.fleet))
                                _infoChip(Icons.local_shipping_outlined, x.fleet),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                    ),
          ),
        ),
      ],
    ),
  );

  Widget _filterChip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: status == value,
          onSelected: (_) {
            setState(() => status = value);
            load();
          },
          selectedColor: const Color(0xFFD9EEE6),
          checkmarkColor: const Color(0xFF1E5A49),
        ),
      );

  bool _hasValue(String value) => value.trim().isNotEmpty && value.trim() != '-';

  String _statusText(PickupSummary item) {
    if (_hasValue(item.statusLabel)) return item.statusLabel;
    switch (item.status.toLowerCase()) {
      case 'pickup':
        return 'Pickup';
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu';
      case 'done':
      case 'completed':
        return 'Selesai';
      default:
        return RegExp(r'^\d+$').hasMatch(item.status) ? 'Pickup' : item.status;
    }
  }

  Widget _statusBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F3ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF1E5A49), fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ]),
      );

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
