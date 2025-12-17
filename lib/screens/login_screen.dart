import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../config/app_config.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo section
              Column(
                children: [
                  // Placeholder for logo image
                  // TODO: Replace with actual logo asset
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.link,
                      size: 64,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 'One Link' text
                  Text(
                    AppConfig.appName,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Phone Input
                    Navigator.pushNamed(context, '/phone-input');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Masuk', style: AppTextStyles.button),
                ),
              ),

              // const SizedBox(height: 16),

              // // Forgot password button
              // TextButton(
              //   onPressed: () {
              //     // TODO: Implement forgot password logic
              //   },
              //   child: Text(
              //     'Lupa Sandi?',
              //     style: AppTextStyles.bodyMedium.copyWith(
              //       color: AppColors.accentOrange,
              //       fontWeight: FontWeight.w500,
              //     ),
              //   ),
              // ),
              const Spacer(flex: 3),

              // Footer text
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  AppConfig.formattedVersion,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
