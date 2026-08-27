import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String email;

  @JsonKey(name: 'full_name')
  final String fullName;

  final String? phone;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  final String role;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'is_verified')
  final bool isVerified;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.isActive = true,
    this.isVerified = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
