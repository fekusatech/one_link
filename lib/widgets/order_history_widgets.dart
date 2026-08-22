import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/supplier_order_history.dart';

/// Shared building blocks for "riwayat setor" (order history) UI — first
/// built for the map's supplier-detail sheet, reused by the task detail
/// sheet since both pull from the same GET /api/suppliers/:id.

class OrderHistorySkeleton extends StatelessWidget {
  const OrderHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 220, height: 14),
        SizedBox(height: 10),
        SkeletonBox(width: 160, height: 14),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}

/// Minimal pulsing placeholder — no shimmer package in pubspec, and a
/// static grey box already reads clearly as "loading" without one.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;

  const SkeletonBox({super.key, required this.width, required this.height});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.borderColor,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// Small bar chart of the last few orders (oldest → newest, left to right)
/// — just enough to show a trend, not a full analytics chart.
class RecentOrdersChart extends StatelessWidget {
  final List<SupplierOrderHistoryItem> orders;

  const RecentOrdersChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final chronological = orders.reversed.toList();
    final maxNominal = chronological
        .map((o) => o.nominal)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxNominal <= 0 ? 1.0 : maxNominal * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final order = chronological[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('d/M').format(order.date)}\n'
                'Rp${order.nominal.round()}',
                const TextStyle(color: Colors.white, fontSize: 11),
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
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chronological.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d/M').format(chronological[index].date),
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < chronological.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: chronological[i].nominal,
                  color: const Color(0xFF2196F3),
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Rp-formatted text (dot thousands separator) — shared so every "riwayat
/// setor" surface renders nominal the same way.
String formatRupiah(double value) {
  final formatted = value
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  return 'Rp$formatted';
}
