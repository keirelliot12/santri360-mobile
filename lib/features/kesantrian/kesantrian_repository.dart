import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import 'kesantrian_models.dart';

class KesantrianRepository {
  const KesantrianRepository(this._dio);

  final Dio _dio;

  Future<Paginated<Permission>> permissions(int santriId, {int page = 1}) =>
      _get('permissions', santriId, page, Permission.fromJson);

  Future<Paginated<Violation>> violations(int santriId, {int page = 1}) =>
      _get('violations', santriId, page, Violation.fromJson);

  Future<Paginated<HealthRecord>> health(int santriId, {int page = 1}) =>
      _get('health', santriId, page, HealthRecord.fromJson);

  Future<Paginated<T>> _get<T>(
    String path,
    int santriId,
    int page,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/children/$santriId/$path',
        queryParameters: {'page': page, 'per_page': 20},
      );
      return Paginated.fromEnvelope(res.data!, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final kesantrianRepositoryProvider = Provider<KesantrianRepository>(
  (ref) => KesantrianRepository(ref.watch(dioProvider)),
);
