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
            (failure) => print('Lỗi tải danh sách khách hàng: ${failure.message}'),
            (customers) => emit(customers), // Cập nhật UI ngay lập tức khi có data mới
      );
    });
  }

  Future<void> addCustomer(Customer customer) async {
    await _createCustomer(CreateCustomerParams(
      tenantId: _currentTenantId,
      customer: customer,
    ));
  }

  Future<void> updateCustomer(Customer customer) async {
    await _updateCustomer(UpdateCustomerParams(customer: customer));
  }

  Future<void> deleteCustomer(String id) async {
    await _deleteCustomer(DeleteCustomerParams(customerId: id));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}