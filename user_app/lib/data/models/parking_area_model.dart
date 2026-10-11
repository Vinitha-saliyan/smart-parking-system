class ParkingAreaModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int totalFloors;
  final int totalSlots;
  final double hourlyRate;
  final String currency;
  final String? imageUrl;
  final bool isActive;
  final String openingTime;
  final String closingTime;
  final int availableSlots;
  final int occupiedSlots;

  ParkingAreaModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalFloors,
    required this.totalSlots,
    required this.hourlyRate,
    this.currency = '₹',
    this.imageUrl,
    this.isActive = true,
    required this.openingTime,
    required this.closingTime,
    this.availableSlots = 0,
    this.occupiedSlots = 0,
  });

  factory ParkingAreaModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = _unwrapData(json);

    final currencyValue = data['currency']?.toString();

    return ParkingAreaModel(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      totalFloors: _toInt(
        data['total_floors'] ?? data['totalFloors'],
        fallback: 1,
      ),
      totalSlots: _toInt(
        data['total_slots'] ?? data['totalSlots'],
      ),
      hourlyRate: _toDouble(
        data['hourly_rate'] ?? data['hourlyRate'],
      ),
      currency:
          currencyValue == null || currencyValue.isEmpty ? '₹' : currencyValue,
      imageUrl: data['image_url']?.toString() ?? data['imageUrl']?.toString(),
      isActive: _toBool(
        data['is_active'] ?? data['isActive'],
        fallback: true,
      ),
      openingTime:
          (data['opening_time'] ?? data['openingTime'])?.toString() ?? '',
      closingTime:
          (data['closing_time'] ?? data['closingTime'])?.toString() ?? '',
      availableSlots: _toInt(
        data['available_slots'] ?? data['availableSlots'],
      ),
      occupiedSlots: _toInt(
        data['occupied_slots'] ?? data['occupiedSlots'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'total_floors': totalFloors,
      'total_slots': totalSlots,
      'hourly_rate': hourlyRate,
      'currency': currency,
      'image_url': imageUrl,
      'is_active': isActive,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'available_slots': availableSlots,
      'occupied_slots': occupiedSlots,
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

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(
    dynamic value, {
    bool fallback = false,
  }) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().toLowerCase();

    if (normalized == 'true' || normalized == '1') {
      return true;
    }

    if (normalized == 'false' || normalized == '0') {
      return false;
    }

    return fallback;
  }
}
