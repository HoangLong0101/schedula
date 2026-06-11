import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/staff_member.dart';

abstract class StaffRepository {
  Stream<Either<Failure, List<StaffMember>>> watchStaff(String tenantId);
  Future<Either<Failure, StaffMember>> createStaff(String tenantId, StaffMember staff);
  Future<Either<Failure, void>> updateStaff(StaffMember staff);
  Future<Either<Failure, void>> deleteStaff(String id);
}