import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/animated_counter.dart';

class AvailabilityCard extends StatelessWidget {
  final int totalSlots;
  final int availableSlots;
  final int occupiedSlots;

  const AvailabilityCard({
    super.key,
    required this.totalSlots,
    required this.availableSlots,
    required this.occupiedSlots,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalSlots <= 0
        ? 0.0
        : (availableSlots / totalSlots).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          CircularPercentIndicator(
            radius: 48.0,
            lineWidth: 10.0,
            animation: true,
            percent: percentage,
            center: AnimatedCounter(
              targetValue: percentage * 100,
              suffix: '%',
              textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: AppColors.success,
            backgroundColor: AppColors.error.withOpacity(0.9),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                  context, 'Available', availableSlots, AppColors.success),
              const SizedBox(height: 14),
              _buildStatRow(
                  context, 'Occupied', occupiedSlots, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedCounter(
          targetValue: count,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
