import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/auth_service.dart';
import '../services/user_storage.dart';
import '../services/persistent_auth_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  // Store session_token for resend and verify
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Load initial values from arguments after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      setState(() {
        _sessionToken = args?['session_token'] as String?;
      });
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    if (_canResend) {
      // Get phone number from arguments
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final phoneNumber = args?['phone'] as String?;

      if (phoneNumber == null) return;

      // Call API to request OTP again
      final result = await AuthService.requestOtp(phoneNumber);

      if (result['success'] == true) {
        // Update session_token from new response
        final data = result['data'] ?? {};
        setState(() {
          _sessionToken = data['session_token'] as String?;
        });

        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kode OTP telah dikirim ulang'),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal mengirim ulang OTP'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length == 4) {
      // Get arguments
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final phoneNumber = args?['phone'] as String?;

      if (phoneNumber == null || _sessionToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Terjadi kesalahan. Silakan login kembali.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryGreen),
                const SizedBox(height: 16),
                Text(
                  'Memverifikasi...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Call API to verify OTP with session_token
      final result = await AuthService.verifyOtp(otp, _sessionToken!);

      // Debug: Print the full result structure
      print('OTP Verification Result: ${jsonEncode(result)}');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result['success'] == true) {
        // Save user data and token using PersistentAuthService
        final data = result['data'];

        // Check if we have full user data structure
        if (data['user'] != null && data['auth'] != null) {
          // Full API response with user data
          final userData = data['user'];
          final authData = data['auth'];

          // Save using PersistentAuthService
          await PersistentAuthService.instance.saveLoginData(
            userId: userData['id'].toString(),
            userName: userData['name'] ?? 'User',
            userEmail: userData['email'] ?? '',
            userPhone: userData['phone'] ?? phoneNumber,
            token: authData['token'],
            tokenExpiry: DateTime.now()
                .add(const Duration(days: 7))
                .toIso8601String(),
          );

          // Fallback: Also save to UserStorage for compatibility
          final user = {
            'id': userData['id'],
            'name': userData['name'],
            'email': userData['email'],
            'phone': userData['phone'],
            'company': userData['company'],
            'groups': userData['groups'],
          };
          await UserStorage.saveUser(user: user, token: authData['token']);
        } else {
          // Fallback for simple response (current API)
          final userId = data['user_id']?.toString() ?? '128';
          final userName = data['name'] ?? 'User';
          final token = data['token'] ?? data['session_token'];

          if (token != null) {
            // Save using PersistentAuthService
            await PersistentAuthService.instance.saveLoginData(
              userId: userId,
              userName: userName,
              userEmail: '',
              userPhone: phoneNumber,
              token: token,
              tokenExpiry: DateTime.now()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
            );

            // Fallback: Also save to UserStorage for compatibility
            final user = {'id': userId, 'phone': phoneNumber, 'name': userName};
            await UserStorage.saveUser(user: user, token: token);
          }
        }

        // Navigate to role selection
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/role-selection',
            (route) => false,
          );
        }
      } else {
        // Show error message
        if (mounted) {
          // Clear OTP fields
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Kode OTP salah. Silakan coba lagi.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phoneNumber = args?['phone'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.primaryGreen,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verifikasi OTP',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Masukkan Kode OTP',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kode telah dikirim ke\n$phoneNumber',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onChanged(value, index),
                      onTap: () {
                        _controllers[index].clear();
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tidak menerima kode? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  if (_canResend)
                    GestureDetector(
                      onTap: _resendOtp,
                      child: Text(
                        'Kirim Ulang',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Kirim ulang dalam $_resendTimer detik',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final otp = _controllers.map((c) => c.text).join();
                    if (otp.length == 4) {
                      _verifyOtp();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Mohon masukkan 4 digit kode OTP',
                          ),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Verifikasi', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
