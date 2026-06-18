import 'package:equatable/equatable.dart';

enum CustomerStatus { active, followUp, newCustomer, recovery }

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String birthday;
  final String notes;
  final String allergies;
  final String lastVisit;
  final int totalVisits;
  final String avatar;
  final String color;

  // Các trường phái sinh (Derived) phục vụ UI
  final CustomerStatus derivedStatus;
  final int futureCount;
  final int recent30Count;
  final int daysSinceLast;
  final int? birthdayInDays;
  final int? age;
  final String? nextApptDate;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.birthday = '',
    this.notes = '',
    this.allergies = '',
    required this.lastVisit,
    this.totalVisits = 0,
    required this.avatar,
    required this.color,
    this.derivedStatus = CustomerStatus.newCustomer,
    this.futureCount = 0,
    this.recent30Count = 0,
    this.daysSinceLast = 0,
    this.birthdayInDays,
    this.age,
    this.nextApptDate,
  });

  Customer copyWith({
    String? name, String? phone, String? email, String? birthday,
    String? notes, String? allergies, String? lastVisit,
    int? totalVisits, String? avatar, String? color,
    CustomerStatus? derivedStatus, int? futureCount, int? recent30Count,
    int? daysSinceLast, int? birthdayInDays, int? age, String? nextApptDate,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name, phone: phone ?? this.phone, email: email ?? this.email,
      birthday: birthday ?? this.birthday, notes: notes ?? this.notes, allergies: allergies ?? this.allergies,
      lastVisit: lastVisit ?? this.lastVisit, totalVisits: totalVisits ?? this.totalVisits,
      avatar: avatar ?? this.avatar, color: color ?? this.color,
      derivedStatus: derivedStatus ?? this.derivedStatus, futureCount: futureCount ?? this.futureCount,
      recent30Count: recent30Count ?? this.recent30Count, daysSinceLast: daysSinceLast ?? this.daysSinceLast,
      birthdayInDays: birthdayInDays ?? this.birthdayInDays, age: age ?? this.age, nextApptDate: nextApptDate ?? this.nextApptDate,
    );
  }

  @override
  List<Object?> get props => [
    id, name, phone, email, birthday, notes, allergies, lastVisit, totalVisits,
    avatar, color, derivedStatus, futureCount, recent30Count, daysSinceLast,
    birthdayInDays, age, nextApptDate,
  ];
}