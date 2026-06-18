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
  final String planTier;
  final DateTime? planStartedAt;
  final DateTime? planExpiresAt;

  const BusinessInfo({
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.website,
    required this.hoursWeekday,
    required this.hoursWeekend,
    required this.description,
    this.planTier = 'basic',
    this.planStartedAt,
    this.planExpiresAt,
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
    String? planTier,
    DateTime? planStartedAt,
    DateTime? planExpiresAt,
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
      planTier: planTier ?? this.planTier,
      planStartedAt: planStartedAt ?? this.planStartedAt,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
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
    planTier,
    planStartedAt,
    planExpiresAt,
  ];
}
