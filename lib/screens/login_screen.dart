import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/user_storage.dart';
import '../services/persistent_auth_service.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/auth_debug_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _appLinks = AppLinks();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  StreamSubscription<Uri>? _ssoLinkSubscription;
  final Set<String> _handledSsoCodes = {};


  @override
  void initState() {
    super.initState();
    unawaited(_listenForSsoCallback());
    // Update check hanya dilakukan di dashboard setelah login berhasil
    // Tidak perlu cek di sini karena belum ada token
  }

  @override
  void dispose() {
    _ssoLinkSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _listenForSsoCallback() async {
    _ssoLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleSsoCallback,
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan login tidak dapat dibuka.')),
        );
      },
    );

    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) await _handleSsoCallback(initialLink);
  }

  Future<void> _handleSsoCallback(Uri uri) async {
    if (uri.scheme != 'onelink' ||
        uri.host != 'auth' ||
        uri.path != '/callback') {
      return;
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty || !_handledSsoCodes.add(code)) return;

    if (mounted) setState(() => _isGoogleLoading = true);
    try {
      final geuUser = await GeuAuthService.loginWithSsoCode(code);

      final userMap = {
        'id': geuUser.id,
        'name': geuUser.name,
        'email': geuUser.email,
        'phone': '',
        'groups': geuUser.roles,
        'roles': geuUser.roles,
      };

      await UserStorage.saveUser(user: userMap, token: '');
      await PersistentAuthService.instance.saveLoginData(
        token: '',
        userId: geuUser.id.toString(),
        userName: geuUser.name,
        userPhone: '',
        userEmail: geuUser.email,
        tokenExpiry: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/role-selection',
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  static final Uri _googleLoginUri = Uri.https(
    'login.greenenergiutama.co.id',
    '/api/auth/google/start',
    {'app_redirect': 'onelink://auth/callback'},
  );

  Future<void> _startGoogleLogin() async {
    if (_isLoading || _isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      final opened = await launchUrl(
        _googleLoginUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Browser tidak tersedia untuk melanjutkan login Google.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai login Google: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _silentGeuLogin(String email, String password) async {
    try {
      await GeuAuthService.login(email, password);
    } catch (_) {
      // ignored — Canvassing/Visit Planner screens handle a missing session
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await AuthService.loginWithEmail(email, password);

      if (!mounted) return;

      if (response['success'] == true) {
        // Handle successful login
        if (response['data'] != null) {
          final data = response['data'];

          final rawUser = data['user'] ?? data;
          final userMap = Map<String, dynamic>.from(rawUser as Map);
          // Some ERP login responses place groups beside `user`; preserve
          // them in the canonical profile used by RoleSelectionScreen.
          if (userMap['groups'] == null && data['groups'] is List) {
            userMap['groups'] = data['groups'];
          }
          if (userMap['groups'] == null && data['roles'] is List) {
            userMap['groups'] = data['roles'];
          }
          final authMap = data['auth'] ?? {};

          final token =
              authMap['token'] ?? data['token'] ?? data['session_token'] ?? '';
          final expiry =
              authMap['expires_at'] ??
              DateTime.now().add(const Duration(days: 30)).toIso8601String();

          await UserStorage.saveUser(user: userMap, token: token);
          // Remove the obsolete debug file as a further safeguard for older
          // builds that previously used it to decide roles.
          await AuthDebugService.clearAuthFile();
          await PersistentAuthService.instance.saveLoginData(
            token: token,
            userId: userMap['id']?.toString() ?? '',
            userName: userMap['name']?.toString() ?? '',
            userPhone: userMap['phone']?.toString() ?? '',
            userEmail: userMap['email']?.toString() ?? '',
            tokenExpiry: expiry,
          );

          // Best-effort: same credentials also unlock Canvassing/Visit
          // Planner (separate backend, see doc.md) — never blocks login,
          // never surfaces its own error; those screens just won't have
          // data if this silently fails.
          // Wait until Canvassing has replaced its persisted cookie/profile;
          // navigating first could briefly show the prior user's data.
          await _silentGeuLogin(email, password);
        }

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/role-selection',
          (route) => false,
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Login gagal'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Logo section
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppConfig.appName,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Silakan masuk dengan Email dan Password',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Form section
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Masukkan email Anda',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.primaryGreen,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            if (!value.contains('@')) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Masukkan password Anda',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.primaryGreen,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Masuk', style: AppTextStyles.button),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider "Atau"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.lightGrey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Atau masuk dengan',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.lightGrey)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tombol Google Login
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: (_isLoading || _isGoogleLoading) ? null : _startGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.g_mobiledata,
                                  size: 32,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Masuk dengan Google',
                                  style: AppTextStyles.button.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Spacer(),

                  // Footer text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
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
        ),
      ),
    );
  }
}
