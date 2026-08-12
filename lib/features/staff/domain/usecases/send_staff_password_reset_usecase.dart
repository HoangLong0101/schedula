import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/staff_repository.dart';

@injectable
class ResetStaffPasswordUseCase {
  const ResetStaffPasswordUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, String>> call(String staffId) {
    if (staffId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã nhân viên.')));
    }
    return _repository.resetPassword(staffId);
  }
}
