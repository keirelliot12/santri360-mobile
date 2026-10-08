import 'package:dio/dio.dart';

/// Error API yang sudah dinormalisasi dari envelope `{success, message, data, meta}`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return const ApiException(
        message:
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
    final body = res.data;
    String message = 'Terjadi kesalahan (${res.statusCode}).';
    String? code;
    var fieldErrors = <String, List<String>>{};
    if (body is Map<String, dynamic>) {
      message = (body['message'] as String?) ?? message;
      final meta = body['meta'];
      if (meta is Map<String, dynamic>) code = meta['code'] as String?;
      code ??= body['code'] as String?;
      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        fieldErrors = errors.map(
          (k, v) => MapEntry(k, (v as List<dynamic>).map((e) => '$e').toList()),
        );
      }
    }
    if (res.statusCode == 429) {
      message = 'Terlalu banyak percobaan. Silakan tunggu sebentar.';
    }
    return ApiException(
      message: message,
      statusCode: res.statusCode,
      code: code,
      fieldErrors: fieldErrors,
    );
  }

  final String message;
  final int? statusCode;

  /// Kode bisnis, mis. `MODULE_NOT_ENTITLED`, `SUBSCRIPTION_INACTIVE`.
  final String? code;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotEntitled =>
      code == 'MODULE_NOT_ENTITLED' || code == 'SUBSCRIPTION_INACTIVE';

  @override
  String toString() => message;
}
