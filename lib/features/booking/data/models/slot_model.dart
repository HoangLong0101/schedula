import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/slot.dart';

class SlotModel extends Slot {
  const SlotModel({
    required super.id,
    required super.tenantId,
    required super.staffId,
    required super.date,
    required super.intervals,
  });

  factory SlotModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawIntervals = data['intervals'] as List<dynamic>? ?? const [];
    return SlotModel(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? '',
      staffId: data['staffId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      intervals: rawIntervals
          .whereType<Map<String, dynamic>>()
          .map(SlotIntervalModel.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'tenantId': tenantId,
        'staffId': staffId,
        'date': Timestamp.fromDate(date),
        'intervals': intervals
            .whereType<SlotIntervalModel>()
            .map((interval) => interval.toJson())
            .toList(growable: false),
      };
}

class SlotIntervalModel extends SlotInterval {
  const SlotIntervalModel({
    required super.startTime,
    required super.endTime,
    super.bookingId,
  });

  factory SlotIntervalModel.fromJson(Map<String, dynamic> json) {
    return SlotIntervalModel(
      startTime: (json['startTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime: (json['endTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      bookingId: json['bookingId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        if (bookingId != null) 'bookingId': bookingId,
      };
}
