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

  String get normalizedRole => role.trim().toLowerCase();

  bool get isOwner => normalizedRole == 'owner';
  bool get isReceptionist => normalizedRole == 'receptionist';
  bool get isStaff => normalizedRole == 'staff';
  bool get canManageTenant => isOwner;
  bool get canManageBookings => isOwner || isReceptionist;

  @override
  List<Object?> get props => [id, email, role, tenantId];
}
