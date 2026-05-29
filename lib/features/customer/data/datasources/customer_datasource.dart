import 'package:injectable/injectable.dart';

import '../models/customer_model.dart';

@lazySingleton
class CustomerDataSource {
  const CustomerDataSource();

  Future<List<CustomerModel>> fetchCustomers() async => const <CustomerModel>[];
}
