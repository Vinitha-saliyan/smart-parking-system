double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class DailyRevenuePoint {
  const DailyRevenuePoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;

  factory DailyRevenuePoint.fromJson(Map<String, dynamic> json) {
    return DailyRevenuePoint(
      date: DateTime.parse(json['date'] as String),
      amount: _asDouble(json['amount']),
    );
  }
}

class StatsModel {
  const StatsModel({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalAreas,
    required this.totalSlots,
    required this.availableSlots,
    required this.occupiedSlots,
    required this.reservedSlots,
    required this.totalReservations,
    required this.totalRevenue,
    required this.occupancyRate,
    required this.revenueLast7Days,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalAreas;
  final int totalSlots;
  final int availableSlots;
  final int occupiedSlots;
  final int reservedSlots;
  final int totalReservations;
  final double totalRevenue;
  final double occupancyRate;
  final List<DailyRevenuePoint> revenueLast7Days;

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue_last_7_days'] as List<dynamic>? ?? const [];
    return StatsModel(
      totalUsers: json['total_users'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      totalAreas: json['total_areas'] as int? ?? 0,
      totalSlots: json['total_slots'] as int? ?? 0,
      availableSlots: json['available_slots'] as int? ?? 0,
      occupiedSlots: json['occupied_slots'] as int? ?? 0,
      reservedSlots: json['reserved_slots'] as int? ?? 0,
      totalReservations: json['total_reservations'] as int? ?? 0,
      totalRevenue: _asDouble(json['total_revenue']),
      occupancyRate: _asDouble(json['occupancy_rate']),
      revenueLast7Days: revenue
          .map(
            (item) => DailyRevenuePoint.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
