import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/user_storage.dart';
import '../services/geu/geu_auth_service.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';
import 'diagnosis_screen.dart';
import 'pickup_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Loading...';
  String _userPhone = '';
  String _userEmail = '';
  String _userCompany = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await UserStorage.getUserName();
    final phone = await UserStorage.getUserPhone();
    final email = await UserStorage.getUserEmail();
    final company = await UserStorage.getUserCompany();

    setState(() {
      _userName = name;
      _userPhone = phone;
      _userEmail = email;
      _userCompany = company;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Profil',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.edit),
        //     color: AppColors.primaryGreen,
        //     onPressed: () {
        //       // TODO: Edit profile
        //     },
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.white),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userPhone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  if (_userEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _userEmail,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                  if (_userCompany.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _userCompany,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('Total', '500L', Icons.local_gas_station),
                      _buildStatCard('Selesai', '24', Icons.check_circle),
                      _buildStatCard('Rating', '4.8', Icons.star),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Menu Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Informasi Pribadi',
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );

                      // Reload data if profile was updated
                      if (result == true) {
                        _loadUserData();
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Informasi Kendaraan',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Riwayat Penjemputan',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PickupHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.attach_money,
                    title: 'Laporan Pendapatan',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settings
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Pengaturan Notifikasi',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.security,
                    title: 'Keamanan & Privasi',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'Bantuan & FAQ',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'Tentang Aplikasi',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.on_device_training_outlined,
                    title: 'Diagnosa',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DiagnosisScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Konfirmasi Keluar',
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Apakah Anda yakin ingin keluar?',
                          style: AppTextStyles.bodyMedium,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Batal',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Keluar',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      // Clear user data
                      await UserStorage.clearUser();
                      GeuAuthService.logout(); // best-effort, don't block logout

                      // Navigate to login
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout),
                      const SizedBox(width: 8),
                      Text('Keluar', style: AppTextStyles.button),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.grey.withOpacity(0.2),
    );
  }
}
