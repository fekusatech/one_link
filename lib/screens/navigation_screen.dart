import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'pickup_process_screen.dart';

class NavigationScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  const NavigationScreen({super.key, this.suratJalan});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  bool _isNavigating = false;
  String _navigationStatus = 'Siap untuk navigasi';
  double _distanceRemaining = 2.5; // km

  // GPS and Permission handling
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Dynamic camera position based on current location
  CameraPosition get _initialPosition => CameraPosition(
    target: _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(-6.200000, 106.816666), // Default Jakarta center
    zoom: 16,
    tilt: 45, // 3D view
    bearing: 30,
  );

  // Dynamic destination coordinates and markers
  Set<Marker> _markers = {};
  List<LatLng> _destinations = [];
  String _primarySupplierName = 'Lokasi Penjemputan';
  int _selectedSupplierIndex = 0; // Track selected supplier

  // Route polyline
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // Request location permission and get current location
  Future<void> _requestLocationPermission() async {
    try {
      print('🌍 NavigationScreen: Requesting location permission...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ NavigationScreen: Location services are disabled');
        setState(() {
          _navigationStatus = 'Location services disabled';
          _isLoadingLocation = false;
        });
        _setupMarkersFromSuratJalan();
        _createRoute();
        return;
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ NavigationScreen: Location permission denied');
          setState(() {
            _navigationStatus = 'Location permission denied';
            _isLoadingLocation = false;
          });
          _setupMarkersFromSuratJalan();
          _createRoute();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ NavigationScreen: Location permission permanently denied');
        setState(() {
          _navigationStatus = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        _setupMarkersFromSuratJalan();
        _createRoute();
        return;
      }

      // Get current location
      print('📍 NavigationScreen: Getting current location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
        '✅ NavigationScreen: Current location: ${position.latitude}, ${position.longitude}',
      );

      setState(() {
        _currentPosition = position;
        _navigationStatus = 'Siap untuk navigasi';
        _isLoadingLocation = false;
      });

      _setupMarkersFromSuratJalan();
      _createRoute();
    } catch (e) {
      print('❌ NavigationScreen: Error getting location: $e');
      setState(() {
        _navigationStatus = 'Error getting location: ${e.toString()}';
        _isLoadingLocation = false;
      });
      _setupMarkersFromSuratJalan();
      _createRoute();
    }
  }

  void _setupMarkersFromSuratJalan() {
    print('🧭 NavigationScreen: Setting up markers from surat jalan data');

    if (widget.suratJalan != null) {
      print(
        '🧭 NavigationScreen: Surat Jalan Kode: ${widget.suratJalan!.kode}',
      );
      print('🧭 NavigationScreen: Status: ${widget.suratJalan!.status}');
      print(
        '🧭 NavigationScreen: Detail count: ${widget.suratJalan!.suratJalanDetail.length}',
      );

      _markers.clear();
      _destinations.clear();

      // Get first supplier as primary destination
      if (widget.suratJalan!.suratJalanDetail.isNotEmpty) {
        _primarySupplierName =
            widget.suratJalan!.suratJalanDetail.first.supplierName;
        print('🧭 NavigationScreen: Primary supplier: $_primarySupplierName');
      }

      // Create markers for each supplier location
      for (int i = 0; i < widget.suratJalan!.suratJalanDetail.length; i++) {
        final detail = widget.suratJalan!.suratJalanDetail[i];
        print(
          '🧭 NavigationScreen: Processing supplier $i: ${detail.supplierName}',
        );
        print('🧭 NavigationScreen: GPS: "${detail.supplierGps}"');

        final gpsParts = detail.supplierGps.split(',');

        if (gpsParts.length >= 2) {
          try {
            double lat = double.parse(gpsParts[0].trim());
            double lng = double.parse(gpsParts[1].trim());

            print('🧭 NavigationScreen: Parsed coordinates: $lat, $lng');

            LatLng position = LatLng(lat, lng);
            _destinations.add(position);

            _markers.add(
              Marker(
                markerId: MarkerId('supplier_$i'),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  detail.status == 'done'
                      ? BitmapDescriptor.hueGreen
                      : detail.status == 'pickup'
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: detail.supplierName,
                  snippet:
                      'Status: ${detail.status.toUpperCase()}\\nTap untuk pilih',
                ),
                onTap: () {
                  // Update selected supplier
                  setState(() {
                    _selectedSupplierIndex = i;
                    _primarySupplierName = detail.supplierName;
                  });
                  print(
                    '🎯 NavigationScreen: Selected supplier: ${detail.supplierName}',
                  );
                },
              ),
            );
            print(
              '🧭 NavigationScreen: Added marker for ${detail.supplierName}',
            );
          } catch (e) {
            print(
              '🧭 NavigationScreen: Error parsing GPS for supplier ${detail.supplierName}: $e',
            );
          }
        } else {
          print(
            '🧭 NavigationScreen: Invalid GPS format for ${detail.supplierName}',
          );
        }
      }

      print('🧭 NavigationScreen: Total destinations: ${_destinations.length}');
      print('🧭 NavigationScreen: Total markers: ${_markers.length}');

      // Add current location marker if available
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(
              title: 'Lokasi Saya',
              snippet: 'Posisi saat ini',
            ),
          ),
        );
        print('🧭 NavigationScreen: Added current location marker');
      }
    } else {
      print(
        '🧭 NavigationScreen: No surat jalan data provided, using fallback',
      );
      // Fallback to default location if no data
      _destinations = [const LatLng(-7.9797, 112.6304)];
      _primarySupplierName = 'Lokasi Penjemputan';
      _markers = {
        Marker(
          markerId: const MarkerId('default'),
          position: _destinations.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(
            title: 'Lokasi Penjemputan',
            snippet: 'Default Location',
          ),
        ),
      };
    }
  }

  void _createRoute() {
    print(
      '🗺️ NavigationScreen: Creating route with ${_destinations.length} destinations',
    );

    if (_destinations.isNotEmpty) {
      // For route, go from current location to each destination
      List<LatLng> routePoints = [];

      // Use actual current location if available, otherwise default to Jakarta center
      if (_currentPosition != null) {
        routePoints.add(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
        print(
          '🗺️ NavigationScreen: Using current GPS location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
        );
      } else {
        routePoints.add(const LatLng(-6.200000, 106.816666));
        print('🗺️ NavigationScreen: Using default Jakarta center location');
      }

      // Add each destination
      for (int i = 0; i < _destinations.length; i++) {
        routePoints.add(_destinations[i]);
        print(
          '🗺️ NavigationScreen: Added route point $i: ${_destinations[i].latitude}, ${_destinations[i].longitude}',
        );
      }

      print('🗺️ NavigationScreen: Total route points: ${routePoints.length}');

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: routePoints,
          color: Colors.white,
          width: 6,
          patterns: [PatternItem.dash(30), PatternItem.gap(20)],
        ),
      );

      print('🗺️ NavigationScreen: Route created successfully');
    } else {
      print('🗺️ NavigationScreen: No destinations available for route');
    }
  }

  // Start navigation mode
  void _startNavigation() {
    setState(() {
      _isNavigating = true;
      _navigationStatus = 'Navigasi dimulai...';
    });

    // Animate camera to follow route
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(-6.200000, 106.816666),
          zoom: 17,
          tilt: 60,
          bearing: 45,
        ),
      ),
    );

    // Simulate navigation updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isNavigating) {
        setState(() {
          _navigationStatus = 'Belok kanan 200m lagi';
          _distanceRemaining = 2.3;
        });
      }
    });
  }

  // Center map to current location
  void _centerToMyLocation() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_initialPosition),
    );
  }

  // Get appropriate navigation icon based on status
  IconData _getNavigationIcon() {
    if (_isNavigating) return Icons.stop;

    if (widget.suratJalan?.status == 'done') {
      return Icons.map;
    } else {
      return Icons.navigation;
    }
  }

  // Handle navigation action based on status
  void _handleNavigationAction() {
    if (widget.suratJalan?.status == 'done') {
      // Open external Google Maps
      _openGoogleMaps();
    } else {
      // Start internal navigation
      _startNavigation();
    }
  }

  // Open Google Maps externally
  void _openGoogleMaps() async {
    if (_destinations.isNotEmpty) {
      try {
        final destination = _destinations.first;
        final url =
            'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}';

        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          // Fallback: try to open with maps app
          final mapsUrl =
              'geo:${destination.latitude},${destination.longitude}';
          if (await canLaunchUrl(Uri.parse(mapsUrl))) {
            await launchUrl(Uri.parse(mapsUrl));
          }
        }
      } catch (e) {
        debugPrint('Error opening maps: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background: Full-screen Google Maps with dark style
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Apply dark map style
              _mapController?.setMapStyle('''
                [
                  {
                    "elementType": "geometry",
                    "stylers": [{"color": "#1B4D3E"}]
                  },
                  {
                    "elementType": "labels.text.fill",
                    "stylers": [{"color": "#FFFFFF"}]
                  },
                  {
                    "elementType": "labels.text.stroke",
                    "stylers": [{"color": "#1B4D3E"}]
                  },
                  {
                    "featureType": "road",
                    "elementType": "geometry",
                    "stylers": [{"color": "#2D6A56"}]
                  },
                  {
                    "featureType": "water",
                    "elementType": "geometry",
                    "stylers": [{"color": "#0A1F1A"}]
                  }
                ]
              ''');
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // Navigation info overlay (top of map, below appbar)
          if (_isNavigating)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _navigationStatus,
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.suratJalan != null)
                      Text(
                        'Menuju: $_primarySupplierName',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten,
                          color: AppColors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_distanceRemaining.toStringAsFixed(1)} km tersisa',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        const Spacer(),
                        // Selected supplier indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Supplier ${_selectedSupplierIndex + 1}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Loading location overlay
          if (_isLoadingLocation)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Mencari lokasi GPS Anda...',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top overlay: Custom AppBar with transparent background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.primaryGreen,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),

                    // Right action buttons
                    Row(
                      children: [
                        // Share button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.share),
                            color: AppColors.primaryGreen,
                            onPressed: () {
                              // TODO: Implement share functionality
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Start Navigation/Map button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(_getNavigationIcon()),
                            color: _isNavigating
                                ? AppColors.error
                                : AppColors.primaryGreen,
                            onPressed: () {
                              if (_isNavigating) {
                                setState(() {
                                  _isNavigating = false;
                                  _navigationStatus = 'Siap untuk navigasi';
                                });
                              } else {
                                _handleNavigationAction();
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Center to location button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.my_location),
                            color: AppColors.primaryGreen,
                            onPressed: _centerToMyLocation,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom overlay: Action button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to pickup process with supplier data
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      _selectedSupplierIndex <
                              (widget.suratJalan?.suratJalanDetail.length ?? 0)
                          ? 'Proses: $_primarySupplierName'
                          : 'Proses Penjemputan',
                      style: AppTextStyles.button,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
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
}
