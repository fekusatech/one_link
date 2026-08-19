import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../constants/app_colors.dart';
import '../services/geu/geu_api_client.dart';

enum MapEngineType { googleMaps, leafletOsm }

class DynamicPickupMapWidget extends StatefulWidget {
  final MapController mapController;
  final LatLng? driverPosition;
  final List<dynamic> stops;
  final List<LatLng> routePolyline;
  final Function(dynamic stop, int order)? onStopTap;
  final VoidCallback? onMapReady;

  const DynamicPickupMapWidget({
    super.key,
    required this.mapController,
    this.driverPosition,
    required this.stops,
    required this.routePolyline,
    this.onStopTap,
    this.onMapReady,
  });

  @override
  State<DynamicPickupMapWidget> createState() => _DynamicPickupMapWidgetState();
}

class _DynamicPickupMapWidgetState extends State<DynamicPickupMapWidget> {
  MapEngineType _currentEngine = MapEngineType.leafletOsm;
  String _googleMapsApiKey = '';
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    _fetchMapConfig();
  }

  Future<void> _fetchMapConfig() async {
    try {
      final dio = Dio();
      final response = await dio.get('${GeuApiClient.baseUrl}/api/mobile/config');
      if (response.statusCode == 200 && response.data is Map) {
        final key = response.data['google_maps_api_key']?.toString() ?? '';
        if (key.isNotEmpty) {
          setState(() {
            _googleMapsApiKey = key;
            _currentEngine = MapEngineType.googleMaps; // Default to Google Maps if key is valid
            _isLoadingConfig = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoadingConfig = false;
      });
    }
  }

  void _toggleEngine() {
    setState(() {
      if (_currentEngine == MapEngineType.googleMaps) {
        _currentEngine = MapEngineType.leafletOsm;
      } else {
        _currentEngine = MapEngineType.googleMaps;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Tile URL
    String tileUrl;
    if (_currentEngine == MapEngineType.googleMaps) {
      tileUrl = _googleMapsApiKey.isNotEmpty
          ? 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=$_googleMapsApiKey'
          : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    } else {
      tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    final initialCenter = widget.driverPosition ??
        (widget.stops.isNotEmpty
            ? widget.stops.first.position
            : const LatLng(-7.9797, 112.6304));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13,
              onMapReady: widget.onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.one_link',
                errorTileCallback: (tile, error, stackTrace) {
                  // Fallback to Leaflet OSM if Google Maps tile fails to load
                  if (_currentEngine == MapEngineType.googleMaps) {
                    setState(() {
                      _currentEngine = MapEngineType.leafletOsm;
                    });
                  }
                },
              ),

              // Polyline Layer for Driving Route
              if (widget.routePolyline.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePolyline,
                      color: const Color(0xFF1877F2),
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // Marker Layer for Driver Position & Pickup Stops
              MarkerLayer(
                markers: [
                  // Driver Marker
                  if (widget.driverPosition != null)
                    Marker(
                      point: widget.driverPosition!,
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                  // Stop Markers
                  ...widget.stops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    final status = stop.detail.status.toLowerCase();
                    final isDone = status == 'done';
                    final isCancelled = status == 'cancelled';

                    Color pinColor = AppColors.error;
                    if (isDone) pinColor = AppColors.success;
                    if (isCancelled) pinColor = AppColors.grey;

                    return Marker(
                      point: stop.position,
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => widget.onStopTap?.call(stop, index + 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: pinColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x44000000), blurRadius: 5),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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

          // Map Engine Switcher Button (Top Right Floating Badge)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _toggleEngine,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentEngine == MapEngineType.googleMaps
                          ? Icons.map_rounded
                          : Icons.eco_rounded,
                      size: 16,
                      color: _currentEngine == MapEngineType.googleMaps
                          ? Colors.blue.shade700
                          : AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentEngine == MapEngineType.googleMaps ? 'Google Maps' : 'Leaflet OSM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _currentEngine == MapEngineType.googleMaps
                            ? Colors.blue.shade900
                            : AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
