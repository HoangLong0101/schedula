import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/staff_repository.dart';

class DeleteStaffParams {
  const DeleteStaffParams({required this.staffId});
  final String staffId;
}

@injectable
class DeleteStaffUseCase {
  const DeleteStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, void>> call(DeleteStaffParams params) {
    return _repository.deleteStaff(params.staffId);
  }
}