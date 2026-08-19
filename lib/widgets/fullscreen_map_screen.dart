import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/supplier_detail_model.dart';
import '../models/supplier_list_model.dart';
import '../services/location_service.dart';

class FullscreenMapScreen extends StatefulWidget {
  final List<SupplierListItem> suppliers;
  final Set<Marker> markers;
  final LatLng? userLocation;

  const FullscreenMapScreen({
    super.key,
    required this.suppliers,
    required this.markers,
    this.userLocation,
  });

  @override
  State<FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<FullscreenMapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isDragging = false;
  SupplierListItem? _selectedSupplier;
  Set<Marker> _clickableMarkers = {};
  LatLng _mapCenter = const LatLng(-6.2088, 106.8456); // Default Jakarta
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Use user location if available, otherwise default to Jakarta
    _mapCenter = widget.userLocation ?? const LatLng(-6.2088, 106.8456);

    // Set initial supplier (first one with GPS data)
    if (widget.suppliers.isNotEmpty) {
      _selectedSupplier = widget.suppliers.firstWhere(
        (supplier) => supplier.gps != null && supplier.gps!.isNotEmpty,
        orElse: () => widget.suppliers.first,
      );
    }

    _createClickableMarkers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      // Dragging down
      setState(() {
        _isDragging = true;
      });
      double progress =
          1 - (details.globalPosition.dy / MediaQuery.of(context).size.height);
      progress = progress.clamp(0.0, 1.0);
      _animationController.value = progress;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    if (_animationController.value < 0.5) {
      // If dragged more than halfway, close the fullscreen
      _animationController.reverse().then((_) {
        Navigator.of(context).pop();
      });
    } else {
      // Otherwise, animate back to full screen
      _animationController.forward();
    }
  }

  void _createClickableMarkers() {
    Set<Marker> suppliers = widget.suppliers
        .where((supplier) => supplier.gps != null && supplier.gps!.isNotEmpty)
        .map((supplier) {
          final gps = supplier.gps!.split(',');
          if (gps.length >= 2) {
            final lat = double.tryParse(gps[0].trim());
            final lng = double.tryParse(gps[1].trim());
            if (lat != null && lng != null) {
              return Marker(
                markerId: MarkerId('supplier_${supplier.id}'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: supplier.name,
                  snippet: supplier.kategoriName ?? supplier.jenis,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                onTap: () {
                  setState(() {
                    _selectedSupplier = supplier;
                  });
                },
              );
            }
          }
          return null;
        })
        .where((marker) => marker != null)
        .cast<Marker>()
        .toSet();

    // Add user location marker if available
    if (widget.userLocation != null) {
      suppliers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: widget.userLocation!,
          infoWindow: const InfoWindow(
            title: 'Lokasi Saya',
            snippet: 'Lokasi saat ini',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    _clickableMarkers = suppliers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              0,
              (1 - _slideAnimation.value) * MediaQuery.of(context).size.height,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle and header
                  GestureDetector(
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  'Lokasi Supplier',
                                  style: AppTextStyles.h5.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    _animationController.reverse().then((_) {
                                      Navigator.of(context).pop();
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Map
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _mapCenter,
                          zoom: 16,
                        ),
                        markers: _clickableMarkers,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: true,
                        compassEnabled: true,
                        trafficEnabled: false,
                        buildingsEnabled: true,
                      ),
                    ),
                  ),

                  // Supplier info at bottom
                  if (_selectedSupplier != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
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
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.store,
                                  color: AppColors.primaryGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedSupplier!.name,
                                      style: AppTextStyles.h6.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedSupplier!.kategoriName ??
                                          _selectedSupplier!.jenis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Supplier code
                          if (_selectedSupplier!.kode != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedSupplier!.kode!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Employee info
                          if (_selectedSupplier!.karyawan != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedSupplier!.karyawan} (${_selectedSupplier!.jabatan ?? 'Staff'})',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Address info
                          if (_selectedSupplier!.alamat != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: AppColors.accentOrange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedSupplier!.alamat!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          if (_selectedSupplier!.phone != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedSupplier!.phone!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    // TODO: Implement call functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Fitur panggilan akan segera tersedia',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.call,
                                    color: AppColors.primaryGreen,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Bottom safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
