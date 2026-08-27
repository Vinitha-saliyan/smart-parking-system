import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/data/models/stats_model.dart';

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.points});

  final List<DailyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final chartPoints = points.isEmpty
        ? List.generate(
            7,
            (index) => DailyRevenuePoint(
              date: DateTime.now().subtract(Duration(days: 6 - index)),
              amount: 0,
            ),
          )
        : points;
    final highest = chartPoints.fold<double>(
      0,
      (value, point) => math.max(value, point.amount),
    );
    final maxY = math.max(1.0, highest * 1.2);

    return AdminCard(
      title: 'Revenue (Last 7 Days)',
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (chartPoints.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) => Text(
                    NumberFormat.compactCurrency(
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(value),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= chartPoints.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(DateFormat.E().format(chartPoints[index].date)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var index = 0; index < chartPoints.length; index++)
                    FlSpot(index.toDouble(), chartPoints[index].amount),
                ],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withOpacity(0.16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
