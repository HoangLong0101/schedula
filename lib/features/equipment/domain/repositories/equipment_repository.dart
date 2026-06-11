import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/equipment.dart';

abstract class EquipmentRepository {
  Stream<Either<Failure, List<Equipment>>> watchEquipment(String tenantId);
  Future<Either<Failure, Equipment>> createEquipment(String tenantId, Equipment equip);
  Future<Either<Failure, void>> updateEquipment(Equipment equip);
  Future<Either<Failure, void>> deleteEquipment(String id);
}