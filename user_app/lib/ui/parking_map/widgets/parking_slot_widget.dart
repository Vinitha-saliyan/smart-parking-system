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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isSelected
                ? status.color.withOpacity(0.28)
                : status.color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: status.color,
              width: isSelected ? 2.5 : 1.5,
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
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slotId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Positioned(
                  right: 7,
                  top: 7,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
