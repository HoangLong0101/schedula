import 'package:injectable/injectable.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final FirebaseAuthDataSource _dataSource;

  @override
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) {
    return _dataSource.signIn(email: email, password: password);
  }

  @override
  Future<AppUser?> signInWithGoogle() {
    return _dataSource.signInWithGoogle();
  }

  @override
  Future<void> signOut() {
    return _dataSource.signOut();
  }

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _dataSource.watchCurrentUser();
  }
}