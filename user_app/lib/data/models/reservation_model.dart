import 'package:smart_parking_user/data/models/parking_slot_model.dart';

class ReservationModel {
  final String id;
  final String userId;
  final String slotId;
  final String parkingAreaId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? actualCheckIn;
  final DateTime? actualCheckOut;
  final DateTime? createdAt;
  final String status;
  final String bookingType;
  final bool advancePaid;
  final String? vehicleNumber;
  final String? qrCode;
  final double? totalAmount;
  final ParkingSlotModel? slotDetails;
  final String? areaName;

  ReservationModel({
    required this.id,
    required this.userId,
    required this.slotId,
    required this.parkingAreaId,
    required this.startTime,
    required this.endTime,
    this.actualCheckIn,
    this.actualCheckOut,
    this.createdAt,
    required this.status,
    this.bookingType = 'PREBOOKED',
    this.advancePaid = false,
    this.vehicleNumber,
    this.qrCode,
    this.totalAmount,
    this.slotDetails,
    this.areaName,
  });

  factory ReservationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = _unwrapData(json);

    final startTime = _toDateTime(
          data['start_time'] ?? data['startTime'],
        ) ??
        DateTime.now();

    final rawSlot = data['slot'] ?? data['slot_details'];
    ParkingSlotModel? slotDetails;

    if (rawSlot is Map) {
      slotDetails = ParkingSlotModel.fromJson(
        Map<String, dynamic>.from(rawSlot),
      );
    }

    return ReservationModel(
      id: data['id']?.toString() ?? '',
      userId: (data['user_id'] ?? data['userId'])?.toString() ?? '',
      slotId: (data['slot_id'] ?? data['slotId'])?.toString() ?? '',
      parkingAreaId:
          (data['parking_area_id'] ?? data['parkingAreaId'])?.toString() ?? '',
      startTime: startTime,
      endTime: _toDateTime(
            data['end_time'] ?? data['endTime'],
          ) ??
          startTime,
      actualCheckIn: _toDateTime(
        data['actual_check_in'] ?? data['actualCheckIn'],
      ),
      actualCheckOut: _toDateTime(
        data['actual_check_out'] ?? data['actualCheckOut'],
      ),
      createdAt: _toDateTime(data['created_at'] ?? data['createdAt']),
      status: _normalizeStatus(data['status']),
      bookingType: _normalizeStatus(
        data['booking_type'] ?? data['bookingType'] ?? 'PREBOOKED',
      ),
      advancePaid: data['advance_paid'] == true || data['advancePaid'] == true,
      vehicleNumber:
          (data['vehicle_number'] ?? data['vehicleNumber'])?.toString(),
      qrCode: (data['qr_code'] ?? data['qrCode'])?.toString(),
      totalAmount: _toNullableDouble(
        data['total_amount'] ?? data['totalAmount'],
      ),
      slotDetails: slotDetails,
      areaName:
          (data['parking_area_name'] ?? data['area_name'] ?? data['areaName'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'slot_id': slotId,
      'parking_area_id': parkingAreaId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'actual_check_in': actualCheckIn?.toIso8601String(),
      'actual_check_out': actualCheckOut?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'status': status,
      'booking_type': bookingType,
      'advance_paid': advancePaid,
      'vehicle_number': vehicleNumber,
      'qr_code': qrCode,
      'total_amount': totalAmount,
      'slot': slotDetails?.toJson(),
      'parking_area_name': areaName,
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

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  static String _normalizeStatus(dynamic value) {
    final status = value?.toString().trim();

    if (status == null || status.isEmpty) {
      return 'PENDING';
    }

    return status.split('.').last.toUpperCase();
  }
}
