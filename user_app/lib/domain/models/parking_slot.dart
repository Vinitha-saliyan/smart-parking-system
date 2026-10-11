import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

enum DomainSlotStatus {
  vacant('VACANT'),
  occupied('OCCUPIED'),
  reserved('RESERVED'),
  maintenance('MAINTENANCE');

  final String value;
  const DomainSlotStatus(this.value);

  Color get color {
    switch (this) {
      case DomainSlotStatus.vacant:
        return AppColors.slotVacant;
      case DomainSlotStatus.occupied:
        return AppColors.slotOccupied;
      case DomainSlotStatus.reserved:
        return AppColors.slotReserved;
      case DomainSlotStatus.maintenance:
        return AppColors.slotMaintenance;
    }
  }

  String get label {
    switch (this) {
      case DomainSlotStatus.vacant:
        return 'Available';
      case DomainSlotStatus.occupied:
        return 'Occupied';
      case DomainSlotStatus.reserved:
        return 'Reserved';
      case DomainSlotStatus.maintenance:
        return 'Maintenance';
    }
  }

  static DomainSlotStatus fromString(String status) {
    return DomainSlotStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => DomainSlotStatus.maintenance,
    );
  }
}

enum DomainSlotType {
  standard('STANDARD'),
  vip('VIP'),
  ev('EV'),
  disabled('DISABLED');

  final String value;
  const DomainSlotType(this.value);

  IconData get icon {
    switch (this) {
      case DomainSlotType.standard:
        return Icons.directions_car;
      case DomainSlotType.vip:
        return Icons.star;
      case DomainSlotType.ev:
        return Icons.electric_car;
      case DomainSlotType.disabled:
        return Icons.accessible;
    }
  }

  String get label {
    switch (this) {
      case DomainSlotType.standard:
        return 'Standard';
      case DomainSlotType.vip:
        return 'VIP';
      case DomainSlotType.ev:
        return 'EV Charging';
      case DomainSlotType.disabled:
        return 'Accessible';
    }
  }

  static DomainSlotType fromString(String type) {
    return DomainSlotType.values.firstWhere(
      (e) => e.value == type,
      orElse: () => DomainSlotType.standard,
    );
  }
}
