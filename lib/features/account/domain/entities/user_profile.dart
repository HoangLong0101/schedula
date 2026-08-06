import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;
  final bool passwordEnabled;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
    this.passwordEnabled = false,
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? passwordEnabled,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
    );
  }

  @override
  List<Object?> get props => [name, phone, email, avatarUrl, passwordEnabled];
}
