import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/core/network/api_response.dart';
import 'package:santri360/features/children/child.dart';
import 'package:santri360/features/kesantrian/kesantrian_models.dart';
import 'package:santri360/features/kesantrian/kesantrian_pages.dart';
import 'package:santri360/features/kesantrian/kesantrian_repository.dart';

class MockRepo extends Mock implements KesantrianRepository {}

class MockDio extends Mock implements Dio {}

Paginated<T> page<T>(List<T> items, {bool more = false}) => Paginated(
  items: items,
  currentPage: 1,
  lastPage: more ? 2 : 1,
  total: items.length,
);

Widget app(Widget home, MockRepo repo) => ProviderScope(
  overrides: [
    kesantrianRepositoryProvider.overrideWithValue(repo),
    selectedChildProvider.overrideWithValue(
      const Child(id: 7, nama: 'Ahmad Fauzi'),
    ),
  ],
  child: MaterialApp(home: home),
);

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  group('parsing', () {
    test('Permission pakai status_portal, fallback status', () {
      final p = Permission.fromJson({
        'id': 1,
        'jenis_izin': 'Pulang',
        'waktu_mulai': '2026-10-01T08:00:00Z',
        'status': 'disetujui',
        'status_portal': 'Keluar',
      });
      expect(p.status, 'keluar');
      expect(p.mulai, isNotNull);
      expect(
        Permission.fromJson({'id': 2, 'status': 'pending'}).status,
        'pending',
      );
    });

    test('Violation & HealthRecord nullable', () {
      final v = Violation.fromJson({'id': 1, 'poin_takzir': 5});
      expect(v.poin, 5);
      expect(v.kategori, isNull);
      final h = HealthRecord.fromJson({'id': 1, 'perlu_dirujuk': null});
      expect(h.perluDirujuk, isFalse);
      expect(h.tanggal, isNull);
    });
  });

  group('repository', () {
    test('GET path & query, parse meta', () async {
      final dio = MockDio();
      when(
        () => dio.get<Map<String, dynamic>>(
          '/children/7/violations',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'data': [
              {'id': 1, 'poin_takzir': 3},
            ],
            'meta': {'current_page': 2, 'last_page': 3},
          },
        ),
      );
      final r = await KesantrianRepository(dio).violations(7, page: 2);
      expect(r.items.single.poin, 3);
      expect(r.hasMore, isTrue);
    });

    test('DioException -> ApiException (403 entitlement)', () async {
      final dio = MockDio();
      final req = RequestOptions(path: '/x');
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
      expect(
        KesantrianRepository(dio).health(7),
        throwsA(
          isA<ApiException>().having((e) => e.isNotEntitled, 'ent', true),
        ),
      );
    });
  });

  group('IzinPage', () {
    testWidgets('data', (t) async {
      when(() => repo.permissions(7, page: 1)).thenAnswer(
        (_) async => page([
          const Permission(
            id: 1,
            jenis: 'Pulang',
            status: 'ditolak',
            alasanPenolakan: 'Ujian',
          ),
        ]),
      );
      await t.pumpWidget(app(const IzinPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Pulang'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.permissions(7, page: 1))
          .thenAnswer((_) async => page(<Permission>[]));
      await t.pumpWidget(app(const IzinPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Belum ada data izin.'), findsOneWidget);
    });

    testWidgets('error 403 ramah', (t) async {
      when(() => repo.permissions(7, page: 1)).thenThrow(
        const ApiException(
          message: 'x',
          statusCode: 403,
          code: 'MODULE_NOT_ENTITLED',
        ),
      );
      await t.pumpWidget(app(const IzinPage(), repo));
      await t.pumpAndSettle();
      expect(find.textContaining('belum diaktifkan'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('PelanggaranPage', () {
    testWidgets('data + total poin', (t) async {
      when(() => repo.violations(7, page: 1)).thenAnswer(
        (_) async => page([
          const Violation(id: 1, kategori: 'Terlambat', poin: 5),
          const Violation(id: 2, kategori: 'Bolos', poin: 10),
        ]),
      );
      await t.pumpWidget(app(const PelanggaranPage(), repo));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('total_poin'))).data, '15');
      expect(find.text('Bolos'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.violations(7, page: 1))
          .thenAnswer((_) async => page(<Violation>[]));
      await t.pumpWidget(app(const PelanggaranPage(), repo));
      await t.pumpAndSettle();
      expect(find.textContaining('belum ada pelanggaran'), findsOneWidget);
    });

    testWidgets('muat lebih banyak', (t) async {
      when(() => repo.violations(7, page: 1)).thenAnswer(
        (_) async => page([const Violation(id: 1, poin: 1)], more: true),
      );
      when(() => repo.violations(7, page: 2)).thenAnswer(
        (_) async => const Paginated(
          items: [Violation(id: 2, kategori: 'Halaman2', poin: 2)],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      );
      await t.pumpWidget(app(const PelanggaranPage(), repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Muat lebih banyak'));
      await t.pumpAndSettle();
      expect(find.text('Halaman2'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsNothing);
    });

    testWidgets('error', (t) async {
      when(() => repo.violations(7, page: 1))
          .thenThrow(const ApiException(message: 'Gagal muat'));
      await t.pumpWidget(app(const PelanggaranPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Gagal muat'), findsOneWidget);
    });
  });

  group('KesehatanPage', () {
    testWidgets('data', (t) async {
      when(() => repo.health(7, page: 1)).thenAnswer(
        (_) async => page([
          HealthRecord(
            id: 1,
            keluhan: 'Demam',
            perluDirujuk: true,
            tanggal: DateTime(2026, 10, 1),
          ),
        ]),
      );
      await t.pumpWidget(app(const KesehatanPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Keluhan: Demam'), findsOneWidget);
      expect(find.text('Dirujuk'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.health(7, page: 1))
          .thenAnswer((_) async => page(<HealthRecord>[]));
      await t.pumpWidget(app(const KesehatanPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Belum ada riwayat kesehatan.'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      when(() => repo.health(7, page: 1))
          .thenThrow(const ApiException(message: 'Gagal muat'));
      await t.pumpWidget(app(const KesehatanPage(), repo));
      await t.pumpAndSettle();
      expect(find.text('Gagal muat'), findsOneWidget);
    });
  });
}
