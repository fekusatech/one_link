import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/surat_jalan.dart';
import '../../services/user_storage.dart';
import '../../services/role_management_service.dart';
import '../../services/geu/driver_tracking_service.dart';
import '../surat_jalan_detail_screen.dart';

const kDriverMapAdminRoles = [
  'developer',
  'super user',
  'superuser',
  'admin',
  'koordinator logistik',
];

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _selfUserId;
  String? _selfUserName;

  @override
  void initState() {
    super.initState();
    _checkRoleAndInit();
  }

  Future<void> _checkRoleAndInit() async {
    final user = await UserStorage.getUser();
    final userId = await UserStorage.getUserId();
    final roleType = await RoleManagementService.analyzeUserRole();

    List<String> roles = [];
    if (user != null && user['groups'] != null) {
      roles = (user['groups'] as List).map((e) => e.toString().toLowerCase()).toList();
    }
    if (user != null && user['roles'] != null) {
      roles.addAll((user['roles'] as List).map((e) => e.toString().toLowerCase()));
    }

    bool isAdminRole = roleType == RoleType.admin ||
        roles.any((r) => kDriverMapAdminRoles.contains(r));

    if (mounted) {
      setState(() {
        _isAdmin = isAdminRole;
        _selfUserId = userId?.toString();
        _selfUserName = user?['name']?.toString() ?? 'Saya';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Peta Driver & Monitoring'),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_isAdmin) {
      return const AdminDriverMapView();
    } else {
      return DriverRouteDetailView(
        driverId: _selfUserId ?? '',
        driverName: _selfUserName ?? 'Saya',
        isSelf: true,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 1. ADMIN MAP VIEW (Live Monitoring All Drivers)
// ─────────────────────────────────────────────────────────────
class AdminDriverMapView extends StatefulWidget {
  const AdminDriverMapView({super.key});

  @override
  State<AdminDriverMapView> createState() => _AdminDriverMapViewState();
}

class _AdminDriverMapViewState extends State<AdminDriverMapView> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  List<TrackingLiveItem> _drivers = [];
  bool _loading = true;
  Timer? _pollingTimer;
  TrackingLiveItem? _selectedDriver;

  static const LatLng _defaultCenter = LatLng(-7.9797, 112.6304); // Default Malang/Java center

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLiveDrivers();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLiveDrivers();
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchLiveDrivers();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchLiveDrivers() async {
    final list = await GeuDriverTrackingService.getLiveTracking();
    if (mounted) {
      setState(() {
        _drivers = list;
        _loading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return const Color(0xFF28A745);
      case 'idle':
        return const Color(0xFFFFC107);
      case 'offline':
      default:
        return const Color(0xFFDC3545);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitoring Driver', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _fetchLiveDrivers();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _drivers.isNotEmpty
                  ? LatLng(_drivers.first.latitude, _drivers.first.longitude)
                  : _defaultCenter,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.one_link',
              ),
              MarkerLayer(
                markers: _drivers.map((driver) {
                  final isMoving = (driver.speed ?? 0) > 0;
                  final heading = driver.heading ?? 0;
                  final statusColor = _getStatusColor(driver.status);
                  final isSelected = _selectedDriver?.karyawanId == driver.karyawanId;

                  return Marker(
                    point: LatLng(driver.latitude, driver.longitude),
                    width: isSelected ? 50 : 44,
                    height: isSelected ? 50 : 44,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedDriver = driver);
                        _mapController.move(LatLng(driver.latitude, driver.longitude), 15.0);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.amber : Colors.white,
                                width: isSelected ? 3.5 : 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: isMoving
                                  ? Transform.rotate(
                                      angle: (heading * math.pi / 180),
                                      child: const Icon(
                                        Icons.navigation_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_pin_circle_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                            ),
                          ),
                          if (driver.isMonitoring)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          if (_loading)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Memperbarui posisi live...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Draggable Sheet with Driver List
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Daftar Driver (${_drivers.length})',
                            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '🔄 Auto-refresh 15s',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                    Expanded(
                      child: _drivers.isEmpty
                          ? Center(
                              child: Text(
                                _loading ? 'Memuat data driver...' : 'Tidak ada driver aktif saat ini',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: _drivers.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final d = _drivers[index];
                                final statusColor = _getStatusColor(d.status);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: 0.15),
                                    child: Icon(Icons.person, color: statusColor),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          d.status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${d.jabatanName} • ${d.vehiclePlat ?? "Armada -"}\nSpeed: ${(d.speed ?? 0).toStringAsFixed(1)} km/h • Baterai: ${d.batteryLevel ?? "-"}%',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DriverRouteDetailView(
                                          driverId: d.karyawanId,
                                          driverName: d.name,
                                          isSelf: false,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. DRIVER ROUTE DETAIL VIEW (Route History + Stops + Dwell Time)
// ─────────────────────────────────────────────────────────────
class DriverRouteDetailView extends StatefulWidget {
  final String driverId;
  final String driverName;
  final bool isSelf;

  const DriverRouteDetailView({
    super.key,
    required this.driverId,
    required this.driverName,
    this.isSelf = false,
  });

  @override
  State<DriverRouteDetailView> createState() => _DriverRouteDetailViewState();
}

class _DriverRouteDetailViewState extends State<DriverRouteDetailView> {
  final MapController _mapController = MapController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  List<TrackingHistoryItem> _historyPoints = [];
  List<SuratJalan> _suratJalanList = [];
  Map<String, int> _dwellTimeMinutes = {}; // Key: suratJalanDetailId -> dwell minutes

  static const LatLng _defaultCenter = LatLng(-7.9797, 112.6304);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final history = await GeuDriverTrackingService.getRouteHistory(
      karyawanId: widget.driverId,
      date: dateStr,
    );

    final sjList = await GeuDriverTrackingService.getDriverSuratJalan(
      dateFrom: dateStr,
      dateTo: dateStr,
      driverId: widget.driverId,
    );

    // Compute Dwell Time per stop (PRD 4.5.4)
    final dwellMap = _computeDwellTimes(history, sjList);

    if (mounted) {
      setState(() {
        _historyPoints = history;
        _suratJalanList = sjList;
        _dwellTimeMinutes = dwellMap;
        _loading = false;
      });
      _fitMapCamera();
    }
  }

  /// Dwell Time Computation per stop (PRD 4.5.4):
  /// Cluster GPS points within 150m of stop location.
  /// If gap between points > 10 mins, sum clusters into total dwell minutes.
  Map<String, int> _computeDwellTimes(
    List<TrackingHistoryItem> points,
    List<SuratJalan> sjList,
  ) {
    final Map<String, int> result = {};

    for (final sj in sjList) {
      for (final detail in sj.suratJalanDetail) {
        final gps = detail.supplierGps;
        if (gps.isEmpty || !gps.contains(',')) continue;

        final parts = gps.split(',');
        final targetLat = double.tryParse(parts[0].trim());
        final targetLng = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
        if (targetLat == null || targetLng == null) continue;

        List<DateTime> matchedTimes = [];
        for (final p in points) {
          if (p.createdAt == null) continue;
          final dist = Geolocator.distanceBetween(
            targetLat,
            targetLng,
            p.latitude,
            p.longitude,
          );
          if (dist <= 150.0) {
            matchedTimes.add(p.createdAt!);
          }
        }

        if (matchedTimes.length < 2) {
          result[detail.suratJalanDetailId] = 0;
          continue;
        }

        matchedTimes.sort();
        const maxGapSeconds = 10 * 60;
        int totalSeconds = 0;
        DateTime clusterStart = matchedTimes[0];
        DateTime prev = matchedTimes[0];

        for (int i = 1; i < matchedTimes.length; i++) {
          final gap = matchedTimes[i].difference(prev).inSeconds;
          if (gap > maxGapSeconds) {
            totalSeconds += prev.difference(clusterStart).inSeconds;
            clusterStart = matchedTimes[i];
          }
          prev = matchedTimes[i];
        }
        totalSeconds += prev.difference(clusterStart).inSeconds;

        final dwellMins = (totalSeconds / 60.0).round();
        result[detail.suratJalanDetailId] = dwellMins;
      }
    }

    return result;
  }

  void _fitMapCamera() {
    List<LatLng> allPoints = [];

    for (final h in _historyPoints) {
      allPoints.add(LatLng(h.latitude, h.longitude));
    }

    for (final sj in _suratJalanList) {
      for (final d in sj.suratJalanDetail) {
        final parts = d.supplierGps.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            allPoints.add(LatLng(lat, lng));
          }
        }
      }
    }

    if (allPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return const Color(0xFF28A745);
      case 'pickup':
        return const Color(0xFF17A2B8);
      case 'progress':
        return const Color(0xFF8B5CF6);
      case 'cancel':
      case 'cancelled':
      default:
        return const Color(0xFF6C757D);
    }
  }

  void _checkRoutePointTap(LatLng tapPoint) {
    if (_historyPoints.isEmpty) return;

    TrackingHistoryItem? closestPoint;
    double minDistance = double.infinity;

    for (final p in _historyPoints) {
      final dist = Geolocator.distanceBetween(
        tapPoint.latitude,
        tapPoint.longitude,
        p.latitude,
        p.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestPoint = p;
      }
    }

    if (closestPoint != null && minDistance <= 300) {
      final timeStr = closestPoint.createdAt != null
          ? DateFormat('HH:mm:ss').format(closestPoint.createdAt!)
          : '-';
      final speedStr = (closestPoint.speed ?? 0).toStringAsFixed(1);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Waktu: $timeStr • Kecepatan: $speedStr km/h',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);

    // Build polylines
    final blueActualPoints = _historyPoints.map((h) => LatLng(h.latitude, h.longitude)).toList();

    // Destination pins
    List<Map<String, dynamic>> stops = [];
    int ownStopCounter = 1;

    for (final sj in _suratJalanList) {
      for (final detail in sj.suratJalanDetail) {
        final parts = detail.supplierGps.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            // Compare by ID, not name — sj.driverName isn't reliably
            // populated (only the List endpoint's JOIN has it, not
            // getById()), and even when it is, name collisions between two
            // different drivers would silently misattribute a stop.
            final isOwn = sj.driverId != null && sj.driverId == widget.driverId;
            stops.add({
              'index': isOwn ? ownStopCounter++ : null,
              'latLng': LatLng(lat, lng),
              'detail': detail,
              'suratJalan': sj,
              'isOwn': isOwn,
            });
          }
        }
      }
    }

    // Red estimated polyline (PRD 4.5.3: Current position -> pending own stops)
    List<LatLng> redEstimatedPoints = [];
    if (blueActualPoints.isNotEmpty) {
      final currentPos = blueActualPoints.last;
      for (final item in stops) {
        final detail = item['detail'] as SuratJalanDetail;
        final isOwn = item['isOwn'] as bool;
        final status = detail.status.toLowerCase();
        if (isOwn && (status == 'progress' || status == 'pickup')) {
          if (redEstimatedPoints.isEmpty) {
            redEstimatedPoints.add(currentPos);
          }
          redEstimatedPoints.add(item['latLng'] as LatLng);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isSelf ? 'Peta Rute Saya' : 'Rute: ${widget.driverName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: blueActualPoints.isNotEmpty ? blueActualPoints.last : _defaultCenter,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                _checkRoutePointTap(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.one_link',
              ),

              // Actual GPS Blue Solid & Estimated Red Polyline (PRD 4.5.3)
              PolylineLayer(
                polylines: [
                  if (blueActualPoints.length >= 2)
                    Polyline(
                      points: blueActualPoints,
                      color: const Color(0xFF007BFF),
                      strokeWidth: 5.5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  if (redEstimatedPoints.length >= 2)
                    Polyline(
                      points: redEstimatedPoints,
                      color: const Color(0xFFDC3545),
                      strokeWidth: 3.5,
                    ),
                ],
              ),

              // Destination Stop Markers
              MarkerLayer(
                markers: stops.map((item) {
                  final detail = item['detail'] as SuratJalanDetail;
                  final statusColor = _getStatusColor(detail.status);
                  final index = item['index'] as int?;
                  final isOwn = item['isOwn'] as bool;

                  return Marker(
                    point: item['latLng'] as LatLng,
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () {
                        _showStopDetailModal(detail, item['suratJalan'] as SuratJalan);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          // Dashed-looking lighter border marks a teammate's
                          // stop (same gudang, not this driver's own job).
                          border: Border.all(
                            color: isOwn ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            width: isOwn ? 2.5 : 1.5,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        alignment: Alignment.center,
                        child: isOwn
                            ? Text(
                                '$index',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              )
                            : const Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),

          // Bottom Sheet with Stop List & Dwell Time
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Tujuan Penjemputan (${stops.length})',
                            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                    Expanded(
                      child: stops.isEmpty
                          ? Center(
                              child: Text(
                                _loading
                                    ? 'Memuat data rute...'
                                    : 'Tidak ada tujuan penjemputan pada tanggal ini',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: stops.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = stops[index];
                                final detail = item['detail'] as SuratJalanDetail;
                                final sj = item['suratJalan'] as SuratJalan;
                                final statusColor = _getStatusColor(detail.status);
                                final dwellMins = _dwellTimeMinutes[detail.suratJalanDetailId] ?? 0;
                                final isOwn = item['isOwn'] as bool;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor,
                                    radius: 14,
                                    child: isOwn
                                        ? Text(
                                            '${item['index']}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          )
                                        : const Icon(Icons.people_alt_rounded, color: Colors.white, size: 14),
                                  ),
                                  title: Text(
                                    detail.supplierName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${sj.kode} • ${detail.supplierAlamat}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (!isOwn && sj.driverName.isNotEmpty && sj.driverName != '-')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${sj.driverName} (tim gudang sama)',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ),
                                      if (dwellMins > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '⏱️ Terpantau $dwellMins Menit di lokasi',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      detail.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SuratJalanDetailScreen(suratJalan: sj),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStopDetailModal(SuratJalanDetail detail, SuratJalan sj) {
    final dwellMins = _dwellTimeMinutes[detail.suratJalanDetailId] ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.supplierName,
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No. SJ: ${sj.kode}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    detail.supplierAlamat,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (dwellMins > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.accentOrange, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Waktu Terpantau di Lokasi: $dwellMins Menit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuratJalanDetailScreen(suratJalan: sj),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_outlined, color: Colors.white),
                label: const Text(
                  'Buka Surat Jalan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
