import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/global_debug_utils.dart';
import '../services/role_management_service.dart';
import '../services/mandatory_gps_service.dart';
import '../services/persistent_auth_service.dart';
import '../services/user_storage.dart';
import '../services/update_service.dart';
import 'access_denied_screen.dart';
import 'mandatory_gps_consent_screen.dart';
import 'login_screen.dart';
import '../widgets/force_login_dialog.dart';
import '../widgets/impersonation_banner.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isAnalyzing = true;
  Map<String, dynamic>? _roleAnalysis;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _analyzeUserRole();

    // Trigger real-time app version check for ALL roles as soon as frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.instance.startMonitoring(context);
      }
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
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

          // Auto route untuk driver dan sales
          final route = RoleManagementService.getRouteForRole(roleType);
          if (route != null) {
            await Future.delayed(const Duration(seconds: 1));

            if (mounted) {
              if (roleType == RoleType.sales) {
                Navigator.pushReplacementNamed(context, '/sales-dashboard');
              } else if (roleType == RoleType.driver) {
                Navigator.pushReplacementNamed(context, '/driver-dashboard');
              }
            }
          }
        } else if (roleType == RoleType.denied) {
          await Future.delayed(const Duration(seconds: 1));

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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar dari Akun?'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi OneLink?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await UserStorage.clearUser();
      await PersistentAuthService.instance.clearAuthData();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
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

    if (roleType == RoleType.admin) {
      return _buildRoleSelectionScreen();
    }

    return _buildRedirectScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F382C), Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'OneLink GEU',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.white, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                'Memeriksa hak akses & versi aplikasi...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F382C), Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.white),
                const SizedBox(height: 16),
                Text(
                  'Gagal Menganalisis Akses',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _roleAnalysis?['message'] ?? 'Terjadi kesalahan sistem',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _analyzeUserRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Coba Lagi'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await UserStorage.clearUser();
                    await PersistentAuthService.instance.clearAuthData();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Login Ulang',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
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

  Widget _buildRedirectScreen() {
    final roleType = _roleAnalysis!['roleType'] as RoleType;

    String redirectInfo;
    IconData redirectIcon;

    switch (roleType) {
      case RoleType.driver:
        redirectInfo = 'Mengarahkan ke Dashboard Driver...';
        redirectIcon = Icons.local_shipping;
        break;
      case RoleType.sales:
        redirectInfo = 'Mengarahkan ke Dashboard Sales / CRO...';
        redirectIcon = Icons.business_center;
        break;
      default:
        redirectInfo = 'Memproses...';
        redirectIcon = Icons.hourglass_empty;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F382C), Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  redirectIcon,
                  size: 56,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Selamat Datang, ${RoleManagementService.getUserName()}!',
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
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.white, strokeWidth: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelectionScreen() {
    final userName = RoleManagementService.getUserName();

    return Scaffold(
      floatingActionButton: GlobalDebugUtils.debugFloatingActionButton(context),
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D3326),
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Top Header Row with Logo & Version Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 28,
                                height: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OneLink GEU',
                                  style: AppTextStyles.h5.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Green Energi Utama',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_appVersion.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              _appVersion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // User Profile Chip Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white,
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Administrator',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout_rounded, color: Colors.white),
                            tooltip: 'Keluar / Logout',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PILIH PERAN KERJA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Role Card 1: Driver
                    _buildModernRoleCard(
                      context: context,
                      title: 'Driver Operasional',
                      subtitle: 'Penjemputan Armada & Surat Jalan',
                      badges: ['Navigasi GPS', 'Settlement Uang Jalan', 'Milestone Fleet'],
                      icon: Icons.local_shipping_rounded,
                      route: '/dashboard',
                      gradientColors: [Colors.white, const Color(0xFFF4F9F6)],
                      textColor: const Color(0xFF1B5E20),
                      accentColor: AppColors.primaryGreen,
                    ),

                    const SizedBox(height: 16),

                    // Role Card 2: CRO / Sales
                    _buildModernRoleCard(
                      context: context,
                      title: 'CRO / RO Sales',
                      subtitle: 'Manajemen Supplier & Penjualan',
                      badges: ['Kelola Supplier', 'Riwayat Kunjungan', 'Klaim & Komisi'],
                      icon: Icons.business_center_rounded,
                      route: '/sales-dashboard',
                      gradientColors: [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
                      textColor: const Color(0xFFB71C1C),
                      accentColor: Colors.deepOrange.shade800,
                    ),

                    const SizedBox(height: 28),

                    // Admin Suite Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Admin Kelola Akses',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Switch / Force Login ke akun driver lain',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const ForceLoginDialog(),
                                );
                              },
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text(
                                'Pindah Akun (Force Login)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade800,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Dedicated Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Keluar / Logout Akun',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                          backgroundColor: Colors.red.shade900.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Green Energi Utama © 2026',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          const ImpersonationFloatingBanner(),
        ],
      ),
    );
  }

  Widget _buildModernRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<String> badges,
    required IconData icon,
    required String route,
    required List<Color> gradientColors,
    required Color textColor,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () async {
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
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h5.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Feature Badges Wrap
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: badges.map((b) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        b,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
