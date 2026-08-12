import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tenantId,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final String role;
  final String tenantId;
  final bool mustChangePassword;

  String get normalizedRole => role.trim().toLowerCase();

  bool get isOwner => normalizedRole == 'owner';
  bool get isReceptionist => normalizedRole == 'receptionist';
  bool get isStaff => normalizedRole == 'staff';
  bool get canManageTenant => isOwner;
  bool get canManageBookings => isOwner || isReceptionist;
  Set<String> get permissions => switch (normalizedRole) {
    'owner' => const {
      'booking.manage',
      'booking.status.own',
      'customer.read',
      'customer.write',
      'staff.manage',
      'report.read',
      'campaign.send',
    },
    'receptionist' => const {
      'booking.manage',
      'customer.read',
      'customer.write',
      'campaign.send',
      'report.read',
    },
    _ => const {'booking.status.own', 'customer.read'},
  };

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  List<Object?> get props => [id, email, role, tenantId, mustChangePassword];
}
