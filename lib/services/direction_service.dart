import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../config/app_config.dart';

class DirectionService {
  static final PolylinePoints _polylinePoints = PolylinePoints();

  /// Mengambil rute jalan (road-following) antara dua koordinat
  static Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      print('🔍 Fetching directions from Google API...');
      print('📍 From: ${origin.latitude},${origin.longitude}');
      print('📍 To: ${destination.latitude},${destination.longitude}');

      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConfig.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        print('✅ Successfully fetched ${result.points.length} polyline points');
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      } else {
        print('⚠️ No points found in directions response: ${result.errorMessage}');
        // Fallback ke garis lurus jika gagal
        return [origin, destination];
      }
    } catch (e) {
      print('❌ DirectionService Error: $e');
      // Fallback ke garis lurus jika error
      return [origin, destination];
    }
  }
}
