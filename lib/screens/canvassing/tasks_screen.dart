import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_colors.dart';
import '../../services/geu/tasks_service.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/supplier_list_service.dart';
import '../../models/supplier_order_history.dart';
import '../../utils/wa_format.dart';
import '../../widgets/order_history_widgets.dart';
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

/// Date-range presets for the task list. "today" is the default — matches
/// the KPI bar above it (GetTaskProgress defaults to today too, Asia/Jakarta)
/// so the numbers up top and the rows below them are finally the same scope;
/// before this, the KPI was today-only while the list underneath had no
/// date filter at all and silently showed the entire multi-thousand-row
/// history, which is why "Total 50 / Selesai 50" never matched what was
/// actually scrollable.
enum _DateScope { today, week, all }

class _TasksScreenState extends State<TasksScreen> with WidgetsBindingObserver {
  TaskProgress? _progress;
  List<CrmTask> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  // Real status values are assigned/completed/revisit/skipped — 'active' is
  // a synthetic value go-rest-api's ListItems translates to "status <>
  // completed". The old default ('') plus a filter dropdown offering
  // 'pending'/'overdue' as literal status values never matched a single row,
  // since neither is a real value in the status column.
  String _status = 'active';
  _DateScope _dateScope = _DateScope.today;
  String _preferenceKey = 'guest';
  DateTime? _cachedAt;
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  GeuUser? _user;

  // Set right before launching WhatsApp so the next app resume (the rep
  // switching back after sending, or backing out) can ask "did it actually
  // send?" — cleared as soon as that question is asked once, so an
  // unrelated later resume (e.g. switching to check something else) never
  // re-triggers it.
  CrmTask? _pendingWaTask;
  String? _pendingWaMessage;

  bool get _isCRO => _user?.hasPermission('crm-self-assign-cro') ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _restoreFilters();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _pendingWaTask == null) return;
    final task = _pendingWaTask!;
    final message = _pendingWaMessage;
    _pendingWaTask = null;
    _pendingWaMessage = null;
    // Post-frame: the resume callback can fire before the widget tree is
    // ready to show a new route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmWaSent(task, message);
    });
  }

  Future<void> _confirmWaSent(CrmTask task, String? message) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi WhatsApp'),
        content: Text(
          'Apakah pesan WhatsApp ke ${task.supplierName} berhasil terkirim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, terkirim'),
          ),
        ],
      ),
    );
    if (sent == null || !mounted) return;

    if (sent) {
      final ok = await SupplierListService.updateWaStatus(
        task.supplierId,
        valid: true,
        message: message,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Tercatat di riwayat follow up.' : 'Gagal mencatat, coba lagi.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final reason = await _chooseWaInvalidReason();
    if (reason == null || !mounted) return;
    final ok = await SupplierListService.updateWaStatus(
      task.supplierId,
      valid: false,
      reason: reason,
      message: message,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Status WA supplier diperbarui.' : 'Gagal mencatat, coba lagi.',
          ),
        ),
      );
    }
  }

  static const _waInvalidReasons = [
    'Nomor tidak terdaftar di WhatsApp',
    'Nomor salah / tidak aktif',
    'Lainnya',
  ];

  Future<String?> _chooseWaInvalidReason() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kenapa pesan tidak terkirim?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (final reason in _waInvalidReasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(sheetContext, reason),
              ),
          ],
        ),
      ),
    );
    if (selected != 'Lainnya') return selected;
    if (!mounted) return null;

    final controller = TextEditingController();
    final custom = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alasan lainnya'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tulis alasannya'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    return (custom == null || custom.isEmpty) ? null : custom;
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  (String, String) _dateRange() {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    switch (_dateScope) {
      case _DateScope.today:
        final today = fmt(now);
        return (today, today);
      case _DateScope.week:
        return (fmt(now.subtract(const Duration(days: 6))), fmt(now));
      case _DateScope.all:
        // An explicit (very wide) bound rather than "" for both endpoints —
        // GetTaskProgress and ListItems both default an *empty* date to
        // "today" server-side, so leaving it blank here would silently
        // narrow "Semua" back down to today and reintroduce the exact
        // KPI/list mismatch this screen is being fixed for.
        return ('2015-01-01', fmt(now));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 1;
    });
    final (dateFrom, dateTo) = _dateRange();
    try {
      final results = await Future.wait([
        TasksService.progress(dateFrom: dateFrom, dateTo: dateTo),
        TasksService.items(
          status: _status,
          search: _search.text,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      ]);
      if (!mounted) return;
      final list = results[1] as TaskList;
      setState(() {
        _progress = results[0] as TaskProgress;
        _items = list.items;
        _hasMore = list.hasMore;
        _cachedAt = list.cachedAt;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final (dateFrom, dateTo) = _dateRange();
    try {
      final list = await TasksService.items(
        page: _page + 1,
        status: _status,
        search: _search.text,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _items = [..._items, ...list.items];
        _hasMore = list.hasMore;
      });
    } catch (_) {
      // Silently keep whatever's already on screen — the user can scroll up
      // and trigger the same load-more attempt again next time they reach
      // the bottom.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _restoreFilters() async {
    final user = await GeuAuthService.getCachedUser();
    _user = user;
    _preferenceKey = user?.id.toString() ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    _status = prefs.getString('geu_tasks_status_$_preferenceKey') ?? 'active';
    _dateScope = _DateScope.values[prefs.getInt('geu_tasks_scope_$_preferenceKey') ?? 0];
    _search.text = prefs.getString('geu_tasks_search_$_preferenceKey') ?? '';
    await _load();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geu_tasks_status_$_preferenceKey', _status);
    await prefs.setInt('geu_tasks_scope_$_preferenceKey', _dateScope.index);
    await prefs.setString('geu_tasks_search_$_preferenceKey', _search.text);
  }

  // 'active' is labeled "Pending" here to match the KPI card above it
  // (GetTaskProgress's Pending = Total - Completed, the exact same rule as
  // this filter's server-side "status <> completed") — they were the same
  // data with two different names before, which read as if the KPI's
  // number had no matching filter.
  static const _statusLabels = {
    'active': 'Pending',
    '': 'Semua Status',
    'completed': 'Selesai',
    'revisit': 'Perlu Revisit',
  };

  static const _scopeLabels = {
    _DateScope.today: 'Hari Ini',
    _DateScope.week: '7 Hari',
    _DateScope.all: 'Semua',
  };

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in _DateScope.values)
                ChoiceChip(
                  label: Text(_scopeLabels[scope]!),
                  selected: _dateScope == scope,
                  onSelected: (_) async {
                    setState(() => _dateScope = scope);
                    await _saveFilters();
                    await _load();
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                label: Text(_statusLabels[_status] ?? _status),
                onPressed: _chooseStatus,
              ),
            ],
          ),
          if (_cachedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Offline • data tersimpan ${_cachedAt!.day.toString().padLeft(2, '0')}/${_cachedAt!.month.toString().padLeft(2, '0')} ${_cachedAt!.hour.toString().padLeft(2, '0')}:${_cachedAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada tugas untuk filter ini.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            ..._items.map(_card),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _hasMore
                            ? 'Scroll untuk memuat lagi…'
                            : '— Semua data sudah ditampilkan —',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
              ),
            ),
          ],
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

  /// Opens WhatsApp pre-filled with a follow-up opener instead of a blank
  /// chat — wording depends on whether contacted_at/notes shows someone
  /// already reached out to this lead before (see CrmTask.hasBeenContacted).
  Future<void> _openWa(CrmTask task) async {
    final message = WaFormat.generateTaskFollowUpMessage(
      supplierName: task.supplierName,
      userName: _user?.name ?? 'Tim GEU',
      alreadyContacted: task.hasBeenContacted,
    );
    final launched = await launchUrl(
      Uri.parse(waUrl(task.phone, text: message)),
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      _pendingWaTask = task;
      _pendingWaMessage = message;
    } else if (mounted) {
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
            onTap: () => _showTaskDetail(task),
            title: Text(task.supplierName),
            subtitle: Text(
              '${task.status}${task.overdue ? ' • TERLAMBAT' : ''}'
              '${task.gpsMissing ? ' • GPS tidak tersedia' : ''}'
              '${task.hasBeenContacted ? ' • sudah pernah dihubungi' : ''}',
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
                    onPressed: () => _openWa(task),
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
    // Real status column values are assigned/completed/revisit/skipped (see
    // task_service.go) — 'active' is go-rest-api's synthetic "not completed
    // yet" filter. The old options ('pending', 'overdue' as literal status
    // strings) never matched a single row.
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusLabels.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: _status == entry.key
                      ? const Icon(Icons.check, color: AppColors.primaryGreen)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, entry.key),
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

  Future<void> _showTaskDetail(CrmTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskDetailSheet(
        task: task,
        onChat: () => _openWa(task),
      ),
    );
  }
}

/// Detail for one assigned lead — supplier context (address/PIC/zona) from
/// GET /api-crm/tasks/supplier/:id/detail, plus real order history (total
/// setor, last order, mini chart) from GET /api/suppliers/:id, the same
/// endpoint the map's supplier sheet uses. Skeleton while both load, no
/// fallback data if either call fails — just says so, per this project's
/// rule against faking numbers when an API call fails.
class _TaskDetailSheet extends StatefulWidget {
  final CrmTask task;
  final VoidCallback onChat;

  const _TaskDetailSheet({required this.task, required this.onChat});

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  bool _loading = true;
  SupplierTaskDetail? _detail;
  SupplierOrderSummary? _orderSummary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TasksService.supplierDetail(widget.task.supplierId),
      SupplierListService.getSupplierOrderSummary(widget.task.supplierId),
    ]);
    if (!mounted) return;
    setState(() {
      _detail = results[0] as SupplierTaskDetail?;
      _orderSummary = results[1] as SupplierOrderSummary?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.supplierName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(
              Icons.flag_outlined,
              '${task.status}${task.overdue ? ' • TERLAMBAT' : ''}',
            ),
            if (task.assigneeName.isNotEmpty)
              _row(Icons.person_outline, 'Ditugaskan ke ${task.assigneeName}'),
            if (task.phone.isNotEmpty) _row(Icons.phone_outlined, task.phone),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SkeletonBox(width: double.infinity, height: 40),
              )
            else if (_detail != null && _detail!.alamat.isNotEmpty)
              _row(Icons.location_on_outlined, _detail!.alamat),
            if (!_loading && (_detail?.picName.isNotEmpty ?? false))
              _row(Icons.badge_outlined, 'PIC: ${_detail!.picName}'),
            if (!_loading && _detail?.zonaName != null)
              _row(Icons.map_outlined, 'Zona: ${_detail!.zonaName}'),
            if (!_loading && (_detail?.jadwalHari.isNotEmpty ?? false))
              _row(Icons.event_repeat_outlined, 'Jadwal: ${_detail!.jadwalHari.join(', ')}'),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Text(
              'Riwayat Follow Up',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (task.hasBeenContacted) ...[
              if (task.contactedAt != null)
                _row(
                  Icons.history_outlined,
                  'Terakhir dihubungi ${_formatDate(task.contactedAt!)}',
                ),
              if (task.notes.trim().isNotEmpty)
                _row(Icons.notes_outlined, task.notes.trim()),
            ] else
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum pernah dihubungi. Ini akan jadi kontak pertama.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Text(
              'Riwayat Setor Minyak',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildOrderHistory(),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: task.phone.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onChat();
                      },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  task.hasBeenContacted ? 'Follow Up via WhatsApp' : 'Hubungi via WhatsApp',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory() {
    if (_loading) return const OrderHistorySkeleton();

    final summary = _orderSummary;
    if (summary == null || !summary.hasHistory) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada riwayat setor minyak.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          Icons.history_outlined,
          'Terakhir setor ${_formatDate(summary.lastOrderDate)}'
          '${summary.lastOrderNominal != null ? ' • ${formatRupiah(summary.lastOrderNominal!)}' : ''}',
        ),
        _row(
          Icons.receipt_long_outlined,
          '${summary.totalOrderCount}x setor • total ${formatRupiah(summary.totalOrderNominal)}',
        ),
        if (summary.recentOrders.length >= 2) ...[
          const SizedBox(height: 12),
          SizedBox(height: 80, child: RecentOrdersChart(orders: summary.recentOrders)),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
      ],
    ),
  );

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
