import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/features/academic/academic_models.dart';
import 'package:santri360/features/academic/academic_repository.dart';

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data) =>
    Response(requestOptions: RequestOptions(), statusCode: 200, data: data);

void main() {
  late MockDio dio;
  late AcademicRepository repo;

  setUp(() {
    dio = MockDio();
    repo = AcademicRepository(dio);
  });

  group('model', () {
    test('WaliScore + komponen', () {
      final s = WaliScore.fromJson({
        'santri_id': 1,
        'mata_pelajaran_id': 2,
        'nama_mapel': 'Fiqih',
        'nilai_akhir': 85.5,
        'komponen': [
          {'komponen': 'UTS', 'nilai': 80, 'bobot': 0.4},
        ],
      });
      expect(s.namaMapel, 'Fiqih');
      expect(s.nilaiAkhir, 85.5);
      expect(s.komponen.single.bobot, 0.4);
    });

    test('Rapor: download_url null = belum bisa diunduh', () {
      final r = Rapor.fromJson({
        'id': 3,
        'semester': 'ganjil',
        'tahun_ajaran': {'id': 1, 'nama': '2025/2026'},
        'download_url': null,
      });
      expect(r.tahunAjaran, '2025/2026');
      expect(r.bisaUnduh, isFalse);
      expect(Rapor.fromJson({'id': 4, 'download_url': 'x'}).bisaUnduh, isTrue);
    });

    test('Tahfidz + rentang setoran, nilai null aman', () {
      final t = Tahfidz.fromJson({
        'santri_id': 1,
        'nama': 'A',
        'total_setoran': 2,
        'total_baris': 150,
        'riwayat': [
          {
            'id': 1,
            'tanggal': '2026-10-01',
            'dari_surah': 'Al-Baqarah',
            'dari_ayat': 1,
            'sampai_surah': 'Al-Baqarah',
            'sampai_ayat': 5,
            'kelancaran': null,
          },
        ],
      });
      expect(t.riwayat.single.rentang, 'Al-Baqarah 1 - Al-Baqarah 5');
      expect(t.perkiraanJuz, 0.5);
      expect(Setoran.fromJson({'id': 2}).rentang, '-');
    });

    test('Sertifikat memakai published_at bila issued_at kosong', () {
      final s = Sertifikat.fromJson({
        'id': 1,
        'juz_ke': 30,
        'published_at': '2026-01-02T00:00:00Z',
      });
      expect(s.juzKe, 30);
      expect(s.issuedAt, isNotNull);
    });

    test('shortDate', () {
      expect(shortDate(null), isNull);
      expect(shortDate('bukan-tanggal'), 'bukan-tanggal');
    });
  });

  group('repository', () {
    test('scores mengirim santri_id & membaca envelope', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/akademik/portal-wali/scores',
          queryParameters: {'santri_id': 7, 'per_page': 50},
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, dynamic>>({
          'data': [
            {'santri_id': 7, 'nama_mapel': 'Nahwu', 'nilai_akhir': 90},
          ],
          'meta': {'current_page': 1, 'last_page': 1},
        }),
      );
      final r = await repo.scores(7);
      expect(r.single.namaMapel, 'Nahwu');
    });

    test('tahfidz memilih item santri yang diminta', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/akademik/portal-wali/tahfidz',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, dynamic>>({
          'data': [
            {'santri_id': 1, 'nama': 'A', 'total_setoran': 1, 'total_baris': 1},
          ],
        }),
      );
      expect(await repo.tahfidz(1), isNotNull);
      expect(await repo.tahfidz(2), isNull);
    });

    test(
      '403 MODULE_NOT_ENTITLED menjadi ApiException.isNotEntitled',
      () async {
        final req = RequestOptions();
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: req,
            response: Response(
              requestOptions: req,
              statusCode: 403,
              data: {
                'message': 'x',
                'meta': {'code': 'MODULE_NOT_ENTITLED'},
              },
            ),
          ),
        );
        await expectLater(
          repo.rapor(1),
          throwsA(
            isA<ApiException>().having((e) => e.isNotEntitled, 'ent', true),
          ),
        );
      },
    );

    test('downloadRapor meminta bytes lewat Dio ber-auth', () async {
      when(
        () => dio.get<List<int>>(
          '/akademik/portal-wali/rapor/9/download',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok<List<int>>([1, 2, 3]));
      expect(await repo.downloadRapor(9), [1, 2, 3]);
    });
  });
}
