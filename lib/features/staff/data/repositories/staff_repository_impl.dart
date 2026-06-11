import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_datasource.dart';

@LazySingleton(as: StaffRepository)
class StaffRepositoryImpl implements StaffRepository {
  const StaffRepositoryImpl(this._dataSource);

  final StaffDataSource _dataSource;

  @override
  Stream<Either<Failure, List<StaffMember>>> watchStaff(String tenantId) {
    return _dataSource.watchStaff(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (error, stackTrace, sink) {
          sink.add(Left(ServerFailure(error.toString())));
        },
      ),
    );
  }

  @override
  Future<Either<Failure, StaffMember>> createStaff(String tenantId, StaffMember staff) async {
    try {
      final model = await _dataSource.createStaff(tenantId, staff);
      return Right(model);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateStaff(StaffMember staff) async {
    try {
      await _dataSource.updateStaff(staff);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteStaff(String id) async {
    try {
      await _dataSource.deleteStaff(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}