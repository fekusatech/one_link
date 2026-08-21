import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class SharedBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showVisitPlan;
  final bool showTasks;
  final bool showHistory;
  final bool showDriverTools;
  final VoidCallback? onMapTap;

  const SharedBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showVisitPlan = false,
    this.showTasks = false,
    this.showHistory = true,
    this.showDriverTools = false,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        <
          ({
            IconData icon,
            IconData activeIcon,
            String label,
            VoidCallback? action,
          })
        >[
          (
            icon: Icons.grid_view_rounded,
            activeIcon: Icons.grid_view_rounded,
            label: 'Beranda',
            action: null,
          ),
          if (showVisitPlan)
            (
              icon: Icons.map_outlined,
              activeIcon: Icons.map_rounded,
              label: 'Visit',
              action: null,
            ),
          if (showTasks)
            (
              icon: Icons.checklist_outlined,
              activeIcon: Icons.checklist_rounded,
              label: 'Tugas',
              action: null,
            ),
          if (showHistory)
            (
              icon: Icons.history_outlined,
              activeIcon: Icons.history_rounded,
              label: 'Riwayat',
              action: null,
            ),
          if (showDriverTools)
            (
              icon: Icons.map_outlined,
              activeIcon: Icons.map_rounded,
              label: 'Peta',
              action: onMapTap,
            ),
          (
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profil',
            action: null,
          ),
        ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: .1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Navigasi ${item.label}',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: item.action ?? () => onTap(index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGreen.withValues(alpha: .1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? item.activeIcon : item.icon,
                            size: 22,
                            color: selected
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.primaryGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
