import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class MalangWorkAreaService {
  static const _webMapDataUrl =
      'https://www.arcgis.com/sharing/rest/content/items/'
      'fb25cda6efba4a4995a4611a5080f76f/data?f=json';

  static Future<List<List<LatLng>>> loadBoundary() async {
    final response = await Dio().get(_webMapDataUrl);
    final body = response.data;
    final layers = body is Map ? body['operationalLayers'] : null;
    final featureCollection = layers is List && layers.isNotEmpty
        ? layers.first['featureCollection']
        : null;
    final featureLayers = featureCollection is Map
        ? featureCollection['layers']
        : null;
    final featureSet = featureLayers is List && featureLayers.isNotEmpty
        ? featureLayers.first['featureSet']
        : null;
    final features = featureSet is Map ? featureSet['features'] : null;
    if (features is! List) return const [];

    final polygons = <List<LatLng>>[];
    for (final feature in features) {
      final geometry = feature is Map ? feature['geometry'] : null;
      final rings = geometry is Map ? geometry['rings'] : null;
      if (rings is! List) continue;
      for (final ring in rings) {
        if (ring is! List || ring.length < 3) continue;
        final points = <LatLng>[];
        for (final coordinate in ring) {
          if (coordinate is! List || coordinate.length < 2) continue;
          final x = double.tryParse(coordinate[0].toString());
          final y = double.tryParse(coordinate[1].toString());
          if (x == null || y == null) continue;
          points.add(_webMercatorToLatLng(x, y));
        }
        if (points.length >= 3) polygons.add(points);
      }
    }
    return polygons;
  }

  static LatLng _webMercatorToLatLng(double x, double y) {
    const origin = 20037508.34;
    final longitude = x / origin * 180;
    final latitude =
        (2 * math.atan(math.exp(y / origin * math.pi)) - math.pi / 2) *
        180 /
        math.pi;
    return LatLng(latitude, longitude);
  }

  static bool contains(LatLng point, List<List<LatLng>> polygons) {
    for (final polygon in polygons) {
      var inside = false;
      for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        final a = polygon[i];
        final b = polygon[j];
        final intersects =
            ((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
            (point.longitude <
                (b.longitude - a.longitude) *
                        (point.latitude - a.latitude) /
                        (b.latitude - a.latitude) +
                    a.longitude);
        if (intersects) inside = !inside;
      }
      if (inside) return true;
    }
    return false;
  }
}
