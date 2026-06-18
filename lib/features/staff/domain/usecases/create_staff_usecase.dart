import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/staff_member.dart';
import '../repositories/staff_repository.dart';

class CreateStaffParams {
  const CreateStaffParams({
    required this.tenantId,
    required this.staff,
  });

  final String tenantId;
  final StaffMember staff;
}

@injectable
class CreateStaffUseCase {
  const CreateStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, StaffMember>> call(CreateStaffParams params) {
    if (params.tenantId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    if (params.staff.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên nhân viên.')));
    }
    if (params.staff.role.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng chọn vai trò nhân viên.')));
    }
    return _repository.createStaff(params.tenantId, params.staff);
  }
}
