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
import '../../widgets/permission_gate.dart';

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SALES FIELD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.accentOrange,
              ),
            ),
            Text(
              'Canvassing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryGreen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildFieldHero(),
            const SizedBox(height: 20),
            if (_needsLoginToSync) ...[
              _PendingSyncBanner(count: _pendingSyncCount, onLogin: _openLogin),
              const SizedBox(height: 20),
            ],
            Text(
              'Prioritas lapangan',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Mulai dari rute kunjungan, lalu lanjutkan tindak lanjut supplier.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _ModuleCard(
              title: 'Mission hari ini',
              subtitle: 'Rute kunjungan, check-in, dan check-out Anda.',
              icon: Icons.route_rounded,
              color: AppColors.primaryGreen,
              featured: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MissionTodayScreen()),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Jelajahi pekerjaan',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
              children: [
                _FieldActionCard(
                  title: 'Supplier nearby',
                  subtitle: 'Cari lokasi',
                  icon: Icons.near_me_outlined,
                  color: AppColors.accentOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PermissionGate(
                        slug: 'crm-read-visit-planner',
                        child: NearbySupplierScreen(),
                      ),
                    ),
                  ),
                ),
                _FieldActionCard(
                  title: 'Scan prospek',
                  subtitle: 'Riset peluang',
                  icon: Icons.radar_outlined,
                  color: AppColors.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PermissionGate(
                        slug: 'crm-read-visit-planner',
                        child: ScanProspectScreen(),
                      ),
                    ),
                  ),
                ),
                _FieldActionCard(
                  title: 'Tugas & klaim',
                  subtitle: 'Follow-up',
                  icon: Icons.checklist_outlined,
                  color: AppColors.primaryGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TasksScreen()),
                  ),
                ),
                _FieldActionCard(
                  title: 'Pickup',
                  subtitle: 'Status angkut',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.textSecondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PermissionGate(
                        slug: 'crm-read-pickup',
                        child: PickupListScreen(),
                      ),
                    ),
                  ),
                ),
                _FieldActionCard(
                  title: 'Statistik saya',
                  subtitle: 'KPI & tren',
                  icon: Icons.insights_outlined,
                  color: AppColors.primaryGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyStatisticScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldHero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGreen.withValues(alpha: .22),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siap bergerak?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Semua aktivitas lapangan dalam satu ruang kerja.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Icon(Icons.explore_rounded, color: AppColors.accentOrange, size: 46),
      ],
    ),
  );
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
  final bool featured;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: featured ? AppColors.primaryGreen : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: featured ? AppColors.primaryGreen : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: featured
                      ? AppColors.white.withValues(alpha: .14)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: featured ? AppColors.accentOrange : color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: featured
                            ? AppColors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: featured
                            ? AppColors.white.withValues(alpha: .75)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: featured ? AppColors.white : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FieldActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: .16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
