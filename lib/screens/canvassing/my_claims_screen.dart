import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/self_assign_service.dart';
import '../../utils/wa_format.dart';
import 'create_work_order_sheet.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});
  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  GeuUser? _user;

  @override
  void initState() {
    super.initState();
    load();
    GeuAuthService.getCachedUser().then((user) {
      if (mounted) setState(() => _user = user);
    });
  }

  bool get _isCRO => _user?.hasPermission('crm-self-assign-cro') ?? false;

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final value = await SelfAssignService.myClaims();
      if (mounted) setState(() => items = value);
    } finally {
      if (mounted) setState(() => loading = false);
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

  Future<void> _createWo(Map<String, dynamic> item) async {
    final supplierId = int.tryParse('${item['supplier_id'] ?? 0}') ?? 0;
    final kode = await showCreateWorkOrderSheet(
      context,
      supplierId: supplierId,
      supplierName: '${item['supplier_name'] ?? '-'}',
    );
    if (kode != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('WO $kode berhasil dibuat.')));
    }
  }

  Future<void> _escalate(Map<String, dynamic> item) async {
    final notes = TextEditingController();
    String recommendation = 'revisit';
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Eskalasi klaim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: recommendation,
                items: const [
                  DropdownMenuItem(value: 'revisit', child: Text('Revisit')),
                  DropdownMenuItem(value: 'delete', child: Text('Hapus')),
                ],
                onChanged: (value) =>
                    setDialogState(() => recommendation = value!),
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Catatan wajib'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
    if (submit != true || notes.text.trim().isEmpty) return;
    try {
      await SelfAssignService.escalate(
        supplierId: int.tryParse('${item['supplier_id'] ?? 0}') ?? 0,
        notes: notes.text.trim(),
        recommendation: recommendation,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Eskalasi terkirim.')));
      await load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Klaim Saya')),
    body: RefreshIndicator(
      onRefresh: load,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                final phone = '${item['phone'] ?? ''}';
                final status = '${item['status'] ?? ''}';
                final canCreateWo = _isCRO && status == 'assigned';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['supplier_name'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$status • ${item['kota'] ?? ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _openWa(phone),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (canCreateWo)
                              OutlinedButton(
                                onPressed: () => _createWo(item),
                                child: const Text('Buat WO'),
                              ),
                            OutlinedButton(
                              onPressed: () => _escalate(item),
                              child: const Text('Eskalasi'),
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
