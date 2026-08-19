import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/geu/my_statistic_service.dart';

class MyStatisticScreen extends StatefulWidget {
  const MyStatisticScreen({super.key});
  @override
  State<MyStatisticScreen> createState() => _MyStatisticScreenState();
}

class _MyStatisticScreenState extends State<MyStatisticScreen> {
  AssignmentStats? stats;
  Map<String, dynamic>? activity;
  int days = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days - 1));
    final result = await Future.wait([
      MyStatisticService.assignment(from, now),
      MyStatisticService.supplierActivity(from, now),
    ]);
    stats = result[0] as AssignmentStats;
    activity = result[1] as Map<String, dynamic>;
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Statistik Saya')),
    body: RefreshIndicator(
      onRefresh: load,
      child: _loading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _rangeSelector(),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _statCard('Total', stats!.total, AppColors.textPrimary),
                    _statCard('Selesai', stats!.completed, AppColors.success),
                    _statCard('Proses', stats!.inProgress, AppColors.info),
                    _statCard(
                      'Pending',
                      stats!.pending,
                      AppColors.accentOrange,
                    ),
                    _statCard('Overdue', stats!.overdue, AppColors.error),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Completion rate',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${stats!.rate.toStringAsFixed(1)}%',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (stats!.rate / 100).clamp(0, 1),
                          minHeight: 10,
                          backgroundColor: AppColors.backgroundGrey,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                if (activity != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Supplier & aktivitas',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _statCard(
                        'Supplier baru',
                        int.tryParse('${activity!['new']}') ?? 0,
                        AppColors.primaryGreen,
                      ),
                      _statCard(
                        'Supplier existing',
                        int.tryParse('${activity!['existing']}') ?? 0,
                        AppColors.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    child: _buildTrendChart(
                      title: 'WO & PO per hari',
                      dates: ((activity!['trend'] as List? ?? [])
                          .whereType<Map>()
                          .map((e) => '${e['date'] ?? ''}')
                          .toList()),
                      series: [
                        _ChartSeries(
                          label: 'WO',
                          color: AppColors.accentOrange,
                          values: ((activity!['trend'] as List? ?? [])
                              .whereType<Map>()
                              .map((e) => _num(e['wo']))
                              .toList()),
                        ),
                        _ChartSeries(
                          label: 'PO',
                          color: AppColors.info,
                          values: ((activity!['trend'] as List? ?? [])
                              .whereType<Map>()
                              .map((e) => _num(e['po']))
                              .toList()),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Tren harian',
                  style: AppTextStyles.h6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  child: _buildTrendChart(
                    dates: stats!.trend
                        .map((x) => '${x['date'] ?? ''}')
                        .toList(),
                    series: [
                      _ChartSeries(
                        label: 'Selesai',
                        color: AppColors.success,
                        values: stats!.trend
                            .map((x) => _num(x['completed']))
                            .toList(),
                      ),
                      _ChartSeries(
                        label: 'Pending',
                        color: AppColors.accentOrange,
                        values: stats!.trend
                            .map((x) => _num(x['pending']))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _rangeSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderColor),
    ),
    child: Row(
      children: [
        _rangeOption(1, 'Hari ini'),
        _rangeOption(7, '7 hari'),
        _rangeOption(30, '30 hari'),
      ],
    ),
  );

  Widget _rangeOption(int value, String label) {
    final selected = days == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => days = value);
          load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryGreen.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderColor),
    ),
    child: child,
  );

  Widget _statCard(String label, int value, Color color) => Container(
    width: 104,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.h5.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String _shortDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  /// Grouped bar chart with a tap-to-reveal tooltip showing the exact value
  /// per series — replaces the old raw-ISO-timestamp list rows.
  Widget _buildTrendChart({
    String? title,
    required List<String> dates,
    required List<_ChartSeries> series,
  }) {
    if (dates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Belum ada data pada rentang ini.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final maxY = series
        .expand((s) => s.values)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final safeMaxY = maxY <= 0 ? 1.0 : maxY * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: series
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: safeMaxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex < series.length
                        ? series[rodIndex].label
                        : '';
                    return BarTooltipItem(
                      '$label\n${rod.toY.toInt()}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _shortDate(dates[index]),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(dates.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: series
                      .map(
                        (s) => BarChartRodData(
                          toY: i < s.values.length ? s.values[i] : 0,
                          color: s.color,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                      .toList(),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartSeries {
  final String label;
  final Color color;
  final List<double> values;
  _ChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });
}
