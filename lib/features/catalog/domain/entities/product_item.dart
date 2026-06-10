import 'package:equatable/equatable.dart';

class ProductItem extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final int price;
  final String unit; // Hộp, Lọ, Chai...
  final String category;

  const ProductItem({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.price,
    required this.unit,
    required this.category,
  });

  @override
  List<Object?> get props => [id, tenantId, name, price, unit, category];
}