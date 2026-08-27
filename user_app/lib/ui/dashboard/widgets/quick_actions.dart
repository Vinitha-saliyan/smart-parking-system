import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onFindParking;
  final VoidCallback onMyBookings;
  final VoidCallback onScanQR;
  final VoidCallback onHistory;

  const QuickActions({
    super.key,
    required this.onFindParking,
    required this.onMyBookings,
    required this.onScanQR,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionItem(context, 'Find Parking', Icons.map,
                AppColors.primary, onFindParking, itemWidth),
            _buildActionItem(context, 'My Bookings', Icons.book,
                AppColors.accent, onMyBookings, itemWidth),
            _buildActionItem(context, 'Scan QR', Icons.qr_code_scanner,
                AppColors.success, onScanQR, itemWidth),
            _buildActionItem(context, 'History', Icons.history,
                AppColors.warning, onHistory, itemWidth),
          ],
        );
      },
    );
  }

  Widget _buildActionItem(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap, double width) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
