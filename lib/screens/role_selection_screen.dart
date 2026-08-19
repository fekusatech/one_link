import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/global_debug_utils.dart';
import '../services/role_management_service.dart';
import '../services/mandatory_gps_service.dart';
import 'access_denied_screen.dart';
import 'mandatory_gps_consent_screen.dart';

import '../services/update_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isAnalyzing = true;
  Map<String, dynamic>? _roleAnalysis;

  @override
  void initState() {
    super.initState();
    // Update check hanya dilakukan di dashboard setelah login berhasil
    _analyzeUserRole();
  }

  Future<void> _analyzeUserRole() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final roleAnalysis = await RoleManagementService.analyzeUserRole();

      setState(() {
        _roleAnalysis = roleAnalysis;
        _isAnalyzing = false;
      });

      // Handle auto-routing
      if (roleAnalysis['success'] == true && mounted) {
        final roleType = roleAnalysis['roleType'] as RoleType;

        if (roleAnalysis['autoRoute'] == true) {
          // Check GPS consent before proceeding to main screens
          bool needsGpsConsent = await MandatoryGpsService.instance
              .needsMandatoryGpsConsent();

          if (needsGpsConsent) {
            // Redirect to mandatory GPS consent
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MandatoryGpsConsentScreen(),
                ),
              );
            }
            return;
          }

          // Auto route untuk driver dan sales (after GPS consent is confirmed)
          final route = RoleManagementService.getRouteForRole(roleType);
          if (route != null) {
            // Delay sedikit untuk user melihat loading
            await Future.delayed(const Duration(seconds: 2));

            if (mounted) {
              if (roleType == RoleType.sales) {
                // Navigate to sales dashboard
                Navigator.pushReplacementNamed(context, '/sales-dashboard');
              } else if (roleType == RoleType.driver) {
                // Navigate to driver dashboard (jika ada)
                Navigator.pushReplacementNamed(context, '/driver-dashboard');
              }
            }
          }
        } else if (roleType == RoleType.denied) {
          // Show access denied screen
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AccessDeniedScreen(
                  message: roleAnalysis['message'],
                  userRoles: List<String>.from(roleAnalysis['userRoles'] ?? []),
                ),
              ),
            );
          }
        }
        // Untuk admin (roleType.admin), tetap di role selection screen
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _roleAnalysis = {
          'success': false,
          'message': 'Error analyzing roles: $e',
          'roleType': RoleType.denied,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return _buildLoadingScreen();
    }

    if (_roleAnalysis == null || _roleAnalysis!['success'] != true) {
      return _buildErrorScreen();
    }

    final roleType = _roleAnalysis!['roleType'] as RoleType;

    // Untuk admin role, tampilkan role selection
    if (roleType == RoleType.admin) {
      return _buildRoleSelectionScreen();
    }

    // Untuk role lain, tampilkan loading dengan info redirect
    return _buildRedirectScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
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
            const SizedBox(height: 32),

            CircularProgressIndicator(color: AppColors.white, strokeWidth: 3),
            const SizedBox(height: 16),

            Text(
              'Analyzing user roles...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.white),
              const SizedBox(height: 16),

              Text(
                'Role Analysis Failed',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _roleAnalysis?['message'] ?? 'Unknown error occurred',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _analyzeUserRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedirectScreen() {
    final roleType = _roleAnalysis!['roleType'] as RoleType;
    final message = _roleAnalysis!['message'] as String;

    String redirectInfo;
    IconData redirectIcon;

    switch (roleType) {
      case RoleType.driver:
        redirectInfo = 'Redirecting to Driver Dashboard...';
        redirectIcon = Icons.local_shipping;
        break;
      case RoleType.sales:
        redirectInfo = 'Redirecting to Sales Dashboard...';
        redirectIcon = Icons.business_center;
        break;
      default:
        redirectInfo = 'Processing...';
        redirectIcon = Icons.hourglass_empty;
    }

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Role Icon
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
              child: Icon(
                redirectIcon,
                size: 60,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Welcome ${RoleManagementService.getUserName()}!',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              redirectInfo,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            CircularProgressIndicator(color: AppColors.white, strokeWidth: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectionScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      floatingActionButton: GlobalDebugUtils.debugFloatingActionButton(context),
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

                // User welcome message
                Text(
                  'Welcome ${RoleManagementService.getUserName()}!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

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
      onTap: () async {
        // Check GPS consent before navigating to any main screen
        bool needsGpsConsent = await MandatoryGpsService.instance
            .needsMandatoryGpsConsent();

        if (needsGpsConsent && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MandatoryGpsConsentScreen(targetRoute: route),
            ),
          );
        } else if (mounted) {
          Navigator.pushReplacementNamed(context, route);
        }
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
