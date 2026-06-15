import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/staff_member.dart';
import '../repositories/staff_repository.dart';

class UpdateStaffParams {
  const UpdateStaffParams({required this.staff});
  final StaffMember staff;
}

@injectable
class UpdateStaffUseCase {
  const UpdateStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, void>> call(UpdateStaffParams params) {
    if (params.staff.id.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã nhân viên.')));
    }
    if (params.staff.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên nhân viên.')));
    }
    if (params.staff.role.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng chọn vai trò nhân viên.')));
    }
    return _repository.updateStaff(params.staff);
  }
}
