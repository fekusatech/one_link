import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/geu/geu_auth_service.dart';

class PermissionGate extends StatelessWidget {
  final String slug;
  final Widget child;

  const PermissionGate({super.key, required this.slug, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeuUser?>(
      future: GeuAuthService.getCachedUser(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }
        if (snap.data?.hasPermission(slug) ?? false) return child;
        return const _AccessDeniedScreen();
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Akses Ditolak',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Anda tidak memiliki izin untuk membuka halaman ini. Hubungi admin bila menurut Anda ini keliru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
