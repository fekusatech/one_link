import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/crm_permission_service.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/visit_planner_service.dart';

class NearbySupplierScreen extends StatefulWidget {
  const NearbySupplierScreen({super.key});
  @override
  State<NearbySupplierScreen> createState() => _NearbySupplierScreenState();
}

class _NearbySupplierScreenState extends State<NearbySupplierScreen> {
  final _city = TextEditingController();
  List<NearbySupplier> _items = const [];
  int _radius = 5000;
  bool _loading = false;
  String? _error;
  final Set<int> _adding = {}, _added = {};
  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await CrmPermissionService.ensureLocation(context))
        throw GpsException('Izin lokasi diperlukan.');
      final gps = await GpsService.getCurrentFix();
      final items = await VisitPlannerService.getNearbySuppliers(
        latitude: gps.latitude,
        longitude: gps.longitude,
        radiusMeters: _radius,
        city: _city.text,
      );
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToMission(NearbySupplier item) async {
    setState(() => _adding.add(item.id));
    try {
      await VisitPlannerService.addSupplierToMission(item.id);
      if (!mounted) return;
      setState(() => _added.add(item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} masuk Mission hari ini.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Supplier Nearby')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Temukan supplier di sekitar Anda atau batasi berdasarkan kota.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _city,
          decoration: const InputDecoration(
            labelText: 'Kota (opsional)',
            hintText: 'Contoh: Bandung',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _radius,
          decoration: const InputDecoration(
            labelText: 'Radius jika tanpa kota',
            border: OutlineInputBorder(),
          ),
          items: const [1000, 5000, 10000, 20000]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v meter')))
              .toList(),
          onChanged: _loading
              ? null
              : (v) => setState(() => _radius = v ?? 5000),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.near_me_outlined),
            label: const Text('Cari supplier'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        const SizedBox(height: 20),
        ..._items.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.address}\n${item.distanceKm.toStringAsFixed(1)} km · ${item.type}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 2,
                children: [
                  if (item.phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone_outlined),
                      tooltip: 'Telepon',
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:${item.phone}')),
                    ),
                  _added.contains(item.id)
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : IconButton(
                          icon: _adding.contains(item.id)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_task_outlined),
                          tooltip: 'Tambah ke Mission',
                          onPressed: _adding.contains(item.id)
                              ? null
                              : () => _addToMission(item),
                        ),
                ],
              ),
            ),
          ),
        ),
        if (!_loading && _items.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text('Atur filter lalu cari supplier.')),
          ),
      ],
    ),
  );
}
