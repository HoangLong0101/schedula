import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula/features/auth/domain/entities/user.dart';
import 'package:schedula/features/auth/domain/repositories/auth_repository.dart';
import 'package:schedula/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:schedula/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:schedula/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:schedula/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:schedula/features/auth/presentation/bloc/auth_event.dart';
import 'package:schedula/features/auth/presentation/bloc/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.user);

  final AppUser? user;
  var signedOut = false;

  @override
  Stream<AppUser?> watchCurrentUser() => Stream.value(user);

  @override
  Future<AppUser?> signIn({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser?> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('AuthBloc', () {
    const user = AppUser(
      id: 'staff-1',
      email: 'staff@example.com',
      role: 'staff',
      tenantId: 'tenant-1',
    );

    AuthBloc blocFor(_FakeAuthRepository repository) {
      return AuthBloc(
        SignInUseCase(repository),
        SignInWithGoogleUseCase(repository),
        SignOutUseCase(repository),
      );
    }

    blocTest<AuthBloc, AuthState>(
      'restores persisted Firebase user on startup',
      build: () => blocFor(_FakeAuthRepository(user)),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        const AuthLoading(),
        const Authenticated(user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'stays signed out when Firebase has no user',
      build: () => blocFor(_FakeAuthRepository(null)),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        const AuthLoading(),
        const Unauthenticated(),
      ],
    );
  });
}
