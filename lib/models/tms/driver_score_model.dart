class DriverScoreIncident {
  final int id;
  final String type;
  final String title;
  final String detail;
  final String timeAgo;
  final String severity;
  final double latitude;
  final double longitude;

  DriverScoreIncident({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timeAgo,
    required this.severity,
    required this.latitude,
    required this.longitude,
  });

  factory DriverScoreIncident.fromJson(Map<String, dynamic> json) {
    return DriverScoreIncident(
      id: json['id'] ?? 0,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DriverScoreBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String unlockedAt;

  DriverScoreBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
  });

  factory DriverScoreBadge.fromJson(Map<String, dynamic> json) {
    return DriverScoreBadge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      unlockedAt: json['unlocked_at']?.toString() ?? '',
    );
  }
}

class DriverScoreHistoryDay {
  final String date;
  final int score;
  final double totalKmDriven;
  final int speedSafetyRate;
  final int smoothBrakingRate;
  final int overspeedCount;
  final int harshBrakeCount;

  DriverScoreHistoryDay({
    required this.date,
    required this.score,
    required this.totalKmDriven,
    required this.speedSafetyRate,
    required this.smoothBrakingRate,
    required this.overspeedCount,
    required this.harshBrakeCount,
  });

  factory DriverScoreHistoryDay.fromJson(Map<String, dynamic> json) {
    return DriverScoreHistoryDay(
      date: json['date']?.toString() ?? '',
      score: json['score'] ?? 0,
      totalKmDriven: (json['total_km_driven'] as num?)?.toDouble() ?? 0.0,
      speedSafetyRate: json['speed_safety_rate'] ?? 0,
      smoothBrakingRate: json['smooth_braking_rate'] ?? 0,
      overspeedCount: json['overspeed_count'] ?? 0,
      harshBrakeCount: json['harsh_brake_count'] ?? 0,
    );
  }
}

class DriverScoreData {
  final int driverId;
  final String driverName;
  final int overallScore;
  final String grade;
  final double ratingStars;
  final int totalTrips;
  final double totalKmDriven;
  final int speedSafetyRate;
  final int smoothBrakingRate;
  final int routeComplianceRate;
  final int incidentsCount;
  final List<DriverScoreIncident> incidents;
  final List<DriverScoreBadge> badges;
  final List<String> tips;

  DriverScoreData({
    required this.driverId,
    required this.driverName,
    required this.overallScore,
    required this.grade,
    required this.ratingStars,
    required this.totalTrips,
    required this.totalKmDriven,
    required this.speedSafetyRate,
    required this.smoothBrakingRate,
    required this.routeComplianceRate,
    required this.incidentsCount,
    required this.incidents,
    required this.badges,
    required this.tips,
  });

  factory DriverScoreData.fromJson(Map<String, dynamic> json) {
    return DriverScoreData(
      driverId: json['driver_id'] ?? 0,
      driverName: json['driver_name']?.toString() ?? 'Driver',
      overallScore: json['overall_score'] ?? 95,
      grade: json['grade']?.toString() ?? 'A+ (Mengemudi Sangat Aman)',
      ratingStars: (json['rating_stars'] as num?)?.toDouble() ?? 4.9,
      totalTrips: json['total_trips'] ?? 0,
      totalKmDriven: (json['total_km_driven'] as num?)?.toDouble() ?? 0.0,
      speedSafetyRate: json['speed_safety_rate'] ?? 98,
      smoothBrakingRate: json['smooth_braking_rate'] ?? 95,
      routeComplianceRate: json['route_compliance_rate'] ?? 99,
      incidentsCount: json['incidents_count'] ?? 0,
      incidents: (json['incidents'] as List<dynamic>?)
              ?.map((e) => DriverScoreIncident.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => DriverScoreBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
