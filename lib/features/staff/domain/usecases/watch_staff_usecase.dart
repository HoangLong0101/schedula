import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/staff_member.dart';
import '../repositories/staff_repository.dart';

class WatchStaffParams {
  const WatchStaffParams({required this.tenantId});
  final String tenantId;
}

@injectable
class WatchStaffUseCase {
  const WatchStaffUseCase(this._repository);

  final StaffRepository _repository;

  Stream<Either<Failure, List<StaffMember>>> call(WatchStaffParams params) {
    return _repository.watchStaff(params.tenantId);
  }
}