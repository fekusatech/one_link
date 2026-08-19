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
import 'surat_jalan_detail_screen.dart';
import '../services/persistent_auth_service.dart';
import '../services/user_storage.dart';
import 'navigation_screen.dart';
import 'notification_screen.dart';
import 'tms/driver_settlement_list_screen.dart';
import 'tms/driver_movement_screen.dart';
import 'profile_screen.dart';
import 'pickup_history_screen.dart';
import '../widgets/shared_bottom_navbar.dart';
import '../widgets/shared_app_bar.dart';
import '../widgets/gps_compliance_widget.dart';
import '../widgets/impersonation_banner.dart';
import '../widgets/dynamic_pickup_map_widget.dart';
import '../services/update_service.dart';
import '../services/location_tracking_service.dart';
import '../services/driver_tracking_service.dart';
import '../services/emergency_shake_service.dart';

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
    // Jalankan monitoring update & shake detector SOS di dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.startMonitoring(context);
      EmergencyShakeService.instance.startListening(context);
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

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      const _HomeScreen(),
      const PickupHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedIndex == 0
          ? SharedAppBar(
              dashboardType: 'driver',
              onNotificationTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
            )
          : null,
      body: screens[_selectedIndex],
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            InkWell(
              onTap: () async {
                await OfflineSyncService.syncNow();
                _checkConnectivityStatus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sync Sekarang',
                  style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
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

  void _fitMarkersInView() {
    if (_optimizedStops.isEmpty) return;
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final stop in _optimizedStops) {
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

  @override
  Widget build(BuildContext context) {
    final progress = _totalTasks == 0 ? 0.0 : _completedTasks / _totalTasks;

    return Column(
      children: [
        _buildConnectivityBanner(),
        Expanded(
          child: RefreshIndicator(
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
                    _buildLegendItem('Rute', const Color(0xFF1877F2)),
                  ],
                ),

                const SizedBox(height: 12),

                // Map view — flutter_map/OpenStreetMap, with a driving-route
                // polyline chained driver -> nearest -> next-nearest -> ...
                Container(
                  height: 280,
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
                  child: DynamicPickupMapWidget(
                    mapController: _mapController,
                    driverPosition: _driverPosition,
                    stops: _optimizedStops,
                    routePolyline: _routePolyline,
                    onMapReady: _fitMarkersInView,
                    onStopTap: (stop, order) async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NavigationScreen(
                            suratJalan: stop.surat,
                          ),
                        ),
                      );
                      _loadSuratJalanData();
                    },
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
                    hintStyle: AppTextStyles.caption.copyWith(color: AppColors.grey),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryGreen),
                    suffixIcon: _sjSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.grey),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
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
                    final filtered = _optimizedStops.where((stop) {
                      final status = stop.detail.status.toLowerCase();
                      bool matchStatus = true;
                      if (_statusFilter == 'proses') {
                        matchStatus = status != 'done' && status != 'cancelled';
                      } else if (_statusFilter == 'selesai') {
                        matchStatus = status == 'done';
                      }

                      if (!matchStatus) return false;

                      if (_sjSearchQuery.isNotEmpty) {
                        final name = stop.detail.supplierName.toLowerCase();
                        final address = stop.detail.supplierAlamat.toLowerCase();
                        final kode = stop.surat.kode.toLowerCase();
                        return name.contains(_sjSearchQuery) ||
                            address.contains(_sjSearchQuery) ||
                            kode.contains(_sjSearchQuery);
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
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
                    final totalPages = (totalItems / _sjPageSize).ceil();
                    final safePage = _sjCurrentPage.clamp(1, totalPages);
                    final startIndex = (safePage - 1) * _sjPageSize;
                    final endIndex = (startIndex + _sjPageSize > totalItems)
                        ? totalItems
                        : startIndex + _sjPageSize;
                    final paginatedList = filtered.sublist(startIndex, endIndex);

                    return Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paginatedList.length,
                          itemBuilder: (context, index) {
                            final stop = paginatedList[index];
                            return _buildStopCard(stop, _routeOrderNumber(stop));
                          },
                        ),
                        if (totalPages > 1) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item ${startIndex + 1}-$endIndex dari $totalItems',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, size: 20),
                                      onPressed: safePage > 1
                                          ? () => setState(() => _sjCurrentPage = safePage - 1)
                                          : null,
                                    ),
                                    Text(
                                      'Halaman $safePage / $totalPages',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, size: 20),
                                      onPressed: safePage < totalPages
                                          ? () => setState(() => _sjCurrentPage = safePage + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
    const ImpersonationFloatingBanner(),
  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildTmsQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layanan Operasional Driver (TMS)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.receipt_long,
                  color: AppColors.primaryGreen,
                  label: 'Uang Jalan &\nSettlement',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverSettlementListScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.local_shipping,
                  color: AppColors.accentOrange,
                  label: 'Milestone\nPergerakan Truk',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverMovementScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
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
                          borderRadius: BorderRadius.circular(20),
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
                          Text(
                            '${SuratJalanService.convertLiterToKg(detail.qtyReal)} kg',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey,
                            ),
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
