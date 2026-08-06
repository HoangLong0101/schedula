import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/staff_repository.dart';

@injectable
class AddStaffLeaveUseCase {
  const AddStaffLeaveUseCase(this._repository);

  final StaffRepository _repository;

  Future<Either<Failure, void>> call({
    required String tenantId,
    required String staffId,
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) {
      return Future.value(
        const Left(ValidationFailure('Ngày kết thúc phải sau ngày bắt đầu.')),
      );
    }
    return _repository.addLeave(
      tenantId: tenantId,
      staffId: staffId,
      start: start,
      end: end,
    );
  }
}
