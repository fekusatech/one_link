import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo and Title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'OneLink',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  'Sistem Manajemen Minyak Jelantah',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'Pilih peran Anda untuk melanjutkan',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Role Cards
                _buildRoleCard(
                  context: context,
                  title: 'Driver',
                  subtitle: 'Kelola penjemputan minyak jelantah',
                  description:
                      '• Navigasi GPS untuk penjemputan\n• Proses pickup dan dokumentasi\n• Tracking volume dan performa',
                  icon: Icons.local_shipping,
                  route: '/dashboard',
                  color: AppColors.white,
                  textColor: AppColors.primaryGreen,
                ),

                const SizedBox(height: 20),

                _buildRoleCard(
                  context: context,
                  title: 'CRO/RO Sales',
                  subtitle: 'Kelola supplier dan penjualan',
                  description:
                      '• Tambah dan kelola supplier\n• Monitor performa sales\n• Analisis data dan laporan',
                  icon: Icons.business_center,
                  route: '/sales-dashboard',
                  color: AppColors.accentOrange,
                  textColor: AppColors.white,
                ),

                const SizedBox(height: 30),

                // Footer
                Text(
                  'Green Energi Utama © 2025',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required String route,
    required Color color,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacementNamed(context, route);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: textColor),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: AppTextStyles.h5.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              description,
              style: AppTextStyles.caption.copyWith(
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: textColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
