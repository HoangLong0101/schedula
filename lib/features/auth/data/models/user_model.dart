import '../../domain/entities/user.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    required super.tenantId,
  });

  factory UserModel.fromAppUser(AppUser user) {
    return UserModel(
      id: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'role': role,
      'tenantId': tenantId,
    };
  }
}