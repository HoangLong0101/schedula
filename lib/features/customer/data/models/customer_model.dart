import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/customer.dart';

class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    super.birthday,
    super.notes,
    super.allergies,
    required super.lastVisit,
    super.totalVisits,
    required super.avatar,
    required super.color,
  });

  factory CustomerModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Xử lý Timestamp lastVisit sang String (yyyy-MM-dd)
    String lastVisitStr = '';
    final lastVisitTs = data['lastVisit'] as Timestamp?;
    if (lastVisitTs != null) {
      lastVisitStr = lastVisitTs.toDate().toIso8601String().split('T')[0];
    }

    return CustomerModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      birthday: data['birthday'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      allergies: data['allergies'] as String? ?? '',
      lastVisit: lastVisitStr,
      totalVisits: data['visitCount'] as int? ?? data['totalVisits'] as int? ?? 0,
      avatar: data['avatar'] as String? ?? 'U',
      color: data['color'] as String? ?? '#22AFC2',
    );
  }

  Map<String, dynamic> toFirestore() {
    DateTime? lastVisitDate;
    try {
      lastVisitDate = DateTime.parse(lastVisit);
    } catch (_) {
      lastVisitDate = DateTime.now();
    }

    return {
      'name': name,
      'phone': phone,
      'email': email,
      'birthday': birthday,
      'notes': notes,
      'allergies': allergies,
      'lastVisit': Timestamp.fromDate(lastVisitDate),
      'visitCount': totalVisits,
      'avatar': avatar,
      'color': color,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}