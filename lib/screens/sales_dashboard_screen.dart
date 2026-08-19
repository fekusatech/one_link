import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/supplier_form_provider.dart';
import '../providers/supplier_list_provider.dart';
import 'add_supplier_screen_simple.dart';
import 'supplier_list_screen.dart';
import '../services/role_management_service.dart';
import 'calendar_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../widgets/shared_bottom_navbar.dart';
import '../widgets/shared_app_bar.dart';
import '../widgets/supplier_detail_widget.dart';
import '../widgets/fullscreen_map_screen.dart';
import '../widgets/location_tracking_widget.dart';
import '../services/dashboard_stats_service.dart';
import '../models/dashboard_stats_model.dart';
import '../models/api_response.dart';
import '../services/supplier_list_service.dart';
import '../models/supplier_list_model.dart';
import '../services/location_service.dart';
import '../services/update_service.dart'; // Import UpdateService
import '../services/persistent_auth_service.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import 'pickup_history_screen.dart';
import 'canvassing/canvassing_home_screen.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Sales statistics
  DashboardStats? _dashboardStats;
  bool _isLoading = true;
  String? _errorMessage;

  // Map data
  List<SupplierListItem> _supplierList = [];
  bool _isLoadingMap = true;
  bool _isLocatingUser = true;
  LatLng? _userLocation;
  LatLng _mapCenter = LocationService.defaultLocation;

  // Map markers for suppliers
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  // Recent activity (real pickup history)
  List<SuratJalan> _recentActivity = [];
  bool _isLoadingActivity = true;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
    _loadUserLocation();
    _loadSupplierData();
    _loadRecentActivity();

    // Update check tidak dilakukan di sales dashboard
    // Hanya di dashboard utama setelah login berhasil
  }

  Future<void> _loadRecentActivity() async {
    setState(() {
      _isLoadingActivity = true;
    });

    try {
      final userData = await PersistentAuthService.instance.getUserData();
      final userId = userData['userId']?.toString();
      if (userId == null) {
        setState(() => _isLoadingActivity = false);
        return;
      }

      final history = await SuratJalanService.getPickupHistory(userId: userId);
      setState(() {
        _recentActivity = history.take(3).toList();
        _isLoadingActivity = false;
      });
    } catch (e) {
      setState(() => _isLoadingActivity = false);
    }
  }

  void _openCanvassing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CanvassingHomeScreen()),
    );
  }

  Future<void> _loadUserLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _userLocation = location;
          _mapCenter = location;
        });
        print(
          '📍 User location loaded: ${location.latitude}, ${location.longitude}',
        );
      } else {
        print('📍 Using default location');
      }
    } catch (e) {
      print('❌ Error loading user location: $e');
    } finally {
      // Resolves either way (denied/unavailable falls back to default) so
      // the map never waits forever — but it does wait for this, so its
      // initial camera reflects a real GPS fix instead of the placeholder.
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ApiResponse<DashboardStats> response =
          await DashboardStatsService.getDashboardStats();

      setState(() {
        _isLoading = false;
        if (response.status && response.data != null) {
          _dashboardStats = response.data;
        } else {
          _errorMessage = response.message;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading dashboard data: $e';
      });
    }
  }

  Future<void> _loadSupplierData() async {
    setState(() {
      _isLoadingMap = true;
    });

    try {
      // Use dashboard suppliers with 1 month filter
      final ApiResponse<SupplierListResponse> response =
          await SupplierListService.getDashboardSuppliers(limit: 50);

      setState(() {
        _isLoadingMap = false;
        if (response.status && response.data != null) {
          _supplierList = response.data!.data;
          _setupSupplierMarkers();
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMap = false;
      });
      print('Error loading supplier data for map: $e');
    }
  }

  void _setupSupplierMarkers() {
    Set<Marker> markers = {};

    for (int i = 0; i < _supplierList.length; i++) {
      final supplier = _supplierList[i];
      if (supplier.gps != null && supplier.gps!.isNotEmpty) {
        try {
          // Parse GPS coordinates (format: "latitude,longitude")
          final coords = supplier.gps!.split(',');
          if (coords.length == 2) {
            final lat = double.parse(coords[0].trim());
            final lng = double.parse(coords[1].trim());

            markers.add(
              Marker(
                markerId: MarkerId('supplier_${supplier.id}'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: supplier.name,
                  snippet:
                      '${supplier.kotaName ?? ''}, ${supplier.provinsiName ?? ''}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  i == 0
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueOrange,
                ),
              ),
            );
          }
        } catch (e) {
          print('Error parsing GPS coordinates for ${supplier.name}: $e');
        }
      }
    }

    if (markers.isEmpty) {
      _setupDefaultMarkers();
    } else {
      _markers = markers;
    }
  }

  void _setupDefaultMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('user_location'),
        position: _mapCenter,
        infoWindow: InfoWindow(
          title: _userLocation != null ? 'Lokasi Anda' : 'Lokasi Default',
          snippet: _userLocation != null
              ? 'Posisi saat ini'
              : 'Jakarta, Indonesia',
        ),
        icon: _userLocation != null
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
            : BitmapDescriptor.defaultMarker,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      _buildMainDashboard(),
      const CalendarScreen(),
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedIndex == 0
          ? SharedAppBar(
              dashboardType: 'sales',
              onNotificationTap: () {
                setState(() {
                  _selectedIndex = 2; // notifications tab
                });
              },
            )
          : null,
      body: _selectedIndex == 0
          ? _buildMainDashboard()
          : screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider(
                      create: (_) => SupplierFormProvider(),
                      child: const AddSupplierScreenSimple(),
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add_business),
            )
          : null,
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
        child: SharedBottomNavbar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildMainDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Statistics Cards
        _buildStatisticsSection(),
        const SizedBox(height: 24),

        // Supplier Detail
        const SupplierDetailWidget(),
        const SizedBox(height: 24),

        // Supplier Map
        _buildSupplierMap(),
        const SizedBox(height: 24),
        // Quick Actions
        _buildQuickActions(),
        const SizedBox(height: 24),
        // Recent Activity
        _buildRecentActivity(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat statistik',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSalesData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Statistik Hari Ini',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (!_isLoading)
              IconButton(
                onPressed: _loadSalesData,
                icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
                tooltip: 'Refresh data',
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Top Row - Main Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Supplier',
                value: _dashboardStats?.totalSuppliers.toString() ?? '0',
                subtitle: 'Terdaftar',
                icon: Icons.store,
                color: AppColors.primaryGreen,
                percentage:
                    _dashboardStats != null &&
                        _dashboardStats!.totalSuppliers > 0
                    ? '+${((_dashboardStats!.newThisMonth / _dashboardStats!.totalSuppliers) * 100).toStringAsFixed(1)}%'
                    : '0%',
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Supplier Aktif',
                value: _dashboardStats?.activeSuppliers.toString() ?? '0',
                subtitle: 'Beroperasi',
                icon: Icons.check_circle,
                color: AppColors.accentOrange,
                percentage:
                    _dashboardStats != null &&
                        _dashboardStats!.totalSuppliers > 0
                    ? '${((_dashboardStats!.activeSuppliers / _dashboardStats!.totalSuppliers) * 100).toStringAsFixed(0)}%'
                    : '0%',
                isPositive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // // Location Tracking Widget
        // const LocationTrackingWidget(),
        // const SizedBox(height: 12),

        // Bottom Row - New Suppliers only
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Baru Bulan Ini',
                value: _dashboardStats?.newThisMonth.toString() ?? '0',
                subtitle: 'Supplier',
                icon: Icons.trending_up,
                color: Colors.blue,
                percentage:
                    _dashboardStats != null &&
                        _dashboardStats!.totalSuppliers > 0
                    ? '+${((_dashboardStats!.newThisMonth / _dashboardStats!.totalSuppliers) * 100).toStringAsFixed(1)}%'
                    : '0%',
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String percentage,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  percentage,
                  style: AppTextStyles.caption.copyWith(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aksi Cepat',
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Tambah Supplier',
                subtitle: 'Daftarkan mitra baru',
                icon: Icons.add_business,
                color: AppColors.primaryGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (_) => SupplierFormProvider(),
                        child: const AddSupplierScreenSimple(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12), // jarak antar kolom
            Expanded(
              child: _buildActionCard(
                title: 'Kelola Supplier',
                subtitle: 'Edit data existing',
                icon: Icons.edit_location,
                color: AppColors.accentOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (_) => SupplierListProvider(),
                        child: const SupplierListScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Canvassing',
                subtitle: 'Cari & Catat Prospek',
                icon: Icons.map_outlined,
                color: Colors.purple,
                onTap: _openCanvassing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lokasi Supplier Saya',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                if (!_isLoadingMap)
                  IconButton(
                    onPressed: _openFullscreenMap,
                    icon: const Icon(
                      Icons.fullscreen,
                      color: AppColors.primaryGreen,
                    ),
                    tooltip: 'Lihat fullscreen',
                  ),
                if (!_isLoadingMap)
                  IconButton(
                    onPressed: _loadSupplierData,
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.primaryGreen,
                    ),
                    tooltip: 'Refresh lokasi',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _isLoadingMap || _isLocatingUser
              ? Container(
                  color: AppColors.white,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Memuat lokasi...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _openFullscreenMap,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          // Rep's real GPS wins as the initial point; supplier
                          // pins just show up as markers around it.
                          target: _userLocation ?? _mapCenter,
                          zoom: 15,
                        ),
                        markers: _markers,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        gestureRecognizers:
                            const <Factory<OneSequenceGestureRecognizer>>{},
                      ),
                      // Overlay to indicate it's tappable
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap untuk perbesar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
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
        if (_supplierList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_supplierList.length} Supplier Ditemukan',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_supplierList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _supplierList.map((s) => s.name).take(3).join(', ') +
                        (_supplierList.length > 3
                            ? ' dan ${_supplierList.length - 3} lainnya'
                            : ''),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openFullscreenMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenMapScreen(
              suppliers: _supplierList,
              markers: _markers,
              userLocation: _userLocation,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        opaque: false,
      ),
    );
  }

  static const Map<String, ({IconData icon, Color color, String label})>
  _activityStatusInfo = {
    'done': (
      icon: Icons.check_circle_outline,
      color: AppColors.primaryGreen,
      label: 'Pickup Selesai',
    ),
    'pickup': (
      icon: Icons.local_shipping_outlined,
      color: AppColors.accentOrange,
      label: 'Sedang Pickup',
    ),
    'pending': (
      icon: Icons.schedule_outlined,
      color: Colors.blueGrey,
      label: 'Menunggu Pickup',
    ),
    'cancelled': (
      icon: Icons.cancel_outlined,
      color: Colors.red,
      label: 'Dibatalkan',
    ),
  };

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aktivitas Terbaru',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PickupHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'Lihat Semua',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: _isLoadingActivity
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              : _recentActivity.isEmpty
              ? Text(
                  'Belum ada aktivitas pickup',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final activity = _recentActivity[index];
                    final info =
                        _activityStatusInfo[activity.status.toLowerCase()] ??
                        (
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.grey,
                          label: activity.status,
                        );
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: info.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(info.icon, color: info.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.label,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                activity.supplierNames.isNotEmpty
                                    ? activity.supplierNames
                                    : activity.kode,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          activity.tanggalFormatted,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
