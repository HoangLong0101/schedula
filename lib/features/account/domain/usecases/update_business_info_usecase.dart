import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/business_info.dart';
import '../repositories/account_repository.dart';

@injectable
class UpdateBusinessInfoUseCase {
  const UpdateBusinessInfoUseCase(this._repository);
  final AccountRepository _repository;
  Future<Either<Failure, void>> call(String tenantId, BusinessInfo info) => _repository.updateBusinessInfo(tenantId, info);
}