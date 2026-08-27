import 'package:flutter/material.dart';
import 'package:smart_parking_user/domain/models/parking_slot.dart';

class ParkingSlotWidget extends StatelessWidget {
  final String slotId;
  final DomainSlotStatus status;
  final DomainSlotType type;
  final VoidCallback onTap;
  final bool isSelected;

  const ParkingSlotWidget({
    super.key,
    required this.slotId,
    required this.status,
    required this.type,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected
              ? status.color.withOpacity(0.8)
              : status.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : status.color,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: status.color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2)
                ]
              : [],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.icon,
                    color: status.color,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slotId,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (status == DomainSlotStatus.occupied)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.directions_car,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
