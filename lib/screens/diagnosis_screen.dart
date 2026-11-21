import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/gps_compliance_widget.dart';
import '../services/geu/debug_log_service.dart';
import '../services/device_security_service.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  bool _sendingLog = false;
  bool _scanning = false;
  // Pre-fill with the background scan splash_screen.dart already ran, so
  // opening this screen doesn't show a blank state before the user taps
  // Scan - they can still re-scan on demand.
  DeviceSecurityResult? _securityResult = DeviceSecurityService.lastResult;

  Future<void> _sendTodayLog() async {
    setState(() => _sendingLog = true);
    final message = await DebugLogService.sendTodayLog();
    if (!mounted) return;
    setState(() => _sendingLog = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scanDeviceSecurity() async {
    setState(() => _scanning = true);
    final result = await DeviceSecurityService.check();
    if (!mounted) return;
    setState(() {
      _securityResult = result;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Diagnosa Sistem',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Perangkat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const GpsComplianceWidget(),
            const SizedBox(height: 24),
            const Text(
              'Keamanan Perangkat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deteksi root/jailbreak dan status fake GPS di perangkat ini.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scanDeviceSecurity,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.security_rounded),
                label: Text(_scanning ? 'Memindai...' : 'Scan Perangkat'),
              ),
            ),
            if (_securityResult != null) ...[
              const SizedBox(height: 12),
              _securityCard(_securityResult!),
            ],
            const SizedBox(height: 24),
            const Text(
              'Log Debug',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kirim catatan aktivitas aplikasi hari ini ke server — dipakai tim support kalau lagi bantu debug masalah di HP kamu.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sendingLog ? null : _sendTodayLog,
                icon: _sendingLog
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_sendingLog ? 'Mengirim...' : 'Kirim Log Hari Ini'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityCard(DeviceSecurityResult result) {
    if (result.error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          result.error!,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final hasRisk = result.hasRisk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (hasRisk ? AppColors.error : AppColors.success).withValues(
          alpha: .1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasRisk
                    ? Icons.warning_amber_rounded
                    : Icons.verified_user_rounded,
                size: 18,
                color: hasRisk ? AppColors.error : AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                hasRisk ? 'Ditemukan risiko keamanan' : 'Perangkat aman',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: hasRisk ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _securityStatusRow(
            'Root/Jailbreak',
            result.isRooted,
            positiveIsBad: true,
          ),
          _securityStatusRow(
            'Fake GPS aktif',
            result.isMockLocationActive,
            positiveIsBad: true,
          ),
          _securityStatusRow(
            'Perangkat asli (bukan emulator)',
            result.isRealDevice,
            positiveIsBad: false,
          ),
        ],
      ),
    );
  }

  Widget _securityStatusRow(String label, bool? value, {required bool positiveIsBad}) {
    final isBad = value == null ? null : (positiveIsBad ? value : !value);
    final text = value == null
        ? 'Tidak diketahui'
        : (positiveIsBad ? (value ? 'Terdeteksi' : 'Tidak terdeteksi') : (value ? 'Ya' : 'Tidak'));
    final color = isBad == null
        ? AppColors.textSecondary
        : (isBad ? AppColors.error : AppColors.success);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
