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
  AssignmentStats? assignmentStats;
  ActualVisitStats? actualVisitStats;
  VisitPerformance? visitStats;
  Map<String, dynamic>? activity;
  Map<String, dynamic>? acquisition;
  int days = 7;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days - 1));
    var failed = false;
    await Future.wait([
      MyStatisticService.actualVisits(from, now)
          .then((value) {
            actualVisitStats = value;
          })
          .catchError((_) {
            failed = true;
          }),
      MyStatisticService.assignment(from, now)
          .then((value) {
            assignmentStats = value;
          })
          .catchError((_) {
            failed = true;
          }),
      MyStatisticService.visitPerformance(from, now)
          .then((value) {
            visitStats = value;
          })
          .catchError((_) {
            failed = true;
          }),
      MyStatisticService.acquisition(from, now)
          .then((value) {
            acquisition = value;
          })
          .catchError((_) {
            failed = true;
          }),
      MyStatisticService.supplierActivity(from, now)
          .then((value) {
            activity = value;
          })
          .catchError((_) {
            failed = true;
          }),
    ]);
    if (mounted) {
      setState(() {
        _loadFailed = failed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Statistik Saya'),
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: _loading && assignmentStats == null
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed && assignmentStats == null
          ? _buildErrorState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _rangeSelector(),
                const SizedBox(height: 16),
                actualVisitStats == null
                    ? _unavailableCard(
                        'Performa kunjungan aktual tidak dapat dimuat',
                      )
                    : _buildActualVisitCard(actualVisitStats!),
                const SizedBox(height: 16),
                if (visitStats != null) _buildMissionActivityCard(visitStats!),
                const SizedBox(height: 24),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        icon: Icons.trending_up_rounded,
                        title: 'Pencapaian akuisisi',
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Volume terkumpul',
                              acquisition == null
                                  ? '—'
                                  : _formatVolume(
                                      _number(acquisition?['total_kg']),
                                    ),
                              AppColors.primaryGreen,
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              'Nilai akuisisi',
                              acquisition == null
                                  ? '—'
                                  : _formatRupiah(
                                      _number(acquisition?['total_amount']),
                                    ),
                              AppColors.info,
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (assignmentStats != null) ...[
                  _sectionHeading(
                    icon: Icons.task_alt_rounded,
                    title: 'Tugas pribadi · ${_periodLabel()}',
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _statCard(
                        'Total',
                        assignmentStats!.total,
                        AppColors.textPrimary,
                      ),
                      _statCard(
                        'Selesai',
                        assignmentStats!.completed,
                        AppColors.success,
                      ),
                      _statCard(
                        'Proses',
                        assignmentStats!.inProgress,
                        AppColors.info,
                      ),
                      _statCard(
                        'Pending',
                        assignmentStats!.pending,
                        AppColors.accentOrange,
                      ),
                      _statCard(
                        'Overdue',
                        assignmentStats!.overdue,
                        AppColors.error,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (activity != null) ...[
                  _sectionHeading(
                    icon: Icons.storefront_outlined,
                    title: 'Supplier & aktivitas',
                    color: AppColors.accentOrange,
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
                const SizedBox(height: 24),
                _sectionHeading(
                  icon: Icons.show_chart_rounded,
                  title: 'Tren kunjungan & mission',
                  color: AppColors.info,
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  child: _buildTrendChart(
                    dates: (visitStats?.trend ?? const <Map<String, dynamic>>[])
                        .map((x) => '${x['date'] ?? ''}')
                        .toList(),
                    series: [
                      _ChartSeries(
                        label: 'Selesai',
                        color: AppColors.success,
                        values:
                            (visitStats?.trend ??
                                    const <Map<String, dynamic>>[])
                                .map((x) => _num(x['completed']))
                                .toList(),
                      ),
                      _ChartSeries(
                        label: 'Pending',
                        color: AppColors.accentOrange,
                        values:
                            (visitStats?.trend ??
                                    const <Map<String, dynamic>>[])
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

  Widget _buildErrorState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(28),
    children: [
      SizedBox(
        height: MediaQuery.sizeOf(context).height * .58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Statistik belum dapat dimuat',
              textAlign: TextAlign.center,
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Periksa koneksi internet, lalu coba muat kembali.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading ? null : load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _unavailableCard(String message) => _sectionCard(
    child: Text(
      message,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _buildActualVisitCard(ActualVisitStats value) {
    final completion = value.completionRate.clamp(0, 100).toDouble();
    final period = switch (days) {
      1 => 'Hari ini',
      30 => '30 hari terakhir',
      _ => '7 hari terakhir',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D3E), Color(0xFF2E7D5B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: .20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Kunjungan aktual',
                  style: AppTextStyles.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                period,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.total == 0 ? '—' : '${completion.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    value.total == 0
                        ? 'Belum ada check-in pada periode ini'
                        : 'check-in berakhir dengan checkout',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: .88),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .22),
              color: const Color(0xFFFFC66D),
            ),
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withValues(alpha: .24), height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _performanceStat(
                  'Checkout selesai',
                  '${value.completed}',
                  Icons.check_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _performanceStat(
                  'Total check-in',
                  '${value.total}',
                  Icons.assignment_outlined,
                ),
              ),
              Expanded(
                child: _performanceStat(
                  'Belum checkout',
                  '${value.total - value.completed}',
                  Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionActivityCard(VisitPerformance value) => _sectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          icon: Icons.route_outlined,
          title: 'Ringkasan status mission',
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: 12),
        Text(
          '${value.completed} selesai · ${value.skipped} dilewati · ${value.pending} belum selesai. Mengikuti status mission dan aktivitas kunjungan.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  String _periodLabel() => switch (days) {
    1 => 'hari ini',
    30 => '30 hari',
    _ => '7 hari',
  };

  Widget _performanceStat(String label, String amount, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: .82),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        amount,
        style: AppTextStyles.h6.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required Color color,
  }) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
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

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _compactNumber(double value) {
    final fixed = value.toStringAsFixed(1);
    final trimmed = fixed.endsWith('.0')
        ? fixed.substring(0, fixed.length - 2)
        : fixed;
    return trimmed.replaceFirst('.', ',');
  }

  String _formatVolume(double kilograms) => kilograms >= 1000
      ? '${_compactNumber(kilograms / 1000)} ton'
      : '${_compactNumber(kilograms)} kg';

  String _formatRupiah(double amount) {
    if (amount >= 1000000) return 'Rp ${_compactNumber(amount / 1000000)} jt';
    if (amount >= 1000) return 'Rp ${_compactNumber(amount / 1000)} rb';
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

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

  Widget _statCard(
    String label,
    Object value,
    Color color, {
    double width = 104,
  }) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    constraints: const BoxConstraints(minHeight: 82),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday\n${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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
                handleBuiltInTouches: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex < series.length
                        ? series[rodIndex].label
                        : '';
                    final date = groupIndex < dates.length
                        ? _shortDate(dates[groupIndex]).replaceAll('\n', ' ')
                        : '';
                    return BarTooltipItem(
                      '$date\n$label: ${rod.toY.toInt()}',
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
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _shortDate(dates[index]),
                          textAlign: TextAlign.center,
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
