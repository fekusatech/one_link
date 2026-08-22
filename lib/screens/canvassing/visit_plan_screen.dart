import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/haversine.dart';
import '../../services/geu/reverse_geocoding_service.dart';
import '../../services/geu/active_visit_service.dart';
import '../../services/geu/visit_navigation_service.dart';
import '../../services/geu/mission_navigation_state.dart';
import '../../services/geu/visit_planner_service.dart';
import '../../services/geu/settings_service.dart';
import '../../services/geu/visit_sync_service.dart';
import 'add_work_order_sheet.dart';
import 'checkin_dialog.dart';
import 'checkout_dialog.dart';
import 'mission_today_screen.dart';
import 'scan_prospect_screen.dart';
import 'skip_mission_sheet.dart';

/// Mobile-first entry point mirroring CRM web's Visit Planner: map first,
/// compact legend/status overlay, and today's visit summary at the bottom.
class VisitPlanScreen extends StatefulWidget {
  const VisitPlanScreen({super.key});
  @override
  State<VisitPlanScreen> createState() => _VisitPlanScreenState();
}

class _VisitPlanScreenState extends State<VisitPlanScreen> {
  // A safe initial value prevents the GPS stream from rebuilding the map
  // before the remote distance_radius_map setting has finished loading.
  int _supplierRadiusMeters = 1000;
  TodaysMission? _mission;
  LatLng? _user;
  double _headingDegrees = 0;
  List<NearbySupplier> _databaseSuppliers = const [];
  List<ScannedProspect> _scannedProspects = const [];
  final MapController _map = MapController();
  bool _loading = true;
  bool _missionActive = false;
  MissionItem? _navigationTarget;
  List<LatLng> _drivingRoute = const [];
  LatLng? _routeOrigin;
  StreamSubscription<GpsFix>? _navigationLocationSubscription;
  StreamSubscription<GpsFix>? _mapLocationSubscription;
  StreamSubscription<MagnetometerEvent>? _compassSubscription;
  int? _addingSupplierId;
  LatLng? _searchCenter;
  bool _isAdmin = false;
  bool _showRecenter = false;
  bool _hidePoo = false;
  LatLng? _lastNearbyQueryPoint;
  int _nearbyRequestId = 0;
  LatLng? _lastMovementPoint;
  DateTime? _lastMovementAt;

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
    _startCompassUpdates();
    _load();
    unawaited(_startMapLocationUpdates());
  }

  void _startCompassUpdates() {
    _compassSubscription =
        magnetometerEventStream(
          samplingPeriod: const Duration(milliseconds: 200),
        ).listen((event) {
          final magnitude = math.sqrt(event.x * event.x + event.y * event.y);
          if (!mounted || magnitude < 1) return;
          // Use the compass only while standing still. While moving, the
          // bearing between GPS fixes is more reliable than phone orientation.
          final movementAt = _lastMovementAt;
          if (movementAt != null &&
              DateTime.now().difference(movementAt).inSeconds < 4) {
            return;
          }
          var heading = math.atan2(event.y, event.x) * 180 / math.pi;
          if (heading < 0) heading += 360;
          setState(() => _headingDegrees = heading);
        });
  }

  double? _updateMovementHeading(LatLng point) {
    final previous = _lastMovementPoint;
    _lastMovementPoint = point;
    if (previous == null) return null;
    final distance = haversineDistanceKm(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    if (distance < .003) return null;
    final lat1 = previous.latitude * math.pi / 180;
    final lat2 = point.latitude * math.pi / 180;
    final dLng = (point.longitude - previous.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    var bearing = math.atan2(y, x) * 180 / math.pi;
    if (bearing < 0) bearing += 360;
    _lastMovementAt = DateTime.now();
    return bearing;
  }

  Future<void> _loadAdminAccess() async {
    final user = await GeuAuthService.getCachedUser();
    final isAdmin = (user?.roles ?? []).any(
      (role) => [
        'admin',
        'developer',
        'superuser',
      ].any((keyword) => role.toLowerCase().contains(keyword)),
    );
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final radiusKm = await SettingsService.getDouble('distance_radius_map');
      if (radiusKm == null) {
        throw StateError('Radius scanner belum tersedia dari server.');
      }
      _supplierRadiusMeters = (radiusKm * 1000).round();
      final mission = await VisitPlannerService.getTodaysMission();
      GpsFix? fix;
      try {
        fix = await GpsService.getCurrentFix();
      } catch (_) {
        // Mission markers remain useful when GPS is unavailable.
      }
      List<NearbySupplier> suppliers = const [];
      final queryCenter =
          _searchCenter ??
          (fix == null ? null : LatLng(fix.latitude, fix.longitude));
      if (queryCenter != null) {
        _lastNearbyQueryPoint = queryCenter;
        try {
          suppliers = await VisitPlannerService.getNearbySuppliers(
            latitude: queryCenter.latitude,
            longitude: queryCenter.longitude,
            radiusMeters: _supplierRadiusMeters,
          );
        } catch (_) {
          // The mission remains usable if the database map query is offline.
        }
      }
      if (!mounted) return;
      setState(() {
        _mission = mission;
        _user = queryCenter;
        _headingDegrees = fix?.headingDegrees ?? 0;
        _databaseSuppliers = suppliers;
      });
      MissionNavigationStateService.refresh(mission.items);
      final center =
          _user ??
          (mission.items.where((item) => item.hasCoordinates).isNotEmpty
              ? LatLng(
                  mission.items.firstWhere((item) => item.hasCoordinates).lat!,
                  mission.items.firstWhere((item) => item.hasCoordinates).lng!,
                )
              : const LatLng(-7.9666, 112.6326));
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _map.move(center, 15),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _navigationLocationSubscription?.cancel();
    _mapLocationSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  /// Keeps the driver map's radius circle and supplier markings aligned with
  /// the moving GPS position. Admins can still pin a manual search center;
  /// normal users always follow their current location.
  Future<void> _startMapLocationUpdates() async {
    try {
      final positions = await GpsService.watchPosition();
      _mapLocationSubscription = positions.listen((fix) {
        if (!mounted || _missionActive || _searchCenter != null) return;
        final point = LatLng(fix.latitude, fix.longitude);
        final bearing = _updateMovementHeading(point);
        final previous = _lastNearbyQueryPoint;
        if (previous != null &&
            haversineDistanceKm(
                  previous.latitude,
                  previous.longitude,
                  point.latitude,
                  point.longitude,
                ) <
                .05) {
          if (mounted) {
            setState(() {
              _user = point;
              if (bearing != null) _headingDegrees = bearing;
            });
          }
          return;
        }
        _lastNearbyQueryPoint = point;
        setState(() {
          _user = point;
          _headingDegrees = bearing ?? _headingDegrees;
          _showRecenter = false;
        });
        _map.move(point, 15);
        unawaited(_refreshNearbySuppliers(point));
      });
    } catch (_) {
      // The initial load already reports location errors where appropriate.
    }
  }

  Future<void> _refreshNearbySuppliers(LatLng point) async {
    final requestId = ++_nearbyRequestId;
    try {
      final suppliers = await VisitPlannerService.getNearbySuppliers(
        latitude: point.latitude,
        longitude: point.longitude,
        radiusMeters: _supplierRadiusMeters,
      );
      if (!mounted || requestId != _nearbyRequestId || _searchCenter != null) {
        return;
      }
      setState(() => _databaseSuppliers = suppliers);
    } catch (_) {
      // Keep the last known markings when a location refresh is offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        _mission?.items.where((item) => item.hasCoordinates).toList() ??
        <MissionItem>[];
    final missionItems = _mission?.items ?? const <MissionItem>[];
    final activeMissionSupplierIds = missionItems
        .where((item) {
          final status = item.status.toUpperCase();
          return item.supplierId > 0 &&
              status != 'VISITED' &&
              status != 'SKIPPED';
        })
        .map((item) => item.supplierId)
        .toSet();
    final center =
        _user ??
        (items.isNotEmpty
            ? LatLng(items.first.lat!, items.first.lng!)
            : const LatLng(-7.9666, 112.6326));
    final visited = missionItems
        .where((item) => item.status.toUpperCase() == 'VISITED')
        .length;
    final skipped = missionItems
        .where((item) => item.status.toUpperCase() == 'SKIPPED')
        .length;
    final remaining = missionItems.where((item) {
      final status = item.status.toUpperCase();
      return status != 'VISITED' && status != 'SKIPPED';
    }).length;
    final visibleVisitCount = missionItems.length - skipped;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && !_showRecenter) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _showRecenter = true);
                  });
                }
              },
              onTap: (_, point) {
                if (_isAdmin && !_missionActive) _setSearchCenter(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.one_link',
              ),
              if (_user != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _user!,
                      radius: _supplierRadiusMeters.toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.info.withValues(alpha: 0.10),
                      borderColor: AppColors.info.withValues(alpha: 0.72),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (_missionActive && _drivingRoute.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _drivingRoute,
                      color: const Color(0xFF1877F2),
                      strokeWidth: 6,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (!_missionActive && !_hidePoo)
                    for (final supplier in _databaseSuppliers)
                      if (!activeMissionSupplierIds.contains(supplier.id) &&
                          supplier.latitude != null &&
                          supplier.longitude != null)
                        Marker(
                          point: LatLng(
                            supplier.latitude!,
                            supplier.longitude!,
                          ),
                          width: 42,
                          height: 50,
                          child: GestureDetector(
                            onTap: () => _showSupplierDetails(supplier),
                            child: _mapPin(
                              supplier.badge.toUpperCase() == 'DALAM_30'
                                  ? const Color(0xFF2196F3)
                                  : const Color(0xFFFF9800),
                              Icons.storefront,
                              tooltip:
                                  '${supplier.name}\n${supplier.type} • ${supplier.distanceKm.toStringAsFixed(1)} km',
                            ),
                          ),
                        ),
                  if (!_missionActive)
                    for (final prospect in _scannedProspects)
                      if (prospect.latitude != null &&
                          prospect.longitude != null)
                        Marker(
                          point: LatLng(
                            prospect.latitude!,
                            prospect.longitude!,
                          ),
                          width: 44,
                          height: 52,
                          child: _mapPin(
                            const Color(0xFFE85D75),
                            Icons.radar_rounded,
                            tooltip: '${prospect.name}\nProspek hasil scan',
                          ),
                        ),
                  if (_missionActive)
                    for (final item in items)
                      if (item.status.toUpperCase() != 'SKIPPED')
                        Marker(
                          point: LatLng(item.lat!, item.lng!),
                          width: 44,
                          height: 52,
                          child: _mapPin(
                            item == _navigationTarget
                                ? AppColors.primaryGreen
                                : const Color(0xFF2196F3),
                            Icons.flag,
                            tooltip: '${item.supplierName}\n${item.status}',
                          ),
                        ),
                  if (_user != null)
                    Marker(
                      point: _user!,
                      width: 34,
                      height: 34,
                      child: Transform.rotate(
                        angle: _headingDegrees * math.pi / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_missionActive)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _missionStatusPill(),
                    ),
                  const Spacer(),
                  if (_loading)
                    const CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Daftar kunjungan hari ini',
                    hint: 'Geser ke atas atau ketuk kartu untuk membuka daftar',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _mission == null ? null : _openVisits,
                      onVerticalDragEnd: _mission == null
                          ? null
                          : (details) {
                              if ((details.primaryVelocity ?? 0) < -100) {
                                _openVisits();
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 12),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.black,
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        remaining == 0
                                            ? 'Kunjungan hari ini selesai'
                                            : "Today's Visits",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        remaining == 0
                                            ? '$visited selesai${skipped > 0 ? ' • $skipped dilewati' : ''}'
                                            : '$visited / $visibleVisitCount visits',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_missionActive)
            Positioned(top: 66, left: 16, right: 16, child: _mapLegend()),
          Positioned(
            top: 92,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'scan-prospect-map',
              tooltip: 'Scan prospek di sekitar',
              onPressed: _openScanCenterSheet,
              backgroundColor: const Color(0xFF287EF0),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.radar_rounded, size: 24),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 126,
            child: FloatingActionButton(
              heroTag: 'register-supplier',
              tooltip: 'Daftarkan supplier',
              onPressed: _openRegisterSupplier,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
          if (_showRecenter && _user != null)
            Positioned(
              right: 20,
              bottom: 194,
              child: FloatingActionButton.small(
                heroTag: 'recenter-user-location',
                tooltip: 'Kembali ke posisi saya',
                onPressed: () {
                  _map.move(_user!, _missionActive ? 17 : 15);
                  setState(() => _showRecenter = false);
                },
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreen,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openVisits() async {
    final items = _mission?.items ?? const <MissionItem>[];
    final hasRemaining = items.any((item) {
      final status = item.status.toUpperCase();
      return status != 'VISITED' && status != 'SKIPPED';
    });
    if (!hasRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Semua kunjungan hari ini sudah selesai atau dilewati.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TodayVisitsSheet(
        items: items
            .where((item) => item.status.toUpperCase() != 'SKIPPED')
            .toList(),
        userPosition: _user,
        missionActive: _missionActive,
        onOpenMission: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MissionTodayScreen()),
        ),
        onMissionActiveChanged: _setMissionActive,
        onMissionChanged: _load,
        onStartDriving: _startDrivingMode,
      ),
    );
  }

  void _setMissionActive(bool active, {MissionItem? target}) {
    setState(() {
      _missionActive = active;
      if (!active) {
        _navigationTarget = null;
        _drivingRoute = const [];
        _routeOrigin = null;
      }
    });
    if (!active) {
      MissionNavigationStateService.end();
      _navigationLocationSubscription?.cancel();
      _navigationLocationSubscription = null;
      return;
    }
    final missionMarkers =
        _mission?.items.where((item) => item.hasCoordinates).toList() ??
        const <MissionItem>[];
    final point =
        target ?? (missionMarkers.isEmpty ? null : missionMarkers.first);
    if (point != null && point.hasCoordinates) {
      _map.move(LatLng(point.lat!, point.lng!), 15);
    }
  }

  Future<void> _startDrivingMode(MissionItem item) async {
    _setMissionActive(true, target: item);
    MissionNavigationStateService.start(
      destination: item,
      items: _mission?.items ?? const <MissionItem>[],
    );
    if (!item.hasCoordinates || _user == null) return;
    setState(() => _navigationTarget = item);
    await _refreshDrivingRoute();
    await _startNavigationLocationUpdates();
  }

  Future<void> _refreshDrivingRoute() async {
    final origin = _user;
    final target = _navigationTarget;
    if (origin == null || target == null || !target.hasCoordinates) return;
    final route = await VisitNavigationService.drivingRoute(
      origin: origin,
      destination: LatLng(target.lat!, target.lng!),
    );
    if (mounted && _missionActive && target == _navigationTarget) {
      setState(() {
        _drivingRoute = route;
        _routeOrigin = origin;
      });
    }
  }

  Future<void> _startNavigationLocationUpdates() async {
    await _navigationLocationSubscription?.cancel();
    try {
      final positions = await GpsService.watchPosition();
      _navigationLocationSubscription = positions.listen((fix) {
        if (!mounted || !_missionActive) return;
        final point = LatLng(fix.latitude, fix.longitude);
        final bearing = _updateMovementHeading(point);
        setState(() {
          _user = point;
          _headingDegrees = bearing ?? _headingDegrees;
        });
        _map.move(point, 17);
        final previousRouteOrigin = _routeOrigin;
        if (previousRouteOrigin == null ||
            haversineDistanceKm(
                  previousRouteOrigin.latitude,
                  previousRouteOrigin.longitude,
                  point.latitude,
                  point.longitude,
                ) >=
                .10) {
          unawaited(_refreshDrivingRoute());
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Widget _missionStatusPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.primaryGreen,
          child: Icon(Icons.navigation, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 210,
          child: _MissionDestinationLabel(
            destination:
                _navigationTarget?.supplierName ?? 'Menentukan tujuan…',
          ),
        ),
      ],
    ),
  );

  Widget _mapLegend() => Align(
    child: Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LegendDot(
            color: Color(0xFF2196F3),
            label: 'Supplier (PO done < 30 days)',
          ),
          const _LegendDot(
            color: Color(0xFFFF9800),
            label: 'Supplier (PO done > 30 days / none)',
          ),
          const _LegendDot(color: Color(0xFFF44336), label: 'Scan Result'),
        ],
      ),
    ),
  );

  Future<void> _openScanCenterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final visited =
                  _mission?.items
                      .where((item) => item.status.toUpperCase() == 'VISITED')
                      .length ??
                  0;
              final total = _mission?.items.length ?? 0;
              final radiusLabel = _supplierRadiusMeters >= 1000
                  ? '${(_supplierRadiusMeters / 1000).toStringAsFixed(1).replaceAll('.0', '')} km'
                  : '${_supplierRadiusMeters} m';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.circle, color: Color(0xFF287EF0), size: 11),
                      SizedBox(width: 8),
                      Text(
                        'Online',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          Icons.radar_rounded,
                          '${_scannedProspects.length}',
                          'Scan results',
                          const Color(0xFFFF6B00),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          Icons.trending_up_rounded,
                          total == 0
                              ? '0%'
                              : '${(visited * 100 / total).round()}%',
                          'Mission progress',
                          const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          Icons.gps_fixed_rounded,
                          radiusLabel,
                          'Radius',
                          const Color(0xFFFF6B00),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          Icons.pending_actions_rounded,
                          '${total - visited}',
                          'Pending',
                          const Color(0xFFFFB000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                    title: const Text(
                      'Hide POO',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: _hidePoo,
                    onChanged: (value) {
                      setState(() => _hidePoo = value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openProspectScanner();
                      },
                      icon: const Icon(Icons.radar_rounded),
                      label: const Text('Mulai scan prospek'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE4E7EC)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _openProspectScanner() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: false,
      builder: (_) => ScanProspectScreen(
        asSheet: true,
        onScanSaved: (job, prospects) async {
          if (!mounted) return;
          setState(() {
            final existing = _scannedProspects
                .where((item) => !prospects.any((p) => p.id == item.id))
                .toList();
            _scannedProspects = [...existing, ...prospects];
          });
        },
      ),
    );
  }

  Future<void> _setSearchCenter(LatLng point) async {
    setState(() => _searchCenter = point);
    _map.move(point, 15);
    await _load();
  }

  Future<void> _openCoordinateInput() async {
    final current = _user;
    final controller = TextEditingController(
      text: current == null
          ? ''
          : '${current.latitude.toStringAsFixed(6)}, ${current.longitude.toStringAsFixed(6)}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Titik radius supplier'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Latitude, Longitude',
            hintText: '-7.985445, 112.683944',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final parts = controller.text.split(',');
              final lat = parts.isEmpty
                  ? null
                  : double.tryParse(parts[0].trim());
              final lng = parts.length < 2
                  ? null
                  : double.tryParse(parts[1].trim());
              if (lat == null ||
                  lng == null ||
                  lat.abs() > 90 ||
                  lng.abs() > 180)
                return;
              Navigator.pop(dialogContext);
              _setSearchCenter(LatLng(lat, lng));
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openRegisterSupplier() async {
    final point = _user;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi GPS diperlukan untuk registrasi supplier.'),
        ),
      );
      return;
    }
    var initialAddress =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    try {
      initialAddress = await ReverseGeocodingService.resolve(
        point.latitude,
        point.longitude,
      );
    } catch (_) {
      // Coordinates remain a useful offline fallback.
    }
    if (!mounted) return;
    List<BankOption> banks = const [];
    try {
      banks = await VisitPlannerService.getBanks();
    } catch (_) {
      // The optional account section remains usable after a later retry.
    }
    if (!mounted) return;
    final name = TextEditingController();
    final address = TextEditingController(text: initialAddress);
    final employee = TextEditingController();
    final position = TextEditingController();
    final phone = TextEditingController();
    final accountName = TextEditingController();
    final accountNumber = TextEditingController();
    var submitting = false;
    var validatingAccount = false;
    BankOption? selectedBank;
    String? accountValidationMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (name.text.trim().isEmpty ||
                employee.text.trim().isEmpty ||
                position.text.trim().isEmpty)
              return;
            setDialogState(() => submitting = true);
            try {
              final supplierId = await VisitPlannerService.registerProspect(
                name: name.text.trim(),
                address: address.text.trim(),
                phone: phone.text.trim(),
                latitude: point.latitude,
                longitude: point.longitude,
                employeeName: employee.text.trim(),
                employeePosition: position.text.trim(),
                accountName: accountName.text.trim(),
                accountNumber: accountNumber.text.trim(),
                bankId: selectedBank?.id,
              );
              await VisitPlannerService.addSupplierToMission(supplierId);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              await _load();
              if (mounted)
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${name.text.trim()} ditambahkan ke Mission.',
                    ),
                  ),
                );
            } catch (error) {
              if (dialogContext.mounted)
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
            } finally {
              if (dialogContext.mounted)
                setDialogState(() => submitting = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Supplier',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tambahkan supplier baru ke mission',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _field(name, 'Nama Supplier *'),
                    _field(address, 'Alamat', maxLines: 2),
                    const SizedBox(height: 18),
                    _dialogSectionHeader(
                      Icons.contact_phone_outlined,
                      'Kontak PIC',
                    ),
                    _field(employee, 'Nama Karyawan *'),
                    _field(position, 'Jabatan *'),
                    _field(
                      phone,
                      'Nomor Telepon',
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 18),
                    _dialogSectionHeader(
                      Icons.account_balance_outlined,
                      'Rekening opsional',
                    ),
                    _field(accountName, 'Nama Pemilik Rekening'),
                    _field(
                      accountNumber,
                      'Nomor Rekening',
                      keyboard: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<BankOption>(
                      value: selectedBank,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Bank',
                        border: OutlineInputBorder(),
                      ),
                      items: banks
                          .map(
                            (bank) => DropdownMenuItem(
                              value: bank,
                              child: Text('${bank.name} (${bank.code})'),
                            ),
                          )
                          .toList(),
                      onChanged: submitting || validatingAccount
                          ? null
                          : (bank) => setDialogState(() {
                              selectedBank = bank;
                              accountValidationMessage = null;
                            }),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: validatingAccount
                            ? null
                            : () async {
                                if (accountNumber.text.trim().isEmpty ||
                                    selectedBank == null) {
                                  setDialogState(
                                    () => accountValidationMessage =
                                        'Isi nomor rekening dan pilih bank terlebih dahulu.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  validatingAccount = true;
                                  accountValidationMessage = null;
                                });
                                try {
                                  final result =
                                      await VisitPlannerService.validateBankAccount(
                                        accountNumber: accountNumber.text
                                            .trim(),
                                        bankCode: selectedBank!.code,
                                        accountName: accountName.text.trim(),
                                      );
                                  if (!dialogContext.mounted) return;
                                  setDialogState(
                                    () =>
                                        accountValidationMessage = result.valid
                                        ? '✓ ${result.accountName}'
                                        : '✗ Rekening tidak valid.',
                                  );
                                } catch (error) {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => accountValidationMessage =
                                          '✗ ${error.toString()}',
                                    );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => validatingAccount = false,
                                    );
                                  }
                                }
                              },
                        icon: validatingAccount
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          validatingAccount
                              ? 'Memvalidasi...'
                              : 'Validasi rekening',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (accountValidationMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (accountValidationMessage!.startsWith('✓')
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          accountValidationMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accountValidationMessage!.startsWith('✓')
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: submitting ? null : submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        submitting ? 'Menyimpan...' : 'Tambah ke Mission',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    address.dispose();
    employee.dispose();
    position.dispose();
    phone.dispose();
    accountName.dispose();
    accountNumber.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primaryGreen.withOpacity(0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primaryGreen.withOpacity(0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
    ),
  );

  Widget _dialogSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primaryGreen),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupplierDetails(NearbySupplier supplier) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Detail Supplier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                supplier.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _supplierDetailRow(Icons.location_on_outlined, supplier.address),
              if (supplier.phone.trim().isNotEmpty)
                _supplierDetailRow(Icons.phone_outlined, supplier.phone),
              _supplierDetailRow(
                Icons.straighten_outlined,
                'Jarak ${supplier.distanceKm.toStringAsFixed(2)} km',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addingSupplierId == supplier.id
                      ? null
                      : () => _addSupplierToMission(supplier, sheetContext),
                  icon: _addingSupplierId == supplier.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _addingSupplierId == supplier.id
                        ? 'Menambahkan...'
                        : 'Tambah ke Mission',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supplierDetailRow(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
      ],
    ),
  );

  Future<void> _addSupplierToMission(
    NearbySupplier supplier,
    BuildContext sheetContext,
  ) async {
    setState(() => _addingSupplierId = supplier.id);
    try {
      await VisitPlannerService.addSupplierToMission(supplier.id);
      if (!mounted) return;
      Navigator.pop(sheetContext);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${supplier.name} ditambahkan ke Mission.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _addingSupplierId = null);
    }
  }

  Widget _mapPin(Color color, IconData icon, {required String tooltip}) =>
      Tooltip(
        message: tooltip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 6),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            CustomPaint(
              size: const Size(16, 10),
              painter: _PinTailPainter(color),
            ),
          ],
        ),
      );
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _MissionDestinationLabel extends StatelessWidget {
  final String destination;
  const _MissionDestinationLabel({required this.destination});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Tujuan: $destination',
    child: Text(
      'Tujuan: $destination',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class _TodayVisitsSheet extends StatefulWidget {
  final List<MissionItem> items;
  final LatLng? userPosition;
  final bool missionActive;
  final VoidCallback onOpenMission;
  final ValueChanged<bool> onMissionActiveChanged;
  final Future<void> Function() onMissionChanged;
  final Future<void> Function(MissionItem item) onStartDriving;
  const _TodayVisitsSheet({
    required this.items,
    required this.userPosition,
    required this.missionActive,
    required this.onOpenMission,
    required this.onMissionActiveChanged,
    required this.onMissionChanged,
    required this.onStartDriving,
  });

  @override
  State<_TodayVisitsSheet> createState() => _TodayVisitsSheetState();
}

class _TodayVisitsSheetState extends State<_TodayVisitsSheet> {
  late List<MissionItem> _items = List.of(widget.items);
  late bool _missionStarted = widget.missionActive;
  double _extent = .7;
  final Set<int> _workOrderSupplierIds = {};
  final List<int> _activeWorkOrderIds = [];
  int? _checkedInSupplierId;

  @override
  void initState() {
    super.initState();
    final active = ActiveVisitService.current.value;
    if (active.isActive) _checkedInSupplierId = active.supplierId;
  }

  MissionItem? get _nextStop {
    for (final item in _items) {
      final status = item.status.toUpperCase();
      if (status != 'VISITED' && status != 'SKIPPED') return item;
    }
    return null;
  }

  Future<void> _openAddWorkOrder(MissionItem item) async {
    final workOrderId = await showAddWorkOrderSheet(context, item);
    if (workOrderId == null || !mounted) return;
    setState(() {
      _workOrderSupplierIds.add(item.supplierId);
      _activeWorkOrderIds.add(workOrderId);
    });
    await _refreshMission();
  }

  bool _hasWorkOrder(MissionItem item) =>
      item.workOrderId != null ||
      _workOrderSupplierIds.contains(item.supplierId);

  bool _isCheckedInAt(MissionItem item) =>
      _checkedInSupplierId == item.supplierId;

  Future<void> _checkIn(MissionItem item) async {
    final draft = await showCheckinDialog(context, item);
    if (draft == null || !mounted) return;
    try {
      final address = await ReverseGeocodingService.resolve(
        draft.fix.latitude,
        draft.fix.longitude,
      );
      await VisitSyncService.enqueueCheckin(
        supplierId: item.supplierId,
        latitude: draft.fix.latitude,
        longitude: draft.fix.longitude,
        address: address,
        photoPath: draft.photo.file.path,
        gpsAccuracyMeters: draft.fix.accuracyMeters,
        isMockLocation: draft.fix.isMocked,
      );
      ActiveVisitService.markPendingCheckin(item.supplierId);
      await VisitSyncService.syncNow();
      if (!mounted) return;
      setState(() => _checkedInSupplierId = item.supplierId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in berhasil disimpan.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _checkOut(MissionItem item) async {
    final draft = await showCheckoutDialog(context, item);
    if (draft == null || !mounted) return;
    try {
      final address = await ReverseGeocodingService.resolve(
        draft.fix.latitude,
        draft.fix.longitude,
      );
      await VisitSyncService.enqueueCheckout(
        latitude: draft.fix.latitude,
        longitude: draft.fix.longitude,
        address: address,
        notes: draft.notes,
        photoPath: draft.photo.file.path,
        workOrderIds: _activeWorkOrderIds,
        gpsAccuracyMeters: draft.fix.accuracyMeters,
        isMockLocation: draft.fix.isMocked,
      );
      await VisitSyncService.syncNow();
      await VisitPlannerService.updateMissionStatus(
        planDetailId: item.planDetailId,
        status: 'VISITED',
      );
      ActiveVisitService.markCheckoutQueued();
      if (!mounted) return;
      setState(() {
        _checkedInSupplierId = null;
        _activeWorkOrderIds.clear();
      });
      await _refreshMission();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-out berhasil disimpan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _refreshMission() async {
    await widget.onMissionChanged();
    try {
      final mission = await VisitPlannerService.getTodaysMission();
      if (mounted) setState(() => _items = List.of(mission.items));
    } catch (_) {
      // The parent preserves its existing mission data if the refresh is
      // temporarily offline; the successful action still remains visible.
    }
  }

  Future<void> _skipMission(MissionItem item) async {
    final draft = await showSkipMissionSheet(context, item);
    if (draft == null || !mounted) return;
    try {
      await VisitPlannerService.updateMissionStatus(
        planDetailId: item.planDetailId,
        status: 'SKIPPED',
        skipReason: draft.reason,
        rescheduleDate: draft.rescheduleDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${item.supplierName} dilewati.')));
      await _refreshMission();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _removeMission(MissionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus dari Mission?'),
        content: Text(
          '${item.supplierName} akan dihapus dari daftar kunjungan hari ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await VisitPlannerService.removeFromMission(item.planDetailId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.supplierName} dihapus dari Mission.')),
      );
      await _refreshMission();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _startMission() async {
    final start = widget.userPosition;
    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi Anda belum tersedia untuk optimasi rute.'),
        ),
      );
      return;
    }
    final candidates = _items
        .where(
          (item) =>
              item.hasCoordinates &&
              item.status.toUpperCase() != 'VISITED' &&
              item.status.toUpperCase() != 'SKIPPED',
        )
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada titik mission yang dapat dinavigasi.'),
        ),
      );
      return;
    }

    candidates.sort(
      (a, b) =>
          haversineDistanceKm(
            start.latitude,
            start.longitude,
            a.lat!,
            a.lng!,
          ).compareTo(
            haversineDistanceKm(
              start.latitude,
              start.longitude,
              b.lat!,
              b.lng!,
            ),
          ),
    );
    final next = candidates.first;
    setState(() {
      _items = [next, ..._items.where((item) => item != next)];
      _missionStarted = true;
    });
    widget.onMissionActiveChanged(true);
    await widget.onStartDriving(next);
  }

  Future<void> _endMission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Akhiri Mission?'),
        content: const Text(
          'Mode perjalanan akan diakhiri dan map kembali menampilkan supplier di sekitar Anda. Daftar mission hari ini tidak dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjutkan Mission'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End Mission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _missionStarted = false);
    widget.onMissionActiveChanged(false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final visited = _items
        .where((item) => item.status.toUpperCase() == 'VISITED')
        .length;
    return DraggableScrollableSheet(
      initialChildSize: .7,
      minChildSize: .18,
      maxChildSize: .94,
      builder: (_, scrollController) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (event) {
              if ((_extent - event.extent).abs() > .02)
                setState(() => _extent = event.extent);
              return false;
            },
            child: Material(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: _missionStarted && _extent <= .24
                  ? _buildMinimized(visited)
                  : Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _missionStarted
                                      ? 'Mission Aktif'
                                      : "Today's Visits",
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.keyboard_arrow_down),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$visited / ${_items.length} visits${_missionStarted ? ' • sedang berjalan' : ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Divider(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                  ),
                                  onPressed: _missionStarted
                                      ? _endMission
                                      : _startMission,
                                  icon: Icon(
                                    _missionStarted
                                        ? Icons.stop_circle_outlined
                                        : Icons.directions_car_filled_outlined,
                                  ),
                                  label: Text(
                                    _missionStarted
                                        ? 'End Mission'
                                        : 'Start Mission & Navigate',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = _items[index];
                              final isNext =
                                  _missionStarted && item == _nextStop;
                              final hasWorkOrder = _hasWorkOrder(item);
                              final isCheckedIn = _isCheckedInAt(item);
                              final canManage =
                                  item.status.toUpperCase() != 'VISITED' &&
                                  item.status.toUpperCase() != 'SKIPPED' &&
                                  !isCheckedIn;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      width: 4,
                                      color:
                                          item.status.toUpperCase() == 'VISITED'
                                          ? AppColors.success
                                          : AppColors.primaryGreen,
                                    ),
                                  ),
                                  color: isNext
                                      ? AppColors.primaryGreen.withValues(
                                          alpha: .10,
                                        )
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.supplierName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (_missionStarted) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                if (isNext && !hasWorkOrder)
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _openAddWorkOrder(item),
                                                    icon: const Icon(
                                                      Icons.note_add_outlined,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Create WO',
                                                    ),
                                                  ),
                                                if (isCheckedIn)
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _checkOut(item),
                                                    icon: const Icon(
                                                      Icons.logout,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Check-out',
                                                    ),
                                                  ),
                                                if (isNext && !isCheckedIn)
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _checkIn(item),
                                                    icon: const Icon(
                                                      Icons.login,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Arrived (Check-in)',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                          if (canManage) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _skipMission(item),
                                                  icon: const Icon(
                                                    Icons.skip_next_outlined,
                                                    size: 16,
                                                  ),
                                                  label: const Text('Skip'),
                                                ),
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            AppColors.error,
                                                      ),
                                                  onPressed: () =>
                                                      _removeMission(item),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 16,
                                                  ),
                                                  label: const Text('Hapus'),
                                                ),
                                              ],
                                            ),
                                          ],
                                          Text(
                                            item.address.isEmpty
                                                ? 'Alamat belum tersedia'
                                                : item.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            isNext
                                                ? 'Tujuan terdekat dari lokasi Anda'
                                                : item.status,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
    );
  }

  Widget _buildMinimized(int visited) {
    final next = _nextStop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Row(
        children: [
          const Icon(Icons.navigation_outlined, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Stop',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  next?.supplierName ?? 'Semua kunjungan selesai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            '$visited / ${_items.length} visits',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
