import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/visit_sync_service.dart';
import '../login_screen.dart';
import 'mission_today_screen.dart';
import 'scan_prospect_screen.dart';
import 'nearby_supplier_screen.dart';
import 'tasks_screen.dart';
import 'pickup_list_screen.dart';
import 'my_statistic_screen.dart';

/// Hub for the 4 CRM operational modules (PRD §3.1) — Visit Planner is the
/// only one wired to real data so far; the rest are placeholders for the
/// remaining Task Handler tasks.
class CanvassingHomeScreen extends StatefulWidget {
  const CanvassingHomeScreen({super.key});

  @override
  State<CanvassingHomeScreen> createState() => _CanvassingHomeScreenState();
}

class _CanvassingHomeScreenState extends State<CanvassingHomeScreen> {
  int _pendingSyncCount = 0;
  bool _needsLoginToSync = false;

  @override
  void initState() {
    super.initState();
    _restoreCanvassingSession();
  }

  Future<void> _restoreCanvassingSession() async {
    final sessionReady = await GeuAuthService.ensureSession();
    var pending = await VisitSyncService.pendingItems();
    if (sessionReady && pending.isNotEmpty) {
      await VisitSyncService.syncNow();
      pending = await VisitSyncService.pendingItems();
    }
    if (!mounted) return;
    setState(() {
      _pendingSyncCount = pending.length;
      _needsLoginToSync = !sessionReady && pending.isNotEmpty;
    });
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) await _restoreCanvassingSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Canvassing'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_needsLoginToSync) ...[
              _PendingSyncBanner(count: _pendingSyncCount, onLogin: _openLogin),
              const SizedBox(height: 12),
            ],
            _ModuleCard(
              title: 'Supplier Nearby',
              subtitle: 'Cari supplier berdasarkan lokasi atau kota',
              icon: Icons.near_me_outlined,
              color: AppColors.accentOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbySupplierScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Scan Prospek',
              subtitle: 'Riset calon supplier di sekitar Anda',
              icon: Icons.radar_outlined,
              color: AppColors.info,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanProspectScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Mission Hari Ini',
              subtitle: 'Kunjungan supplier — check-in & check-out',
              icon: Icons.map_outlined,
              color: AppColors.primaryGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MissionTodayScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Tasks & Self-Assign',
              subtitle: 'Klaim supplier CRO, RO, atau revisit',
              icon: Icons.checklist_outlined,
              color: AppColors.primaryGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TasksScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Pickup',
              subtitle: 'Daftar dan status pengambilan',
              icon: Icons.local_shipping_outlined,
              color: AppColors.grey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PickupListScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Statistik Saya',
              subtitle: 'KPI assignment dan tren harian',
              icon: Icons.bar_chart_outlined,
              color: AppColors.grey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyStatisticScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature — belum tersedia')));
  }
}

class _PendingSyncBanner extends StatelessWidget {
  final int count;
  final VoidCallback onLogin;

  const _PendingSyncBanner({required this.count, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count data menunggu dikirim. Login untuk mengirim.',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.sync_problem_outlined,
              color: AppColors.accentOrange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count data menunggu dikirim',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Login untuk memulihkan sesi dan mengirim data kunjungan.',
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onLogin,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
