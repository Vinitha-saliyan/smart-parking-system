double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.slotId,
    required this.areaName,
    required this.startTime,
    required this.status,
    required this.amount,
  });

  final String id;
  final String userId;
  final String userName;
  final String slotId;
  final String areaName;
  final DateTime startTime;
  final String status;
  final double amount;

  bool get canCancel => status == 'PENDING' || status == 'ACTIVE';

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      userName: json['user_name'] as String? ?? 'Unknown user',
      slotId: json['slot_id']?.toString() ?? '-',
      areaName: json['area_name'] as String? ?? 'Unknown area',
      startTime: DateTime.parse(json['start_time'] as String),
      status: (json['status'] as String? ?? 'UNKNOWN').toUpperCase(),
      amount: _asDouble(json['amount']),
    );
  }
}
