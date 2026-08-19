import 'package:flutter/material.dart';
import '../services/persistent_auth_service.dart';
import '../services/mandatory_gps_service.dart';
import '../services/update_service.dart';
import '../services/geu/geu_auth_service.dart';

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

    // 2. Lanjut ke Cek Login secara paralel/setelah delay
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Tunggu minimal 2 detik untuk menampilkan splash screen
    await Future.delayed(const Duration(seconds: 2));

    try {
      final authService = PersistentAuthService.instance;
      final isLoggedIn = await authService.isLoggedIn();

      if (mounted) {
        if (isLoggedIn) {
          // Best-effort, non-blocking: re-open the Canvassing/Visit Planner
          // session using securely cached credentials, since this auto-login
          // path never sees a password to forward.
          GeuAuthService.ensureSession();

          // Check if user needs mandatory GPS consent
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
            // Check if can proceed to main app
            bool canProceed = await MandatoryGpsService.instance
                .canProceedToMain();

            if (canProceed) {
              // User has everything set up, go to main app
              print(
                '🚀 Auto-login successful with GPS consent, navigating to main app',
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
              );
            } else {
              // Something is wrong, force GPS consent again
              print('⚠️ GPS setup invalid, forcing consent screen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MandatoryGpsConsentScreen(),
                ),
              );
            }
          }
        } else {
          // Belum login atau token expired, ke login screen
          print('🔑 No valid login found, navigating to login');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
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
                        'Checking login status...',
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
