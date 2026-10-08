import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import 'academic_models.dart';

class AcademicRepository {
  AcademicRepository(this._dio);

  final Dio _dio;

  Future<Paginated<T>> _list<T>(
    String path,
    int santriId,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {'santri_id': santriId, 'per_page': 50},
      );
      return Paginated.fromEnvelope(res.data!, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<WaliScore>> scores(int santriId) async => (await _list(
    '/akademik/portal-wali/scores',
    santriId,
    WaliScore.fromJson,
  )).items;

  Future<List<Rapor>> rapor(int santriId) async => (await _list(
    '/akademik/portal-wali/rapor',
    santriId,
    Rapor.fromJson,
  )).items;

  /// Endpoint mengembalikan satu ringkasan per santri; difilter `santri_id`.
  Future<Tahfidz?> tahfidz(int santriId) async {
    final p = await _list(
      '/akademik/portal-wali/tahfidz',
      santriId,
      Tahfidz.fromJson,
    );
    for (final t in p.items) {
      if (t.santriId == santriId) return t;
    }
    return null;
  }

  Future<List<Sertifikat>> sertifikat(int santriId) async => (await _list(
    '/akademik/portal-wali/sertifikat',
    santriId,
    Sertifikat.fromJson,
  )).items;

  /// Byte PDF lewat Dio (header Bearer): token tidak pernah masuk URL.
  Future<List<int>> downloadRapor(int id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/akademik/portal-wali/rapor/$id/download',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(ref.watch(dioProvider)),
);

final scoresProvider = FutureProvider.family<List<WaliScore>, int>(
  (ref, santriId) => ref.watch(academicRepositoryProvider).scores(santriId),
);

final raporProvider = FutureProvider.family<List<Rapor>, int>(
  (ref, santriId) => ref.watch(academicRepositoryProvider).rapor(santriId),
);

final tahfidzProvider = FutureProvider.family<Tahfidz?, int>(
  (ref, santriId) => ref.watch(academicRepositoryProvider).tahfidz(santriId),
);

final sertifikatProvider = FutureProvider.family<List<Sertifikat>, int>(
  (ref, santriId) => ref.watch(academicRepositoryProvider).sertifikat(santriId),
);
