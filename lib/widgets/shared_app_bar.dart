import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/role_management_service.dart';
import '../screens/qr_scanner_screen.dart';
import '../services/persistent_auth_service.dart';

class SharedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String dashboardType; // 'driver' or 'sales'
  final VoidCallback? onQRResult;
  final VoidCallback? onNotificationTap;

  const SharedAppBar({
    super.key,
    required this.dashboardType,
    this.onQRResult,
    this.onNotificationTap,
  });

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
        // QR Scanner button (only for driver dashboard)
        if (dashboardType == 'driver')
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );

              if (result != null && onQRResult != null) {
                onQRResult!();
              }
            },
            color: AppColors.primaryGreen,
          ),

        // Notification button (only for sales dashboard)
        if (dashboardType == 'sales')
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.primaryGreen,
            onPressed: onNotificationTap,
          ),

        // Admin switch button (for both dashboards)
        if (RoleManagementService.isAdmin())
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              if (dashboardType == 'driver') {
                Navigator.pushReplacementNamed(context, '/sales-dashboard');
              } else {
                Navigator.pushReplacementNamed(context, '/driver-dashboard');
              }
            },
            color: AppColors.primaryGreen,
            tooltip: dashboardType == 'driver'
                ? 'Switch to Sales Dashboard'
                : 'Switch to Driver Dashboard',
          ),

        // Menu button (only for driver dashboard)
        if (dashboardType == 'driver')
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            iconColor: AppColors.primaryGreen,
            onSelected: (value) async {
              if (value == 'logout') {
                _showLogoutDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await PersistentAuthService.instance.clearAuthData();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
