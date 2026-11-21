import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Small, non-interactive map thumbnail for one GPS point - mirrors
/// crm-react's GpsMapPreview (components/shared/gps-map-preview.tsx),
/// closing the "just a text link" gap crm-mobile's WO detail visit cards
/// had versus crm-react/erpmysql, which both show an inline map, not just
/// a "Buka di Maps" link.
class GpsMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final Color markerColor;

  const GpsMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.markerColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 110,
      child: IgnorePointer(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            // Plain OpenStreetMap tiles - free, no API key, same source
            // erpmysql's own Leaflet driver map uses (map_tracking.php).
            // CartoDB's basemaps started asking for a key, this doesn't.
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.one_link',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(latitude, longitude),
                  width: 28,
                  height: 28,
                  child: Icon(Icons.location_on, color: markerColor, size: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
