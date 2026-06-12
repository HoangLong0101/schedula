import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

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

  Future<Map<String, dynamic>> scanAppointmentImage(String imagePath) async {
    _ensureConfigured();

    final formData = FormData.fromMap(<String, dynamic>{
      'image': await MultipartFile.fromFile(imagePath),
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
        'BOOKING_CASCADE_API_BASE_URL is not set. Add it to your '
        '.firebase-config.<flavor>.json and run with --dart-define-from-file.',
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
        'Booking Cascade API request failed: '
        '${error.response?.statusCode ?? error.type.name} '
        '${error.response?.data ?? error.message}',
      );
    }
  }
}
