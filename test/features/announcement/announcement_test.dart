import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/core/network/api_response.dart';
import 'package:santri360/features/announcement/announcement.dart';
import 'package:santri360/features/announcement/announcement_pages.dart';

class _MockDio extends Mock implements Dio {}

class _MockRepo extends Mock implements AnnouncementRepository {}

Paginated<Announcement> _page(List<Announcement> items, {int last = 1}) =>
    Paginated(
      items: items,
      currentPage: 1,
      lastPage: last,
      total: items.length,
    );

const _a = Announcement(
  id: 1,
  judul: 'Libur Maulid',
  isi: 'Libur tanggal 12.',
  kategori: 'Umum',
);

Widget _wrap(_MockRepo repo, Widget child) => ProviderScope(
  overrides: [announcementRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('model + repo', () {
    test('fromJson membaca field & tanggal', () {
      final a = Announcement.fromJson({
        'id': 3,
        'judul': 'J',
        'isi': 'I',
        'kategori': null,
        'tanggal_mulai': '2026-10-01',
        'tanggal_selesai': null,
      });
      expect(a.tanggalMulai, DateTime(2026, 10, 1));
      expect(a.tanggalSelesai, isNull);
      expect(a.kategori, isNull);
    });

    test('list memanggil /announcements dan memetakan paginasi', () async {
      final dio = _MockDio();
      when(
        () => dio.get<Map<String, dynamic>>(
          '/announcements',
          queryParameters: {'page': 2, 'per_page': 15},
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'data': [
              {'id': 1, 'judul': 'A', 'isi': 'B'},
            ],
            'meta': {'current_page': 2, 'last_page': 3, 'total': 40},
          },
        ),
      );
      final p = await AnnouncementRepository(dio).list(page: 2);
      expect(p.items.single.judul, 'A');
      expect(p.hasMore, isTrue);
    });

    test('repo membungkus DioException jadi ApiException', () async {
      final dio = _MockDio();
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
      expect(
        AnnouncementRepository(dio).list(),
        throwsA(
          isA<ApiException>().having((e) => e.isNotEntitled, 'ent', true),
        ),
      );
    });
  });

  group('halaman', () {
    testWidgets('daftar menampilkan data', (t) async {
      final repo = _MockRepo();
      when(() => repo.list(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_a]));
      await t.pumpWidget(_wrap(repo, const AnnouncementListPage()));
      await t.pumpAndSettle();
      expect(find.text('Libur Maulid'), findsOneWidget);
    });

    testWidgets('daftar kosong', (t) async {
      final repo = _MockRepo();
      when(() => repo.list(page: any(named: 'page')))
          .thenAnswer((_) async => _page([]));
      await t.pumpWidget(_wrap(repo, const AnnouncementListPage()));
      await t.pumpAndSettle();
      expect(find.text('Belum ada pengumuman.'), findsOneWidget);
    });

    testWidgets('error 403 modul → pesan ramah', (t) async {
      final repo = _MockRepo();
      when(() => repo.list(page: any(named: 'page'))).thenThrow(
        const ApiException(message: 'x', code: 'MODULE_NOT_ENTITLED'),
      );
      await t.pumpWidget(_wrap(repo, const AnnouncementListPage()));
      await t.pumpAndSettle();
      expect(find.textContaining('belum aktif'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('detail menampilkan isi', (t) async {
      final repo = _MockRepo();
      when(() => repo.list(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_a]));
      await t.pumpWidget(_wrap(repo, const AnnouncementDetailPage(id: 1)));
      await t.pumpAndSettle();
      expect(find.text('Libur tanggal 12.'), findsOneWidget);
    });

    testWidgets('detail id tidak ada', (t) async {
      final repo = _MockRepo();
      when(() => repo.list(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_a]));
      await t.pumpWidget(_wrap(repo, const AnnouncementDetailPage(id: 99)));
      await t.pumpAndSettle();
      expect(find.text('Pengumuman tidak ditemukan.'), findsOneWidget);
    });
  });
}
