import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/appointment_image_upload.dart';

class BookingCascadeApiException implements Exception {
  BookingCascadeApiException(this.message);

  final String message;
}

class BookingCascadeApiNotConfiguredException implements Exception {
  BookingCascadeApiNotConfiguredException(this.message);

  final String message;
}

@lazySingleton
class BookingCascadeApiDataSource {
  BookingCascadeApiDataSource(
    this._dio,
    @Named('bookingCascadeBaseUrl') this._baseUrl,
  );

  final Dio _dio;
  final String _baseUrl;
  final Logger _logger = Logger();

  Future<Map<String, dynamic>> extractText(String text) async {
    _ensureConfigured();

    final response = await _request(
      () => _dio.post<List<int>>(
        '$_baseUrl/api/v1/extract',
        data: <String, dynamic>{'text': text, 'record': false},
        options: Options(
          contentType: 'application/json; charset=utf-8',
          responseType: ResponseType.bytes,
        ),
      ),
    );

    return _decodeJson(response.data);
  }

  Future<Map<String, dynamic>> scanAppointmentImage(
    AppointmentImageUpload image,
  ) async {
    _ensureConfigured();

    final formData = FormData.fromMap(<String, dynamic>{
      'image': MultipartFile.fromBytes(image.bytes, filename: image.filename),
    });

    final response = await _request(
      () => _dio.post<List<int>>(
        '$_baseUrl/api/v1/scan-appointment',
        queryParameters: <String, dynamic>{'record': false},
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      ),
    );

    return _decodeJson(response.data);
  }

  /// Decodes the raw body as UTF-8 explicitly: the API does not always
  /// declare a charset, and falling back to latin-1 garbles Vietnamese
  /// diacritics (e.g. "Ngọc" -> "Ngá»c").
  Map<String, dynamic> _decodeJson(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    _logger.d('Booking Cascade API response: $decoded');
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  void _ensureConfigured() {
    if (_baseUrl.isEmpty) {
      throw BookingCascadeApiNotConfiguredException(
        'Chưa cấu hình địa chỉ AI. Vui lòng kiểm tra '
        'BOOKING_CASCADE_API_BASE_URL trong file cấu hình Firebase.',
      );
    }
  }

  Future<Response<List<int>>> _request(
    Future<Response<List<int>>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw BookingCascadeApiException(
        'Không thể gọi dịch vụ AI đặt lịch: '
        '${error.response?.statusCode ?? error.type.name} '
        '${error.response?.data ?? error.message}',
      );
    }
  }
}
