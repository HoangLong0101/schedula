import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/account_repository.dart';

@injectable
class ChangePasswordUseCase {
  const ChangePasswordUseCase(this._repository);

  final AccountRepository _repository;

  Future<Either<Failure, void>> call(
    String email,
    String currentPassword,
    String newPassword,
  ) {
    if (newPassword.length < 6) {
      return Future.value(
        const Left(ValidationFailure('Mật khẩu mới phải có ít nhất 6 ký tự.')),
      );
    }
    return _repository.changePassword(email, currentPassword, newPassword);
  }
}
