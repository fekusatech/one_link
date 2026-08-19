import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/visit_planner_service.dart';
import 'checkin_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mission Hari Ini'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mission == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null && _mission == null) {
      return _buildError();
    }
    final mission = _mission!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(_error ?? 'Gagal memuat data', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
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
          const Icon(Icons.event_available, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('Belum ada mission hari ini', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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
            child: Text('Data per $formatted (offline)', style: AppTextStyles.caption),
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
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
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
                  style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.address, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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
              if (item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _navigate(item.lat!, item.lng!),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Navigasi'),
                ),
              if (item.status.toUpperCase() != 'VISITED' && item.hasCoordinates)
                TextButton.icon(
                  style: _actionButtonStyle,
                  onPressed: () => _checkin(item),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Check-in'),
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
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
  }

  Future<void> _checkin(MissionItem item) async {
    final draft = await showCheckinDialog(context, item);
    if (draft == null || !mounted) return;
    // Submission to POST /api/visits/checkin (with photo + Idempotency-Key)
    // is the sync-engine task — this just confirms the gate passed.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      'Siap check-in (${(draft.distanceKm * 1000).round()}m'
      '${draft.confirmFar ? ", confirm_far" : ""}) — menunggu foto & submit.',
    )));
  }
}
