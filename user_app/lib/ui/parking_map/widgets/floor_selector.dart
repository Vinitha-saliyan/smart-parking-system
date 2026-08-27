import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class FloorSelector extends StatelessWidget {
  final int totalFloors;
  final int selectedFloor;
  final Function(int) onFloorSelected;

  const FloorSelector({
    super.key,
    required this.totalFloors,
    required this.selectedFloor,
    required this.onFloorSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (totalFloors <= 1) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalFloors,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final floor = index + 1;
          final isSelected = floor == selectedFloor;

          return GestureDetector(
            onTap: () => onFloorSelected(floor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Floor $floor',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
