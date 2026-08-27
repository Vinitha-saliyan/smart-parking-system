import 'package:smart_parking_admin/core/constants/app_constants.dart';

class ParkingSlotModel {
  final String id;
  final String areaId;
  final String slotNumber;
  final int floor;
  final SlotStatus status;
  final SlotType type;

  ParkingSlotModel({
    required this.id,
    required this.areaId,
    required this.slotNumber,
    required this.floor,
    required this.status,
    required this.type,
  });

  factory ParkingSlotModel.fromJson(Map<String, dynamic> json) {
    return ParkingSlotModel(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      slotNumber: json['slot_number'] as String,
      floor: json['floor'] as int,
      status: SlotStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => SlotStatus.available),
      type: SlotType.values.firstWhere((e) => e.name == json['type'], orElse: () => SlotType.standard),
    );
  }
}
