import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class UpdateCustomerParams {
  const UpdateCustomerParams({required this.customer});
  final Customer customer;
}

@injectable
class UpdateCustomerUseCase {
  const UpdateCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<Failure, void>> call(UpdateCustomerParams params) {
    return _repository.updateCustomer(params.customer);
  }
}