import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/business_info.dart';

abstract class AccountRepository {
  Stream<Either<Failure, BusinessInfo>> watchBusinessInfo(String tenantId);
  Future<Either<Failure, void>> updateBusinessInfo(String tenantId, BusinessInfo info);
}