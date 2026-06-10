import 'package:equatable/equatable.dart';

enum StaffStatus { available, inSession, absent }
enum ShiftValue { morning, afternoon, full, off }

class StaffMember extends Equatable {
  final String id;
  final String name;
  final String role;
  final StaffStatus status;
  final String color;
  final int appointments;
  final double rating;
  final String phone;
  final String email;
  final List<String> specialties;
  final Map<String, ShiftValue> shift;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.color,
    this.appointments = 0,
    this.rating = 5.0,
    this.phone = '',
    this.email = '',
    this.specialties = const [],
    this.shift = const {},
  });

  StaffMember copyWith({
    String? name,
    String? role,
    StaffStatus? status,
    String? color,
    int? appointments,
    double? rating,
    String? phone,
    String? email,
    List<String>? specialties,
    Map<String, ShiftValue>? shift,
  }) {
    return StaffMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      color: color ?? this.color,
      appointments: appointments ?? this.appointments,
      rating: rating ?? this.rating,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      specialties: specialties ?? this.specialties,
      shift: shift ?? this.shift,
    );
  }

  @override
  List<Object?> get props => [
    id, name, role, status, color, appointments,
    rating, phone, email, specialties, shift,
  ];
}