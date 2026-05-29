import 'package:injectable/injectable.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

@injectable
class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser?> call({
    required String email,
    required String password,
  }) {
    return _repository.signIn(email: email, password: password);
  }
}