import 'package:equatable/equatable.dart';

class ServiceItem extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final int price;
  final int duration; // Số phút
  final String category;
  final List<String> resources;

  const ServiceItem({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.price,
    required this.duration,
    required this.category,
    this.resources = const [],
  });

  @override
  List<Object?> get props => [id, tenantId, name, price, duration, category, resources];
}