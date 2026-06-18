import 'package:equatable/equatable.dart';

enum EquipmentStatus { available, inUse, maintenance }

class Equipment extends Equatable {
  final String id;
  final String name;
  final EquipmentStatus status;
  final String location;
  final String lastMaintenance;
  final int quantity;

  const Equipment({
    required this.id,
    required this.name,
    required this.status,
    required this.location,
    required this.lastMaintenance,
    this.quantity = 1,
  });

  Equipment copyWith({
    String? name,
    EquipmentStatus? status,
    String? location,
    String? lastMaintenance,
    int? quantity,
  }) {
    return Equipment(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      location: location ?? this.location,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [id, name, status, location, lastMaintenance, quantity];
}