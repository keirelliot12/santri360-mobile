import 'dart:math';

import 'package:dio/dio.dart';

import '../config/tenant_config.dart';
import '../storage/token_storage.dart';

/// Dibuat sekali per app. Interceptor:
/// - `X-Pesantren-Code` (tenant white-label) di setiap request
/// - Bearer token Sanctum
/// - callback [onUnauthorized] saat 401 (logout paksa)
Dio createDio({
  required TenantConfig config,
  required TokenStorage tokens,
  required void Function() onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${config.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'X-Pesantren-Code': config.tenantCode,
      },
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401 &&
            !e.requestOptions.path.endsWith('/auth/login')) {
          onUnauthorized();
        }
        handler.next(e);
      },
    ),
  );
  return dio;
}

/// Header `Idempotency-Key` untuk POST/PUT bermiddleware `idempotency`.
/// Simpan key yang sama saat retry aksi yang sama agar tidak dobel.
Options idempotent(String key) => Options(headers: {'Idempotency-Key': key});

String newIdempotencyKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
