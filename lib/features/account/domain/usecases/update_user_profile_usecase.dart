import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user_profile.dart';
import '../repositories/account_repository.dart';

@injectable
class UpdateUserProfileUseCase {
  const UpdateUserProfileUseCase(this._repository);

  final AccountRepository _repository;

  Future<Either<Failure, void>> call(String userId, UserProfile profile) {
    if (profile.name.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Tên tài khoản không được để trống.')),
      );
    }
    return _repository.updateUserProfile(userId, profile);
  }
}
