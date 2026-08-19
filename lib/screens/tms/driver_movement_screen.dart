import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/tms/movement_model.dart';
import '../../services/tms/tms_movement_service.dart';

class DriverMovementScreen extends StatefulWidget {
  const DriverMovementScreen({super.key});

  @override
  State<DriverMovementScreen> createState() => _DriverMovementScreenState();
}

class _DriverMovementScreenState extends State<DriverMovementScreen> {
  bool isLoading = true;
  List<MovementItem> movements = [];

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => isLoading = true);
    try {
      final list = await TmsMovementService.getMovements();
      if (mounted) {
        setState(() {
          movements = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showMilestoneDialog(MovementItem item, String actionType) async {
    final odoController = TextEditingController();
    final notesController = TextEditingController();

    final title = actionType == 'loading' ? 'Input Milestone Loading (Muat)' : 'Input Milestone Unloading (Bongkar)';

    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: odoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Angka Odometer Truk (KM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_road),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Operasional (Opsional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final odo = double.tryParse(odoController.text) ?? 0.0;
              Navigator.pop(c);
              setState(() => isLoading = true);

              try {
                if (actionType == 'loading') {
                  await TmsMovementService.submitLoading(
                    movementId: item.id,
                    odometer: odo,
                    notes: notesController.text,
                  );
                } else {
                  await TmsMovementService.submitUnloading(
                    movementId: item.id,
                    odometer: odo,
                    notes: notesController.text,
                  );
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Milestone $actionType berhasil diperbarui!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadMovements();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal memperbarui milestone: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Simpan Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Pergerakan Armada (Movement)',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMovements,
              child: movements.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.grey),
                              SizedBox(height: 16),
                              Text('Belum ada tugas pergerakan armada aktif', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: movements.length,
                      itemBuilder: (context, index) {
                        final item = movements[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.kode ?? 'MOV-${item.id}',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.accentOrange),
                                      ),
                                      child: Text(
                                        item.progress.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.accentOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.directions_bus, size: 18, color: AppColors.primaryGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${item.fleetName ?? 'Truk'} (${item.fleetPlat ?? '-'})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.alt_route, size: 18, color: AppColors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Rute: ${item.dariGudang ?? 'Asal'} ➔ ${item.tujuanGudang ?? 'Tujuan'}',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showMilestoneDialog(item, 'loading'),
                                        icon: const Icon(Icons.upload, size: 18),
                                        label: const Text('Mulai Loading'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _showMilestoneDialog(item, 'unloading'),
                                        icon: const Icon(Icons.download, size: 18),
                                        label: const Text('Unloading'),
                                        style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
