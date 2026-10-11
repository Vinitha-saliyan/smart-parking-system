class ParkingAreaModel {
  final String id;
  final String name;
  final String address;
  final int totalSlots;
  final int availableSlots;
  final int occupiedSlots;
  final bool isActive;

  ParkingAreaModel({
    required this.id,
    required this.name,
    required this.address,
    required this.totalSlots,
    this.availableSlots = 0,
    this.occupiedSlots = 0,
    required this.isActive,
  });

  factory ParkingAreaModel.fromJson(Map<String, dynamic> json) {
    return ParkingAreaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      totalSlots: json['total_slots'] as int,
      availableSlots: json['available_slots'] as int? ?? 0,
      occupiedSlots: json['occupied_slots'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
