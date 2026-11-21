import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../screens/login_screen.dart';
import '../services/geu/geu_auth_service.dart';

/// "Ganti Akun" — lets a user switch between accounts they've already
/// logged into on this device without retyping credentials (password is
/// remembered per-account in the secure vault, see GeuAuthService). Adding
/// a brand-new account is just a normal login; it gets remembered
/// automatically the moment it succeeds.
class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AccountSwitcherSheet(),
    );
  }

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  List<SavedAccount> _accounts = [];
  String? _currentEmail;
  bool _loading = true;
  String? _switchingEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      GeuAuthService.getSavedAccounts(),
      GeuAuthService.getCachedUser(),
    ]);
    if (!mounted) return;
    setState(() {
      _accounts = results[0] as List<SavedAccount>;
      _currentEmail = (results[1] as GeuUser?)?.email;
      _loading = false;
    });
  }

  Future<void> _switch(SavedAccount account) async {
    if (account.email.toLowerCase() == _currentEmail?.toLowerCase()) {
      Navigator.pop(context);
      return;
    }
    setState(() => _switchingEmail = account.email);
    try {
      await GeuAuthService.switchToAccount(account.email);
      if (!mounted) return;
      // Same destination a fresh login lands on — the newly-active
      // account's own role/permissions decide what shows next, so there's
      // no special-casing needed here versus a normal sign-in.
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/role-selection', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingEmail = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal masuk sebagai ${account.email}. Kalau password akun ini '
            'sudah berubah, hapus lalu tambahkan lagi.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _remove(SavedAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus akun ini?'),
        content: Text(
          '${account.name.isNotEmpty ? account.name : account.email} akan '
          'dihapus dari daftar switch cepat. Anda perlu login ulang untuk '
          'menambahkannya lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await GeuAuthService.forgetSavedAccount(account.email);
    await _load();
  }

  Future<void> _addAccount() async {
    Navigator.pop(context);
    if (!mounted) return;
    // LoginScreen already navigates into the app on success via
    // pushNamedAndRemoveUntil('/role-selection', ...) — nothing else to do
    // here once it's pushed.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.switch_account_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ganti Akun',
                    style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Belum ada akun tersimpan di perangkat ini. Login sekali, '
                  'lalu akun ini bisa langsung di-switch tanpa ngetik lagi.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ..._accounts.map(_accountTile),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addAccount,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Akun Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTile(SavedAccount account) {
    final isCurrent = account.email.toLowerCase() == _currentEmail?.toLowerCase();
    final isSwitching = _switchingEmail == account.email;
    final initial = account.name.trim().isNotEmpty
        ? account.name.trim()[0].toUpperCase()
        : (account.email.isNotEmpty ? account.email[0].toUpperCase() : '?');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryGreen.withValues(alpha: .15),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        account.name.isNotEmpty ? account.name : account.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(account.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isSwitching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCurrent
              ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
              : IconButton(
                  tooltip: 'Hapus akun',
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  onPressed: () => _remove(account),
                ),
      onTap: isSwitching ? null : () => _switch(account),
    );
  }
}
