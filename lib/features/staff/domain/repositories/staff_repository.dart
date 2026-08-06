import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/staff_member.dart';

typedef CreatedStaff = ({StaffMember staff, String temporaryPassword});

abstract class StaffRepository {
  Stream<Either<Failure, List<StaffMember>>> watchStaff(String tenantId);
  Future<Either<Failure, CreatedStaff>> createStaff(
    String tenantId,
    StaffMember staff,
  );
  Future<Either<Failure, void>> updateStaff(StaffMember staff);
  Future<Either<Failure, void>> deleteStaff(
    String id, {
    required bool cancelFuture,
    String? reassignTo,
  });
  Future<Either<Failure, void>> sendPasswordReset(String id);
  Future<Either<Failure, void>> setAccessRole(String id, String role);
  Future<Either<Failure, void>> addLeave({
    required String tenantId,
    required String staffId,
    required DateTime start,
    required DateTime end,
  });
}
