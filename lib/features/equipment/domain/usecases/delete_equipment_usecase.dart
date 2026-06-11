import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/equipment_repository.dart';

@injectable
class DeleteEquipmentUseCase {
  const DeleteEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;
  Future<Either<Failure, void>> call(String id) => _repository.deleteEquipment(id);
}