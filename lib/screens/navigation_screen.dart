import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import 'pickup_process_screen.dart';
import '../services/direction_service.dart';
import '../utils/wa_format.dart';

enum NavMapEngine { leafletOsm, googleMaps }

class NavigationScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  const NavigationScreen({super.key, this.suratJalan});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;

  NavMapEngine _mapEngine = NavMapEngine.leafletOsm;
  List<LatLng> _destinations = [];
  List<LatLng> _routePoints = [];
  int _selectedSupplierIndex = 0;
  String _primarySupplierName = 'Lokasi Penjemputan';

  LatLng? _currentPosition;
  double _heading = 0.0;
  bool _isLoadingLocation = true;
  bool _isLoadingRoute = false;
  String _locationStatus = 'Mencari lokasi GPS real-time...';
  bool _followDriver = true; // Auto-follow driver on map

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (math.pi / 180.0);
    final startLng = start.longitude * (math.pi / 180.0);
    final endLat = end.latitude * (math.pi / 180.0);
    final endLng = end.longitude * (math.pi / 180.0);

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final bearingRad = math.atan2(y, x);
    return (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;
  }

  static const LatLng _defaultCenter = LatLng(-7.9797, 112.6304);

  @override
  void initState() {
    super.initState();
    _setupDestinations();
    _startRealtimeLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Setup destination coordinates from SuratJalan ──
  void _setupDestinations() {
    _destinations.clear();
    final details = widget.suratJalan?.suratJalanDetail ?? [];

    if (details.isEmpty) {
      _destinations.add(_defaultCenter);
      return;
    }

    _primarySupplierName = details.first.supplierName;

    for (int i = 0; i < details.length; i++) {
      final detail = details[i];
      final gpsParts = detail.supplierGps.split(',');
      if (gpsParts.length < 2) continue;

      try {
        final lat = double.parse(gpsParts[0].trim());
        final lng = double.parse(gpsParts[1].trim());
        _destinations.add(LatLng(lat, lng));
      } catch (_) {}
    }

    if (_destinations.isEmpty) {
      _destinations.add(_defaultCenter);
    }
  }

  // ── Start Real-time GPS Location Stream (Follows Movement) ──
  Future<void> _startRealtimeLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'GPS tidak aktif';
          _isLoadingLocation = false;
        });
        _fetchRealRoute();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Izin GPS ditolak';
          _isLoadingLocation = false;
        });
        _fetchRealRoute();
        return;
      }

      // Initial fast location fetch
      final initialPos =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          ).catchError(
            (_) async =>
                await Geolocator.getLastKnownPosition() ??
                Position(
                  latitude: _defaultCenter.latitude,
                  longitude: _defaultCenter.longitude,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                ),
          );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(initialPos.latitude, initialPos.longitude);
          _locationStatus = 'GPS Real-time Aktif';
          _isLoadingLocation = false;
        });

        _fetchRealRoute();
        _fitBounds();
      }

      // Listen to continuous real-time movement stream
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Trigger every 3 meters of movement
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) {
            if (!mounted) return;

            final newPos = LatLng(position.latitude, position.longitude);
            double heading = position.heading;

            if ((heading == 0 || heading.isNaN) && _currentPosition != null) {
              heading = _calculateBearing(_currentPosition!, newPos);
            }

            setState(() {
              _currentPosition = newPos;
              if (!heading.isNaN && heading != 0) {
                _heading = heading;
              }
            });

            // Auto-center map following real driver movement
            if (_followDriver) {
              _mapController.move(newPos, _mapController.camera.zoom);
            }
          });
    } catch (e) {
      print('⚠️ Real-time GPS stream error: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Koneksi GPS terbatas';
          _isLoadingLocation = false;
        });
        _fetchRealRoute();
      }
    }
  }

  // ── Fetch real street route polyline from OSRM ──
  Future<void> _fetchRealRoute() async {
    if (_destinations.isEmpty) return;

    setState(() => _isLoadingRoute = true);

    final destination = _destinations.length > _selectedSupplierIndex
        ? _destinations[_selectedSupplierIndex]
        : _destinations.first;

    final origin = _currentPosition ?? _defaultCenter;

    final points = await DirectionService.getRoutePolyline(
      origin: origin,
      destination: destination,
    );

    if (mounted) {
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
    }
  }

  // ── Fit camera to show both driver & selected destination ──
  void _fitBounds() {
    if (_destinations.isEmpty) return;

    final dest = _destinations.length > _selectedSupplierIndex
        ? _destinations[_selectedSupplierIndex]
        : _destinations.first;

    final origin = _currentPosition ?? _defaultCenter;

    final bounds = LatLngBounds.fromPoints([origin, dest]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)),
    );
  }

  // ── Select supplier stop ──
  void _selectSupplier(int index) {
    if (index >= _destinations.length) return;

    setState(() {
      _selectedSupplierIndex = index;
      _primarySupplierName =
          widget.suratJalan!.suratJalanDetail[index].supplierName;
      _followDriver = false; // Pause auto-follow when inspecting stops
    });

    _fetchRealRoute();

    _mapController.move(_destinations[index], 15.5);
  }

  // ── Open external Google Maps navigation ──
  Future<void> _openGoogleMaps() async {
    LatLng target;
    if (_destinations.length > _selectedSupplierIndex) {
      target = _destinations[_selectedSupplierIndex];
    } else {
      target = _destinations.first;
    }

    String url;
    if (_currentPosition != null) {
      url =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destination=${target.latitude},${target.longitude}'
          '&travelmode=driving';
    } else {
      url =
          'https://www.google.com/maps/dir/?api=1'
          '&destination=${target.latitude},${target.longitude}'
          '&travelmode=driving';
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka aplikasi Google Maps.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Toggle Map Engine (Leaflet OSM / Google Maps Tile) ──
  void _toggleEngine() {
    setState(() {
      _mapEngine = _mapEngine == NavMapEngine.leafletOsm
          ? NavMapEngine.googleMaps
          : NavMapEngine.leafletOsm;
    });
  }

  SuratJalanDetail? get _selectedDetail {
    final details = widget.suratJalan?.suratJalanDetail ?? const [];
    if (_selectedSupplierIndex >= details.length) return null;
    return details[_selectedSupplierIndex];
  }

  double get _selectedDistanceKm {
    if (_currentPosition == null || _destinations.isEmpty) return 0;
    final destination = _destinations.length > _selectedSupplierIndex
        ? _destinations[_selectedSupplierIndex]
        : _destinations.first;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
  }

  Future<void> _callSupplier() async {
    final phone = _selectedDetail?.supplierPhone.trim() ?? '';
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _messageSupplier() async {
    final phone = _selectedDetail?.supplierPhone.trim() ?? '';
    if (phone.isEmpty) return;
    await launchUrl(
      Uri.parse(
        waUrl(phone, text: 'Halo, saya sedang menuju $_primarySupplierName.'),
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildTripSummary() {
    final details = widget.suratJalan?.suratJalanDetail ?? const [];
    final completed = details.where((detail) {
      final status = detail.status.toLowerCase();
      return status == 'done' || status == 'completed' || status == 'selesai';
    }).length;
    final total = details.isEmpty ? _destinations.length : details.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final distance = _selectedDistanceKm;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            height: 27,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.14),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$completed/$total titik selesai',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (distance > 0)
            Text(
              '${distance.toStringAsFixed(1)} km',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(width: 7),
          Icon(
            _isLoadingLocation ? Icons.gps_not_fixed : Icons.gps_fixed,
            size: 16,
            color: _isLoadingLocation
                ? AppColors.accentOrange
                : AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierActions() {
    final hasPhone = (_selectedDetail?.supplierPhone.trim() ?? '').isNotEmpty;
    if (!hasPhone) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _callSupplier,
            icon: const Icon(Icons.phone_outlined, size: 17),
            label: const Text('Telepon'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _messageSupplier,
            icon: const Icon(Icons.chat_bubble_outline, size: 17),
            label: const Text('WhatsApp'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              foregroundColor: AppColors.primaryGreen,
              side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter =
        _currentPosition ??
        (_destinations.isNotEmpty ? _destinations.first : _defaultCenter);

    final tileUrl = _mapEngine == NavMapEngine.googleMaps
        ? 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      body: Stack(
        children: [
          // ── Leaflet FlutterMap Canvas ─────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followDriver) {
                  setState(() => _followDriver = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.one_link',
              ),

              // Real Road Routing Polyline Layer
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF1877F2),
                      strokeWidth: 6,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // Markers (Real Driver Position + Destination Pins)
              MarkerLayer(
                markers: [
                  // Real-time Driver Position Marker (Rotates with direction)
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 44,
                      height: 44,
                      child: Transform.rotate(
                        angle: (_heading * (math.pi / 180.0)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                  // Destination Markers
                  ..._destinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pos = entry.value;
                    final isSelected = index == _selectedSupplierIndex;

                    return Marker(
                      point: pos,
                      width: isSelected ? 40 : 32,
                      height: isSelected ? 40 : 32,
                      child: GestureDetector(
                        onTap: () => _selectSupplier(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.error
                                : AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Top Header Controls ──────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _mapBtn(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.error,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'TUJUAN AKTIF',
                                        style: AppTextStyles.overline.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        _primarySupplierName,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Map Engine Switcher Button
                        GestureDetector(
                          onTap: _toggleEngine,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _mapEngine == NavMapEngine.leafletOsm
                                      ? Icons.layers_outlined
                                      : Icons.map_outlined,
                                  size: 15,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _mapEngine == NavMapEngine.leafletOsm
                                      ? 'OSM'
                                      : 'Google',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildFuelEstimatorBadge(),
                  ],
                ),
              ),
            ),
          ),

          // ── GPS Status Banner ───────────────────────────
          if (_isLoadingLocation || _isLoadingRoute)
            Positioned(
              top: kToolbarHeight + 56,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isLoadingRoute
                            ? 'Menghitung rute tercepat...'
                            : _locationStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Real Movement Follow Driver Button ──────────
          Positioned(
            right: 16,
            bottom: 178,
            child: FloatingActionButton.small(
              heroTag: 'follow_driver_btn',
              backgroundColor: _followDriver
                  ? const Color(0xFF1877F2)
                  : Colors.white,
              onPressed: () async {
                setState(() => _followDriver = true);
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 16);
                } else {
                  try {
                    final pos = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(
                        accuracy: LocationAccuracy.high,
                      ),
                    );
                    final latLng = LatLng(pos.latitude, pos.longitude);
                    if (mounted) {
                      setState(() {
                        _currentPosition = latLng;
                      });
                      _mapController.move(latLng, 16);
                    }
                  } catch (_) {
                    if (_destinations.isNotEmpty) {
                      _mapController.move(_destinations.first, 15);
                    }
                  }
                }
              },
              child: Icon(
                Icons.my_location_rounded,
                color: _followDriver ? Colors.white : const Color(0xFF1877F2),
              ),
            ),
          ),

          // ── Bottom Action Controls ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 22,
                    offset: const Offset(0, -7),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTripSummary(),
                    const SizedBox(height: 7),
                    _buildSupplierActions(),
                    if ((_selectedDetail?.supplierPhone.trim() ?? '')
                        .isNotEmpty)
                      const SizedBox(height: 7),
                    // Start Google Maps External Nav
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Mulai Navigasi Google Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          textStyle: AppTextStyles.button,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Process Pickup Button
                    if (widget.suratJalan?.status != 'done' &&
                        widget.suratJalan?.status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PickupProcessScreen(
                                  suratJalan: widget.suratJalan,
                                  supplierIndex: _selectedSupplierIndex,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_shipping_rounded),
                          label: Text(
                            'Proses: $_primarySupplierName',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: AppTextStyles.button,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.primaryGreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFuelEstimatorBadge() {
    double distanceKm = 0.0;
    if (_currentPosition != null && _destinations.isNotEmpty) {
      final dest = _destinations.length > _selectedSupplierIndex
          ? _destinations[_selectedSupplierIndex]
          : _destinations.first;
      final distanceMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        dest.latitude,
        dest.longitude,
      );
      distanceKm = distanceMeters / 1000.0;
    }

    if (distanceKm <= 0) return const SizedBox.shrink();

    final liters = distanceKm / 8.0;
    final cost = liters * 13500;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_gas_station,
            size: 14,
            color: AppColors.accentOrange,
          ),
          const SizedBox(width: 6),
          Text(
            'Est. BBM: ${liters.toStringAsFixed(1)} L (~Rp ${cost.toStringAsFixed(0)})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
