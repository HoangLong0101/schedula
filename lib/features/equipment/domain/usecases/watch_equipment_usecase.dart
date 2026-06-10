import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

@injectable
class WatchEquipmentUseCase {
  const WatchEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;
  Stream<Either<Failure, List<Equipment>>> call(String tenantId) => _repository.watchEquipment(tenantId);
}