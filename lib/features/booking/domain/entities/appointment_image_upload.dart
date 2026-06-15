import 'dart:typed_data';

class AppointmentImageUpload {
  const AppointmentImageUpload({
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String? contentType;
}
