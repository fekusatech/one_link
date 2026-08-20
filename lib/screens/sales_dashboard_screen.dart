import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/supplier_list_provider.dart';
import 'supplier_list_screen.dart';
import '../services/role_management_service.dart';
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
import '../services/update_service.dart';
import '../services/persistent_auth_service.dart';
import '../services/user_storage.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import 'tms/driver_score_screen.dart';
import 'pickup_history_screen.dart';
import 'canvassing/canvassing_home_screen.dart';
import 'canvassing/visit_plan_screen.dart';
import 'canvassing/visit_history_screen.dart';
import 'canvassing/scan_prospect_screen.dart';
import 'canvassing/nearby_supplier_screen.dart';
import 'canvassing/tasks_hub_screen.dart';
import 'canvassing/pickup_list_screen.dart';
import 'canvassing/my_statistic_screen.dart';
import 'canvassing/work_order_list_screen.dart';
import 'canvassing/self_assign_screen.dart';
import '../services/geu/mission_navigation_state.dart';
import '../models/geu/visit_planner_models.dart';
import '../services/geu/visit_planner_service.dart';
import '../services/geu/my_statistic_service.dart';
import '../services/geu/geu_auth_service.dart';

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
  String _userName = 'CRO';
  bool _isLoading = true;
  String? _errorMessage;
  TodaysMission? _todaysMission;
  AssignmentStats? _myStats;
  GeuUser? _geuUser;

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
    _loadUserName();
    _loadUserLocation();
    _loadSupplierData();
    _loadRecentActivity();
    _loadMissionSummary();
    _loadMyStatistics();
    _loadPermissions();

    // CRO/RO can land here directly on app open (not just via Driver
    // dashboard), so the update/maintenance check needs to fire from here
    // too — UpdateService's own _hasCheckedOnThisLoad flag prevents a
    // duplicate check if the admin dashboard-switch button is used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.startMonitoring(context);
    });
  }

  Future<void> _loadPermissions() async {
    final user = await GeuAuthService.getCachedUser();
    if (mounted) setState(() => _geuUser = user);
  }

  bool _has(String slug) => _geuUser?.hasPermission(slug) ?? false;

  Future<void> _loadUserName() async {
    final name = await UserStorage.getUserName();
    if (mounted && name.trim().isNotEmpty) {
      setState(() => _userName = name.trim());
    }
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

  Future<void> _loadMissionSummary() async {
    try {
      final mission = await VisitPlannerService.getTodaysMission();
      if (mounted) setState(() => _todaysMission = mission);
    } catch (_) {
      // The dashboard card gracefully keeps its empty state until the user
      // opens Visit Plan, which has its own cached/offline handling.
    }
  }

  Future<void> _loadMyStatistics() async {
    try {
      final now = DateTime.now();
      final stats = await MyStatisticService.assignment(
        now.subtract(const Duration(days: 6)),
        now,
      );
      if (mounted) setState(() => _myStats = stats);
    } catch (_) {
      // The dashboard omits its optional chart when the reporting API has no
      // usable data, rather than displaying a misleading empty visualization.
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
    // CRO/RO share this dashboard, but Visit Planner (mission map,
    // check-in/out, and kunjungan history) is only meaningful for users who
    // hold crm-read-visit-planner — mirrors the web sidebar's gating of the
    // "Visit Plan" menu item, and keeps the tab/screens list positionally in
    // sync with SharedBottomNavbar's own showVisitPlan-driven item list.
    final hasVisitPlanner = _has('crm-read-visit-planner');
    final showTasksTab = _has('crm-read-task') || _has('crm-read-self-assign');
    final List<Widget> screens = [
      _buildMainDashboard(),
      if (hasVisitPlanner) const VisitPlanScreen(),
      if (showTasksTab) const TasksHubScreen(),
      if (hasVisitPlanner) const VisitHistoryScreen(),
      const ProfileScreen(role: ProfileRole.cro),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: _selectedIndex == 0
          ? SharedAppBar(
              dashboardType: 'sales',
              onNotificationTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
            )
          : null,
      body: _selectedIndex == 0
          ? _buildMainDashboard()
          : screens[_selectedIndex],
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
          showVisitPlan: hasVisitPlanner,
          showTasks: showTasksTab,
          showHistory: hasVisitPlanner,
        ),
      ),
    );
  }

  /// Reachable from Beranda's app bar hamburger (auto-added by Scaffold once
  /// `drawer` is set). Holds everything from the Menu section on Beranda
  /// plus items that don't have room on Beranda's scroll or the bottom
  /// nav — currently just Daftar Work Order — so it's the overflow surface
  /// for secondary CRO/RO navigation without crowding the 5-slot bottom nav.
  Widget _buildDrawer() {
    final items = [
      ..._menuItems(),
      _CroMenuItem(
        title: 'Daftar Work Order',
        subtitle: 'Riwayat & status semua WO',
        icon: Icons.assignment_outlined,
        color: AppColors.primaryGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkOrderListScreen()),
        ),
      ),
    ];
    final visible = items
        .where((item) => item.permission == null || _has(item.permission!))
        .toList();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.primaryGreen,
              child: Text(
                'Menu',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final item in visible)
              ListTile(
                leading: Icon(item.icon, color: item.color),
                title: Text(item.title),
                subtitle: Text(
                  item.subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboard() {
    final hasVisitPlanner = _has('crm-read-visit-planner');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      children: [
        _buildCroGreeting(),
        const SizedBox(height: 16),
        if (hasVisitPlanner) ...[
          _buildMissionSummary(),
          const SizedBox(height: 20),
        ],
        Text(
          'Ringkasan aktivitas',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Pantau supplier dan lanjutkan aktivitas lapangan.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildStatisticsSection(),
        const SizedBox(height: 20),
        _buildMyStatistics(),
        const SizedBox(height: 20),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildCroGreeting() {
    final stats = _dashboardStats;
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

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
            color: AppColors.primaryGreen.withValues(alpha: .25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: AppColors.white.withValues(alpha: .75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _has('crm-self-assign-cro') && _has('crm-self-assign-ro')
                          ? 'CRO / RO'
                          : _has('crm-self-assign-cro')
                              ? 'CRO'
                              : _has('crm-self-assign-ro')
                                  ? 'RO / ROE'
                                  : 'SALES',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dateLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCroStat(
                Icons.storefront_outlined,
                stats?.totalSuppliers ?? 0,
                'Supplier',
              ),
              _croDivider(),
              _buildCroStat(
                Icons.verified_outlined,
                stats?.activeSuppliers ?? 0,
                'Aktif',
              ),
              _croDivider(),
              _buildCroStat(
                Icons.add_business_outlined,
                stats?.newThisMonth ?? 0,
                'Baru bulan ini',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSummary() {
    return ValueListenableBuilder<MissionNavigationState>(
      valueListenable: MissionNavigationStateService.current,
      builder: (context, mission, _) {
        final active = mission.isActive;
        final destination = mission.destination?.trim();
        final plannedItems = _todaysMission?.items ?? const <MissionItem>[];
        final plannedCompleted = plannedItems
            .where((item) => item.status.toUpperCase() == 'VISITED')
            .length;
        final totalVisits = active ? mission.totalVisits : plannedItems.length;
        final completedVisits = active
            ? mission.completedVisits
            : plannedCompleted;
        return InkWell(
          onTap: () => setState(() => _selectedIndex = 1),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEAF6F0) : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? AppColors.primaryGreen.withValues(alpha: .28)
                    : AppColors.borderColor,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryGreen
                        : AppColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active ? Icons.navigation_rounded : Icons.map_outlined,
                    color: active ? AppColors.white : AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            active
                                ? 'Mission sedang berjalan'
                                : 'Mission hari ini',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completedVisits/$totalVisits kunjungan selesai',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (active &&
                          destination != null &&
                          destination.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me_outlined,
                              size: 15,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Menuju $destination',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Buka Visit Plan untuk mulai kunjungan.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCroStat(IconData icon, int value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 20, color: AppColors.white),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.white.withValues(alpha: .75),
            fontSize: 11,
          ),
        ),
      ],
    ),
  );

  Widget _croDivider() => Container(
    height: 44,
    width: 1,
    color: AppColors.white.withValues(alpha: .2),
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi 👋';
    if (hour < 15) return 'Selamat siang 👋';
    if (hour < 19) return 'Selamat sore 👋';
    return 'Selamat malam 👋';
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
              'Supplier',
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
                title: 'Total supplier',
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
                title: 'Supplier aktif',
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
        const SizedBox(height: 12),
        _buildStatCard(
          title: 'Supplier baru bulan ini',
          value: _dashboardStats?.newThisMonth.toString() ?? '0',
          subtitle: 'Akuisisi baru',
          icon: Icons.person_add_alt_1_outlined,
          color: Colors.blue,
          percentage: 'Bulan berjalan',
          isPositive: true,
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

  Widget _buildMyStatistics() {
    final stats = _myStats;
    if (stats == null) return const SizedBox.shrink();
    final trend = stats.trend
        .map((item) => _number(item['completed']) + _number(item['pending']))
        .toList();
    final hasChart = trend.isNotEmpty && trend.any((value) => value > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik saya',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _miniStat('Total', stats.total, AppColors.primaryGreen),
                  _miniStat('Selesai', stats.completed, AppColors.success),
                  _miniStat('Proses', stats.inProgress, AppColors.info),
                  _miniStat('Pending', stats.pending, AppColors.accentOrange),
                ],
              ),
              if (hasChart) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Aktivitas 7 hari terakhir',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(height: 82, child: _activityChart(trend)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.h6.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _activityChart(List<int> values) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.take(7).map((value) {
        final fraction = value / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 10 + (62 * fraction),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: .78),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  /// Full CRO/RO menu, mirroring the web sidebar's permission-slug gating
  /// (crm-react's filterNav()): an item with no `permission` is always
  /// shown once logged in; otherwise it only shows if `_geuUser.permissions`
  /// includes that slug. This is what makes RO (which holds
  /// crm-read-visit-planner) see Mission/Visit Plan while CRO (which
  /// doesn't) does not.
  // Tugas Saya & Self Assign live in the "Tugas" bottom-nav tab
  // (TasksHubScreen) instead of here, so they aren't duplicated as both a
  // tab and a menu card.
  List<_CroMenuItem> _menuItems() => [
    _CroMenuItem(
      title: 'Mission hari ini',
      subtitle: 'Rute & check-in kunjungan',
      icon: Icons.map_outlined,
      color: Colors.purple,
      permission: 'crm-read-visit-planner',
      onTap: () => setState(() => _selectedIndex = 1),
    ),
    _CroMenuItem(
      title: 'Tugas Saya',
      subtitle: 'Daftar tugas & follow-up harian',
      icon: Icons.assignment_outlined,
      color: Colors.indigo,
      permission: 'crm-read-task',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasksHubScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Self Assign',
      subtitle: 'Klaim supplier & lead (CRO / RO)',
      icon: Icons.handshake_outlined,
      color: Colors.teal,
      permission: 'crm-read-self-assign',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SelfAssignScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Pickup',
      subtitle: 'Daftar dan status pengambilan',
      icon: Icons.local_shipping_outlined,
      color: AppColors.accentOrange,
      permission: 'crm-read-pickup',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PickupListScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Daftar Work Order',
      subtitle: 'Kelola & lihat status Work Order',
      icon: Icons.description_outlined,
      color: AppColors.primaryGreen,
      permission: 'crm-read-work-order',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkOrderListScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Daftar Supplier',
      subtitle: 'Cari & perbarui data supplier',
      icon: Icons.edit_location,
      color: AppColors.accentOrange,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => SupplierListProvider(),
            child: const SupplierListScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Supplier Nearby',
      subtitle: 'Cari supplier berdasarkan lokasi/kota',
      icon: Icons.near_me_outlined,
      color: AppColors.info,
      permission: 'crm-read-visit-planner',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbySupplierScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Scan Prospek',
      subtitle: 'Riset calon supplier di sekitar Anda',
      icon: Icons.radar_outlined,
      color: AppColors.info,
      permission: 'crm-read-visit-planner',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanProspectScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Statistik Saya',
      subtitle: 'KPI assignment dan tren harian',
      icon: Icons.bar_chart_outlined,
      color: Colors.blueGrey,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyStatisticScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Nilai & Rating Driver',
      subtitle: 'Performa berkendara & safety score',
      icon: Icons.speed_rounded,
      color: const Color(0xFFFF8F00),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverScoreScreen()),
      ),
    ),
  ];

  Widget _buildQuickActions() {
    final visible = _menuItems()
        .where((item) => item.permission == null || _has(item.permission!))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Menu Layanan',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${visible.length} Fitur',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final item = visible[index];
            return _buildGridActionCard(
              title: item.title,
              subtitle: item.subtitle,
              icon: item.icon,
              color: item.color,
              onTap: item.onTap,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGridActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textSecondary.withValues(alpha: .5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

class _CroMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? permission;
  final VoidCallback onTap;

  const _CroMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.permission,
    required this.onTap,
  });
}
