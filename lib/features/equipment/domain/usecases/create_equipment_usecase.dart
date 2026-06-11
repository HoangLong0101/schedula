import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

@injectable
class CreateEquipmentUseCase {
  const CreateEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;
  Future<Either<Failure, Equipment>> call(String tenantId, Equipment equip) => _repository.createEquipment(tenantId, equip);
}