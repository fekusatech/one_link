import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/role_management_service.dart';
import '../services/user_storage.dart';
import '../services/impersonation_service.dart';

class SharedAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String dashboardType; // 'driver' or 'sales'
  final VoidCallback? onNotificationTap;

  const SharedAppBar({
    super.key,
    required this.dashboardType,
    this.onNotificationTap,
  });

  @override
  State<SharedAppBar> createState() => _SharedAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SharedAppBarState extends State<SharedAppBar> {
  bool _canSwitchRole = false;

  @override
  void initState() {
    super.initState();
    _checkSwitchPermission();
  }

  Future<void> _checkSwitchPermission() async {
    bool canSwitch = RoleManagementService.isAdmin();

    if (!canSwitch) {
      final user = await UserStorage.getUser();
      if (user != null) {
        final groups = user['groups'] as List<dynamic>? ?? [];
        final roles = user['roles'] as List<dynamic>? ?? [];
        final combined = [...groups, ...roles].map((e) => e.toString().toLowerCase()).join(' ');
        if (combined.contains('admin') ||
            combined.contains('developer') ||
            combined.contains('super')) {
          canSwitch = true;
        }
      }
    }

    if (!canSwitch) {
      canSwitch = await ImpersonationService.canImpersonate();
    }

    if (mounted) {
      setState(() {
        _canSwitchRole = canSwitch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      title: Text(
        'One Link',
        style: AppTextStyles.h4.copyWith(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.primaryGreen,
          onPressed: widget.onNotificationTap,
          tooltip: 'Notifikasi',
        ),

        // Admin switch button (for both dashboards)
        if (_canSwitchRole)
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, size: 28),
            onPressed: () {
              if (widget.dashboardType == 'driver') {
                Navigator.pushReplacementNamed(context, '/sales-dashboard');
              } else {
                Navigator.pushReplacementNamed(context, '/driver-dashboard');
              }
            },
            color: AppColors.primaryGreen,
            tooltip: widget.dashboardType == 'driver'
                ? 'Pindah ke Sales Dashboard'
                : 'Pindah ke Driver Dashboard',
          ),
      ],
    );
  }
}
