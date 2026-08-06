import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user_profile.dart';
import '../repositories/account_repository.dart';

@injectable
class WatchUserProfileUseCase {
  const WatchUserProfileUseCase(this._repository);

  final AccountRepository _repository;

  Stream<Either<Failure, UserProfile>> call(
    String userId,
    String defaultEmail,
  ) {
    return _repository.watchUserProfile(userId, defaultEmail);
  }
}
