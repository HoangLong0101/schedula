import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tenantId,
  });

  final String id;
  final String email;
  final String role;
  final String tenantId;

  @override
  List<Object?> get props => [id, email, role, tenantId];
}