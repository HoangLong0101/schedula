import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

@injectable
class UpdateEquipmentUseCase {
  const UpdateEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;
  Future<Either<Failure, void>> call(Equipment equip) => _repository.updateEquipment(equip);
}