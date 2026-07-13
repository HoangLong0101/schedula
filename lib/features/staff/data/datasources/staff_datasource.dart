import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/staff_repository.dart';
import '../models/staff_model.dart';

@lazySingleton
class StaffDataSource {
  StaffDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<StaffModel>> watchStaff(String tenantId) {
    return _users
        .where('tenantId', isEqualTo: tenantId)
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(StaffModel.fromFirestore).toList());
  }

  Future<CreatedStaff> createStaff(String tenantId, StaffMember staff) async {
    if (tenantId.isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('createStaffAccount').call<Map<String, dynamic>>({
      'name': staff.name,
      'email': staff.email,
      'phone': staff.phone,
      'roleTitle': staff.role,
      'status': _statusToString(staff.status),
      'color': staff.color,
      'specialties': staff.specialties,
      'shift': staff.shift.map(
        (day, value) => MapEntry(day, value.name),
      ),
    });
    final uid = result.data['uid'] as String;
    return (
      staff: StaffModel(
        id: uid,
        name: staff.name,
        role: staff.role,
        status: staff.status,
        color: staff.color,
        phone: staff.phone,
        email: staff.email,
        specialties: staff.specialties,
        shift: staff.shift,
      ),
      temporaryPassword: result.data['temporaryPassword'] as String,
    );
  }

  Future<void> updateStaff(StaffMember staff) async {
    final model = StaffModel(
      id: staff.id,
      name: staff.name,
      role: staff.role,
      status: staff.status,
      color: staff.color,
      appointments: staff.appointments,
      rating: staff.rating,
      phone: staff.phone,
      email: staff.email,
      specialties: staff.specialties,
      shift: staff.shift,
    );
    await _users.doc(staff.id).update(model.toFirestore());
  }

  Future<void> deleteStaff(String id) async {
    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('deleteStaffAccount').call<Map<String, dynamic>>({
      'uid': id,
    });
  }

  String _statusToString(StaffStatus status) => switch (status) {
    StaffStatus.available => 'available',
    StaffStatus.inSession => 'in_session',
    StaffStatus.absent => 'absent',
  };
}
