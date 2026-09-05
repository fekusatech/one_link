import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/visit_planner_service.dart';
import '../../services/geu/visit_sync_service.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/active_visit_service.dart';
import '../../services/geu/reverse_geocoding_service.dart';
import '../../services/geu/visit_gps_mode_service.dart';
import '../../services/geu/visit_gps_ping_service.dart';
import '../../utils/wa_format.dart';
import 'checkin_dialog.dart';
import 'checkout_dialog.dart';
import '../../widgets/permission_gate.dart';
import '../../widgets/active_visit_warning_banner.dart';
import 'skip_mission_sheet.dart';
import 'add_work_order_sheet.dart';
import 'register_supplier_dialog.dart';
import 'sync_status_screen.dart';
import 'visit_history_screen.dart';

/// FR-VP-01: mission hari ini, urut sort_order, tersedia offline dari cache
/// terakhir dengan penanda waktu (§4 A1). Peta (FR-VP-02) dan check-in
/// (FR-VP-06..13) adalah task terpisah di Task Handler.
class MissionTodayScreen extends StatefulWidget {
  const MissionTodayScreen({super.key});

  @override
  State<MissionTodayScreen> createState() => _MissionTodayScreenState();
}

class _MissionTodayScreenState extends State<MissionTodayScreen> {
  TodaysMission? _mission;
  String? _error;
  bool _isLoading = true;
  final List<int> _activeWorkOrderIds = [];
  bool _manualOffline = false;

  // shrinkWrap tap target so wrapped action rows don't get Material's
  // default 48dp minimum touch target, which overlapped adjacent rows'
  // buttons (Telepon's hit area was swallowing taps meant for Check-in).
  static final _actionButtonStyle = TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  @override
  void initState() {
    super.initState();
    _load();
    _loadGpsMode();
    VisitGpsPingService.start();
  }

  @override
  void dispose() {
    VisitGpsPingService.stop();
    super.dispose();
  }

  Future<void> _loadGpsMode() async {
    final value = await VisitGpsModeService.isManualOffline();
    if (mounted) setState(() => _manualOffline = value);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final mission = await VisitPlannerService.getTodaysMission();
      if (!mounted) return;
      setState(() {
        _mission = mission;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Buka Google Maps external menuju koordinat supplier pertama yang punya
  /// koordinat (Google Maps URL hanya mendukung 1 destinasi).
  Future<void> _openAllInGoogleMaps() async {
    final mission = _mission;
    if (mission == null) return;
    final withCoords = mission.items
        .where((item) => item.hasCoordinates)
        .toList();
    if (withCoords.isEmpty) return;
    final dest = withCoords.first;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${dest.lat},${dest.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mission Hari Ini'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat kunjungan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PermissionGate(
                  slug: 'crm-read-visit-planner',
                  child: VisitHistoryScreen(),
                ),
              ),
            ),
          ),
          FutureBuilder<List>(
            future: VisitSyncService.pendingItems(),
            builder: (_, snapshot) => IconButton(
              icon: Badge(
                isLabelVisible: (snapshot.data?.isNotEmpty ?? false),
                label: Text('${snapshot.data?.length ?? 0}'),
                child: const Icon(Icons.sync),
              ),
              tooltip: 'Status sinkronisasi',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_manualOffline ? Icons.cloud_off : Icons.cloud_queue),
            tooltip: _manualOffline
                ? 'Mode offline manual aktif'
                : 'Aktifkan mode offline manual',
            onPressed: () async {
              final next = !_manualOffline;
              await VisitGpsModeService.setManualOffline(next);
              if (next) {
                await VisitGpsPingService.stop();
              } else {
                await VisitGpsPingService.start();
              }
              if (mounted) setState(() => _manualOffline = next);
            },
          ),
          if (_mission?.items.any((item) => item.hasCoordinates) ?? false)
            IconButton(
              icon: const Icon(Icons.navigation_outlined),
              tooltip: 'Buka Google Maps',
              onPressed: _openAllInGoogleMaps,
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPoi,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah POI'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mission == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_error != null && _mission == null) {
      return _buildError();
    }
    final mission = _mission!;
    final completed = mission.items
        .where((item) => item.status.toUpperCase() == 'VISITED')
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$completed / ${mission.items.length} kunjungan selesai',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: mission.items.isEmpty
                    ? 0
                    : completed / mission.items.length,
                minHeight: 7,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.accentOrange,
                ),
              ),
            ],
          ),
        ),
        const ActiveVisitWarningBanner(),
        if (mission.cachedAt != null) _buildCacheBanner(mission.cachedAt!),
        if (mission.items.isEmpty) _buildEmpty(),
        ...mission.items.map(_buildMissionCard),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Gagal memuat data',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.event_available,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada mission hari ini',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheBanner(DateTime cachedAt) {
    final formatted =
        '${cachedAt.hour.toString().padLeft(2, '0')}:${cachedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: AppColors.darkGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data per $formatted (offline)',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(MissionItem item) {
    final statusColor = switch (item.status.toUpperCase()) {
      'VISITED' => AppColors.success,
      'SKIPPED' => AppColors.error,
      'ACTIVE' => AppColors.accentOrange,
      _ => AppColors.info,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.supplierName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.address,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 12,
            children: [
              if (item.supplierPhone.isNotEmpty)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _call(item.supplierPhone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Telepon'),
                ),
              if (item.supplierPhone.isNotEmpty)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _whatsApp(item),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('WhatsApp'),
                ),
              if (item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _navigate(item.lat!, item.lng!),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Navigasi'),
                ),
              if (item.supplierId == 0 && item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _registerSupplier(item),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Daftarkan Supplier'),
                ),
              ValueListenableBuilder<ActiveVisitState>(
                valueListenable: ActiveVisitService.current,
                builder: (_, state, __) =>
                    item.supplierId > 0 &&
                        state.isActive &&
                        state.supplierId == item.supplierId
                    ? TextButton.icon(
                        style: _actionButtonStyle,
                        onPressed: () => _addWorkOrder(item),
                        icon: const Icon(Icons.note_add_outlined, size: 16),
                        label: const Text('Tambah WO'),
                      )
                    : const SizedBox.shrink(),
              ),
              if (item.supplierId > 0 &&
                  item.status.toUpperCase() != 'VISITED' &&
                  item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _checkin(item),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Check-in'),
                ),
              ValueListenableBuilder<ActiveVisitState>(
                valueListenable: ActiveVisitService.current,
                builder: (_, state, __) =>
                    state.isActive && state.supplierId == item.supplierId
                    ? TextButton.icon(
                        style: _actionButtonStyle,
                        onPressed: () => _checkout(item),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Check-out'),
                      )
                    : const SizedBox.shrink(),
              ),
              if (item.status.toUpperCase() != 'VISITED' &&
                  item.status.toUpperCase() != 'SKIPPED')
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _skip(item),
                  icon: const Icon(Icons.skip_next_outlined, size: 16),
                  label: const Text('Lewati'),
                ),
              ValueListenableBuilder<ActiveVisitState>(
                valueListenable: ActiveVisitService.current,
                builder: (_, state, __) =>
                    state.isActive && state.supplierId == item.supplierId
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        style: _actionButtonStyle,
                        onPressed: () => _remove(item),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Hapus',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _navigate(double lat, double lng) async {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    );
  }

  Future<void> _whatsApp(MissionItem item) async {
    final message =
        'Halo ${item.supplierName}, saya dari One Link terkait kunjungan hari ini.';
    final launched = await launchUrl(
      Uri.parse(waUrl(item.supplierPhone, text: message)),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp tidak tersedia di perangkat ini.'),
        ),
      );
  }

  Future<void> _checkin(MissionItem item) async {
    final draft = await showCheckinDialog(context, item);
    if (draft == null || !mounted) return;
    final address = await ReverseGeocodingService.resolve(
      draft.fix.latitude,
      draft.fix.longitude,
    );
    final queued = await VisitSyncService.enqueueCheckin(
      supplierId: item.supplierId,
      latitude: draft.fix.latitude,
      longitude: draft.fix.longitude,
      address: address,
      photoPath: draft.photo.file.path,
      gpsAccuracyMeters: draft.fix.accuracyMeters,
      isMockLocation: draft.fix.isMocked,
    );
    ActiveVisitService.markPendingCheckin(item.supplierId);
    await VisitSyncService.syncNow();
    final delivered = await VisitSyncService.wasDelivered(queued.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivered
              ? 'Check-in berhasil dikirim ke server (${(draft.distanceKm * 1000).round()}m'
                    '${draft.confirmFar ? ", confirm_far" : ""}).'
              : 'Check-in tersimpan offline — akan dikirim otomatis saat koneksi tersedia.',
        ),
      ),
    );
  }

  Future<void> _checkout(MissionItem item) async {
    final draft = await showCheckoutDialog(context, item);
    if (draft == null || !mounted) return;
    final address = await ReverseGeocodingService.resolve(
      draft.fix.latitude,
      draft.fix.longitude,
    );
    final queued = await VisitSyncService.enqueueCheckout(
      latitude: draft.fix.latitude,
      longitude: draft.fix.longitude,
      address: address,
      notes: draft.notes,
      photoPath: draft.photo.file.path,
      workOrderIds: _activeWorkOrderIds,
      gpsAccuracyMeters: draft.fix.accuracyMeters,
      isMockLocation: draft.fix.isMocked,
    );
    await VisitSyncService.syncNow();
    final delivered = await VisitSyncService.wasDelivered(queued.id);
    try {
      await VisitPlannerService.updateMissionStatus(
        planDetailId: item.planDetailId,
        status: 'VISITED',
      );
      await _load();
    } catch (_) {
      // The check-out remains safely queued; status can be retried on refresh.
    }
    if (delivered) {
      ActiveVisitService.markCheckoutQueued();
    } else {
      ActiveVisitService.markCheckoutFailed(
        supplierId: item.supplierId,
        supplierName: item.supplierName,
      );
    }
    _activeWorkOrderIds.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivered
              ? 'Check-out berhasil dikirim ke server.'
              : 'Check-out tersimpan offline — akan dikirim otomatis saat koneksi tersedia. Cek ikon sinkronisasi jika lama.',
        ),
      ),
    );
  }

  Future<void> _skip(MissionItem item) async {
    final draft = await showSkipMissionSheet(context, item);
    if (draft == null || !mounted) return;
    try {
      await VisitPlannerService.updateMissionStatus(
        planDetailId: item.planDetailId,
        status: 'SKIPPED',
        skipReason: draft.reason,
        rescheduleDate: draft.rescheduleDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mission ditandai dilewati.')),
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addWorkOrder(MissionItem item) async {
    final workOrderId = await showAddWorkOrderSheet(context, item);
    if (workOrderId != null && mounted) {
      setState(() => _activeWorkOrderIds.add(workOrderId));
      // Refresh the mission before returning control to the user so the new
      // WO badge/detail is visible immediately, without pull-to-refresh.
      await _load();
    }
  }

  Future<void> _registerSupplier(MissionItem item) async {
    if (!item.hasCoordinates) return;
    final result = await showRegisterSupplierDialog(
      context,
      latitude: item.lat!,
      longitude: item.lng!,
      initialName: item.supplierName,
      initialAddress: item.address,
      initialPhone: item.supplierPhone,
    );
    if (result == null || !mounted) return;
    // The scanned-place row (supplier_id 0) is now redundant — the dialog
    // added a fresh mission row with a real supplier_id above.
    try {
      await VisitPlannerService.removeFromMission(item.planDetailId);
    } catch (_) {
      // Non-fatal: the mission still has the newly registered supplier.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.name} terdaftar sebagai supplier.')),
    );
    await _load();
  }

  Future<void> _remove(MissionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus dari Mission?'),
        content: Text(
          '${item.supplierName} akan dihapus dari daftar mission hari ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VisitPlannerService.removeFromMission(item.planDetailId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item dihapus dari Mission.')),
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addPoi() async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Tambah Titik (POI)'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nama lokasi *',
              hintText: 'Contoh: Warung Bu Siti',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Pakai lokasi saat ini'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final fix = await GpsService.getCurrentFix();
      final address = await ReverseGeocodingService.resolve(
        fix.latitude,
        fix.longitude,
      );
      final planDetailId = await VisitPlannerService.addPoiToMission(
        name: name,
        latitude: fix.latitude,
        longitude: fix.longitude,
        address: address,
      );
      if (!mounted) return;
      // FR from the 3-Sep-2026 RO meeting: don't leave a new point
      // unregistered — go straight into the Supplier form so the RO can't
      // forget to link it, same as tapping "Daftarkan Supplier" later would.
      final result = await showRegisterSupplierDialog(
        context,
        latitude: fix.latitude,
        longitude: fix.longitude,
        initialName: name,
        initialAddress: address,
      );
      if (result != null && mounted) {
        try {
          await VisitPlannerService.removeFromMission(planDetailId);
        } catch (_) {
          // Non-fatal: the mission still has the newly registered supplier.
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.name} terdaftar sebagai supplier.')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'POI ditambahkan ke Mission. Daftarkan sebagai supplier dari daftar Mission kapan saja.',
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _MissionMapScreen extends StatefulWidget {
  final List<MissionItem> items;
  const _MissionMapScreen({required this.items});

  @override
  State<_MissionMapScreen> createState() => _MissionMapScreenState();
}

class _MissionMapScreenState extends State<_MissionMapScreen> {
  // Halaman ini TANPA inline map: tombol pojok kanan atas langsung membuka
  // Google Maps (external app). Setiap supplier punya tombol WhatsApp +
  // Navigasi direct ke Google Maps.

  static final _actionButtonStyle = TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  /// Buka Google Maps external menuju supplier pertama yang punya koordinat.
  Future<void> _openAllInGoogleMaps() async {
    final first = widget.items
        .where((item) => item.hasCoordinates)
        .toList()
        .firstOrNull;
    if (first == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${first.lat},${first.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _navigateTo(MissionItem item) => launchUrl(
    Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${item.lat},${item.lng}',
    ),
    mode: LaunchMode.externalApplication,
  );

  Future<void> _call(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _whatsApp(MissionItem item) async {
    final message =
        'Halo ${item.supplierName}, saya dari One Link terkait kunjungan hari ini.';
    final launched = await launchUrl(
      Uri.parse(waUrl(item.supplierPhone, text: message)),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp tidak tersedia di perangkat ini.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mappable = widget.items.where((item) => item.hasCoordinates).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Mission'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_outlined),
            tooltip: 'Buka di Google Maps',
            onPressed: mappable.isEmpty ? null : _openAllInGoogleMaps,
          ),
        ],
      ),
      body: mappable.isEmpty
          ? const Center(child: Text('Tidak ada supplier dengan koordinat.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mappable.length,
              itemBuilder: (_, index) => _buildSupplierCard(mappable[index]),
            ),
    );
  }

  Widget _buildSupplierCard(MissionItem item) {
    final statusColor = switch (item.status.toUpperCase()) {
      'VISITED' => AppColors.success,
      'SKIPPED' => AppColors.error,
      'ACTIVE' => AppColors.accentOrange,
      _ => AppColors.info,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.supplierName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.address,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 12,
            children: [
              if (item.supplierPhone.isNotEmpty)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _call(item.supplierPhone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Telepon'),
                ),
              if (item.supplierPhone.isNotEmpty)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _whatsApp(item),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('WhatsApp'),
                ),
              if (item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _navigateTo(item),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Navigasi'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
