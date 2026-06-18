import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/business_info.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_datasource.dart';

@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._dataSource);

  final AccountDataSource _dataSource;

  @override
  Stream<Either<Failure, BusinessInfo>> watchBusinessInfo(String tenantId) {
    return _dataSource.watchBusinessInfo(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (_, _, sink) =>
            sink.add(const Left(ServerFailure('Không thể tải thông tin cơ sở.'))),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> updateBusinessInfo(String tenantId, BusinessInfo info) async {
    try {
      await _dataSource.updateBusinessInfo(tenantId, info);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật thông tin cơ sở.'));
    }
  }
}
