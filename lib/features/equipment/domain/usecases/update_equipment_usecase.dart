import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

@injectable
class UpdateEquipmentUseCase {
  const UpdateEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;

  Future<Either<Failure, void>> call(Equipment equip) {
    if (equip.id.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã thiết bị.')));
    }
    if (equip.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên thiết bị.')));
    }
    if (equip.quantity <= 0) {
      return Future.value(const Left(ValidationFailure('Số lượng thiết bị phải lớn hơn 0.')));
    }
    return _repository.updateEquipment(equip);
  }
}
