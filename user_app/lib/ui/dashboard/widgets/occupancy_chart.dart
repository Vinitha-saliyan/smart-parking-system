import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class OccupancyChart extends StatefulWidget {
  final int vacant;
  final int occupied;
  final int reserved;

  const OccupancyChart({
    super.key,
    required this.vacant,
    required this.occupied,
    required this.reserved,
  });

  @override
  State<OccupancyChart> createState() => _OccupancyChartState();
}

class _OccupancyChartState extends State<OccupancyChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    int total = widget.vacant + widget.occupied + widget.reserved;
    if (total == 0) total = 1; // Prevent division by zero

    return AspectRatio(
      aspectRatio: 1,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  touchedIndex = -1;
                  return;
                }
                touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            PieChartSectionData(
              color: AppColors.slotVacant,
              value: widget.vacant.toDouble(),
              title: '${((widget.vacant / total) * 100).toStringAsFixed(0)}%',
              radius: touchedIndex == 0 ? 40.0 : 30.0,
              titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            PieChartSectionData(
              color: AppColors.slotOccupied,
              value: widget.occupied.toDouble(),
              title: '${((widget.occupied / total) * 100).toStringAsFixed(0)}%',
              radius: touchedIndex == 1 ? 40.0 : 30.0,
              titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            PieChartSectionData(
              color: AppColors.slotReserved,
              value: widget.reserved.toDouble(),
              title: '${((widget.reserved / total) * 100).toStringAsFixed(0)}%',
              radius: touchedIndex == 2 ? 40.0 : 30.0,
              titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
