import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/booking.dart';

class BookingModel extends Booking {
  BookingModel({required super.id, required super.title});

  factory BookingModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BookingModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
    );
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'title': title,
      };
}
