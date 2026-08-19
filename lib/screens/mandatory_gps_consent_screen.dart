import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/location_tracking_service.dart';
import '../services/user_storage.dart';
import '../services/gps_enforcement_service.dart';
import 'privacy_policy_screen.dart';

class MandatoryGpsConsentScreen extends StatefulWidget {
  final String? targetRoute;

  const MandatoryGpsConsentScreen({super.key, this.targetRoute});

  @override
  State<MandatoryGpsConsentScreen> createState() =>
      _MandatoryGpsConsentScreenState();
}

class _MandatoryGpsConsentScreenState extends State<MandatoryGpsConsentScreen> {
  bool _isLoading = false;
  bool _hasReadPolicy = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // App Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 60,
                    color: AppColors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Izin Lokasi Diperlukan',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'Aplikasi One Link memerlukan akses lokasi untuk:',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Features List
                _buildFeatureItem(
                  Icons.navigation,
                  'Navigasi rute pengantaran saat tugas aktif',
                ),
                _buildFeatureItem(
                  Icons.location_searching,
                  'Mencari supplier terdekat',
                ),
                _buildFeatureItem(
                  Icons.verified_user,
                  'Verifikasi kehadiran di lokasi',
                ),
                _buildFeatureItem(
                  Icons.analytics,
                  'Laporan perjalanan dan analisis',
                ),

                const SizedBox(height: 32),

                // Privacy Policy Checkbox
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _hasReadPolicy,
                        onChanged: (value) {
                          setState(() {
                            _hasReadPolicy = value ?? false;
                          });
                        },
                        activeColor: AppColors.primaryGreen,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Saya telah membaca dan menyetujui ',
                                ),
                                TextSpan(
                                  text: 'Kebijakan Privasi',
                                  style: TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' terkait penggunaan data lokasi',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Warning Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Akses lokasi wajib untuk menggunakan aplikasi ini. Tanpa persetujuan, aplikasi tidak dapat berfungsi.',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _hasReadPolicy && !_isLoading
                        ? _grantPermissions
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Berikan Izin Lokasi',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _showExitDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Keluar Aplikasi',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _grantPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request location permissions
      bool hasPermissions = await LocationTrackingService.instance
          .requestPermissions(context);

      if (hasPermissions) {
        // Save consent
        await UserStorage.setLocationTrackingConsent(true);
        await UserStorage.setMandatoryGpsConsentGiven(true);

        // Start tracking automatically (best effort)
        try {
          await LocationTrackingService.instance
              .startTrackingWithoutPermissionCheck();
          GpsEnforcementService.instance.startEnforcement();
        } catch (_) {}

        // Navigate to main app based on role or passed target
        if (mounted) {
          String routeToPush = widget.targetRoute ?? '/dashboard';

          if (widget.targetRoute == null) {
            final user = await UserStorage.getUser();
            if (user != null) {
              final groups = user['groups'] as List<dynamic>?;
              if (groups != null && groups.isNotEmpty) {
                final role = groups.first.toString().toLowerCase();
                if (role.contains('sales') || role.contains('sal')) {
                  routeToPush = '/sales-dashboard';
                } else if (role.contains('drv') || role.contains('driver')) {
                  routeToPush = '/driver-dashboard';
                }
              }
            }
          }

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(routeToPush);
          }
        }
      } else {
        _showPermissionErrorDialog();
      }
    } catch (e) {
      _showPermissionErrorDialog();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Izin Diperlukan',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Aplikasi memerlukan izin lokasi untuk berfungsi. Silakan berikan izin di pengaturan atau coba lagi.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Coba Lagi',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Keluar Aplikasi?',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tanpa izin lokasi, Anda tidak dapat menggunakan aplikasi ini. Yakin ingin keluar?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Batal',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Force close app
              Navigator.of(context).pop();
              // Exit app completely
              Future.delayed(const Duration(milliseconds: 100), () {
                // This will close the app
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/exit', (route) => false);
                }
              });
            },
            child: Text(
              'Keluar',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
