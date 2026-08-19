import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../config/app_config.dart';

class DirectionService {
  static final Dio _dio = Dio();
  static final PolylinePoints _polylinePoints = PolylinePoints();

  /// Mengambil rute jalan (real road-following geometry) antara dua koordinat LatLng
  static Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // 1. Coba panggil OSRM API (Open Source Routing Machine) untuk rute jalan asli tanpa bayar
    try {
      final osrmUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(osrmUrl);
      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes.first['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            final points = coords.map((c) {
              final lng = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();

            if (points.isNotEmpty) {
              print('✅ OSRM Route fetched: ${points.length} road points');
              return points;
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ OSRM Route failed: $e, trying Google Polyline API...');
    }

    // 2. Fallback ke Google Directions API jika OSRM gagal
    try {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConfig.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        print('✅ Google Directions fetched: ${result.points.length} points');
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      print('❌ DirectionService Error: $e');
    }

    // Fallback terakhir: garis lurus
    return [origin, destination];
  }
}
