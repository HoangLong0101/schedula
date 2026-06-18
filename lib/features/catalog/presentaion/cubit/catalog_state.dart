import 'package:equatable/equatable.dart';
import '../../domain/entities/product_item.dart';
import '../../domain/entities/service_item.dart';

enum CatalogTab { service, product }

class CatalogState extends Equatable {
  final CatalogTab currentTab;
  final List<ServiceItem> services;
  final List<ProductItem> products;
  final bool showForm;
  final dynamic editingItem; // Có thể là ServiceItem hoặc ProductItem

  const CatalogState({
    this.currentTab = CatalogTab.service,
    this.services = const [],
    this.products = const [],
    this.showForm = false,
    this.editingItem,
  });

  CatalogState copyWith({
    CatalogTab? currentTab,
    List<ServiceItem>? services,
    List<ProductItem>? products,
    bool? showForm,
    dynamic editingItem,
    bool resetEdit = false,
  }) {
    return CatalogState(
      currentTab: currentTab ?? this.currentTab,
      services: services ?? this.services,
      products: products ?? this.products,
      showForm: showForm ?? this.showForm,
      editingItem: resetEdit ? null : (editingItem ?? this.editingItem),
    );
  }

  @override
  List<Object?> get props => [currentTab, services, products, showForm, editingItem];
}