import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/customer.dart';

abstract class CustomerRepository {
  Stream<Either<Failure, List<Customer>>> watchCustomers(String tenantId);
  Future<Either<Failure, Customer>> createCustomer(String tenantId, Customer customer);
  Future<Either<Failure, void>> updateCustomer(Customer customer);
  Future<Either<Failure, void>> deleteCustomer(String id);
}