import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import 'mission_today_screen.dart';

/// Hub for the 4 CRM operational modules (PRD §3.1) — Visit Planner is the
/// only one wired to real data so far; the rest are placeholders for the
/// remaining Task Handler tasks.
class CanvassingHomeScreen extends StatelessWidget {
  const CanvassingHomeScreen({super.key});

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
              subtitle: 'Segera hadir',
              icon: Icons.checklist_outlined,
              color: AppColors.grey,
              onTap: () => _showComingSoon(context, 'Tasks & Self-Assign'),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Pickup',
              subtitle: 'Segera hadir',
              icon: Icons.local_shipping_outlined,
              color: AppColors.grey,
              onTap: () => _showComingSoon(context, 'Pickup'),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              title: 'Statistik Saya',
              subtitle: 'Segera hadir',
              icon: Icons.bar_chart_outlined,
              color: AppColors.grey,
              onTap: () => _showComingSoon(context, 'Statistik Saya'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — belum tersedia')),
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
                    Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
