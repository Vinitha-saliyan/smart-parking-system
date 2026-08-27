import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class FilterChips extends StatelessWidget {
  final List<String> options;
  final String selectedOption;
  final Function(String) onSelected;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selectedOption;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
