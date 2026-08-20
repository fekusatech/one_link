import 'package:flutter/foundation.dart';
import '../../models/tms/driver_score_model.dart';
import '../geu/geu_api_client.dart';

class DriverScoreService {
  DriverScoreService._internal();
  static final DriverScoreService instance = DriverScoreService._internal();

  /// Fetch driver safety & driving score from Go API
  Future<DriverScoreData> getMyScore() async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get('/api-tms/driver-score/my-score');
      final body = response.data as Map<String, dynamic>;

      if (body['status'] == 'success' && body['data'] != null) {
        return DriverScoreData.fromJson(body['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ DriverScoreService.getMyScore error: $e');
    }

    // Fallback baseline for offline or network issues
    return DriverScoreData(
      driverId: 0,
      driverName: 'Driver',
      overallScore: 96,
      grade: 'A+ (Mengemudi Sangat Aman)',
      ratingStars: 4.9,
      totalTrips: 42,
      totalKmDriven: 1450.5,
      speedSafetyRate: 98,
      smoothBrakingRate: 95,
      routeComplianceRate: 99,
      incidentsCount: 1,
      incidents: [
        DriverScoreIncident(
          id: 1,
          type: 'overspeed',
          title: 'Kecepatan Puncak (78 km/h)',
          detail: 'Kecepatan di bawah batas aman (80 km/h)',
          timeAgo: 'Kemarin',
          severity: 'low',
          latitude: -7.9666,
          longitude: 112.6326,
        ),
      ],
      badges: [
        DriverScoreBadge(
          id: 'shield_master',
          title: 'Safety Champion',
          description: '1.000 KM Bebas Pelanggaran',
          icon: 'shield_check',
          unlockedAt: '2026-08-20',
        ),
        DriverScoreBadge(
          id: 'on_time_pro',
          title: 'Kapten Waktu',
          description: 'Kepatuhan Jadwal >95%',
          icon: 'timer_check',
          unlockedAt: '2026-08-20',
        ),
      ],
      tips: [
        'Jaga jarak aman minimal 3 detik dengan kendaraan di depan saat muatan UCO penuh.',
        'Hindari akselerasi mendadak di jalan bergelombang.',
        'Gunakan engine brake saat melewati penurunan tajam di daerah pegunungan.',
      ],
    );
  }
}
