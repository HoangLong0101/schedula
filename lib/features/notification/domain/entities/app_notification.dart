import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    this.bookingId,
    this.sentAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final String? bookingId;
  final DateTime? sentAt;

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    message,
    read,
    bookingId,
    sentAt,
  ];
}
