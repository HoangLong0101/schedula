import '../entities/user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser?> signIn({
    required String email,
    required String password,
  });

  Future<AppUser?> signInWithGoogle();

  Future<void> signOut();
}