import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/gps_enforcement_service.dart';

class GpsComplianceWidget extends StatefulWidget {
  const GpsComplianceWidget({super.key});

  @override
  State<GpsComplianceWidget> createState() => _GpsComplianceWidgetState();
}

class _GpsComplianceWidgetState extends State<GpsComplianceWidget> {
  GpsComplianceStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();

    // Refresh status periodically
    _startStatusRefresh();
  }

  void _startStatusRefresh() {
    // Refresh every 10 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) {
        await _loadStatus();
        return true;
      }
      return false;
    });
  }

  Future<void> _loadStatus() async {
    final status = await GpsEnforcementService.instance.getComplianceStatus();

    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_status == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _status!.isCompliant
                        ? AppColors.primaryGreen.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _status!.isCompliant ? Icons.verified_user : Icons.warning,
                    color: _status!.isCompliant
                        ? AppColors.primaryGreen
                        : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS System Status',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _status!.isCompliant
                            ? 'Sistem Aktif'
                            : 'Perlu Perhatian',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _status!.isCompliant
                              ? AppColors.primaryGreen
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_status!.isCompliant) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Status Details
            Column(
              children: [
                _buildStatusItem(
                  icon: Icons.check_circle,
                  title: 'Persetujuan GPS',
                  status: _status!.hasConsent,
                ),
                _buildStatusItem(
                  icon: Icons.location_on,
                  title: 'Izin Lokasi',
                  status: _status!.hasPermission,
                ),
                _buildStatusItem(
                  icon: Icons.settings,
                  title: 'Layanan GPS',
                  status: _status!.serviceEnabled,
                ),
                _buildStatusItem(
                  icon: Icons.gps_fixed,
                  title: 'Lokasi Aktif',
                  status: _status!.isTracking,
                ),
              ],
            ),

            // Error message if any
            if (_status!.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status!.error!,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Warning if not compliant
            if (!_status!.isCompliant) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Wajib Aktif',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistem GPS harus tetap aktif untuk menggunakan aplikasi. Aplikasi akan otomatis tertutup jika GPS dinonaktifkan.',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required bool status,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: status ? AppColors.primaryGreen : Colors.red,
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            status ? 'OK' : 'Error',
            style: AppTextStyles.caption.copyWith(
              color: status ? AppColors.primaryGreen : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
