import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/location_tracking_service.dart';
import '../services/user_storage.dart';
import 'privacy_policy_screen.dart';

class LocationTrackingSettingsScreen extends StatefulWidget {
  const LocationTrackingSettingsScreen({super.key});

  @override
  State<LocationTrackingSettingsScreen> createState() =>
      _LocationTrackingSettingsScreenState();
}

class _LocationTrackingSettingsScreenState
    extends State<LocationTrackingSettingsScreen> {
  bool _trackingEnabled = false;
  bool _hasConsent = false;
  DateTime? _consentDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hasConsent = await UserStorage.hasLocationTrackingConsent();
    final consentDate = await UserStorage.getLocationConsentDate();
    final isTracking = LocationTrackingService.instance.isTracking;

    setState(() {
      _hasConsent = hasConsent;
      _consentDate = consentDate;
      _trackingEnabled = isTracking;
      _isLoading = false;
    });
  }

  Future<void> _toggleTracking(bool value) async {
    if (value) {
      // Start tracking
      final success = await LocationTrackingService.instance.startTracking(
        context: context,
        onLocationUpdate: (position) {
          // Handle location updates here
          print('Location: ${position.latitude}, ${position.longitude}');
        },
      );

      if (success) {
        setState(() => _trackingEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tracking GPS diaktifkan'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      } else {
        setState(() => _trackingEnabled = false);
      }
    } else {
      // Stop tracking
      await LocationTrackingService.instance.stopTracking();
      setState(() => _trackingEnabled = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking GPS dinonaktifkan')),
      );
    }
  }

  Future<void> _revokeConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cabut Persetujuan'),
        content: const Text(
          'Apakah Anda yakin ingin mencabut persetujuan tracking lokasi? '
          'Fitur tracking akan dinonaktifkan dan data lokasi akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocationTrackingService.instance.stopTracking();
      await UserStorage.setLocationTrackingConsent(false);

      setState(() {
        _trackingEnabled = false;
        _hasConsent = false;
        _consentDate = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persetujuan tracking telah dicabut')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengaturan GPS Tracking'),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: Text(
          'Pengaturan GPS Tracking',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTrackingCard(),
          const SizedBox(height: 16),
          _buildConsentCard(),
          const SizedBox(height: 16),
          _buildPrivacyCard(),
          const SizedBox(height: 16),
          _buildDataManagementCard(),
        ],
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _trackingEnabled ? Icons.gps_fixed : Icons.gps_off,
                  color: _trackingEnabled
                      ? AppColors.primaryGreen
                      : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'GPS Tracking',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _trackingEnabled,
                  onChanged: _hasConsent ? _toggleTracking : null,
                  activeColor: AppColors.primaryGreen,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _trackingEnabled
                  ? 'Tracking aktif - Lokasi Anda sedang dipantau'
                  : 'Tracking nonaktif - Fitur navigation terbatas',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (!_hasConsent) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Persetujuan diperlukan untuk mengaktifkan tracking',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.orange.shade700,
                        ),
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

  Widget _buildConsentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasConsent ? Icons.check_circle : Icons.cancel,
                  color: _hasConsent ? AppColors.primaryGreen : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  'Status Persetujuan',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasConsent
                  ? 'Anda telah memberikan persetujuan tracking'
                  : 'Persetujuan belum diberikan',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (_consentDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Diberikan: ${_formatDate(_consentDate!)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (_hasConsent) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _revokeConsent,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cabut Persetujuan'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Text(
                  'Kebijakan Privasi',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pelajari bagaimana kami melindungi dan menggunakan data lokasi Anda',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.article),
              label: const Text('Baca Kebijakan Privasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Text(
                  'Pengelolaan Data',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Data lokasi disimpan maksimal 30 hari dan dihapus otomatis',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement data export
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Fitur export data akan segera tersedia',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showDeleteDataDialog();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Hapus Data',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Lokasi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua data lokasi yang tersimpan? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement data deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data lokasi telah dihapus')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
