import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_datasource.dart';

@LazySingleton(as: CustomerRepository)
class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl(this._dataSource);

  final CustomerDataSource _dataSource;

  @override
  Stream<Either<Failure, List<Customer>>> watchCustomers(String tenantId) {
    return _dataSource.watchCustomers(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (error, stackTrace, sink) {
          sink.add(Left(ServerFailure(error.toString())));
        },
      ),
    );
  }

  @override
  Future<Either<Failure, Customer>> createCustomer(String tenantId, Customer customer) async {
    try {
      final model = await _dataSource.createCustomer(tenantId, customer);
      return Right(model);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCustomer(Customer customer) async {
    try {
      await _dataSource.updateCustomer(customer);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomer(String id) async {
    try {
      await _dataSource.deleteCustomer(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}