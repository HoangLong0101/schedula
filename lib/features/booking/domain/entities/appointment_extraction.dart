import 'package:equatable/equatable.dart';

/// Response of the Booking Cascade API (`/api/v1/extract` and
/// `/api/v1/scan-appointment`), used to pre-fill the booking form.
///
/// Raw shape:
/// ```json
/// {
///   "intent": "book",
///   "extracted_fields": {
///     "appointment_date": "2026-06-16",
///     "appointment_time": "15:00",
///     "customer_name": "Ngọc",
///     "phone": "0901234567"
///   },
///   "ocr": {"full_text": "...", "booking_lines": []}
/// }
/// ```
class AppointmentExtraction extends Equatable {
  const AppointmentExtraction({required this.fields});

  /// Full decoded API response.
  final Map<String, dynamic> fields;

  String? get intent => _string(fields['intent']);

  Map<String, dynamic> get _extracted =>
      fields['extracted_fields'] is Map<String, dynamic>
          ? fields['extracted_fields'] as Map<String, dynamic>
          : const <String, dynamic>{};

  String? get customerName => _string(_extracted['customer_name']);

  String? get phone => _string(_extracted['phone']);

  /// Staff name when the API extracted one; usually absent.
  String? get staffName =>
      _string(_extracted['staff_name']) ??
      _string(_extracted['staff']) ??
      _entityText(const {'nhân viên', 'staff'});

  /// Service name when the API extracted one; usually absent.
  String? get serviceName =>
      _string(_extracted['service_name']) ??
      _string(_extracted['service']) ??
      _entityText(const {'dịch vụ', 'service'});

  /// The sentence the API ran extraction on (OCR'd booking text).
  String? get sourceText => _string(fields['text']);

  /// `appointment_date` parsed from `yyyy-MM-dd`.
  DateTime? get appointmentDate {
    final raw = _string(_extracted['appointment_date']);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// `appointment_time` parsed from `HH:mm`.
  ({int hour, int minute})? get appointmentTime {
    final raw = _string(_extracted['appointment_time']);
    final match =
        raw == null ? null : RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  String? get ocrFullText {
    final ocr = fields['ocr'];
    return ocr is Map<String, dynamic> ? _string(ocr['full_text']) : null;
  }

  String? _entityText(Set<String> labels) {
    final entities = fields['entities'];
    if (entities is! List) {
      return null;
    }
    for (final entity in entities.whereType<Map<String, dynamic>>()) {
      final label = _string(entity['label'])?.toLowerCase();
      if (label != null && labels.contains(label)) {
        return _string(entity['text']);
      }
    }
    return null;
  }

  static String? _string(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [fields];
}
