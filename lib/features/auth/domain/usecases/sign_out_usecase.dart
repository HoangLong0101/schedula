import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.signOut();
  }
}