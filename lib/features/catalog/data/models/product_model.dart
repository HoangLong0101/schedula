import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_item.dart';

class ProductModel extends ProductItem {
  const ProductModel({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.price,
    required super.unit,
    required super.category,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ProductModel(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      price: data['price'] as int? ?? 0,
      unit: data['unit'] as String? ?? 'Lọ',
      category: data['category'] as String? ?? 'Khác',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'name': name,
      'price': price,
      'unit': unit,
      'category': category,
    };
  }
}