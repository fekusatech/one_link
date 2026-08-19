import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/services/geu/haversine.dart';

void main() {
  test('same point is zero distance', () {
    expect(haversineDistanceKm(-6.2, 106.8, -6.2, 106.8), closeTo(0, 0.0001));
  });

  test('Jakarta to Bandung is roughly 115-125km', () {
    // Monas (-6.1754, 106.8272) to Gedung Sate (-6.9024, 107.6186)
    final d = haversineDistanceKm(-6.1754, 106.8272, -6.9024, 107.6186);
    expect(d, greaterThan(110));
    expect(d, lessThan(130));
  });

  test('500m apart is within visit_checkin_max_distance_km default (0.5km)', () {
    // ~0.0045 deg latitude ≈ 500m
    final d = haversineDistanceKm(-6.2, 106.8, -6.2045, 106.8);
    expect(d, closeTo(0.5, 0.05));
  });
}
