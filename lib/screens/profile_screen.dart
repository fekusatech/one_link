import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/user_storage.dart';
import '../services/persistent_auth_service.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/geu/visit_sync_service.dart';
import '../services/geu/surat_jalan_service.dart';
import '../services/surat_jalan_service.dart';
import '../services/tms/tms_settlement_service.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';
import 'diagnosis_screen.dart';
import 'pickup_history_screen.dart';
import 'location_tracking_settings_screen.dart';
import 'canvassing/my_statistic_screen.dart';
import 'canvassing/my_claims_screen.dart';
import 'canvassing/visit_history_screen.dart';
import 'tms/driver_settlement_list_screen.dart';
import 'tms/driver_score_screen.dart';
import 'tms/vehicle_issue_report_screen.dart';
import '../services/geu/my_statistic_service.dart';
import '../services/update_service.dart';
import '../services/impersonation_service.dart';
import '../widgets/force_login_dialog.dart';
import '../widgets/impersonation_banner.dart';

enum ProfileRole { driver, cro }

class ProfileScreen extends StatefulWidget {
  final ProfileRole role;
  const ProfileScreen({super.key, this.role = ProfileRole.driver});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Loading...';
  String _userPhone = '';
  String _userEmail = '';
  String _userCompany = '';
  bool _checkingUpdate = false;
  bool _canImpersonate = false;

  // CRO Performance Stats
  AssignmentStats? _croPerformance;

  // Driver Performance Stats (Loaded from existing APIs)
  int _driverCompletedPickups = 0;
  double _driverTotalKg = 0.0;
  double _driverApprovedSettlement = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (widget.role == ProfileRole.cro) {
      _loadCroPerformance();
    } else {
      _loadDriverPerformance();
    }
  }

  Future<void> _loadCroPerformance() async {
    try {
      final now = DateTime.now();
      final stats = await MyStatisticService.assignment(
        now.subtract(const Duration(days: 29)),
        now,
      );
      if (mounted) setState(() => _croPerformance = stats);
    } catch (_) {}
  }

  Future<void> _loadDriverPerformance() async {
    try {
      // 1. Fetch completed pickups count and weight from existing API
      final pickups = await GeuSuratJalanService.listForDriver(limit: 100);
      final completed = pickups.where((s) => s.status.toLowerCase() == 'done').toList();

      double totalKgSum = 0.0;
      for (var p in completed) {
        final kgStr = SuratJalanService.convertLiterToKg(p.totalLiter);
        totalKgSum += double.tryParse(kgStr) ?? 0.0;
      }

      // 2. Fetch approved settlements sum from existing API
      double settlementSum = 0.0;
      try {
        final settlements = await TmsSettlementService.getSettlements(status: 'approved');
        for (var st in settlements) {
          settlementSum += st.totalCostActual ?? st.totalCostPlanned ?? 0.0;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _driverCompletedPickups = completed.length;
          _driverTotalKg = totalKgSum;
          _driverApprovedSettlement = settlementSum;
        });
      }
    } catch (_) {}
  }

  String? _userAvatar;

  Future<void> _loadUserData() async {
    final user = await UserStorage.getUser();
    final name = await UserStorage.getUserName();
    final phone = await UserStorage.getUserPhone();
    final email = await UserStorage.getUserEmail();
    final company = await UserStorage.getUserCompany();
    final canImp = await ImpersonationService.canImpersonate();

    String? avatar = user?['avatar_path'] as String? ?? user?['avatar'] as String?;

    if (mounted) {
      setState(() {
        _userName = name;
        _userPhone = phone.isNotEmpty ? phone : (email.contains('santosofebrikukuh') ? '082140647578' : '');
        _userEmail = email;
        _userCompany = company;
        _userAvatar = avatar;
        _canImpersonate = canImp;
      });
    }

    // Live fetch updated avatar from server
    try {
      final userId = await UserStorage.getUserId();
      if (userId != null) {
        final res = await http.get(Uri.parse('${AppConfig.serverDomain}/driver_tracking/get_profile?karyawan_id=$userId'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == true && data['data'] != null && data['data']['avatar'] != null) {
            final serverAvatar = data['data']['avatar'].toString();
            if (serverAvatar.isNotEmpty && serverAvatar != _userAvatar) {
              if (mounted) {
                setState(() {
                  _userAvatar = serverAvatar;
                });
              }
              if (user != null) {
                user['avatar'] = serverAvatar;
                user['avatar_path'] = serverAvatar;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_data', jsonEncode(user));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Profile live avatar fetch error: $e');
    }
  }

  Widget _buildAvatarWidget(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('data:image/')) {
        try {
          final bytes = base64Decode(path.split(',').last);
          return ClipOval(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 90,
              height: 90,
              errorBuilder: (_, _, _) => const Icon(Icons.person, size: 46, color: AppColors.primaryGreen),
            ),
          );
        } catch (_) {}
      }
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            path,
            fit: BoxFit.cover,
            width: 90,
            height: 90,
            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 46, color: AppColors.primaryGreen),
          ),
        );
      }

      if (File(path).existsSync()) {
        return ClipOval(
          child: Image.file(File(path), fit: BoxFit.cover, width: 90, height: 90),
        );
      }

      final r2Url = path.startsWith('filemanager/')
          ? 'https://geu.fekusa.com/$path'
          : 'https://geu.fekusa.com/filemanager/avatar/$path';

      final erpUrl = path.startsWith('filemanager/') || path.startsWith('uploads/')
          ? '${AppConfig.serverDomain}/$path'
          : '${AppConfig.serverDomain}/filemanager/avatar/$path';

      return ClipOval(
        child: Image.network(
          r2Url,
          fit: BoxFit.cover,
          width: 90,
          height: 90,
          errorBuilder: (_, _, _) => Image.network(
            erpUrl,
            fit: BoxFit.cover,
            width: 90,
            height: 90,
            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 46, color: AppColors.primaryGreen),
          ),
        ),
      );
    }

    return const Icon(Icons.person, size: 46, color: AppColors.primaryGreen);
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      await UpdateService.instance.checkNow(context);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showVehicleInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Informasi Kendaraan & SIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInfoRow('Jenis Armada', 'Truk Engkel / Box GEU'),
            _buildDialogInfoRow('Nomor Plat', 'N 8923 GE'),
            _buildDialogInfoRow('Gudang Base', 'Gudang Utama Malang'),
            _buildDialogInfoRow('Status SIM Driver', 'SIM B1 Umum (Aktif)'),
            _buildDialogInfoRow('Masa Berlaku SIM', '24 Des 2028'),
            const Divider(height: 16),
            const Text(
              'Perubahan data armada dan lisensi driver dilakukan oleh Admin Gudang / HRD.',
              style: TextStyle(fontSize: 11, color: AppColors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCro = widget.role == ProfileRole.cro;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Profil ${isCro ? "Sales" : "Driver"}',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // ── Profile Header Card ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: AppColors.white),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryGreen, width: 2),
                            ),
                            child: _buildAvatarWidget(_userAvatar),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primaryGreen,
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                  );
                                  if (res == true) _loadUserData();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userName,
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Role Badge (Driver vs CRO / Sales)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isCro ? AppColors.accentOrange : AppColors.primaryGreen).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isCro ? '💼 Sales / Sourcing CRO' : '🚛 Pengemudi Armada TMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCro ? AppColors.accentOrange : AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        _userPhone,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
                      ),
                      if (_userEmail.isNotEmpty)
                        Text(
                          _userEmail,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey),
                        ),
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

                      // ── Role Specific Performance Stat Cards ────────
                      if (isCro) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard('Tugas', '${_croPerformance?.total ?? 0}', Icons.assignment_outlined),
                            _buildStatCard('Selesai', '${_croPerformance?.completed ?? 0}', Icons.check_circle),
                            _buildStatCard('Pencapaian', '${(_croPerformance?.rate ?? 0).toStringAsFixed(0)}%', Icons.trending_up),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard('SJ Selesai', '$_driverCompletedPickups', Icons.local_shipping),
                            _buildStatCard('Muatan', '${_driverTotalKg.toStringAsFixed(0)} Kg', Icons.scale),
                            _buildStatCard(
                              'Uang Jalan',
                              _driverApprovedSettlement >= 1000000
                                  ? 'Rp ${(_driverApprovedSettlement / 1000000).toStringAsFixed(1)}M'
                                  : 'Rp ${(_driverApprovedSettlement / 1000).toStringAsFixed(0)}k',
                              Icons.payments_outlined,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Main Feature Menu Cards ────────────────────────
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
                        title: 'Informasi Pribadi & Akun',
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          );
                          if (result == true) _loadUserData();
                        },
                      ),
                      _buildDivider(),

                      // Role Specific Menus
                      if (isCro) ...[
                        _buildMenuItem(
                          icon: Icons.bar_chart_outlined,
                          title: 'Statistik Saya',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStatisticScreen())),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.map_outlined,
                          title: 'Riwayat Kunjungan',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitHistoryScreen())),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Klaim & Komisi Saya',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyClaimsScreen())),
                        ),
                      ] else ...[
                        _buildMenuItem(
                          icon: Icons.local_shipping_outlined,
                          title: 'Informasi Kendaraan & SIM Driver',
                          onTap: _showVehicleInfoDialog,
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.history,
                          title: 'Riwayat Penjemputan',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PickupHistoryScreen())),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.payments_outlined,
                          title: 'Laporan Uang Jalan & Settlement',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSettlementListScreen())),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.verified_user_rounded,
                          title: 'Penilaian & Rating Berkendara Driver',
                          iconColor: const Color(0xFF1877F2),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverScoreScreen())),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.warning_amber_rounded,
                          title: 'Laporkan Kendala Armada (Mogok/Emergency)',
                          iconColor: AppColors.error,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleIssueReportScreen())),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── App & Security Settings Card ───────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.my_location_outlined,
                        title: 'Pengaturan Lokasi GPS & Tracking',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationTrackingSettingsScreen())),
                      ),
                      _buildDivider(),
                      if (_canImpersonate) ...[
                        _buildMenuItem(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Force Login / Pindah Akun (Admin)',
                          onTap: () => showDialog(context: context, builder: (_) => const ForceLoginDialog()),
                        ),
                        _buildDivider(),
                      ],
                      ListTile(
                        leading: const Icon(Icons.system_update_outlined, color: AppColors.primaryGreen),
                        title: Text(
                          'Cek Pembaruan Aplikasi',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        trailing: _checkingUpdate
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right, color: AppColors.grey),
                        onTap: _checkingUpdate ? null : _checkForUpdate,
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        title: 'Tentang Aplikasi',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.on_device_training_outlined,
                        title: 'Diagnosa Koneksi & Sistem',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosisScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Logout Button ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final pending = await VisitSyncService.pendingItems();
                        if (!mounted) return;
                        if (pending.isNotEmpty) {
                          final choice = await showDialog<String>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Data kunjungan belum terkirim'),
                              content: Text('${pending.length} data menunggu dikirim. Pilih Kirim dulu untuk mempertahankan data.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
                                TextButton(onPressed: () => Navigator.pop(dialogContext, 'send'), child: const Text('Kirim dulu')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, 'discard'),
                                  child: const Text('Logout & buang data', style: TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          );
                          if (choice == 'send') {
                            await VisitSyncService.syncNow();
                            if (!mounted) return;
                          } else if (choice == 'discard') {
                            await VisitSyncService.discardPending();
                          } else {
                            return;
                          }
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Konfirmasi Keluar', style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                            content: Text('Apakah Anda yakin ingin keluar?', style: AppTextStyles.bodyMedium),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Keluar', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          await UserStorage.clearUser();
                          await PersistentAuthService.instance.clearAuthData();
                          GeuAuthService.logout();
                          if (mounted) {
                            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          const ImpersonationFloatingBanner(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.h6.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primaryGreen),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
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
