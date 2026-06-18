import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/customer.dart';
import '../models/customer_model.dart';

@lazySingleton
class CustomerDataSource {
  CustomerDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');

  Stream<List<CustomerModel>> watchCustomers(String tenantId) {
    return _customers
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map(CustomerModel.fromFirestore).toList());
  }

  Future<CustomerModel> createCustomer(String tenantId, Customer customer) async {
    final docRef = _customers.doc();

    final model = CustomerModel(
      id: docRef.id,
      name: customer.name, phone: customer.phone, email: customer.email,
      birthday: customer.birthday, notes: customer.notes, allergies: customer.allergies,
      lastVisit: customer.lastVisit, totalVisits: customer.totalVisits,
      avatar: customer.avatar, color: customer.color,
    );

    final data = model.toFirestore();
    data['tenantId'] = tenantId;
    data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return model;
  }

  Future<void> updateCustomer(Customer customer) async {
    final model = CustomerModel(
      id: customer.id,
      name: customer.name, phone: customer.phone, email: customer.email,
      birthday: customer.birthday, notes: customer.notes, allergies: customer.allergies,
      lastVisit: customer.lastVisit, totalVisits: customer.totalVisits,
      avatar: customer.avatar, color: customer.color,
    );
    await _customers.doc(customer.id).update(model.toFirestore());
  }

  Future<void> deleteCustomer(String id) async {
    await _customers.doc(id).delete();
  }
}