import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class WatchCustomersParams {
  const WatchCustomersParams({required this.tenantId});
  final String tenantId;
}

@injectable
class WatchCustomersUseCase {
  const WatchCustomersUseCase(this._repository);
  final CustomerRepository _repository;

  Stream<Either<Failure, List<Customer>>> call(WatchCustomersParams params) {
    return _repository.watchCustomers(params.tenantId);
  }
}