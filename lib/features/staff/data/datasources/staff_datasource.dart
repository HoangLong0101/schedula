import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/staff_member.dart';
import '../models/staff_model.dart';

@lazySingleton
class StaffDataSource {
  StaffDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // Đọc danh sách real-time
  Stream<List<StaffModel>> watchStaff(String tenantId) {
    return _users
        .where('tenantId', isEqualTo: tenantId)
        .where('role', isEqualTo: 'staff') // Chỉ lấy nhân viên
        .snapshots()
        .map((snapshot) => snapshot.docs.map(StaffModel.fromFirestore).toList());
  }

  Future<StaffModel> createStaff(String tenantId, StaffMember staff) async {
    final docRef = _users.doc(); // Firestore tự tạo ID

    final model = StaffModel(
      id: docRef.id, name: staff.name, role: staff.role, status: staff.status,
      color: staff.color, appointments: staff.appointments, rating: staff.rating,
      phone: staff.phone, email: staff.email, specialties: staff.specialties, shift: staff.shift,
    );

    final data = model.toFirestore();
    data['tenantId'] = tenantId;
    data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return model;
  }

  Future<void> updateStaff(StaffMember staff) async {
    final model = StaffModel(
      id: staff.id, name: staff.name, role: staff.role, status: staff.status,
      color: staff.color, appointments: staff.appointments, rating: staff.rating,
      phone: staff.phone, email: staff.email, specialties: staff.specialties, shift: staff.shift,
    );
    await _users.doc(staff.id).update(model.toFirestore());
  }

  Future<void> deleteStaff(String id) async {
    await _users.doc(id).delete();
  }
}