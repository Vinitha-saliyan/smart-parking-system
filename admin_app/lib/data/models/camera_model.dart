class CameraModel {
  const CameraModel({
    required this.id,
    required this.name,
    required this.areaName,
    required this.status,
    required this.isActive,
    this.floor,
  });

  final String id;
  final String name;
  final String areaName;
  final String status;
  final bool isActive;
  final int? floor;

  bool get isOnline => isActive && status.toUpperCase() == 'ONLINE';

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Camera',
      areaName: json['area_name'] as String? ?? 'Unknown area',
      status: (json['status'] as String? ?? 'OFFLINE').toUpperCase(),
      isActive: json['is_active'] as bool? ?? true,
      floor: json['floor'] as int?,
    );
  }
}
