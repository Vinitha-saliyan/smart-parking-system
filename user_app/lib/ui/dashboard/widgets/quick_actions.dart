import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onFindParking;
  final VoidCallback onMyBookings;

  const QuickActions({
    super.key,
    required this.onFindParking,
    required this.onMyBookings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Row(
          children: [
            _buildActionItem(
              context,
              'Find Parking',
              Icons.location_on_rounded,
              onFindParking,
              itemWidth,
            ),
            const SizedBox(width: 12),
            _buildActionItem(
              context,
              'My Bookings',
              Icons.calendar_month_rounded,
              onMyBookings,
              itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    double width,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          height: 102,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
