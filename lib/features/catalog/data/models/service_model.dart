import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/service_item.dart';

class ServiceModel extends ServiceItem {
  const ServiceModel({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.price,
    required super.duration,
    required super.category,
    super.resources,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ServiceModel(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      price: data['price'] as int? ?? 0,
      duration: data['duration'] as int? ?? data['durationMin'] as int? ?? 30,
      category: data['category'] as String? ?? 'Khác',
      resources: List<String>.from(data['resources'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'name': name,
      'price': price,
      'duration': duration,
      'durationMin': duration,
      'category': category,
      'resources': resources,
    };
  }
}
