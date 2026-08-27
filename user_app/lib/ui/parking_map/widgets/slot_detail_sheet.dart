import 'package:flutter/material.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/domain/models/parking_slot.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';

class SlotDetailSheet extends StatelessWidget {
  final ParkingSlotModel slot;
  final String areaName;
  final double hourlyRate;
  final String currency;
  final VoidCallback onReserve;
  final bool isReserving;

  const SlotDetailSheet({
    super.key,
    required this.slot,
    required this.areaName,
    required this.hourlyRate,
    required this.currency,
    required this.onReserve,
    this.isReserving = false,
  });

  @override
  Widget build(BuildContext context) {
    final domainStatus = DomainSlotStatus.fromString(slot.status);
    final domainType = DomainSlotType.fromString(slot.slotType);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot ${slot.slotId}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    areaName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: domainStatus.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: domainStatus.color),
                ),
                child: Text(
                  domainStatus.label,
                  style: TextStyle(
                    color: domainStatus.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildInfoItem(
                  context, 'Type', domainType.label, domainType.icon),
              const SizedBox(width: 32),
              _buildInfoItem(
                context,
                'Rate',
                '₹20 first hour',
                Icons.payments,
              ),
              const SizedBox(width: 32),
              _buildInfoItem(context, 'Floor', '${slot.floor}', Icons.layers),
            ],
          ),
          const SizedBox(height: 32),
          if (domainStatus == DomainSlotStatus.vacant)
            GradientButton(
              text: 'Reserve This Slot',
              isLoading: isReserving,
              onPressed: onReserve,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This slot is currently unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
