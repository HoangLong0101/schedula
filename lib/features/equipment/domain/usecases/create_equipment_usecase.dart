import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

@injectable
class CreateEquipmentUseCase {
  const CreateEquipmentUseCase(this._repository);
  final EquipmentRepository _repository;

  Future<Either<Failure, Equipment>> call(String tenantId, Equipment equip) {
    if (tenantId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    if (equip.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên thiết bị.')));
    }
    if (equip.quantity <= 0) {
      return Future.value(const Left(ValidationFailure('Số lượng thiết bị phải lớn hơn 0.')));
    }
    return _repository.createEquipment(tenantId, equip);
  }
}
