import 'geu_api_client.dart';

class VisitPerformance {
  final int total, completed, pending, skipped;
  final double rate;
  final List<Map<String, dynamic>> trend;

  const VisitPerformance({
    required this.total,
    required this.completed,
    required this.pending,
    required this.skipped,
    required this.rate,
    required this.trend,
  });

  factory VisitPerformance.fromHistory(List<dynamic> days) {
    var total = 0;
    var completed = 0;
    var skipped = 0;
    final trend = <Map<String, dynamic>>[];

    for (final rawDay in days.whereType<Map>()) {
      final items = (rawDay['items'] as List? ?? []).whereType<Map>();
      var dayCompleted = 0;
      var dayPending = 0;
      for (final item in items) {
        total++;
        switch ('${item['status'] ?? ''}'.toUpperCase()) {
          case 'VISITED':
            completed++;
            dayCompleted++;
          case 'SKIPPED':
            skipped++;
          default:
            dayPending++;
        }
      }
      trend.add({
        'date': '${rawDay['visit_date'] ?? ''}',
        'completed': dayCompleted,
        'pending': dayPending,
      });
    }

    return VisitPerformance(
      total: total,
      completed: completed,
      pending: total - completed - skipped,
      skipped: skipped,
      rate: total == 0 ? 0 : completed * 100 / total,
      trend: trend,
    );
  }
}

class ActualVisitStats {
  final int total, completed;
  final double averageDurationMinutes;

  const ActualVisitStats({
    required this.total,
    required this.completed,
    required this.averageDurationMinutes,
  });

  double get completionRate => total == 0 ? 0 : completed * 100 / total;

  factory ActualVisitStats.fromJson(Map data) => ActualVisitStats(
    total: int.tryParse('${data['total_visits'] ?? 0}') ?? 0,
    completed: int.tryParse('${data['completed_visits'] ?? 0}') ?? 0,
    averageDurationMinutes:
        double.tryParse('${data['avg_duration'] ?? 0}') ?? 0,
  );
}

class AssignmentStats {
  final int total, completed, inProgress, pending, overdue;
  final double rate;
  final List<Map<String, dynamic>> trend;
  const AssignmentStats({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
    required this.overdue,
    required this.rate,
    required this.trend,
  });
  factory AssignmentStats.fromJson(Map data) => AssignmentStats(
    total: int.tryParse('${data['total'] ?? 0}') ?? 0,
    completed: int.tryParse('${data['completed'] ?? 0}') ?? 0,
    inProgress: int.tryParse('${data['in_progress'] ?? 0}') ?? 0,
    pending: int.tryParse('${data['pending'] ?? 0}') ?? 0,
    overdue: int.tryParse('${data['overdue'] ?? 0}') ?? 0,
    rate: double.tryParse('${data['completion_rate'] ?? 0}') ?? 0,
    trend: (data['daily_trend'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
  );
}

class MyStatisticService {
  static Future<ActualVisitStats> actualVisits(
    DateTime from,
    DateTime to,
  ) async {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await (await GeuApiClient.instance).get(
      '/api/visits/stats',
      queryParameters: {'date_from': date(from), 'date_to': date(to)},
    );
    final body = response.data;
    final data = body is Map && body['data'] is Map
        ? body['data'] as Map
        : null;
    if (response.statusCode != 200 || data == null) {
      throw Exception('Statistik checkout tidak dapat dimuat.');
    }
    return ActualVisitStats.fromJson(data);
  }

  static Future<VisitPerformance> visitPerformance(
    DateTime from,
    DateTime to,
  ) async {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await (await GeuApiClient.instance).get(
      '/api/visit-planner/mission/history',
      queryParameters: {'date_from': date(from), 'date_to': date(to)},
    );
    final body = response.data;
    final data = body is Map && body['data'] is List
        ? body['data'] as List
        : null;
    if (response.statusCode != 200 || data == null) {
      throw Exception('Statistik kunjungan tidak dapat dimuat.');
    }
    return VisitPerformance.fromHistory(data);
  }

  static Future<Map<String, dynamic>> acquisition(
    DateTime from,
    DateTime to,
  ) async {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await (await GeuApiClient.instance).get(
      '/api-crm/dashboard/my-statistic/acquisition',
      queryParameters: {'date_from': date(from), 'date_to': date(to)},
    );
    final body = response.data;
    if (response.statusCode != 200 || body is! Map) {
      throw Exception('Pencapaian volume tidak dapat dimuat.');
    }
    final data = body['data'] is Map ? body['data'] as Map : body;
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> supplierActivity(
    DateTime from,
    DateTime to,
  ) async {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final dio = await GeuApiClient.instance;
    final values = await Future.wait([
      dio.get(
        '/api-crm/dashboard/my-statistic/new-supplier',
        queryParameters: {'date_from': date(from), 'date_to': date(to)},
      ),
      dio.get('/api-crm/dashboard/my-statistic/existing-supplier'),
      dio.get(
        '/api-crm/dashboard/my-statistic/daily-activity',
        queryParameters: {'date_from': date(from), 'date_to': date(to)},
      ),
    ]);
    Map data(dynamic response) =>
        response.data is Map && response.data['data'] is Map
        ? response.data['data'] as Map
        : response.data as Map;
    return {
      'new': data(values[0])['created'] ?? 0,
      'existing': data(values[1])['total'] ?? 0,
      'trend': data(values[2])['daily_trend'] ?? [],
    };
  }

  static Future<AssignmentStats> assignment(DateTime from, DateTime to) async {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await (await GeuApiClient.instance).get(
      '/api-crm/dashboard/my-statistic/assignment-performance',
      queryParameters: {'date_from': date(from), 'date_to': date(to)},
    );
    final body = response.data;
    if (response.statusCode != 200 || body is! Map) {
      throw Exception('Statistik tidak dapat dimuat.');
    }
    return AssignmentStats.fromJson(body['data'] is Map ? body['data'] : body);
  }
}
