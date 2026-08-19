import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import 'pickup_process_screen.dart';
import '../services/direction_service.dart';

class NavigationScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  const NavigationScreen({super.key, this.suratJalan});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _destinations = [];
  int _selectedSupplierIndex = 0;
  String _primarySupplierName = 'Lokasi Penjemputan';

  LatLng? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isLoadingRoute = false;
  String _locationStatus = 'Mencari lokasi GPS...';

  static const LatLng _defaultCenter = LatLng(-7.9797, 112.6304);

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _fetchLocation();
  }

  // ── Get current location (low accuracy → fast, safe) ──
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'GPS tidak aktif';
          _isLoadingLocation = false;
        });
        _drawRoute();
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
        _drawRoute();
        return;
      }

      // Low accuracy → cepat & hemat memori
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _locationStatus = 'Lokasi ditemukan';
        _isLoadingLocation = false;
      });

      // Tambah marker posisi saya
      _markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: '📍 Lokasi Saya',
            snippet: 'Posisi saat ini',
          ),
        ),
      );

      _drawRoute();
      _fitBounds();
    } catch (e) {
      print('⚠️ NavigationScreen: GPS error: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Tidak dapat mengambil lokasi';
          _isLoadingLocation = false;
        });
        _drawRoute();
      }
    }
  }

  // ── Build supplier markers ──────────────────────────────
  void _setupMarkers() {
    _markers.clear();
    _destinations.clear();

    final details = widget.suratJalan?.suratJalanDetail ?? [];
    if (details.isEmpty) {
      _destinations.add(_defaultCenter);
      _markers.add(
        Marker(
          markerId: const MarkerId('default'),
          position: _defaultCenter,
          infoWindow: const InfoWindow(title: 'Lokasi Penjemputan'),
        ),
      );
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
        final pos = LatLng(lat, lng);
        _destinations.add(pos);

        final isSelected = i == _selectedSupplierIndex;
        _markers.add(
          Marker(
            markerId: MarkerId('supplier_$i'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              detail.status == 'done'
                  ? BitmapDescriptor.hueGreen
                  : isSelected
                      ? BitmapDescriptor.hueRed
                      : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${detail.supplierName}',
              snippet: detail.supplierAlamat,
            ),
            onTap: () => _selectSupplier(i),
          ),
        );
      } catch (_) {}
    }

    print('🗺️ ${_markers.length} marker siap, ${_destinations.length} tujuan');
  }

  // ── Draw real road route (my pos → selected supplier) ──
  Future<void> _drawRoute() async {
    if (_destinations.isEmpty) return;

    setState(() => _isLoadingRoute = true);

    final destination = _destinations.length > _selectedSupplierIndex
        ? _destinations[_selectedSupplierIndex]
        : _destinations.first;

    final origin = _currentPosition ?? _defaultCenter;

    final routePoints = await DirectionService.getRoutePolyline(
      origin: origin,
      destination: destination,
    );

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: AppColors.primaryGreen,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    if (mounted) {
      setState(() => _isLoadingRoute = false);
    }

    print('🗺️ Route drawn with ${routePoints.length} points');
  }

  // ── Fit camera to show both current pos + destination ──
  void _fitBounds() {
    if (_destinations.isEmpty || _mapController == null) return;

    final dest = _destinations.length > _selectedSupplierIndex
        ? _destinations[_selectedSupplierIndex]
        : _destinations.first;

    final origin = _currentPosition ?? _defaultCenter;

    final minLat = origin.latitude < dest.latitude ? origin.latitude : dest.latitude;
    final maxLat = origin.latitude > dest.latitude ? origin.latitude : dest.latitude;
    final minLng = origin.longitude < dest.longitude ? origin.longitude : dest.longitude;
    final maxLng = origin.longitude > dest.longitude ? origin.longitude : dest.longitude;

    // Padding supaya tidak terlalu mepet tepi
    const pad = 0.003;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ── Select a different supplier chip ───────────────────
  void _selectSupplier(int index) {
    if (index >= _destinations.length) return;

    setState(() {
      _selectedSupplierIndex = index;
      _primarySupplierName =
          widget.suratJalan!.suratJalanDetail[index].supplierName;
    });

    _setupMarkers();
    // Re-add my location marker after refresh
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: '📍 Lokasi Saya'),
        ),
      );
    }

    _drawRoute();

    // Animate camera toward the new destination
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_destinations[index], 14),
    );

    Future.delayed(const Duration(milliseconds: 600), _fitBounds);
  }

  // ── Open Google Maps with Navigation Mode ─────────────
  Future<void> _openGoogleMaps() async {
    LatLng target;
    if (_destinations.length > _selectedSupplierIndex) {
      target = _destinations[_selectedSupplierIndex];
    } else if (_destinations.isNotEmpty) {
      target = _destinations.first;
    } else {
      return;
    }

    String url;
    if (_currentPosition != null) {
      // Dengan titik asal (lokasi saya) → mode navigasi
      url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destination=${target.latitude},${target.longitude}'
          '&travelmode=driving';
    } else {
      // Tanpa titik asal → hanya tujuan
      url = 'https://www.google.com/maps/dir/?api=1'
          '&destination=${target.latitude},${target.longitude}'
          '&travelmode=driving';
    }

    final uri = Uri.parse(url);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching directly without canLaunch check (common for Android 11+)
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka Google Maps. Pastikan aplikasi Google Maps terpasang.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Center camera to my location ──────────────────────
  void _centerToMyLocation() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget =
        _destinations.isNotEmpty ? _destinations.first : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
            ),
            markers: Set.from(_markers),
            polylines: Set.from(_polylines),
            onMapCreated: (controller) {
              _mapController = controller;
              // After map ready, fit the route
              Future.delayed(const Duration(milliseconds: 500), _fitBounds);
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: false, // handled manually via Geolocator
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // ── Top Bar ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _mapBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _primarySupplierName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Fit route button
                    _mapBtn(
                      icon: Icons.fit_screen,
                      onTap: _fitBounds,
                      tooltip: 'Tampilkan Rute',
                    ),
                    const SizedBox(width: 8),
                    // My location button
                    _mapBtn(
                      icon: Icons.my_location,
                      onTap: _centerToMyLocation,
                      color: _currentPosition != null
                          ? AppColors.primaryGreen
                          : AppColors.grey,
                      tooltip: 'Lokasi Saya',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── GPS Loading Banner ─────────────────────────
          if (_isLoadingLocation)
            Positioned(
              top: kToolbarHeight + 56,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _locationStatus,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Route Loading Banner ───────────────────────
          if (_isLoadingRoute)
            Positioned(
              top: kToolbarHeight + (_isLoadingLocation ? 112 : 56),
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menghitung rute tercepat...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Route Info Banner (after location found) ───
          if (!_isLoadingLocation && _currentPosition != null)
            Positioned(
              top: kToolbarHeight + 56,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Origin dot
                    const Icon(Icons.circle, color: Colors.blue, size: 12),
                    const SizedBox(width: 8),
                    const Text('Lokasi Saya', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: AppColors.primaryGreen.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, color: AppColors.error, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _primarySupplierName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Supplier Chips (multiple) ──────────────────
          if (_destinations.length > 1)
            Positioned(
              top: kToolbarHeight + (_isLoadingLocation || _currentPosition != null ? 112 : 60),
              left: 0,
              right: 0,
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.suratJalan!.suratJalanDetail.length,
                  itemBuilder: (context, i) {
                    final selected = i == _selectedSupplierIndex;
                    final detail = widget.suratJalan!.suratJalanDetail[i];
                    return GestureDetector(
                      onTap: () => _selectSupplier(i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Text(
                          '${i + 1}. ${detail.supplierName}',
                          style: AppTextStyles.caption.copyWith(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Bottom Buttons ────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Navigasi via Google Maps
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.navigation),
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
                    const SizedBox(height: 10),

                    // Proses pickup
                    if (widget.suratJalan?.status != 'done' &&
                        widget.suratJalan?.status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        height: 52,
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
                          icon: const Icon(Icons.local_shipping),
                          label: Text(
                            'Proses: $_primarySupplierName',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: AppTextStyles.button,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
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
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
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
      ),
    );
  }
}
