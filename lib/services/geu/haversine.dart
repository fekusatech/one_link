import 'dart:math';

/// Great-circle distance in km — matches the formula op-sqlite/go-rest-api's
/// service layer uses server-side (src/service/crm/sales_visit_service.go),
/// so client and server never disagree on whether a check-in is "in range".
/// Pure function, no network — works with cached supplier coordinates while
/// offline (FR-VP-08).
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
