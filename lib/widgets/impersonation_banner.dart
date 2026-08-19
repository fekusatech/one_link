import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/impersonation_service.dart';
import '../services/user_storage.dart';

class ImpersonationFloatingBanner extends StatefulWidget {
  const ImpersonationFloatingBanner({super.key});

  @override
  State<ImpersonationFloatingBanner> createState() => _ImpersonationFloatingBannerState();
}

class _ImpersonationFloatingBannerState extends State<ImpersonationFloatingBanner> {
  bool _isImpersonating = false;
  String _targetUserName = '';
  String _adminName = '';
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final active = await ImpersonationService.isImpersonating();
    if (mounted) {
      if (active) {
        final user = await UserStorage.getUser();
        final admin = await ImpersonationService.getOriginalAdmin();
        setState(() {
          _isImpersonating = true;
          _targetUserName = user?['name'] ?? 'User';
          _adminName = admin?['name'] ?? 'Admin';
        });
      } else {
        setState(() {
          _isImpersonating = false;
        });
      }
    }
  }

  Future<void> _exit() async {
    setState(() => _isExiting = true);
    final success = await ImpersonationService.exitImpersonation();
    if (mounted) {
      setState(() {
        _isExiting = false;
        _isImpersonating = false;
        _targetUserName = '';
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil kembali ke akun Admin ($_adminName)'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImpersonating) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade900,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Impersonate: $_targetUserName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isExiting ? null : _exit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isExiting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Row(
                          children: [
                            Icon(Icons.arrow_back, size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'Kembali Admin',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
