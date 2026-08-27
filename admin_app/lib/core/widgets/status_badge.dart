import 'package:flutter/material.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';

enum BadgeVariant { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;

  const StatusBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.neutral,
  });

  Color get _color {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.warning:
        return AppColors.warning;
      case BadgeVariant.error:
        return AppColors.error;
      case BadgeVariant.info:
        return AppColors.info;
      case BadgeVariant.neutral:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
