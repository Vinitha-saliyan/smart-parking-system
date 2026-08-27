import 'package:flutter/material.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback? onTap;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (reservation.status.toUpperCase()) {
      case 'ACTIVE':
      case 'PENDING':
        statusColor = AppColors.warning;
        break;
      case 'COMPLETED':
        statusColor = AppColors.success;
        break;
      case 'CANCELLED':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Slot ${reservation.slotId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reservation.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.areaName ?? 'Parking Area',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${reservation.startTime.formatDate} • ${reservation.startTime.formatTime}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              if (reservation.totalAmount != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '₹${reservation.totalAmount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
