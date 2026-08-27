import 'package:flutter/material.dart';
import 'package:smart_parking_user/domain/models/parking_slot.dart';

class LegendBar extends StatelessWidget {
  const LegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    const visibleStatuses = [
      DomainSlotStatus.vacant,
      DomainSlotStatus.occupied,
      DomainSlotStatus.reserved,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: visibleStatuses.map((status) {
          return Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
