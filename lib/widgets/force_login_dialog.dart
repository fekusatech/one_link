import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/impersonation_service.dart';

class ForceLoginDialog extends StatefulWidget {
  const ForceLoginDialog({super.key});

  @override
  State<ForceLoginDialog> createState() => _ForceLoginDialogState();
}

class _ForceLoginDialogState extends State<ForceLoginDialog> {
  final _userIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    final text = _userIdController.text.trim();
    final targetId = int.tryParse(text);

    if (targetId == null || targetId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan User ID yang valid!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ImpersonationService.impersonateTargetUser(targetUserId: targetId);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil pindah ke User ID #$targetId'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (r) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal melakukan Force Login / Impersonate.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Text(
            'Force Login (Admin)',
            style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan User ID target untuk berpindah akun tanpa perlu password:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target User ID (mis. 12)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_search),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Pindah Akun'),
        ),
      ],
    );
  }
}
