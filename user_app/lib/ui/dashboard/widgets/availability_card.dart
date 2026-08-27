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
    double percentage = totalSlots == 0 ? 0.0 : occupiedSlots / totalSlots;
    Color indicatorColor = percentage < 0.5
        ? AppColors.success
        : (percentage < 0.8 ? AppColors.warning : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          CircularPercentIndicator(
            radius: 40.0,
            lineWidth: 8.0,
            animation: true,
            percent: percentage,
            center: AnimatedCounter(
              targetValue: percentage * 100,
              suffix: '%',
              textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: indicatorColor,
            backgroundColor: Colors.grey.withOpacity(0.2),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Available', availableSlots, AppColors.success),
              const SizedBox(height: 8),
              _buildStatRow('Occupied', occupiedSlots, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count, Color color) {
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
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        AnimatedCounter(
          targetValue: count,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
