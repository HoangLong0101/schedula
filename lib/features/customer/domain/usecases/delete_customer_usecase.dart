import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/customer_repository.dart';

class DeleteCustomerParams {
  const DeleteCustomerParams({required this.customerId});
  final String customerId;
}

@injectable
class DeleteCustomerUseCase {
  const DeleteCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<Failure, void>> call(DeleteCustomerParams params) {
    if (params.customerId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã khách hàng.')));
    }
    return _repository.deleteCustomer(params.customerId);
  }
}
