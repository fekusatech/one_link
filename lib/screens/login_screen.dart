import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../config/app_config.dart';
import '../services/persistent_auth_service.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/geu/device_lock_request_service.dart';
import '../services/auth_debug_service.dart';
import '../services/geu/nfc_recovery_service.dart';

// Google's official multi-color "G" mark (Sign-In branding guidelines) -
// Icons.g_mobiledata is Material's generic "g" glyph, not recognizable as
// Google, so this is inlined instead of bundling a logo asset.
const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">
  <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z"/>
  <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z"/>
  <path fill="#FBBC05" d="M3.964 10.71c-.18-.54-.282-1.117-.282-1.71s.102-1.17.282-1.71V4.958H.957C.347 6.173 0 7.548 0 9s.348 2.827.957 4.042l3.007-2.332z"/>
  <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 5.482 0 2.438 2.017.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z"/>
</svg>
''';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _appLinks = AppLinks();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isNfcLoading = false;
  bool _isNfcListening = false;
  bool _isNfcSessionStarting = false;
  bool _reportedNfcScanError = false;
  bool _obscurePassword = true;
  StreamSubscription<Uri>? _ssoLinkSubscription;
  final Set<String> _handledSsoCodes = {};
  final Set<String> _attemptedNfcCardIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_listenForSsoCallback());
    unawaited(_startLoginNfcListener());
    // Update check hanya dilakukan di dashboard setelah login berhasil
    // Tidak perlu cek di sini karena belum ada token
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopLoginNfcListener());
    _ssoLinkSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startLoginNfcListener());
    } else {
      unawaited(_stopLoginNfcListener());
    }
  }

  Future<void> _startLoginNfcListener() async {
    if (!mounted || _isNfcListening || _isNfcSessionStarting) return;
    _isNfcSessionStarting = true;
    try {
      await NfcRecoveryService.startRecoveryListener(
        onCard: _handleNfcCard,
        onError: _handleNfcScanError,
      );
      if (!mounted) {
        await NfcRecoveryService.stopRecoveryListener();
        return;
      }
      _isNfcListening = true;
    } catch (error) {
      debugPrint('[NFC_RECOVERY] login listener unavailable error=$error');
    } finally {
      _isNfcSessionStarting = false;
    }
  }

  Future<void> _stopLoginNfcListener() async {
    if (!_isNfcListening) return;
    _isNfcListening = false;
    try {
      await NfcRecoveryService.stopRecoveryListener();
    } catch (error) {
      debugPrint('[NFC_RECOVERY] login listener stop error=$error');
    }
  }

  void _handleNfcScanError(Object error) {
    if (!mounted) return;
    // A tag can advertise NDEF while Android still fails to connect to it
    // (for example an unformatted or unsupported card). Keep the reader
    // session alive so the user can scan the recovery card after that.
    if (_reportedNfcScanError) return;
    _reportedNfcScanError = true;
    final raw = error.toString().toLowerCase();
    final message =
        raw.contains('ioexception') ||
            raw.contains('platformexception') ||
            raw.contains('basic tag technology') ||
            raw.contains('ndef.connect')
        ? 'Kartu NFC tidak bisa dibaca. Pastikan kartu pemulihan sudah ditulis, lalu tempelkan kembali.'
        : 'Kartu NFC tidak terbaca. Gunakan kartu pemulihan One Link yang sudah ditulis.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleNfcCard(Map<String, String> card) async {
    if (!mounted || _isLoading || _isGoogleLoading || _isNfcLoading) return;
    _reportedNfcScanError = false;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      unawaited(_stopLoginNfcListener());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Isi email dan password, lalu tempelkan kartu NFC kembali.',
          ),
        ),
      );
      return;
    }

    final cardId = card['card_id']!;
    if (!_attemptedNfcCardIds.add(cardId)) return;
    setState(() => _isNfcLoading = true);
    try {
      await NfcRecoveryService.recover(
        email: email,
        password: password,
        cardId: cardId,
        token: card['token']!,
      );
      if (!mounted) return;
      await _stopLoginNfcListener();
      setState(() => _isNfcLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kartu valid. Device lock terbuka, login dilanjutkan.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _handleLogin();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isNfcLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onCredentialChanged(String _) {
    _attemptedNfcCardIds.clear();
    _reportedNfcScanError = false;
    unawaited(_startLoginNfcListener());
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
      // loginWithSsoCode exchanges the one-time code for a fresh Go access
      // token and persists both UserStorage and PersistentAuthService. Do not
      // overwrite that token here: the former callback saved an empty token,
      // which made the Sales dashboard immediately receive HTTP 401.
      await GeuAuthService.loginWithSsoCode(code);

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
      // inAppBrowserView opens Chrome Custom Tabs (Android) / SFSafariViewController
      // (iOS) — a browser overlay that slides up over the app instead of
      // switching to a separate Chrome window, while staying a real system
      // browser context. Google's OAuth screen actively blocks plain
      // embedded WebViews ("This browser or app may not be secure") since
      // 2016, so a true in-app WebView isn't an option here — this is the
      // closest compliant equivalent.
      final opened = await launchUrl(
        _googleLoginUri,
        mode: LaunchMode.inAppBrowserView,
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

  /// Backend/network exceptions land here as raw English/technical text
  /// (e.g. "Exception: Invalid credentials", a Dio timeout dump) — map the
  /// ones we actually expect to plain Indonesian, and fall back to a single
  /// generic line for anything else rather than showing that to a driver.
  String _friendlyLoginError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').toLowerCase();

    if (raw.contains('invalid credentials')) {
      return 'Email atau password salah. Silakan periksa kembali.';
    }
    if (raw.contains('perangkat ini sedang dipakai akun lain') ||
        raw.contains('akun sedang aktif di perangkat lain')) {
      // Preserve the API's device-lock message, including its unlock time
      // and remaining duration. The generic fallback below used to hide it.
      return e.toString().replaceFirst('Exception: ', '');
    }
    if (raw.contains('account is banned') || raw.contains('banned')) {
      return 'Akun Anda dinonaktifkan. Hubungi admin untuk bantuan.';
    }
    if (raw.contains('tidak ada koneksi') ||
        raw.contains('connection') ||
        raw.contains('socketexception')) {
      return 'Tidak ada koneksi internet. Periksa jaringan Anda dan coba lagi.';
    }
    if (raw.contains('timeout')) {
      return 'Koneksi ke server terlalu lama. Silakan coba lagi.';
    }
    if (raw.contains('sesi login telah berakhir')) {
      return 'Sesi telah berakhir. Silakan masuk kembali.';
    }
    if (raw.contains('endpoint not found') || raw.contains('404')) {
      return 'Server sedang bermasalah. Silakan coba beberapa saat lagi.';
    }
    return 'Gagal masuk. Silakan periksa email/password Anda dan coba lagi.';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // AuthService.loginWithEmail() posted to {serverDomain}/api/login — a
      // legacy PHP path. apipi.greenenergiutama.co.id now routes to the Go
      // API only (see refactor(api) commit enforcing that domain for it);
      // /api/login 404s there. GeuAuthService.login() hits the real,
      // working POST /api-auth/login and already persists UserStorage
      // (id/name/email/groups/roles) + the httpOnly session cookie itself
      // — no need to hand-build a user map from a response shape anymore.
      final user = await GeuAuthService.login(email, password);

      if (!mounted) return;

      // Remove the obsolete debug file as a further safeguard for older
      // builds that previously used it to decide roles.
      await AuthDebugService.clearAuthFile();

      // PersistentAuthService only gates the app's local "already logged
      // in, skip the login screen" check at startup (isLoggedIn() just
      // checks token != null, not that it's non-empty) — the real session
      // lives in GeuApiClient's persisted cookie jar, established above.
      await PersistentAuthService.instance.saveLoginData(
        token: '',
        userId: user.id.toString(),
        userName: user.name,
        userPhone: '',
        userEmail: user.email,
        tokenExpiry: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/role-selection',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is DeviceLockConflictException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyLoginError(e)),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Ajukan Akses',
              onPressed: () => _showRequestAccessSheet(e.conflictToken),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyLoginError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Opens a bottom sheet collecting a reason and submitting the
  /// device-lock access request tied to [conflictToken] (from
  /// [DeviceLockConflictException]).
  void _showRequestAccessSheet(String conflictToken) {
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              setSheetState(() {
                isSubmitting = true;
                errorMessage = null;
              });
              try {
                await DeviceLockRequestService.submit(
                  conflictToken,
                  reasonController.text.trim(),
                );
                // Sheet may already be gone if the user swiped it away while
                // the request was in flight — it still fires, so fall back
                // to the login screen's own context/mounted check to make
                // sure the confirmation isn't silently dropped.
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pengajuan terkirim, menunggu persetujuan admin.',
                    ),
                  ),
                );
              } catch (e) {
                final message = e.toString().replaceFirst('Exception: ', '');
                if (sheetContext.mounted) {
                  // The sheet is still open: a SnackBar here can render
                  // underneath a tall/full-height modal sheet, so show the
                  // error inline in the sheet instead where it's guaranteed
                  // visible.
                  setSheetState(() => errorMessage = message);
                } else if (mounted) {
                  // Sheet already dismissed (e.g. swiped away mid-submit) —
                  // no sheet left to show an inline error in, so fall back
                  // to the login screen's own SnackBar.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ajukan Akses Perangkat',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jelaskan alasan Anda ingin menggunakan perangkat ini. Admin akan meninjau pengajuan ini.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 4,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Alasan',
                      hintText: 'Masukkan alasan pengajuan akses',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (isSubmitting || reasonController.text.trim().isEmpty)
                              ? null
                              : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Kirim Pengajuan', style: AppTextStyles.button),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(reasonController.dispose);
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
                          onChanged: _onCredentialChanged,
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
                          onChanged: _onCredentialChanged,
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

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isNfcLoading
                          ? 'Memvalidasi kartu NFC dan membuka device lock…'
                          : '',
                      style: AppTextStyles.caption.copyWith(
                        color: _isNfcLoading
                            ? AppColors.primaryGreen
                            : AppColors.grey,
                      ),
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

                  // const SizedBox(height: 16),

                  // // Divider "Atau"
                  // Row(
                  //   children: [
                  //     const Expanded(
                  //       child: Divider(color: AppColors.lightGrey),
                  //     ),
                  //     Padding(
                  //       padding: const EdgeInsets.symmetric(horizontal: 16),
                  //       child: Text(
                  //         'Atau masuk dengan',
                  //         style: AppTextStyles.caption.copyWith(
                  //           color: AppColors.grey,
                  //         ),
                  //       ),
                  //     ),
                  //     const Expanded(
                  //       child: Divider(color: AppColors.lightGrey),
                  //     ),
                  //   ],
                  // ),

                  // const SizedBox(height: 16),

                  // Tombol Google Login
                  // SizedBox(
                  //   width: double.infinity,
                  //   height: 56,
                  //   child: OutlinedButton(
                  //     onPressed: (_isLoading || _isGoogleLoading)
                  //         ? null
                  //         : _startGoogleLogin,
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: AppColors.borderColor),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(16),
                  //       ),
                  //     ),
                  //     child: _isGoogleLoading
                  //         ? const SizedBox(
                  //             width: 24,
                  //             height: 24,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               color: AppColors.primaryGreen,
                  //             ),
                  //           )
                  //         : Row(
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               SvgPicture.string(
                  //                 _googleLogoSvg,
                  //                 width: 22,
                  //                 height: 22,
                  //               ),
                  //               const SizedBox(width: 12),
                  //               Text(
                  //                 'Masuk dengan Google',
                  //                 style: AppTextStyles.button.copyWith(
                  //                   color: AppColors.textPrimary,
                  //                   fontWeight: FontWeight.w600,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //   ),
                  // ),
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
