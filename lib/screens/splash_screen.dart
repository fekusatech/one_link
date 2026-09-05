import 'dart:async';
import 'package:flutter/material.dart';
import '../services/persistent_auth_service.dart';
import '../services/mandatory_gps_service.dart';
import '../services/update_service.dart';
import '../services/device_security_service.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/geu/active_visit_service.dart';
import '../services/geu/visit_sync_service.dart';
import '../services/geu/push_notification_service.dart';

import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'mandatory_gps_consent_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _loadingStatus = 'Menyiapkan aplikasi...';

  void _setLoadingStatus(String status) {
    if (mounted) setState(() => _loadingStatus = status);
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    // Reset update service flag untuk app session baru
    UpdateService.instance.resetForNewLoad();

    // Root/fake-GPS scan runs in the background here so the result is
    // already cached (DeviceSecurityService.lastResult) by the time the
    // user opens Diagnosa Sistem - fire-and-forget, must never delay login.
    DeviceSecurityService.check();

    // 2. Lanjut ke Cek Login secara paralel/setelah delay
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Tunggu minimal 2 detik untuk menampilkan splash screen
    _setLoadingStatus('Menyiapkan layanan aplikasi...');
    await Future.delayed(const Duration(seconds: 2));

    try {
      _setLoadingStatus('Mengecek sesi login...');
      final authService = PersistentAuthService.instance;
      final isLoggedIn = await authService.isLoggedIn();

      if (mounted) {
        if (isLoggedIn) {
          _setLoadingStatus('Mengamankan sesi akun...');
          // Best-effort, non-blocking: re-open the Canvassing/Visit Planner
          // session using securely cached credentials, since this auto-login
          // path never sees a password to forward.
          final geuSessionReady = await GeuAuthService.ensureSession();
          _setLoadingStatus('Memulihkan kunjungan aktif...');
          await ActiveVisitService.restore();
          if (geuSessionReady) {
            _setLoadingStatus('Menyinkronkan data terbaru...');
            await VisitSyncService.syncNow();
            // Re-register here too, not just on a fresh password login — an
            // app reinstall or a token FCM silently rotated before the
            // previous session ended would otherwise never get a token on
            // file until the user explicitly logs out and back in.
            unawaited(PushNotificationService.registerToken());
          }

          // Check if user needs mandatory GPS consent
          _setLoadingStatus('Mengecek izin lokasi dan GPS...');
          bool needsGpsConsent = await MandatoryGpsService.instance
              .needsMandatoryGpsConsent();

          if (needsGpsConsent) {
            // User logged in but hasn't given GPS consent - mandatory screen
            print(
              '🔒 User logged in but needs GPS consent, navigating to consent screen',
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MandatoryGpsConsentScreen(),
              ),
            );
          } else {
            // Auto-login successful, navigate straight to main app
            _setLoadingStatus('Menyiapkan dashboard...');
            print('🚀 Auto-login successful, navigating to main app');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
            );
          }
        } else {
          // Belum login atau token expired, ke login screen
          _setLoadingStatus('Sesi belum ditemukan, membuka login...');
          print('🔑 No valid login found, navigating to login');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      _setLoadingStatus('Terjadi kendala, membuka halaman login...');
      print('❌ Error during auto-login check: $e');
      // Jika ada error, arahkan ke login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreen.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Nama aplikasi
                      Text(
                        'One Link - GEU',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Green Energi Utama',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white.withOpacity(0.8),
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Loading indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white.withOpacity(0.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        _loadingStatus,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withOpacity(0.7),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Version info
                      Text(
                        AppConfig.formattedVersion,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
