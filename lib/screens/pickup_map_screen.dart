import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/dynamic_pickup_map_widget.dart';

class PickupMapScreen extends StatefulWidget {
  final LatLng? driverPosition;
  final List<dynamic> stops;
  final List<LatLng> routePolyline;
  final Future<void> Function(dynamic stop)? onStopTap;

  const PickupMapScreen({
    super.key,
    this.driverPosition,
    required this.stops,
    required this.routePolyline,
    this.onStopTap,
  });

  @override
  State<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends State<PickupMapScreen> {
  final MapController _mapController = MapController();

  void _fitAllMarkers() {
    final points = <LatLng>[
      if (widget.driverPosition != null) widget.driverPosition!,
      ...widget.stops.map<LatLng?>((stop) {
        try {
          return stop.position as LatLng;
        } catch (_) {
          return null;
        }
      }).whereType<LatLng>(),
    ];

    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapController.move(points.first, 14);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 48),
          maxZoom: 13.5,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Peta Lokasi Pickup',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: DynamicPickupMapWidget(
        mapController: _mapController,
        driverPosition: widget.driverPosition,
        stops: widget.stops,
        routePolyline: widget.routePolyline,
        onMapReady: _fitAllMarkers,
        onStopTap: (stop, _) async {
          await widget.onStopTap?.call(stop);
        },
      ),
    );
  }
}
