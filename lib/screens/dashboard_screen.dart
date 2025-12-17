import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import 'surat_jalan_detail_screen.dart';
import '../services/persistent_auth_service.dart';
import 'navigation_screen.dart';
import 'calendar_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

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

                // Clear auth data
                await PersistentAuthService.instance.clearAuthData();

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.grey,
          selectedLabelStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
          unselectedLabelStyle: AppTextStyles.caption.copyWith(
            color: AppColors.grey,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Kalender',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Notifikasi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
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
    _totalTasks = _suratJalanList.length;

    double totalKg = 0;
    int completed = 0;

    for (final surat in _suratJalanList) {
      // Hitung total kg (convert dari liter)
      try {
        final liter = double.parse(surat.totalLiter);
        totalKg += liter * 0.9; // Convert liter to kg (UCO density)
      } catch (e) {
        // Ignore parsing errors
      }

      // Hitung yang sudah selesai
      if (surat.status.toLowerCase() == 'done') {
        completed++;
      }
    }

    _totalMinyak = '${totalKg.toStringAsFixed(1)} kg';
    _completedTasks = completed;
  }

  void _setupMapData() {
    _markers.clear();
    print(
      '🗺️ Setting up map markers for ${_suratJalanList.length} surat jalan',
    );

    // Create markers for each supplier location from surat jalan details
    for (int i = 0; i < _suratJalanList.length; i++) {
      final surat = _suratJalanList[i];
      print('🔍 Processing surat ${i}: ${surat.kode}');

      // Process each supplier in the surat jalan detail
      for (
        int detailIndex = 0;
        detailIndex < surat.suratJalanDetail.length;
        detailIndex++
      ) {
        final detail = surat.suratJalanDetail[detailIndex];
        print('  📍 Supplier ${detailIndex}: ${detail.supplierName}');
        print('     GPS: "${detail.supplierGps}"');

        // Parse supplier GPS coordinates
        final gpsParts = detail.supplierGps.split(',');
        print('     GPS Parts: $gpsParts (length: ${gpsParts.length})');

        if (gpsParts.length >= 2) {
          try {
            double lat = double.parse(gpsParts[0].trim());
            double lng = double.parse(gpsParts[1].trim());

            print('     ✅ Parsed coordinates: $lat, $lng');

            final kgAmount = SuratJalanService.convertLiterToKg(detail.qtyReal);
            final markerId =
                'surat_${surat.suratJalanId}_detail_${detail.suratJalanDetailId}';

            final marker = Marker(
              markerId: MarkerId(markerId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: detail.supplierName,
                snippet:
                    '${kgAmount} kg - ${surat.status.toUpperCase()}\n${surat.kode}\nTap untuk detail',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                surat.status == 'done'
                    ? BitmapDescriptor.hueGreen
                    : surat.status == 'pickup'
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueRed,
              ),
              onTap: () {
                // Navigate to navigation screen when marker is tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NavigationScreen(suratJalan: surat),
                  ),
                );
              },
            );

            _markers.add(marker);
            print('     ➕ Marker added: $markerId');
          } catch (e) {
            print('     ❌ Error parsing GPS coordinates: $e');
          }
        } else {
          print('     ❌ Invalid GPS format');
        }
      }
    }

    print('🗺️ Total markers created: ${_markers.length}');
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statistics Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Tugas Hari Ini',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalTasks.toString(),
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    width: 1,
                    color: AppColors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Total Minyak',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalMinyak,
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    width: 1,
                    color: AppColors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Selesai',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _completedTasks.toString(),
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
              // Tasks exist - show normal content
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Surat Jalan Hari Ini',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadSuratJalanData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Map section header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Peta Lokasi Pickup',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Map legend
                  Row(
                    children: [
                      _buildLegendItem('Selesai', Colors.green),
                      const SizedBox(width: 8),
                      _buildLegendItem('Pickup', Colors.orange),
                      const SizedBox(width: 8),
                      _buildLegendItem('Pending', Colors.red),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Map view (enhanced interactive)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                    // Enable marker info windows
                    onTap: (LatLng position) {
                      // Optional: Handle map tap
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

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

            // const SizedBox(height: 24),

            // // Quick Actions (always visible)
            // Text(
            //   'Aksi Cepat',
            //   style: AppTextStyles.h5.copyWith(
            //     color: AppColors.primaryGreen,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),

            // const SizedBox(height: 12),

            // Row(
            //   children: [
            //     Expanded(
            //       child: _buildQuickActionButton(
            //         icon: Icons.refresh,
            //         label: 'Refresh Data',
            //         onTap: _loadSuratJalanData,
            //       ),
            //     ),
            //     const SizedBox(width: 12),
            //     Expanded(
            //       child: _buildQuickActionButton(
            //         icon: Icons.list_alt,
            //         label: 'Lihat Semua',
            //         onTap: () {
            //           // TODO: Navigate to all surat jalan list
            //         },
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
        ? AppColors.primaryGreen
        : surat.status == 'pickup'
        ? const Color(0xFFFF9500)
        : AppColors.error;

    final statusText = surat.status == 'done'
        ? 'Selesai'
        : surat.status == 'pickup'
        ? 'Pickup'
        : 'Pending';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuratJalanDetailScreen(suratJalan: surat),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.background),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header dengan kode surat jalan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      surat.kode,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

                  const SizedBox(height: 12),

                  // Tanggal
                  Text(
                    'Tanggal: ${surat.tanggalFormatted}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey,
                    ),
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
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.background),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.primaryGreen),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
