import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/product_item.dart';
import '../../domain/entities/service_item.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_state.dart';

@injectable
class CatalogCubit extends Cubit<CatalogState> {
  final CatalogRepository _repository;
  CatalogCubit(this._repository) : super(const CatalogState());

  StreamSubscription? _serviceSub;
  StreamSubscription? _productSub;
  String _tenantId = '';

  void init(String tenantId) {
    _tenantId = tenantId;
    _serviceSub?.cancel();
    _productSub?.cancel();

    _serviceSub = _repository.watchServices(tenantId).listen((res) {
      res.fold((_) => null, (list) => emit(state.copyWith(services: list)));
    });

    _productSub = _repository.watchProducts(tenantId).listen((res) {
      res.fold((_) => null, (list) => emit(state.copyWith(products: list)));
    });
  }

  void changeTab(CatalogTab tab) => emit(state.copyWith(currentTab: tab, showForm: false, resetEdit: true));
  void toggleForm(bool show) => emit(state.copyWith(showForm: show));
  void setEditItem(dynamic item) => emit(state.copyWith(editingItem: item, showForm: true));
  void cancelEdit() => emit(state.copyWith(showForm: false, resetEdit: true));

  Future<void> saveService(String? id, String name, int price, int duration, String category, List<String> res) async {
    final item = ServiceItem(id: id ?? '', tenantId: _tenantId, name: name, price: price, duration: duration, category: category, resources: res);
    id == null ? await _repository.createService(item) : await _repository.updateService(item);
    cancelEdit();
  }

  Future<void> saveProduct(String? id, String name, int price, String unit, String category) async {
    final item = ProductItem(id: id ?? '', tenantId: _tenantId, name: name, price: price, unit: unit, category: category);
    id == null ? await _repository.createProduct(item) : await _repository.updateProduct(item);
    cancelEdit();
  }

  Future<void> deleteService(String id) async => await _repository.deleteService(id);
  Future<void> deleteProduct(String id) async => await _repository.deleteProduct(id);

  @override
  Future<void> close() {
    _serviceSub?.cancel();
    _productSub?.cancel();
    return super.close();
  }
}