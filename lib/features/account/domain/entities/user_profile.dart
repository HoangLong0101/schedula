import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;
  final bool faceIdEnabled;
  final bool fingerprintEnabled;
  final bool twoFaEnabled;
  final String twoFaMethod; // 'sms', 'email', 'app'

  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
    this.faceIdEnabled = true,
    this.fingerprintEnabled = false,
    this.twoFaEnabled = true,
    this.twoFaMethod = 'sms',
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? faceIdEnabled,
    bool? fingerprintEnabled,
    bool? twoFaEnabled,
    String? twoFaMethod,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      twoFaMethod: twoFaMethod ?? this.twoFaMethod,
    );
  }

  @override
  List<Object?> get props => [
    name,
    phone,
    email,
    avatarUrl,
    faceIdEnabled,
    fingerprintEnabled,
    twoFaEnabled,
    twoFaMethod,
  ];
}