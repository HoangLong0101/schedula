import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/equipment_repository.dart';

@injectable
class DeleteEquipmentUseCase {
  const DeleteEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    if (id.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã thiết bị.')));
    }
    return _repository.deleteEquipment(id);
  }
}
