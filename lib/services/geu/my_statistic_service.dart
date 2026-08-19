import 'geu_api_client.dart';

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
    if (response.statusCode != 200 || body is! Map)
      throw Exception('Statistik tidak dapat dimuat.');
    return AssignmentStats.fromJson(body['data'] is Map ? body['data'] : body);
  }
}
