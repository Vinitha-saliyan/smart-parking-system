class ParkingSlotModel {
  final String id;
  final String slotId;
  final String parkingAreaId;
  final int floor;
  final String slotType;
  final String status;
  final int positionX;
  final int positionY;

  ParkingSlotModel({
    required this.id,
    required this.slotId,
    required this.parkingAreaId,
    required this.floor,
    required this.slotType,
    required this.status,
    required this.positionX,
    required this.positionY,
  });

  factory ParkingSlotModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = _unwrapData(json);

    return ParkingSlotModel(
      id: data['id']?.toString() ?? '',
      slotId: (data['slot_id'] ?? data['slotId'])?.toString() ?? '',
      parkingAreaId:
          (data['parking_area_id'] ?? data['parkingAreaId'])?.toString() ?? '',
      floor: _toInt(data['floor'], fallback: 1),
      slotType: _normalizeEnum(
        data['slot_type'] ?? data['slotType'],
        fallback: 'STANDARD',
      ),
      status: _normalizeEnum(
        data['status'],
        fallback: 'VACANT',
      ),
      positionX: _toInt(
        data['position_x'] ?? data['positionX'],
      ),
      positionY: _toInt(
        data['position_y'] ?? data['positionY'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slot_id': slotId,
      'parking_area_id': parkingAreaId,
      'floor': floor,
      'slot_type': slotType,
      'status': status,
      'position_x': positionX,
      'position_y': positionY,
    };
  }

  static Map<String, dynamic> _unwrapData(
    Map<String, dynamic> json,
  ) {
    final nestedData = json['data'];

    if (nestedData is Map) {
      return Map<String, dynamic>.from(nestedData);
    }

    return json;
  }

  static int _toInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _normalizeEnum(
    dynamic value, {
    required String fallback,
  }) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return fallback;
    }

    return text.split('.').last.toUpperCase();
  }
}
