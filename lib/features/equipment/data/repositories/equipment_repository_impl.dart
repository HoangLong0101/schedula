import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';
import '../datasources/equipment_datasource.dart';

@LazySingleton(as: EquipmentRepository)
class EquipmentRepositoryImpl implements EquipmentRepository {
  const EquipmentRepositoryImpl(this._dataSource);

  final EquipmentDataSource _dataSource;

  @override
  Stream<Either<Failure, List<Equipment>>> watchEquipment(String tenantId) {
    return _dataSource.watchEquipment(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (_, _, sink) =>
            sink.add(const Left(ServerFailure('Không thể tải thiết bị.'))),
      ),
    );
  }

  @override
  Future<Either<Failure, Equipment>> createEquipment(String tenantId, Equipment equip) async {
    try {
      final model = await _dataSource.createEquipment(tenantId, equip);
      return Right(model);
    } catch (_) {
      return const Left(ServerFailure('Không thể tạo thiết bị.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateEquipment(Equipment equip) async {
    try {
      await _dataSource.updateEquipment(equip);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật thiết bị.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEquipment(String id) async {
    try {
      await _dataSource.deleteEquipment(id);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể xóa thiết bị.'));
    }
  }
}
