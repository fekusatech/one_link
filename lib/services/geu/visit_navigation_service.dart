import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Road-following route for Flutter Map. The map remains inside Visit Plan;
/// no external navigation application is opened for a field mission.
class VisitNavigationService {
  static Future<List<LatLng>> drivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.https('router.project-osrm.org', '/route/v1/driving/$coordinates', {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      final body = jsonDecode(response.body);
      final routes = body is Map ? body['routes'] : null;
      final geometry = routes is List && routes.isNotEmpty && routes.first is Map
          ? routes.first['geometry']
          : null;
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      if (response.statusCode == 200 && coordinates is List) {
        final points = coordinates
            .whereType<List>()
            .where((point) => point.length >= 2)
            .map(
              (point) => LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ),
            )
            .toList();
        if (points.length >= 2) return points;
      }
    } catch (_) {
      // A direct line remains a useful, honest fallback when route service is
      // unavailable; the user location marker still keeps updating.
    }
    return [origin, destination];
  }
}
