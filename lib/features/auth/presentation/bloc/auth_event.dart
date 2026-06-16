import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

final class AuthProfileCompleted extends AuthEvent {
  const AuthProfileCompleted(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
