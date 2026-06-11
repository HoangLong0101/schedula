import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/staff_member.dart';

class StaffModel extends StaffMember {
  const StaffModel({
    required super.id,
    required super.name,
    required super.role,
    required super.status,
    required super.color,
    super.appointments,
    super.rating,
    super.phone,
    super.email,
    super.specialties,
    super.shift,
  });

  factory StaffModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Xử lý parse Shift (Lịch trực)
    final rawShift = data['shift'] as Map<String, dynamic>? ?? {};
    final parsedShift = <String, ShiftValue>{};
    rawShift.forEach((key, value) {
      parsedShift[key] = _shiftFromString(value as String?);
    });

    return StaffModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      // Seed data cũ dùng 'specialty', form mới dùng 'role_title'
      role: data['role_title'] ?? data['specialty'] as String? ?? 'Nhân viên',
      status: _statusFromString(data['status'] as String?),
      color: data['color'] as String? ?? '#148a9c',
      appointments: data['appointments'] as int? ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      specialties: List<String>.from(data['specialties'] ?? []),
      shift: parsedShift.isEmpty ? _defaultShift : parsedShift,
    );
  }

  Map<String, dynamic> toFirestore() {
    final shiftMap = <String, String>{};
    shift.forEach((key, value) {
      shiftMap[key] = value.name;
    });

    return {
      'name': name,
      'role_title': role, // Chức danh hiển thị
      'role': 'staff',    // BẮT BUỘC: Phân quyền trong Firestore
      'status': _statusToString(status),
      'color': color,
      'appointments': appointments,
      'rating': rating,
      'phone': phone,
      'email': email,
      'specialties': specialties,
      'shift': shiftMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // --- Helpers ---
  static StaffStatus _statusFromString(String? val) {
    switch (val) {
      case 'in_session': return StaffStatus.inSession;
      case 'absent': return StaffStatus.absent;
      case 'available':
      default: return StaffStatus.available;
    }
  }

  static String _statusToString(StaffStatus status) {
    switch (status) {
      case StaffStatus.inSession: return 'in_session';
      case StaffStatus.absent: return 'absent';
      case StaffStatus.available: return 'available';
    }
  }

  static ShiftValue _shiftFromString(String? val) {
    switch (val) {
      case 'morning': return ShiftValue.morning;
      case 'afternoon': return ShiftValue.afternoon;
      case 'off': return ShiftValue.off;
      case 'full':
      default: return ShiftValue.full;
    }
  }

  static final _defaultShift = {
    'mon': ShiftValue.full, 'tue': ShiftValue.full, 'wed': ShiftValue.full,
    'thu': ShiftValue.full, 'fri': ShiftValue.full, 'sat': ShiftValue.morning, 'sun': ShiftValue.off,
  };
}