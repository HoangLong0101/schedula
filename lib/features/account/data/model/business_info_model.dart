import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/business_info.dart';

class BusinessInfoModel extends BusinessInfo {
  const BusinessInfoModel({
    required super.name,
    required super.type,
    required super.address,
    required super.phone,
    required super.website,
    required super.hoursWeekday,
    required super.hoursWeekend,
    required super.description,
  });

  factory BusinessInfoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BusinessInfoModel(
      name: data['name'] as String? ?? 'Schedula Spa',
      type: data['type'] as String? ?? 'Spa & Làm đẹp',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      website: data['website'] as String? ?? '',
      hoursWeekday: data['hoursWeekday'] as String? ?? '08:00 - 20:00',
      hoursWeekend: data['hoursWeekend'] as String? ?? '09:00 - 18:00',
      description: data['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'address': address,
      'phone': phone,
      'website': website,
      'hoursWeekday': hoursWeekday,
      'hoursWeekend': hoursWeekend,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}