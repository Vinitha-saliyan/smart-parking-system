import 'package:smart_parking_admin/core/constants/app_constants.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final Role role;
  final bool isActive;
  final DateTime createdAt;

  bool get isAdmin => role == Role.ADMIN || role == Role.MANAGER;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String? ?? 'USER').toUpperCase();
    return UserModel(
      id: json['id'].toString(),
      name: json['full_name'] as String? ?? 'Unknown user',
      email: json['email'] as String? ?? '',
      role: Role.values.firstWhere(
        (role) => role.name == rawRole,
        orElse: () => Role.USER,
      ),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
