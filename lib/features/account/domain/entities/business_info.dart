import 'package:equatable/equatable.dart';

class BusinessInfo extends Equatable {
  final String name;
  final String type;
  final String address;
  final String phone;
  final String website;
  final String hoursWeekday;
  final String hoursWeekend;
  final String description;

  const BusinessInfo({
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.website,
    required this.hoursWeekday,
    required this.hoursWeekend,
    required this.description,
  });

  BusinessInfo copyWith({
    String? name,
    String? type,
    String? address,
    String? phone,
    String? website,
    String? hoursWeekday,
    String? hoursWeekend,
    String? description,
  }) {
    return BusinessInfo(
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      hoursWeekday: hoursWeekday ?? this.hoursWeekday,
      hoursWeekend: hoursWeekend ?? this.hoursWeekend,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
    name,
    type,
    address,
    phone,
    website,
    hoursWeekday,
    hoursWeekend,
    description,
  ];
}