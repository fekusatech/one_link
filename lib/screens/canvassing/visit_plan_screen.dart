import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../models/supplier_order_history.dart';
import '../../services/supplier_list_service.dart';
import '../../widgets/order_history_widgets.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/haversine.dart';
import '../../services/geu/reverse_geocoding_service.dart';
import '../../services/geu/active_visit_service.dart';
import '../../services/geu/visit_navigation_service.dart';
import '../../services/geu/mission_navigation_state.dart';
import '../../services/geu/malang_work_area_service.dart';
import '../../services/geu/visit_planner_service.dart';
import '../../services/geu/settings_service.dart';
import '../../services/geu/visit_sync_service.dart';
import 'add_work_order_sheet.dart';
import 'checkin_dialog.dart';
import 'checkout_dialog.dart';
import 'mission_today_screen.dart';
import 'register_supplier_dialog.dart';
import 'scan_prospect_screen.dart';
import 'skip_mission_sheet.dart';

/// Mobile-first entry point mirroring CRM web's Visit Planner: map first,
/// compact legend/status overlay, and today's visit summary at the bottom.
class VisitPlanScreen extends StatefulWidget {
  const VisitPlanScreen({super.key});
  @override
  State<VisitPlanScreen> createState() => _VisitPlanScreenState();
}

class _VisitPlanScreenState extends State<VisitPlanScreen>
    with SingleTickerProviderStateMixin {
  // Temporary rollout switch: keep the area boundary code available, but do
  // not restrict Visit Planner usage or show the static zone overlay.
  static const bool _workAreaRestrictionEnabled = false;
  static const _workAreaCenter = LatLng(-7.9666, 112.6326);
  static const double _workAreaRadiusKm = 15;
  // A safe initial value prevents the GPS stream from rebuilding the map
  // before the remote distance_radius_map setting has finished loading.
  int _supplierRadiusMeters = 1000;
  // 'osm' | 'google' — from the 'visit_plan_map_provider' backend setting.
  // Only the tile source changes; markers/circles/routes are unaffected.
  String _mapTileProvider = 'osm';
  String _googleTilesApiKey = '';
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
  LatLng? _searchCenter;
  bool _isAdmin = false;
  bool _showRecenter = false;
  bool _hidePoo = false;
  bool _insideWorkArea = true;
  bool _workAreaAlertShown = false;
  List<List<LatLng>> _workAreaPolygons = const [];
  late final AnimationController _radiusPulse;
  LatLng? _lastNearbyQueryPoint;
  int _nearbyRequestId = 0;
  LatLng? _lastMovementPoint;
  DateTime? _lastMovementAt;

  @override
  void initState() {
    super.initState();
    _radiusPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadAdminAccess();
    _startCompassUpdates();
    _load();
    unawaited(_loadWorkAreaBoundary());
    unawaited(_startMapLocationUpdates());
  }

  Future<void> _loadWorkAreaBoundary() async {
    if (!_workAreaRestrictionEnabled) return;
    try {
      final polygons = await MalangWorkAreaService.loadBoundary();
      if (!mounted || polygons.isEmpty) return;
      setState(() => _workAreaPolygons = polygons);
      if (_user != null) _updateWorkAreaStatus(_user!);
    } catch (_) {
      // Keep the local fallback circle when ArcGIS is temporarily unavailable.
    }
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
      final tileProvider = await SettingsService.getByKey(
        'visit_plan_map_provider',
      );
      if (tileProvider == 'google') {
        _mapTileProvider = 'google';
        _googleTilesApiKey =
            await SettingsService.getByKey('google_maps_api_key') ?? '';
      }
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
      _advanceNavigationTargetIfNeeded(mission.items);
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
    _radiusPulse.dispose();
    super.dispose();
  }

  /// Keeps the driver map's radius circle and supplier markings aligned with
  /// the moving GPS position. Admins can still pin a manual search center;
  /// normal users always follow their current location.
  Future<void> _startMapLocationUpdates() async {
    try {
      final positions = await GpsService.watchPosition();
      _mapLocationSubscription = positions.listen((fix) {
        if (!mounted || _missionActive) return;
        final point = LatLng(fix.latitude, fix.longitude);
        _updateWorkAreaStatus(point);
        // Admin map exploration may pin a temporary center, but the real GPS
        // position must still be checked against the work-area boundary.
        if (_searchCenter != null) return;
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
        // Pan only — forcing a fixed zoom here fights any manual zoom the RO
        // made to confirm the exact pin position while approaching a POO.
        _map.move(point, _map.camera.zoom);
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

  void _updateWorkAreaStatus(LatLng point) {
    if (!_workAreaRestrictionEnabled) {
      if (_insideWorkArea != true && mounted) {
        setState(() => _insideWorkArea = true);
      }
      _workAreaAlertShown = false;
      return;
    }
    final inside = _isInsideWorkAreaPoint(point);
    if (_insideWorkArea == inside) return;
    setState(() => _insideWorkArea = inside);
    if (!inside && !_workAreaAlertShown) {
      _workAreaAlertShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOutsideWorkAreaAlert();
      });
    } else if (inside) {
      _workAreaAlertShown = false;
    }
  }

  bool _isInsideWorkAreaPoint(LatLng point) {
    if (!_workAreaRestrictionEnabled) return true;
    if (_workAreaPolygons.isNotEmpty) {
      return MalangWorkAreaService.contains(point, _workAreaPolygons);
    }
    return haversineDistanceKm(
          _workAreaCenter.latitude,
          _workAreaCenter.longitude,
          point.latitude,
          point.longitude,
        ) <=
        _workAreaRadiusKm;
  }

  Future<void> _showOutsideWorkAreaAlert() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Di luar area kerja')),
          ],
        ),
        content: const Text(
          'Anda berada di luar area kerja Kota Malang. Aplikasi tidak dapat digunakan di lokasi ini. Silakan kembali ke area kerja untuk melanjutkan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Mengerti'),
          ),
        ],
      ),
    );
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
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.example.one_link',
                errorTileCallback: (tile, error, stackTrace) {
                  // Google's raster endpoint isn't an officially supported
                  // third-party API — fall back to OSM if it stops serving.
                  if (_mapTileProvider == 'google' && mounted) {
                    setState(() => _mapTileProvider = 'osm');
                  }
                },
              ),
              if (_insideWorkArea && _user != null)
                AnimatedBuilder(
                  animation: _radiusPulse,
                  builder: (context, child) {
                    final pulse = Curves.easeInOut.transform(
                      _radiusPulse.value,
                    );
                    return CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _user!,
                          radius: _supplierRadiusMeters * (0.94 + pulse * 0.06),
                          useRadiusInMeter: true,
                          color: AppColors.info.withValues(
                            alpha: 0.12 - pulse * 0.035,
                          ),
                          borderColor: AppColors.info.withValues(
                            alpha: 0.58 - pulse * 0.18,
                          ),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    );
                  },
                ),
              if (_workAreaRestrictionEnabled && _workAreaPolygons.isNotEmpty)
                PolygonLayer(
                  polygons: _workAreaPolygons
                      .map(
                        (points) => Polygon(
                          points: points,
                          color: const Color(
                            0xFF174D43,
                          ).withValues(alpha: 0.18),
                          borderColor: const Color(
                            0xFF0F3D35,
                          ).withValues(alpha: 0.9),
                          borderStrokeWidth: 2.5,
                        ),
                      )
                      .toList(),
                )
              else if (_workAreaRestrictionEnabled)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _workAreaCenter,
                      radius: _workAreaRadiusKm * 1000,
                      useRadiusInMeter: true,
                      color: Colors.orange.withValues(alpha: 0.025),
                      borderColor: Colors.orange.withValues(alpha: 0.35),
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
                  if (_insideWorkArea && !_missionActive && !_hidePoo)
                    for (final supplier in _databaseSuppliers)
                      if (!activeMissionSupplierIds.contains(supplier.id) &&
                          supplier.latitude != null &&
                          supplier.longitude != null &&
                          _isInsideWorkAreaPoint(
                            LatLng(supplier.latitude!, supplier.longitude!),
                          ))
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
                              _supplierBadgeColor(supplier.badge),
                              Icons.storefront,
                              tooltip:
                                  '${supplier.name}\n${supplier.type} • ${supplier.distanceKm.toStringAsFixed(1)} km',
                            ),
                          ),
                        ),
                  if (!_missionActive)
                    for (final prospect in _scannedProspects)
                      if (prospect.latitude != null &&
                          prospect.longitude != null &&
                          _isInsideWorkAreaPoint(
                            LatLng(prospect.latitude!, prospect.longitude!),
                          ))
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
          if (_workAreaRestrictionEnabled && !_insideWorkArea)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.white.withValues(alpha: .86),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(28),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            size: 42,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Di luar area kerja',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Anda berada di luar area kerja Kota Malang. Aplikasi tidak dapat digunakan di lokasi ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openVisits() async {
    if (!_insideWorkArea) {
      await _showOutsideWorkAreaAlert();
      return;
    }
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

  /// The "Tujuan:" banner and driving route both key off `_navigationTarget`,
  /// but nothing was advancing it once that stop got checked out — the map
  /// kept navigating to an already-VISITED supplier instead of the next
  /// pending one. Called every time the mission list is refreshed (checkout,
  /// skip, add, remove) while a mission is actively being driven.
  void _advanceNavigationTargetIfNeeded(List<MissionItem> items) {
    if (!_missionActive) return;
    final target = _navigationTarget;
    final targetStatus = target == null
        ? null
        : items
              .cast<MissionItem?>()
              .firstWhere(
                (i) => i?.planDetailId == target.planDetailId,
                orElse: () => null,
              )
              ?.status
              .toUpperCase();
    final targetDone =
        target == null || targetStatus == null || targetStatus == 'VISITED' || targetStatus == 'SKIPPED';
    if (!targetDone) return;

    MissionItem? next;
    for (final item in items) {
      final status = item.status.toUpperCase();
      if (status != 'VISITED' && status != 'SKIPPED' && item.hasCoordinates) {
        next = item;
        break;
      }
    }
    if (next == null) {
      // Every stop is done or skipped — nothing left to navigate to.
      _setMissionActive(false);
      return;
    }
    setState(() => _navigationTarget = next);
    MissionNavigationStateService.start(destination: next, items: items);
    _map.move(LatLng(next.lat!, next.lng!), _map.camera.zoom);
    unawaited(_refreshDrivingRoute());
  }

  Future<void> _startDrivingMode(MissionItem item) async {
    if (!_insideWorkArea) {
      await _showOutsideWorkAreaAlert();
      return;
    }
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
        _updateWorkAreaStatus(point);
        final bearing = _updateMovementHeading(point);
        setState(() {
          _user = point;
          _headingDegrees = bearing ?? _headingDegrees;
        });
        // Same reasoning as the browsing-mode listener above: pan without
        // resetting zoom so the RO's manual zoom survives while navigating.
        _map.move(point, _map.camera.zoom);
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
            label: 'Supplier (PO < 30 days)',
          ),
          const _LegendDot(
            color: Color(0xFFFF9800),
            label: 'Supplier (PO > 30 days)',
          ),
          const _LegendDot(
            color: Color(0xFF9E9E9E),
            label: 'Supplier (Belum ada PO)',
          ),
          const _LegendDot(color: Color(0xFFF44336), label: 'Scan Result'),
        ],
      ),
    ),
  );

  Future<void> _openScanCenterSheet() async {
    if (!_insideWorkArea) {
      await _showOutsideWorkAreaAlert();
      return;
    }
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
    _updateWorkAreaStatus(point);
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
    if (!_insideWorkArea) {
      await _showOutsideWorkAreaAlert();
      return;
    }
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
    final result = await showRegisterSupplierDialog(
      context,
      latitude: point.latitude,
      longitude: point.longitude,
      initialAddress: initialAddress,
    );
    if (result == null || !mounted) return;
    await _load();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} ditambahkan ke Mission.')),
      );
  }

  Future<void> _showSupplierDetails(NearbySupplier supplier) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SupplierDetailSheet(
        supplier: supplier,
        onAddToMission: () => _addSupplierToMission(supplier, sheetContext),
      ),
    );
  }

  Future<void> _addSupplierToMission(
    NearbySupplier supplier,
    BuildContext sheetContext,
  ) async {
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
      rethrow;
    }
  }

  /// badge_status from the nearby-suppliers query is one of DALAM_30 (a
  /// completed pickup within 30 days), LEBIH_30 (one, but older), or
  /// BELUM_WO (never picked up at all — no t_pickup_detail row exists yet,
  /// same source the order-history sheet checks). LEBIH_30 and BELUM_WO
  /// used to share one orange color/legend entry ("PO > 30 days"), which
  /// misleadingly implied every orange pin had SOME order history.
  String get _tileUrl => _mapTileProvider == 'google'
      ? 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'
            '${_googleTilesApiKey.isNotEmpty ? '&key=$_googleTilesApiKey' : ''}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  Color _supplierBadgeColor(String badge) {
    switch (badge.toUpperCase()) {
      case 'DALAM_30':
        return const Color(0xFF2196F3);
      case 'LEBIH_30':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
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

/// "Detail Supplier" map-marker sheet — only ever opened for
/// _databaseSuppliers (blue/orange pins, real m_supplier rows). Scanned
/// prospect pins (red) have no supplier_id yet, so they stay tooltip-only
/// with no sheet at all — nothing to fetch order history for.
class _SupplierDetailSheet extends StatefulWidget {
  final NearbySupplier supplier;
  final Future<void> Function() onAddToMission;

  const _SupplierDetailSheet({
    required this.supplier,
    required this.onAddToMission,
  });

  @override
  State<_SupplierDetailSheet> createState() => _SupplierDetailSheetState();
}

class _SupplierDetailSheetState extends State<_SupplierDetailSheet> {
  bool _isAdding = false;
  bool _loadingSummary = true;
  SupplierOrderSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await SupplierListService.getSupplierOrderSummary(
      widget.supplier.id,
    );
    if (mounted) {
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
    }
  }

  Future<void> _handleAdd() async {
    setState(() => _isAdding = true);
    try {
      await widget.onAddToMission();
    } catch (_) {
      // Already surfaced to the user via SnackBar by the caller.
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplier = widget.supplier;
    return SafeArea(
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              supplier.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _supplierDetailRow(Icons.location_on_outlined, supplier.address),
            if (supplier.phone.trim().isNotEmpty)
              _supplierDetailRow(Icons.phone_outlined, supplier.phone),
            _supplierDetailRow(
              Icons.straighten_outlined,
              'Jarak ${supplier.distanceKm.toStringAsFixed(2)} km',
            ),
            if (supplier.lastWoKode != null && supplier.lastWoKode!.isNotEmpty)
              _supplierDetailRow(
                Icons.assignment_turned_in_outlined,
                'WO terakhir: ${supplier.lastWoKode}'
                '${supplier.umurHari != null ? ' (${supplier.umurHari} hari lalu)' : ''}',
              ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildOrderHistorySection(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isAdding ? null : _handleAdd,
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isAdding ? 'Menambahkan...' : 'Tambah ke Mission'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistorySection() {
    if (_loadingSummary) return const OrderHistorySkeleton();

    final summary = _summary;
    if (summary == null || !summary.hasHistory) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada riwayat setor minyak.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _supplierDetailRow(
          Icons.history_outlined,
          'Terakhir setor ${_formatDate(summary.lastOrderDate)}'
          '${summary.lastOrderNominal != null ? ' • ${formatRupiah(summary.lastOrderNominal!)}' : ''}',
        ),
        _supplierDetailRow(
          Icons.receipt_long_outlined,
          '${summary.totalOrderCount}x setor • total ${formatRupiah(summary.totalOrderNominal)}',
        ),
        if (summary.recentOrders.length >= 2) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: RecentOrdersChart(orders: summary.recentOrders),
          ),
        ],
      ],
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

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }
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

  Future<void> _registerSupplier(MissionItem item) async {
    if (!item.hasCoordinates) return;
    final result = await showRegisterSupplierDialog(
      context,
      latitude: item.lat!,
      longitude: item.lng!,
      initialName: item.supplierName,
      initialAddress: item.address,
      initialPhone: item.supplierPhone,
    );
    if (result == null || !mounted) return;
    // The scanned-place row (supplier_id 0) is now redundant — the dialog
    // added a fresh mission row with a real supplier_id above.
    try {
      await VisitPlannerService.removeFromMission(item.planDetailId);
    } catch (_) {
      // Non-fatal: the mission still has the newly registered supplier.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.name} terdaftar sebagai supplier.')),
    );
    await _refreshMission();
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
                              final isRegistered = item.supplierId > 0;
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
                                                if (isNext && !isRegistered)
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _registerSupplier(
                                                          item,
                                                        ),
                                                    icon: const Icon(
                                                      Icons
                                                          .person_add_alt_1_outlined,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Daftarkan Supplier',
                                                    ),
                                                  ),
                                                if (isNext &&
                                                    isRegistered &&
                                                    isCheckedIn &&
                                                    !hasWorkOrder)
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
                                                if (isNext &&
                                                    isRegistered &&
                                                    !isCheckedIn)
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
