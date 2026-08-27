import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';

class OccupancyGauge extends StatelessWidget {
  const OccupancyGauge({
    super.key,
    required this.available,
    required this.occupied,
    required this.reserved,
    required this.occupancyRate,
  });

  final int available;
  final int occupied;
  final int reserved;
  final double occupancyRate;

  @override
  Widget build(BuildContext context) {
    final total = available + occupied + reserved;
    final sections = total == 0
        ? [
            PieChartSectionData(
              color: Colors.grey.shade600,
              value: 1,
              title: '',
              radius: 20,
            ),
          ]
        : [
            PieChartSectionData(
              color: AppColors.error,
              value: occupied.toDouble(),
              title: '',
              radius: 20,
            ),
            PieChartSectionData(
              color: AppColors.warning,
              value: reserved.toDouble(),
              title: '',
              radius: 20,
            ),
            PieChartSectionData(
              color: AppColors.success,
              value: available.toDouble(),
              title: '',
              radius: 20,
            ),
          ];

    return AdminCard(
      title: 'Live Occupancy',
      child: SizedBox(
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 80,
                sections: sections,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${occupancyRate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text('Occupied', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Text(
                  '$occupied occupied • $reserved reserved',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
