class GateStatusModel {
  const GateStatusModel({
    required this.cameraRunning,
    required this.cameraIndex,
    required this.mode,
    required this.areaId,
    required this.gateState,
    required this.lastVehicleNumber,
    required this.lastRawVehicleNumber,
    required this.ocrConfidence,
    required this.decisionSeconds,
    required this.lastAuthorized,
    required this.message,
    required this.error,
    required this.yoloLoaded,
    required this.ocrLoaded,
    required this.reservationId,
    required this.slotId,
    required this.slotNumber,
    required this.bookingType,
    required this.amountDue,
    required this.advancePaid,
    required this.manualPaymentRequired,
  });

  final bool cameraRunning;
  final int cameraIndex;
  final String mode;
  final String? areaId;
  final String gateState;
  final String? lastVehicleNumber;
  final String? lastRawVehicleNumber;
  final double? ocrConfidence;
  final double? decisionSeconds;
  final bool? lastAuthorized;
  final String message;
  final String? error;
  final bool yoloLoaded;
  final bool ocrLoaded;
  final String? reservationId;
  final String? slotId;
  final String? slotNumber;
  final String? bookingType;
  final double? amountDue;
  final bool? advancePaid;
  final bool manualPaymentRequired;

  factory GateStatusModel.fromJson(Map<String, dynamic> json) {
    return GateStatusModel(
      cameraRunning: json['camera_running'] == true,
      cameraIndex: (json['camera_index'] as num?)?.toInt() ?? 0,
      mode: (json['mode'] ?? 'ENTRY').toString().toUpperCase(),
      areaId: json['parking_area_id']?.toString(),
      gateState: (json['gate_state'] ?? 'CLOSED').toString().toUpperCase(),
      lastVehicleNumber: json['last_vehicle_number']?.toString(),
      lastRawVehicleNumber: json['last_raw_vehicle_number']?.toString(),
      ocrConfidence: _toDouble(json['last_ocr_confidence']),
      decisionSeconds: _toDouble(json['last_decision_seconds']),
      lastAuthorized: json['last_authorized'] as bool?,
      message: json['message']?.toString() ?? '',
      error: json['error']?.toString(),
      yoloLoaded: json['yolo_loaded'] == true,
      ocrLoaded: json['ocr_loaded'] == true,
      reservationId: json['last_reservation_id']?.toString(),
      slotId: json['last_slot_id']?.toString(),
      slotNumber: json['last_slot_number']?.toString(),
      bookingType: json['last_booking_type']?.toString().toUpperCase(),
      amountDue: _toDouble(json['last_amount_due']),
      advancePaid: json['last_advance_paid'] as bool?,
      manualPaymentRequired: json['manual_payment_required'] == true,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class WalkInSlotModel {
  const WalkInSlotModel({
    required this.id,
    required this.slotNumber,
    required this.status,
  });

  final String id;
  final String slotNumber;
  final String status;

  bool get isVacant => status == 'VACANT';

  factory WalkInSlotModel.fromJson(Map<String, dynamic> json) {
    return WalkInSlotModel(
      id: json['id']?.toString() ?? '',
      slotNumber: json['slot_id']?.toString() ?? '',
      status: (json['status'] ?? 'VACANT').toString().toUpperCase(),
    );
  }
}

class GateEventModel {
  const GateEventModel({
    required this.id,
    required this.areaId,
    required this.reservationId,
    required this.slotNumber,
    required this.eventType,
    required this.vehicleNumber,
    required this.ocrConfidence,
    required this.authorized,
    required this.gateState,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String areaId;
  final String? reservationId;
  final String? slotNumber;
  final String eventType;
  final String vehicleNumber;
  final double? ocrConfidence;
  final bool authorized;
  final String gateState;
  final String message;
  final DateTime createdAt;

  factory GateEventModel.fromJson(Map<String, dynamic> json) {
    return GateEventModel(
      id: json['id']?.toString() ?? '',
      areaId: json['parking_area_id']?.toString() ?? '',
      reservationId: json['reservation_id']?.toString(),
      slotNumber: json['slot_number']?.toString(),
      eventType: (json['event_type'] ?? 'ENTRY').toString().toUpperCase(),
      vehicleNumber: json['vehicle_number']?.toString() ?? '-',
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      authorized: json['authorized'] == true,
      gateState: (json['gate_state'] ?? 'CLOSED').toString().toUpperCase(),
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
