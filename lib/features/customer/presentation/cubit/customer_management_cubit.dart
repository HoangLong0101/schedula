import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/customer.dart';
import '../../domain/usecases/create_customer_usecase.dart';
import '../../domain/usecases/delete_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import '../../domain/usecases/watch_customers_usecase.dart';

@injectable
class CustomerManagementCubit extends Cubit<List<Customer>> {
  CustomerManagementCubit(
    this._watchCustomers,
    this._createCustomer,
    this._updateCustomer,
    this._deleteCustomer,
  ) : super(const []);

  final WatchCustomersUseCase _watchCustomers;
  final CreateCustomerUseCase _createCustomer;
  final UpdateCustomerUseCase _updateCustomer;
  final DeleteCustomerUseCase _deleteCustomer;

  StreamSubscription? _subscription;
  String _currentTenantId = '';

  // Hàm khởi tạo lắng nghe dữ liệu Real-time từ Firestore
  void init(String tenantId) {
    _currentTenantId = tenantId;
    _subscription?.cancel();

    _subscription = _watchCustomers(WatchCustomersParams(tenantId: tenantId))
        .listen((either) {
          either.fold(
            (_) {},
            (customers) =>
                emit(customers), // Cập nhật UI ngay lập tức khi có data mới
          );
        });
  }

  Future<String?> addCustomer(Customer customer) async {
    final result = await _createCustomer(
      CreateCustomerParams(tenantId: _currentTenantId, customer: customer),
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> updateCustomer(Customer customer) async {
    final result = await _updateCustomer(
      UpdateCustomerParams(customer: customer),
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> deleteCustomer(String id) async {
    final result = await _deleteCustomer(DeleteCustomerParams(customerId: id));
    return result.fold((failure) => failure.message, (_) => null);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
