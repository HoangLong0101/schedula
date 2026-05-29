import 'package:injectable/injectable.dart';

import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_datasource.dart';

@LazySingleton(as: CustomerRepository)
class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl(this._dataSource);

  final CustomerDataSource _dataSource;

  @override
  Future<List<Customer>> getCustomers() async => await _dataSource.fetchCustomers();
}
