import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/business_info.dart';
import '../repositories/account_repository.dart';

@injectable
class WatchBusinessInfoUseCase {
  const WatchBusinessInfoUseCase(this._repository);
  final AccountRepository _repository;
  Stream<Either<Failure, BusinessInfo>> call(String tenantId) => _repository.watchBusinessInfo(tenantId);
}