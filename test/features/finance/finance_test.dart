import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/features/finance/keuangan_page.dart';
import 'package:santri360/features/finance/tabungan.dart';

class _MockDio extends Mock implements Dio {}

class _MockRepo extends Mock implements FinanceRepository {}

Widget _wrap(_MockRepo repo) => ProviderScope(
  overrides: [financeRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: KeuanganPage()),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('model + repo', () {
    test('formatRupiah', () {
      expect(formatRupiah(1500000).replaceAll(' ', ' '), 'Rp 1.500.000');
    });

    test(
      'repo memetakan data + saldo_total (nominal string diterima)',
      () async {
        final dio = _MockDio();
        when(
          () => dio.get<Map<String, dynamic>>(
            '/keuangan/portal-wali/tabungan',
            queryParameters: {'santri_id': 7},
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'data': [
                {
                  'id': 1,
                  'santri_id': 7,
                  'saldo': '250000.00',
                  'mutasi_terakhir': [
                    {
                      'id': 9,
                      'jenis_mutasi': 'debit',
                      'nominal': 10000,
                      'tanggal_mutasi': '2026-10-01T08:00:00Z',
                    },
                  ],
                },
              ],
              'meta': {'saldo_total': 250000},
            },
          ),
        );
        final r = await FinanceRepository(dio).tabungan(santriId: 7);
        expect(r.items.single.saldo, 250000);
        expect(r.items.single.mutasi.single.keluar, isTrue);
        expect(r.saldoTotal, 250000);
      },
    );
  });

  group('halaman', () {
    testWidgets('tab Tabungan menampilkan saldo & mutasi', (t) async {
      final repo = _MockRepo();
      when(() => repo.tabungan(santriId: any(named: 'santriId'))).thenAnswer(
        (_) async => TabunganResult(
          saldoTotal: 250000,
          items: [
            Tabungan(
              id: 1,
              santriId: 7,
              saldo: 250000,
              mutasi: [
                MutasiTabungan(
                  id: 1,
                  jenis: 'kredit',
                  nominal: 50000,
                  keterangan: 'Setoran',
                  tanggal: DateTime(2026, 10, 1),
                ),
              ],
            ),
          ],
        ),
      );
      await t.pumpWidget(_wrap(repo));
      await t.pumpAndSettle();
      expect(find.textContaining('250.000'), findsOneWidget);
      expect(find.text('Setoran'), findsOneWidget);
    });

    testWidgets('tab Tabungan kosong', (t) async {
      final repo = _MockRepo();
      when(
        () => repo.tabungan(santriId: any(named: 'santriId')),
      ).thenAnswer((_) async => const TabunganResult(items: [], saldoTotal: 0));
      await t.pumpWidget(_wrap(repo));
      await t.pumpAndSettle();
      expect(find.text('Belum ada data tabungan.'), findsOneWidget);
    });

    testWidgets('tab Tabungan error 403', (t) async {
      final repo = _MockRepo();
      when(() => repo.tabungan(santriId: any(named: 'santriId'))).thenThrow(
        const ApiException(message: 'x', code: 'MODULE_NOT_ENTITLED'),
      );
      await t.pumpWidget(_wrap(repo));
      await t.pumpAndSettle();
      expect(find.textContaining('belum aktif'), findsOneWidget);
    });

    testWidgets('tab lain placeholder Segera hadir', (t) async {
      final repo = _MockRepo();
      when(
        () => repo.tabungan(santriId: any(named: 'santriId')),
      ).thenAnswer((_) async => const TabunganResult(items: [], saldoTotal: 0));
      await t.pumpWidget(_wrap(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Tagihan'));
      await t.pumpAndSettle();
      expect(find.text('Segera hadir'), findsWidgets);
    });
  });
}
