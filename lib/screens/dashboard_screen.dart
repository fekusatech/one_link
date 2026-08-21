import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/offline_sync_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import '../services/geu/surat_jalan_service.dart';
import '../services/geu/visit_navigation_service.dart';
import '../services/location_service.dart';
import '../services/driver_monitoring_service.dart';
import 'surat_jalan_detail_screen.dart';
import '../services/persistent_auth_service.dart';
import '../services/user_storage.dart';
import 'navigation_screen.dart';
import 'notification_screen.dart';
import 'tms/driver_settlement_list_screen.dart';
import 'tms/driver_movement_screen.dart';
import 'tms/driver_score_screen.dart';
import 'tms/driver_map_screen.dart';
import 'tms/vehicle_issue_report_screen.dart';
import 'profile_screen.dart';
import 'pickup_history_screen.dart';
import 'pickup_map_screen.dart';
import 'diagnosis_screen.dart';
import '../widgets/gps_compliance_widget.dart';
import '../widgets/impersonation_banner.dart';
import '../widgets/force_login_dialog.dart';
import '../widgets/dynamic_pickup_map_widget.dart';
import '../services/update_service.dart';
import '../services/location_tracking_service.dart';
import '../services/driver_tracking_service.dart';
import '../services/emergency_shake_service.dart';
import '../services/proximity_wa_service.dart';
import '../services/dashboard_access_service.dart';
import '../services/local_notify_service.dart';
import '../widgets/working_mode_header_widget.dart';
import '../services/role_management_service.dart';
import '../services/impersonation_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _showDriverMap = true;

  @override
  void initState() {
    super.initState();
    // Jalankan monitoring update & shake detector SOS di dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.startMonitoring(context);
      EmergencyShakeService.instance.startListening(context);
      LocalNotifyService.instance.init();
      LocalNotifyService.instance.ensurePermission();
      _startLocationTracking();
      _loadDriverAccess();
    });
  }

  Future<void> _loadDriverAccess() async {
    final access = await DashboardAccessService.fetchDashboardAccess();
    if (mounted) {
      setState(() {
        if (access != null) _showDriverMap = access.driver || access.admin;
      });
    }
  }

  /// Mulai ProximityWaService hanya jika user punya akses driver (server-side).
  Future<void> _startProximityIfDriver() async {
    try {
      final access = await DashboardAccessService.fetchDashboardAccess();
      if (access?.driver == true) {
        ProximityWaService.instance.start(context);
      } else {
        debugPrint(
          '🛰️ ProximityWaService skipped: user bukan driver '
          '(driver=${access?.driver})',
        );
      }
    } catch (e) {
      debugPrint('🛰️ ProximityWaService role check error: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    // Only auto-start if Working Mode is ACTIVE!
    final isWorking = await UserStorage.isWorkingModeActive();
    if (!isWorking) {
      debugPrint(
        '🛑 Working Mode is OFF: Location tracking paused on dashboard init.',
      );
      return;
    }
    final hasConsent = await UserStorage.hasLocationTrackingConsent();
    if (hasConsent) {
      final hasPermission = await LocationTrackingService.instance
          .hasPermissions();
      if (hasPermission && !LocationTrackingService.instance.isTracking) {
        await LocationTrackingService.instance
            .startTrackingWithoutPermissionCheck();
        print(
          '📍 Auto-started location tracking after login (Mode Bekerja Aktif)',
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      const _HomeScreen(),
      const PickupHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: _selectedIndex == 0
          ? _DriverAppBar(
              onNotificationTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
            )
          : null,
      body: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable:
                DriverMonitoringService.instance.activeMonitoringStatusNotifier,
            builder: (context, statusText, child) {
              return const SizedBox.shrink();
            },
          ),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: _DriverBottomBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showMap: _showDriverMap,
        onMapTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.small(
              heroTag: 'driver-vehicle-issue',
              tooltip: 'Laporkan kendala armada',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VehicleIssueReportScreen(),
                ),
              ),
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              elevation: 4,
              child: const Icon(Icons.priority_high_rounded),
            )
          : null,
    );
  }
}

class _DriverAppBar extends StatefulWidget implements PreferredSizeWidget {
  const _DriverAppBar({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  State<_DriverAppBar> createState() => _DriverAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _DriverAppBarState extends State<_DriverAppBar> {
  bool _canSwitchDashboard = false;

  @override
  void initState() {
    super.initState();
    _loadSwitchPermission();
  }

  Future<void> _loadSwitchPermission() async {
    var allowed = RoleManagementService.isAdmin();
    if (!allowed) {
      final user = await UserStorage.getUser();
      final groups = user?['groups'] as List<dynamic>? ?? const [];
      final roles = user?['roles'] as List<dynamic>? ?? const [];
      final identity = [
        ...groups,
        ...roles,
      ].map((role) => role.toString().toLowerCase()).join(' ');
      allowed =
          identity.contains('admin') ||
          identity.contains('developer') ||
          identity.contains('super');
    }
    if (!allowed) allowed = await ImpersonationService.canImpersonate();
    if (mounted) setState(() => _canSwitchDashboard = allowed);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF4F7F5),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONE LINK',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.accentOrange,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          Text(
            'Transport Management System',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          label: 'Buka notifikasi',
          button: true,
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.onNotificationTap,
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.primaryGreen,
            tooltip: 'Notifikasi',
          ),
        ),
        if (_canSwitchDashboard)
          Semantics(
            label: 'Pindah ke dashboard Sales',
            button: true,
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/sales-dashboard'),
              icon: const Icon(Icons.swap_horiz_rounded),
              color: AppColors.primaryGreen,
              tooltip: 'Pindah ke Dashboard Sales',
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _DriverBottomBar extends StatelessWidget {
  const _DriverBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.onMapTap,
    required this.showMap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMapTap;
  final bool showMap;

  @override
  Widget build(BuildContext context) {
    final items = <_DriverNavItem>[
      const _DriverNavItem(
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        label: 'Beranda',
        tabIndex: 0,
      ),
      const _DriverNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: 'Riwayat',
        tabIndex: 1,
      ),
      if (showMap)
        _DriverNavItem(
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
          label: 'Peta',
          onPressed: onMapTap,
        ),
      const _DriverNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        tabIndex: 2,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: .10),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = item.tabIndex == currentIndex;
            final isProfile = index == items.length - 1;
            final foreground = selected
                ? AppColors.primaryGreen
                : AppColors.textSecondary;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Navigasi ${item.label}',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      if (item.tabIndex != null) {
                        onTap(item.tabIndex!);
                      } else {
                        item.onPressed?.call();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGreen.withValues(alpha: .10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isProfile)
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primaryGreen
                                    : AppColors.primaryGreen.withValues(
                                        alpha: .10,
                                      ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 17,
                                color: selected
                                    ? AppColors.white
                                    : AppColors.primaryGreen,
                              ),
                            )
                          else
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: foreground,
                            ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DriverNavItem {
  const _DriverNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.tabIndex,
    this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? tabIndex;
  final VoidCallback? onPressed;
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
  bool _canImpersonate = false;

  final MapController _mapController = MapController();
  LatLng? _driverPosition;
  List<_RouteStop> _allStops = [];
  List<_RouteStop> _optimizedStops = [];
  List<LatLng> _routePolyline = [];
  bool _loadingRoute = false;
  String _statusFilter = 'semua'; // semua | proses | selesai
  final TextEditingController _sjSearchController = TextEditingController();
  String _sjSearchQuery = '';
  int _sjCurrentPage = 1;
  static const int _sjPageSize = 5;
  bool _isPaginating = false;

  bool _isOnline = true;
  int _pendingSyncCount = 0;
  Timer? _connectivityTimer;

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _sjSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
    _loadDriverPosition();
    _startConnectivityMonitoring();
    _loadImpersonationAccess();
  }

  Future<void> _loadImpersonationAccess() async {
    final allowed = await ImpersonationService.canImpersonate();
    if (mounted) setState(() => _canImpersonate = allowed);
  }

  void _startConnectivityMonitoring() {
    _checkConnectivityStatus();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkConnectivityStatus();
    });
  }

  Future<void> _checkConnectivityStatus() async {
    final online = await OfflineSyncService.isOnline();
    final count = await OfflineSyncService.getPendingCount();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _pendingSyncCount = count;
      });
    }
  }

  Widget _buildConnectivityBanner() {
    if (!_isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.accentOrange,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MODE OFFLINE AKTIF (Sinyal Terputus)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _pendingSyncCount > 0
                        ? '$_pendingSyncCount data tersimpan di HP & akan otomatis di-sync saat sinyal kembali.'
                        : 'Aplikasi menyimpan data & koordinat lokal secara otomatis saat offline.',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_pendingSyncCount > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.primaryGreen,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_pendingSyncCount data offline siap disinkronkan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () async {
                await OfflineSyncService.syncNow();
                _checkConnectivityStatus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sync Sekarang',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
        _suratJalanList = [];
        _allStops = [];
        _optimizedStops = [];
        _routePolyline = [];
        _totalTasks = 0;
        _completedTasks = 0;
        _totalMinyak = '0L';
        _isLoading = true;
        _errorMessage = null;
      });

      if (!mounted) return;

      print('🔍 Dashboard: Loading surat jalan data for user: $_userId');
      final suratJalanList = await GeuSuratJalanService.listTodayHydrated();
      print('✅ Dashboard: Data loaded successfully');

      setState(() {
        _suratJalanList = suratJalanList;
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
      // 1. Hitung total kg dari header (convert dari liter). totalLiter
      // dihitung dari qty_real (baru keisi setelah pickup selesai
      // ditimbang) — sebelum itu nilainya 0. Pakai totalQty (rencana/qty
      // order) sebagai estimasi selama belum ada realisasi, biar gak
      // nampilin 0.0 kg buat surat jalan yang masih berjalan hari ini.
      try {
        final realLiter = double.parse(surat.totalLiter);
        final liter = realLiter > 0 ? realLiter : double.parse(surat.totalQty);
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

  LatLng? _parseGps(String gpsStr) {
    if (gpsStr.isEmpty || !gpsStr.contains(',')) return null;
    final parts = gpsStr.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _loadDriverPosition() async {
    final location = await LocationService.getCurrentLocation();
    if (location == null || !mounted) return;
    setState(
      () => _driverPosition = LatLng(location.latitude, location.longitude),
    );
    _reorderStops();
  }

  void _setupMapData() {
    final stops = <_RouteStop>[];
    for (final surat in _suratJalanList) {
      for (final detail in surat.suratJalanDetail) {
        final position = _parseGps(detail.supplierGps);
        if (position == null) {
          print(
            '⚠️ Dashboard Map: Skipping supplier "${detail.supplierName}" due to invalid GPS: "${detail.supplierGps}"',
          );
          continue;
        }
        stops.add(_RouteStop(surat: surat, detail: detail, position: position));
      }
    }
    _allStops = stops;
    print(
      '🗺️ Map Setup Summary: ${_allStops.length} valid stops from ${_suratJalanList.length} surat jalan',
    );
    _reorderStops();
  }

  /// Greedy nearest-neighbor ordering from the driver's current position.
  /// Stops that are 'done' or 'cancelled' are excluded from the
  /// optimization/route-line entirely (per requirement) and just appended
  /// at the end so they remain visible/filterable in the list.
  void _reorderStops() {
    final routable = _allStops.where((s) {
      final status = s.detail.status.toLowerCase();
      return status != 'done' && status != 'cancelled';
    }).toList();
    final locked = _allStops.where((s) {
      final status = s.detail.status.toLowerCase();
      return status == 'done' || status == 'cancelled';
    }).toList();

    final driver = _driverPosition;
    List<_RouteStop> ordered;
    if (driver == null || routable.isEmpty) {
      ordered = routable;
    } else {
      final remaining = List<_RouteStop>.from(routable);
      ordered = [];
      var current = driver;
      while (remaining.isNotEmpty) {
        remaining.sort((a, b) {
          final distA = Geolocator.distanceBetween(
            current.latitude,
            current.longitude,
            a.position.latitude,
            a.position.longitude,
          );
          final distB = Geolocator.distanceBetween(
            current.latitude,
            current.longitude,
            b.position.latitude,
            b.position.longitude,
          );
          return distA.compareTo(distB);
        });
        final nearest = remaining.removeAt(0);
        ordered.add(nearest);
        current = nearest.position;
      }
    }

    setState(() => _optimizedStops = [...ordered, ...locked]);
    _loadRoutePolyline(ordered);
  }

  static const _maxRoutePolylineStops = 15;

  /// Chains OSRM driving segments driver -> stop1 -> stop2 -> ... so the map
  /// shows a real road-following route through the optimized order. Capped
  /// so a very long stop list doesn't fire dozens of sequential requests.
  Future<void> _loadRoutePolyline(List<_RouteStop> ordered) async {
    final driver = _driverPosition;
    if (driver == null || ordered.isEmpty) {
      if (mounted) setState(() => _routePolyline = []);
      return;
    }
    final capped = ordered.take(_maxRoutePolylineStops).toList();
    if (mounted) setState(() => _loadingRoute = true);
    final points = <LatLng>[];
    var origin = driver;
    for (final stop in capped) {
      final segment = await VisitNavigationService.drivingRoute(
        origin: origin,
        destination: stop.position,
      );
      if (points.isEmpty) {
        points.addAll(segment);
      } else {
        points.addAll(segment.skip(1));
      }
      origin = stop.position;
    }
    if (mounted) {
      setState(() {
        _routePolyline = points;
        _loadingRoute = false;
      });
    }
  }

  List<_RouteStop> get _filteredStopsForMap {
    if (_statusFilter == 'all') return _optimizedStops;
    return _optimizedStops.where((stop) {
      final status = stop.detail.status.toLowerCase();
      if (_statusFilter == 'done') return status == 'done';
      if (_statusFilter == 'pickup')
        return status == 'pickup' || status == 'progress';
      if (_statusFilter == 'pending')
        return status == 'pending' ||
            (status != 'done' &&
                status != 'pickup' &&
                status != 'progress' &&
                status != 'cancelled');
      return true;
    }).toList();
  }

  void _fitMarkersInView() {
    final activeStops = _filteredStopsForMap;
    if (activeStops.isEmpty) return;
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final stop in activeStops) {
      final lat = stop.position.latitude;
      final lng = stop.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    if (_driverPosition != null) {
      minLat = math.min(minLat, _driverPosition!.latitude);
      maxLat = math.max(maxLat, _driverPosition!.latitude);
      minLng = math.min(minLng, _driverPosition!.longitude);
      maxLng = math.max(maxLng, _driverPosition!.longitude);
    }
    const padding = 0.01;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - padding, minLng - padding),
          LatLng(maxLat + padding, maxLng + padding),
        ),
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  List<_RouteStop> get _filteredStopsForList => _optimizedStops.where((stop) {
    final status = stop.detail.status.toLowerCase();
    if (_statusFilter == 'proses' &&
        (status == 'done' || status == 'cancelled')) {
      return false;
    }
    if (_statusFilter == 'selesai' && status != 'done') return false;
    if (_sjSearchQuery.isEmpty) return true;
    final query = _sjSearchQuery;
    return stop.detail.supplierName.toLowerCase().contains(query) ||
        stop.detail.supplierAlamat.toLowerCase().contains(query) ||
        stop.surat.kode.toLowerCase().contains(query);
  }).toList();

  bool _handleDashboardScroll(ScrollNotification notification) {
    if (notification is! ScrollEndNotification ||
        notification.metrics.axis != Axis.vertical ||
        notification.metrics.pixels <
            notification.metrics.maxScrollExtent - 160) {
      return false;
    }
    final totalPages = (_filteredStopsForList.length / _sjPageSize).ceil();
    if (totalPages > 0 &&
        _sjCurrentPage < totalPages &&
        mounted &&
        !_isPaginating) {
      setState(() {
        _isPaginating = true;
        _sjCurrentPage++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isPaginating = false);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalTasks == 0 ? 0.0 : _completedTasks / _totalTasks;

    return Column(
      children: [
        _buildConnectivityBanner(),
        // const WorkingModeHeaderWidget(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: _loadSuratJalanData,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleDashboardScroll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero card: greeting + daily progress + stats
                      _buildHeroCard(progress),

                      const SizedBox(height: 16),

                      // TMS Quick Action Menu for Driver
                      _buildTmsQuickActions(),

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
                              '${_optimizedStops.length} titik',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Search Bar Input
                        TextField(
                          controller: _sjSearchController,
                          decoration: InputDecoration(
                            hintText: 'Cari nama supplier / alamat...',
                            hintStyle: AppTextStyles.caption.copyWith(
                              color: AppColors.grey,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: AppColors.primaryGreen,
                            ),
                            suffixIcon: _sjSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: AppColors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _sjSearchController.clear();
                                        _sjSearchQuery = '';
                                        _sjCurrentPage = 1;
                                      });
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _sjSearchQuery = val.trim().toLowerCase();
                              _sjCurrentPage = 1;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Status filter
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('semua', 'Semua'),
                            _buildFilterChip('proses', 'Proses'),
                            _buildFilterChip('selesai', 'Selesai'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Surat jalan list — flattened per supplier stop with search & pagination
                        Builder(
                          builder: (context) {
                            final filtered = _filteredStopsForList;

                            if (filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    _sjSearchQuery.isNotEmpty
                                        ? 'Tidak ada titik yang cocok dengan pencarian "$_sjSearchQuery".'
                                        : 'Tidak ada titik pada filter ini.',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Pagination Math
                            final totalItems = filtered.length;
                            final totalPages = (totalItems / _sjPageSize)
                                .ceil();
                            final safePage = _sjCurrentPage.clamp(
                              1,
                              totalPages,
                            );
                            const startIndex = 0;
                            final endIndex =
                                (safePage * _sjPageSize > totalItems)
                                ? totalItems
                                : safePage * _sjPageSize;
                            final paginatedList = filtered.sublist(
                              startIndex,
                              endIndex,
                            );

                            return Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: paginatedList.length,
                                  itemBuilder: (context, index) {
                                    final stop = paginatedList[index];
                                    return _buildStopCard(
                                      stop,
                                      _routeOrderNumber(stop),
                                    );
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    safePage < totalPages
                                        ? 'Geser ke bawah untuk memuat titik berikutnya'
                                        : 'Semua titik sudah ditampilkan',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            );
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
            ),
          ),
        ),
        const ImpersonationFloatingBanner(),
      ],
    );
  }

  Widget _buildHeroCard(double progress) {
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -58,
            child: Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -62,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withOpacity(0.72),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.today_outlined,
                          size: 14,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'rute selesai hari ini',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white.withOpacity(0.72),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.white.withOpacity(0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accentOrange,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$_completedTasks dari $_totalTasks titik telah diselesaikan',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white.withOpacity(0.72),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    _buildHeroStat(
                      Icons.route_outlined,
                      _totalTasks.toString(),
                      'Titik',
                    ),
                    _heroDivider(),
                    _buildHeroStat(
                      Icons.water_drop_outlined,
                      _compactLoadLabel,
                      'Muatan',
                      tooltip: _totalMinyak,
                    ),
                    _heroDivider(),
                    _buildHeroStat(
                      Icons.task_alt_outlined,
                      _completedTasks.toString(),
                      'Selesai',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      height: 38,
      width: 1,
      color: AppColors.white.withOpacity(0.2),
    );
  }

  String get _compactLoadLabel {
    final raw = double.tryParse(_totalMinyak.replaceAll(' kg', '').trim());
    if (raw == null) return _totalMinyak;
    if (raw >= 1000) {
      final value = (raw / 1000).toStringAsFixed(1).replaceFirst('.0', '');
      return '${value}K kg';
    }
    return '${raw.toStringAsFixed(0)} kg';
  }

  Widget _buildHeroStat(
    IconData icon,
    String value,
    String label, {
    String? tooltip,
  }) {
    return Expanded(
      child: Tooltip(
        message: tooltip ?? value,
        child: Column(
          children: [
            Icon(icon, color: AppColors.white.withOpacity(0.78), size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.h6.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withOpacity(0.75),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTmsQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pusat Operasional',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'TMS',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              _buildQuickActionButton(
                icon: Icons.receipt_long,
                color: AppColors.primaryGreen,
                label: 'Uang Jalan\n& Settlement',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverSettlementListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                icon: Icons.local_shipping,
                color: AppColors.accentOrange,
                label: 'Pergerakan\nTruk',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverMovementScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                icon: Icons.verified_user_rounded,
                color: const Color(0xFF1877F2),
                label: 'Nilai &\nRating',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverScoreScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                icon: Icons.on_device_training_outlined,
                color: const Color(0xFF7C4DFF),
                label: 'Diagnosa Koneksi & Sistem',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosisScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                icon: Icons.system_update_outlined,
                color: const Color(0xFF00897B),
                label: 'Cek Pembaruan Aplikasi',
                onTap: () {
                  UpdateService.instance.checkNow(context);
                },
              ),
              if (_canImpersonate) ...[
                const SizedBox(width: 8),
                _buildQuickActionButton(
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFFE65100),
                  label: 'Force Login / Pindah Akun',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ForceLoginDialog(),
                    );
                  },
                ),
              ],
              const SizedBox(width: 8),
              _buildPickupMapButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  Widget _buildPickupMapButton() {
    return _buildQuickActionButton(
      icon: Icons.map_outlined,
      color: AppColors.primaryGreen,
      label: 'Peta Lokasi Pickup',
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PickupMapScreen(
              driverPosition: _driverPosition,
              stops: _filteredStopsForMap,
              routePolyline: _routePolyline,
              onStopTap: (stop) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NavigationScreen(suratJalan: stop.surat),
                  ),
                );
                if (mounted) _loadSuratJalanData();
              },
            ),
          ),
        );
        if (mounted) _loadSuratJalanData();
      },
    );
  }

  Widget _buildSectionHeader(
    String title, {
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
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

  /// 1-based position of [stop] within the nearest-neighbor route order, or
  /// null if it's a done/cancelled stop (excluded from optimization).
  int? _routeOrderNumber(_RouteStop stop) {
    final status = stop.detail.status.toLowerCase();
    if (status == 'done' || status == 'cancelled') return null;
    final routable = _optimizedStops.where((s) {
      final st = s.detail.status.toLowerCase();
      return st != 'done' && st != 'cancelled';
    }).toList();
    final index = routable.indexOf(stop);
    return index == -1 ? null : index + 1;
  }

  Widget _stopPin(_RouteStop stop) {
    final status = stop.detail.status.toLowerCase();
    final color = status == 'done'
        ? AppColors.success
        : status == 'cancelled'
        ? AppColors.grey
        : status == 'pickup'
        ? const Color(0xFFFF9500)
        : AppColors.error;
    final orderNumber = _routeOrderNumber(stop);
    return Tooltip(
      message: '${stop.detail.supplierName}\n${stop.detail.status}',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: orderNumber != null
            ? Text(
                '$orderNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : Icon(
                status == 'done' ? Icons.check : Icons.close,
                color: Colors.white,
                size: 16,
              ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _statusFilter = value;
        _sjCurrentPage = 1;
      }),
      selectedColor: AppColors.primaryGreen.withOpacity(0.15),
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: selected ? AppColors.primaryGreen : AppColors.grey,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryGreen : AppColors.borderColor,
      ),
      backgroundColor: AppColors.white,
    );
  }

  Widget _buildStopCard(_RouteStop stop, int? orderNumber) {
    final surat = stop.surat;
    final detail = stop.detail;
    final status = detail.status.toLowerCase();
    final statusColor = status == 'done'
        ? AppColors.success
        : status == 'cancelled'
        ? AppColors.grey
        : status == 'pickup'
        ? const Color(0xFFFF9500)
        : AppColors.error;
    final statusText = status == 'done'
        ? 'Selesai'
        : status == 'cancelled'
        ? 'Batal'
        : status == 'pickup'
        ? 'Proses'
        : 'Pending';
    final distanceLabel = _driverPosition == null
        ? null
        : '${(Geolocator.distanceBetween(_driverPosition!.latitude, _driverPosition!.longitude, stop.position.latitude, stop.position.longitude) / 1000).toStringAsFixed(1)} km';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuratJalanDetailScreen(suratJalan: surat),
          ),
        );
        _loadSuratJalanData();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: orderNumber != null
                  ? Text(
                      '$orderNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    )
                  : Icon(
                      status == 'done' ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detail.supplierName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    surat.kode,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.scale, size: 14, color: AppColors.grey),
                          const SizedBox(width: 4),
                          Builder(
                            builder: (context) {
                              // qty_real is only filled in once the driver
                              // actually completes the pickup (weighed on
                              // site) — before that it's legitimately 0, so
                              // fall back to the planned qty (qty_order) as
                              // an estimate rather than showing "0.0 kg".
                              final hasReal =
                                  double.tryParse(detail.qtyReal) != null &&
                                  double.parse(detail.qtyReal) > 0;
                              final kgText = SuratJalanService.convertLiterToKg(
                                hasReal ? detail.qtyReal : detail.qtyOrder,
                              );
                              return Text(
                                hasReal ? '$kgText kg' : 'Estimasi $kgText kg',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.grey,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (distanceLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me_outlined,
                              size: 14,
                              color: AppColors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distanceLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          ],
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

  Widget _buildLegendItem(String label, Color color, String filterValue) {
    final isSelected = _statusFilter == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = filterValue;
          _sjCurrentPage = 1;
        });
        _fitMarkersInView();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : AppColors.darkGrey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single supplier pickup point — one SuratJalanDetail plus the parent
/// SuratJalan it belongs to, with its parsed GPS position. This is the unit
/// the nearest-neighbor route optimization and the flattened "Surat Jalan
/// Hari Ini" list both operate on, since GPS/status live per-stop rather
/// than per-delivery-note.
class _RouteStop {
  final SuratJalan surat;
  final SuratJalanDetail detail;
  final LatLng position;

  const _RouteStop({
    required this.surat,
    required this.detail,
    required this.position,
  });
}
