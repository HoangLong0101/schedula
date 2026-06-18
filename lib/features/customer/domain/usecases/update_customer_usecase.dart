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
    if (params.customer.id.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã khách hàng.')));
    }
    if (params.customer.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên khách hàng.')));
    }
    if (params.customer.phone.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập số điện thoại khách hàng.')));
    }
    return _repository.updateCustomer(params.customer);
  }
}
