import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class CreateCustomerParams {
  const CreateCustomerParams({required this.tenantId, required this.customer});
  final String tenantId;
  final Customer customer;
}

@injectable
class CreateCustomerUseCase {
  const CreateCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<Failure, Customer>> call(CreateCustomerParams params) {
    if (params.tenantId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    if (params.customer.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập tên khách hàng.')));
    }
    if (params.customer.phone.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập số điện thoại khách hàng.')));
    }
    return _repository.createCustomer(params.tenantId, params.customer);
  }
}
