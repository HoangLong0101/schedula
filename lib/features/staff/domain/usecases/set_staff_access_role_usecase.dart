import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/staff_repository.dart';

@injectable
class SetStaffAccessRoleUseCase {
  const SetStaffAccessRoleUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, void>> call(String staffId, String role) {
    if (!const {'staff', 'receptionist'}.contains(role)) {
      return Future.value(
        const Left(ValidationFailure('Vai trò truy cập không hợp lệ.')),
      );
    }
    return _repository.setAccessRole(staffId, role);
  }
}
