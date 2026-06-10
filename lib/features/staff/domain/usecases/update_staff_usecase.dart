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
    return _repository.updateStaff(params.staff);
  }
}