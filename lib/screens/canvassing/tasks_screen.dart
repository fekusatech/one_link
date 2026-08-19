import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_colors.dart';
import '../../services/geu/tasks_service.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../utils/wa_format.dart';
import 'create_work_order_sheet.dart';
import 'my_claims_screen.dart';

class TasksScreen extends StatefulWidget {
  /// When true, renders just the list content (no Scaffold/AppBar) so this
  /// can be embedded as a tab inside TasksHubScreen. Standalone navigation
  /// (e.g. from CanvassingHomeScreen) keeps using the default full screen.
  final bool embedded;

  const TasksScreen({super.key, this.embedded = false});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskProgress? _progress;
  List<CrmTask> _items = [];
  bool _loading = true;
  String _status = '';
  String _preferenceKey = 'guest';
  DateTime? _cachedAt;
  final _search = TextEditingController();
  GeuUser? _user;

  bool get _isCRO => _user?.hasPermission('crm-self-assign-cro') ?? false;

  @override
  void initState() {
    super.initState();
    _restoreFilters();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        TasksService.progress(),
        TasksService.items(status: _status, search: _search.text),
      ]);
      if (!mounted) return;
      setState(() {
        _progress = results[0] as TaskProgress;
        _items = (results[1] as TaskList).items;
        _cachedAt = (results[1] as TaskList).cachedAt;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFilters() async {
    final user = await GeuAuthService.getCachedUser();
    _user = user;
    _preferenceKey = user?.id.toString() ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    _status = prefs.getString('geu_tasks_status_$_preferenceKey') ?? '';
    _search.text = prefs.getString('geu_tasks_search_$_preferenceKey') ?? '';
    await _load();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geu_tasks_status_$_preferenceKey', _status);
    await prefs.setString('geu_tasks_search_$_preferenceKey', _search.text);
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_progress != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _kpi('Total', _progress!.total, AppColors.primaryGreen),
                _kpi('Selesai', _progress!.completed, AppColors.info),
                _kpi('Pending', _progress!.pending, AppColors.accentOrange),
                _kpi('Terlambat', _progress!.overdue, AppColors.error),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onSubmitted: (_) async {
              await _saveFilters();
              await _load();
            },
            decoration: InputDecoration(
              hintText: 'Cari supplier',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _chooseStatus,
              ),
            ),
          ),
          if (_cachedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Offline • data tersimpan ${_cachedAt!.day.toString().padLeft(2, '0')}/${_cachedAt!.month.toString().padLeft(2, '0')} ${_cachedAt!.hour.toString().padLeft(2, '0')}:${_cachedAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._items.map(_card),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined),
            tooltip: 'Klaim saya',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyClaimsScreen()),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _kpi(String label, int value, Color color) => Container(
    width: 76,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Future<void> _createWo(CrmTask task) async {
    final kode = await showCreateWorkOrderSheet(
      context,
      supplierId: task.supplierId,
      supplierName: task.supplierName,
    );
    if (kode != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('WO $kode berhasil dibuat.')));
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

  Widget _card(CrmTask task) {
    final canCreateWo = _isCRO && task.status == 'assigned';
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(task.supplierName),
            subtitle: Text(
              '${task.status}${task.overdue ? ' • TERLAMBAT' : ''}${task.gpsMissing ? ' • GPS tidak tersedia' : ''}',
            ),
            trailing: Wrap(
              spacing: 0,
              children: [
                if (task.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_outlined),
                    onPressed: () => launchUrl(Uri.parse('tel:${task.phone}')),
                  ),
                if (task.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => _openWa(task.phone),
                  ),
                if (!task.gpsMissing)
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buka detail supplier untuk navigasi.'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canCreateWo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => _createWo(task),
                  child: const Text('Buat WO'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseStatus() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['', 'pending', 'completed', 'overdue']
              .map(
                (status) => ListTile(
                  title: Text(status.isEmpty ? 'Semua status' : status),
                  onTap: () => Navigator.pop(sheetContext, status),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _status = selected);
    await _saveFilters();
    await _load();
  }
}
