import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

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

  Future<Map<String, dynamic>> extractText(String text) async {
    _ensureConfigured();

    final response = await _request(
      () => _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/v1/extract',
        data: <String, dynamic>{'text': text, 'record': false},
        options: Options(contentType: 'application/json; charset=utf-8'),
      ),
    );

    return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> scanAppointmentImage(String imagePath) async {
    _ensureConfigured();

    final formData = FormData.fromMap(<String, dynamic>{
      'image': await MultipartFile.fromFile(imagePath),
    });

    final response = await _request(
      () => _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/v1/scan-appointment',
        queryParameters: <String, dynamic>{'record': false},
        data: formData,
      ),
    );

    return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
  }

  void _ensureConfigured() {
    if (_baseUrl.isEmpty) {
      throw BookingCascadeApiNotConfiguredException(
        'BOOKING_CASCADE_API_BASE_URL is not set. Add it to your '
        '.firebase-config.<flavor>.json and run with --dart-define-from-file.',
      );
    }
  }

  Future<Response<Map<String, dynamic>>> _request(
    Future<Response<Map<String, dynamic>>> Function() send,
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
