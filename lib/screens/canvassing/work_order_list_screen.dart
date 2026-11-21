import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/geu/work_order_service.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/supplier_list_service.dart';
import '../../models/supplier_list_model.dart';
import '../../utils/wa_format.dart';
import 'work_order_detail_sheet.dart';
import 'work_order_filter_sheet.dart';
import 'create_work_order_sheet.dart';

/// [initialFilters] and [titleOverride] let other screens deep-link into a
/// pre-filtered view - e.g. the WO detail sheet's "Lihat WO lain dari
/// supplier ini" button pushes this with a supplier_id filter already set,
/// the mobile equivalent of crm-react's "History WO" panel.
class WorkOrderListScreen extends StatefulWidget {
  final WorkOrderFilters initialFilters;
  final String? titleOverride;
  const WorkOrderListScreen({
    super.key,
    this.initialFilters = const WorkOrderFilters(),
    this.titleOverride,
  });

  @override
  State<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends State<WorkOrderListScreen> {
  final _search = TextEditingController();
  List<WorkOrderListItem> _items = [];
  int _page = 1;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  late WorkOrderFilters _filters;
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _loadCreatePermission();
    _load();
  }

  Future<void> _loadCreatePermission() async {
    final user = await GeuAuthService.getCachedUser();
    if (mounted) {
      setState(
        () => _canCreate =
            user?.hasPermission('crm-create-work-order') == true ||
            user?.hasPermission('tms-create-work-order') == true,
      );
    }
  }

  Future<void> _createWorkOrder() async {
    final supplier = await showModalBottomSheet<SupplierListItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WorkOrderSupplierPicker(),
    );
    if (supplier == null || !mounted) return;
    final supplierId = int.tryParse(supplier.id);
    if (supplierId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID supplier tidak valid.')));
      return;
    }
    final code = await showCreateWorkOrderSheet(
      context,
      supplierId: supplierId,
      supplierName: supplier.name,
    );
    if (code != null && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$code berhasil dibuat')));
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await WorkOrderService.list(
        page: 1,
        search: _search.text.trim(),
        filters: _filters,
      );
      if (mounted) {
        setState(() {
          _items = result.items;
          _hasNext = result.hasNext;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final result = await WorkOrderService.list(
        page: _page + 1,
        search: _search.text.trim(),
        filters: _filters,
      );
      if (mounted) {
        setState(() {
          _items = [..._items, ...result.items];
          _hasNext = result.hasNext;
          _page += 1;
        });
      }
    } catch (_) {
      // Keep whatever's already loaded; the "Muat lagi" button stays
      // available so the user can simply retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  int get _activeFilterCount => [
    _filters.dateFrom,
    _filters.dateTo,
    _filters.statusId,
    _filters.type,
    _filters.picId,
  ].where((v) => v != null).length;

  Future<void> _openFilterSheet() async {
    final result = await showWorkOrderFilterSheet(context, current: _filters);
    if (result != null && mounted) {
      setState(() => _filters = result);
      _load();
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

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Same signals as crm-react's WO table: visit status (checked-in-only vs
  // fully checked-out vs none), an anomaly warning, the linked pickup kode,
  // and the Revisit/CRO/Reguler type badge.
  Widget _metaChips(WorkOrderListItem wo) {
    final chips = <Widget>[];

    if (wo.visitStatus == 'checked_out') {
      chips.add(_chip('Checkin & Checkout', AppColors.success));
    } else if (wo.visitStatus == 'checked_in') {
      chips.add(_chip('Checkin saja', AppColors.accentOrange));
    }
    if (wo.visitHasAnomaly) {
      chips.add(
        Tooltip(
          message: 'Ada anomali pada kunjungan ini',
          child: _chip('⚠ Anomali', AppColors.error),
        ),
      );
    }
    if (wo.pickupKode != null && wo.pickupKode!.isNotEmpty) {
      chips.add(_chip('Pickup: ${wo.pickupKode}', AppColors.primaryGreen));
    }
    if (wo.type == 'Revisit') {
      chips.add(_chip('Revisit', AppColors.accentOrange));
    } else if (wo.type == 'CRO') {
      chips.add(_chip('CRO', AppColors.error));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primaryGreen,
      title: Text(widget.titleOverride ?? 'Daftar Work Order'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Cari kode WO atau nama supplier',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  label: Text('$_activeFilterCount'),
                  isLabelVisible: _activeFilterCount > 0,
                  child: IconButton.filledTonal(
                    onPressed: _openFilterSheet,
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    ),
    floatingActionButton: _canCreate
        ? FloatingActionButton.extended(
            onPressed: _createWorkOrder,
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.add),
            label: const Text('Buat WO'),
          )
        : null,
  );

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Belum ada work order.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      itemCount: _items.length + 1,
      itemBuilder: (_, index) {
        if (index == _items.length) {
          if (!_hasNext) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Muat lagi'),
                    ),
            ),
          );
        }
        final wo = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          child: InkWell(
            onTap: () => showWorkOrderDetailSheet(context, wo.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wo.kode,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        tooltip: 'Lihat detail',
                        onPressed: () =>
                            showWorkOrderDetailSheet(context, wo.id),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (wo.close
                                    ? AppColors.success
                                    : AppColors.accentOrange)
                                .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        wo.statusName,
                        style: AppTextStyles.caption.copyWith(
                          color: wo.close
                              ? AppColors.success
                              : AppColors.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wo.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(wo.tgl),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (wo.supplierPhone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _openWa(wo.supplierPhone),
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
                            wo.supplierPhone,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _metaChips(wo),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkOrderSupplierPicker extends StatefulWidget {
  const _WorkOrderSupplierPicker();

  @override
  State<_WorkOrderSupplierPicker> createState() =>
      _WorkOrderSupplierPickerState();
}

class _WorkOrderSupplierPickerState extends State<_WorkOrderSupplierPicker> {
  final _search = TextEditingController();
  List<SupplierListItem> _items = const [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await SupplierListService.getSupplierList(
      limit: 30,
      search: _search.text.trim(),
    );
    if (!mounted || request != _request) return;
    setState(() {
      _items = response.data?.data ?? const [];
      _error = response.status ? null : response.message;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih supplier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Cari nama supplier',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _items.isEmpty
                  ? const Center(child: Text('Supplier tidak ditemukan.'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          subtitle: Text(item.kode ?? item.phone ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
