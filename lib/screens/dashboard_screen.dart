import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import 'surat_jalan_detail_screen.dart';
import '../services/persistent_auth_service.dart';
import '../services/user_storage.dart';
import 'navigation_screen.dart';
import 'calendar_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import '../services/global_debug_utils.dart';
import '../services/role_management_service.dart';
import '../widgets/shared_bottom_navbar.dart';
import '../widgets/shared_app_bar.dart';
import '../widgets/gps_compliance_widget.dart';
import '../services/update_service.dart';
import '../services/location_tracking_service.dart';
import '../services/driver_tracking_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Jalankan monitoring update di dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.startMonitoring(context);
      _startLocationTracking();
    });
  }

  Future<void> _startLocationTracking() async {
    // Auto-start location tracking after login (only if consent already given)
    final hasConsent = await UserStorage.hasLocationTrackingConsent();
    if (hasConsent) {
      final hasPermission = await LocationTrackingService.instance
          .hasPermissions();
      if (hasPermission && !LocationTrackingService.instance.isTracking) {
        await LocationTrackingService.instance
            .startTrackingWithoutPermissionCheck();
        print('📍 Auto-started location tracking after login');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleScanResult(Map<String, String> locationData) {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lokasi "${locationData['name']}" berhasil ditambahkan!'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // TODO: Add location to database/list
    // For now, just show success feedback
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Konfirmasi Logout'),
            ],
          ),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Stop location tracking on logout
                await LocationTrackingService.instance.stopTracking();
                await UserStorage.setLocationTrackingConsent(false);
                print('📍 Stopped location tracking on logout');

                // Clear auth data
                await PersistentAuthService.instance.clearAuthData();
                await UserStorage.clearUser();

                // Navigate to login screen
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      const _HomeScreen(),
      const CalendarScreen(),
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              title: Text(
                'One Link',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    // Navigate to QR Scanner
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerScreen(),
                      ),
                    );

                    // Handle scan result
                    if (result != null) {
                      _handleScanResult(result);
                    }
                  },
                  color: AppColors.primaryGreen,
                ),
                // Admin switch button
                if (RoleManagementService.isAdmin())
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/sales-dashboard',
                      );
                    },
                    color: AppColors.primaryGreen,
                    tooltip: 'Switch to Sales Dashboard',
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  iconColor: AppColors.primaryGreen,
                  onSelected: (value) async {
                    if (value == 'logout') {
                      _showLogoutDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                  color: AppColors.primaryGreen,
                ),
              ],
            )
          : null,
      body: screens[_selectedIndex],
      floatingActionButton: GlobalDebugUtils.debugFloatingActionButton(context),
      bottomNavigationBar: SharedBottomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Home Screen Widget
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  // API data state
  List<SuratJalan> _suratJalanList = [];
  bool _isLoading = true;
  String? _errorMessage;

  // User ID - akan diambil dari data login
  String? _userId;
  String _userName = 'Driver';

  // Statistics
  int _totalTasks = 0;
  String _totalMinyak = '0L';
  int _completedTasks = 0;

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    print('🔍 Dashboard: Initializing user data...');

    // Get user ID from persistent auth
    final userData = await PersistentAuthService.instance.getUserData();
    print('📋 Dashboard: User data received: $userData');

    if (userData != null && userData['userId'] != null) {
      _userId = userData['userId'].toString();
      final name = userData['userName'];
      if (name != null && name.trim().isNotEmpty) {
        _userName = name.trim();
      }
      print('✅ Dashboard: User ID set to: $_userId');
      await _loadSuratJalanData();
    } else {
      print('❌ Dashboard: No valid user data found');
      setState(() {
        _isLoading = false;
        _errorMessage = 'User data tidak ditemukan. Silakan login ulang.';
      });
    }
  }

  Future<void> _loadSuratJalanData() async {
    if (_userId == null) {
      print('❌ Dashboard: User ID is null, cannot load data');
      setState(() {
        _isLoading = false;
        _errorMessage = 'User ID tidak tersedia. Silakan login ulang.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔍 Dashboard: Loading surat jalan data for user: $_userId');
      final response = await SuratJalanService.getTodaySuratJalan(_userId!);
      print('✅ Dashboard: Data loaded successfully');

      setState(() {
        _suratJalanList = response.data.suratJalan;
        _isLoading = false;
        _calculateStatistics();
        _setupMapData();
      });

      // Debug: Check data received in UI
      print('📱 Dashboard received data:');
      print('  - User ID: $_userId');
      print('  - Total surat jalan: ${_suratJalanList.length}');
      print('  - Total tasks calculated: $_totalTasks');
      for (int i = 0; i < _suratJalanList.length; i++) {
        final surat = _suratJalanList[i];
        print('  - UI Item $i: ${surat.kode} (${surat.status})');
      }
    } catch (e) {
      print('❌ Dashboard: Error loading data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _calculateStatistics() {
    int totalDestinations = 0;
    int completedDestinations = 0;
    double totalKg = 0;

    for (final surat in _suratJalanList) {
      // 1. Hitung total kg dari header (convert dari liter)
      try {
        final liter = double.parse(surat.totalLiter);
        totalKg += liter * 0.9;
      } catch (_) {}

      // 2. Hitung jumlah item/tujuan dari detail
      for (final detail in surat.suratJalanDetail) {
        totalDestinations++;
        if (detail.status.toLowerCase() == 'done') {
          completedDestinations++;
        }
      }
    }

    _totalTasks = totalDestinations;
    _completedTasks = completedDestinations;
    _totalMinyak = '${totalKg.toStringAsFixed(1)} kg';
  }

  void _setupMapData() {
    _markers.clear();
    int countTotalDetails = 0;
    int countWithGps = 0;

    for (int i = 0; i < _suratJalanList.length; i++) {
      final surat = _suratJalanList[i];
      for (
        int detailIndex = 0;
        detailIndex < surat.suratJalanDetail.length;
        detailIndex++
      ) {
        countTotalDetails++;
        final detail = surat.suratJalanDetail[detailIndex];

        // Validasi GPS String
        final gpsStr = detail.supplierGps;
        if (gpsStr.isEmpty || !gpsStr.contains(',')) {
          print(
            '⚠️ Dashboard Map: Skipping supplier "${detail.supplierName}" due to invalid GPS: "$gpsStr"',
          );
          continue;
        }

        final gpsParts = gpsStr.split(',');
        if (gpsParts.length >= 2) {
          try {
            double lat = double.parse(gpsParts[0].trim());
            double lng = double.parse(gpsParts[1].trim());

            final kgAmount = SuratJalanService.convertLiterToKg(detail.qtyReal);
            final markerId =
                'surat_${surat.suratJalanId}_detail_${detail.suratJalanDetailId}';

            final marker = Marker(
              markerId: MarkerId(markerId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: detail.supplierName,
                snippet:
                    '${kgAmount} kg - ${detail.status.toUpperCase()}\n${surat.kode}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                detail.status == 'done'
                    ? BitmapDescriptor.hueGreen
                    : detail.status == 'pickup'
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueRed,
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NavigationScreen(suratJalan: surat),
                  ),
                );
                // Refresh data when returning
                _loadSuratJalanData();
              },
            );

            _markers.add(marker);
            countWithGps++;
          } catch (e) {
            print(
              '❌ Dashboard Map: Error parsing coordinates for "${detail.supplierName}": $e',
            );
          }
        }
      }
    }

    print('🗺️ Map Setup Summary:');
    print('  - Total Surat Jalan: ${_suratJalanList.length}');
    print('  - Total Destinations (Tasks): $countTotalDetails');
    print('  - Valid Markers Created: $countWithGps');
    print('  - Set size: ${_markers.length}');
  }

  void _fitMarkersInView(GoogleMapController controller) async {
    if (_markers.isEmpty) return;

    // Calculate bounds from all markers
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Add some padding
    final padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // Animate to fit bounds
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalTasks == 0 ? 0.0 : _completedTasks / _totalTasks;

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadSuratJalanData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero card: greeting + daily progress + stats
              _buildHeroCard(progress),

              const SizedBox(height: 24),

              // Loading indicator
              if (_isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                // Error state
                _buildErrorWidget(),
              ] else if (_suratJalanList.isNotEmpty) ...[
                // Map section header
                _buildSectionHeader(
                  'Peta Lokasi Pickup',
                  icon: Icons.map_outlined,
                ),
                const SizedBox(height: 12),

                // Map legend
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem('Selesai', AppColors.success),
                    _buildLegendItem('Pickup', const Color(0xFFFF9500)),
                    _buildLegendItem('Pending', AppColors.error),
                  ],
                ),

                const SizedBox(height: 12),

                // Map view (enhanced interactive)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(-7.9797, 112.6304), // Malang coordinates
                        zoom: 13.0,
                      ),
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        // Map controller ready - fit bounds if there are markers
                        if (_markers.isNotEmpty) {
                          _fitMarkersInView(controller);
                        }
                      },
                      zoomControlsEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      mapType: MapType.normal,
                      onTap: (LatLng position) {},
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Surat jalan list header
                _buildSectionHeader(
                  'Surat Jalan Hari Ini',
                  icon: Icons.receipt_long_outlined,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_suratJalanList.length} surat',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Surat jalan list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suratJalanList.length,
                  itemBuilder: (context, index) {
                    final surat = _suratJalanList[index];
                    return _buildSuratJalanCard(surat);
                  },
                ),
              ] else ...[
                // No tasks today - show empty state
                _buildEmptyTasksWidget(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(double progress) {
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D3E), Color(0xFF2E7D5B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppColors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Daily progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Hari Ini',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.white.withOpacity(0.75),
                ),
              ),
              Text(
                '$_completedTasks / $_totalTasks selesai',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentOrange,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Stat tiles
          Row(
            children: [
              _buildHeroStat(
                Icons.assignment_outlined,
                _totalTasks.toString(),
                'Tugas',
              ),
              _heroDivider(),
              _buildHeroStat(
                Icons.local_gas_station_outlined,
                _totalMinyak,
                'Total Minyak',
              ),
              _heroDivider(),
              _buildHeroStat(
                Icons.check_circle_outline,
                _completedTasks.toString(),
                'Selesai',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      height: 44,
      width: 1,
      color: AppColors.white.withOpacity(0.2),
    );
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h6.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.white.withOpacity(0.75),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi 👋';
    if (hour < 15) return 'Selamat siang 👋';
    if (hour < 19) return 'Selamat sore 👋';
    return 'Selamat malam 👋';
  }

  Widget _buildSectionHeader(
    String title, {
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Gagal Memuat Data',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Terjadi kesalahan saat memuat data surat jalan',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Navigate to login to re-authenticate
                    await PersistentAuthService.instance.clearAuthData();
                    await UserStorage.clearUser();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Login Ulang',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _initializeAndLoadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Coba Lagi',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuratJalanCard(SuratJalan surat) {
    final statusColor = surat.status == 'done'
        ? AppColors.success
        : (surat.status == 'progress' || surat.status == 'pickup')
        ? const Color(0xFFFF9500)
        : AppColors.error;

    final statusText = surat.status == 'done'
        ? 'Selesai'
        : (surat.status == 'progress' || surat.status == 'pickup')
        ? 'Proses'
        : surat.status == 'cancelled'
        ? 'Batal'
        : 'Pending';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuratJalanDetailScreen(suratJalan: surat),
          ),
        );
        // Refresh data when returning
        _loadSuratJalanData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header dengan kode surat jalan
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surat.kode,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          surat.tanggalFormatted,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier info
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          surat.supplierNames,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Driver dan plat
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: AppColors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                surat.driverName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            surat.plat,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quantity dan harga
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.scale,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${SuratJalanService.convertLiterToKg(surat.totalLiter)} kg',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  SuratJalanService.formatCurrency(
                                    surat.totalHarga,
                                  ),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                          Text(
                            '${surat.progress.percentage}%',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: surat.progress.percentage / 100,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          surat.progress.percentage == 100
                              ? AppColors.primaryGreen
                              : const Color(0xFFFF9500),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Footer: tap affordance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Lihat detail',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco,
              size: 60,
              color: AppColors.primaryGreen,
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            'Tidak Ada Surat Jalan Hari Ini',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            'Belum ada surat jalan untuk user ini pada tanggal ${DateTime.now().day.toString().padLeft(2, '0')} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}. Silakan cek kembali nanti atau refresh data.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.grey,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadSuratJalanData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Refresh Data',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to view all surat jalan
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Lihat Semua',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return monthNames[month - 1];
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.darkGrey,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
