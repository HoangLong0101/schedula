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
    return _repository.createStaff(params.tenantId, params.staff);
  }
}