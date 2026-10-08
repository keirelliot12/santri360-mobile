import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/features/academic/academic_models.dart';
import 'package:santri360/features/academic/academic_pages.dart';
import 'package:santri360/features/academic/academic_repository.dart';
import 'package:santri360/features/children/child.dart';

class MockRepo extends Mock implements AcademicRepository {}

Future<void> _pump(
  WidgetTester t,
  MockRepo repo,
  Widget page, {
  PdfOpener? opener,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        academicRepositoryProvider.overrideWithValue(repo),
        childrenProvider.overrideWith(
          (_) async => [const Child(id: 1, nama: 'Ahmad')],
        ),
        if (opener != null) pdfOpenerProvider.overrideWithValue(opener),
      ],
      child: MaterialApp(home: Scaffold(body: page)),
    ),
  );
}

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  Future<void> loadingThenSettle(WidgetTester t, Completer<void> c) async {
    await t.pump();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    c.complete();
    await t.pumpAndSettle();
  }

  group('Nilai', () {
    testWidgets('loading -> data', (t) async {
      final c = Completer<void>();
      when(() => repo.scores(1)).thenAnswer((_) async {
        await c.future;
        return [
          const WaliScore(
            santriId: 1,
            mapelId: 1,
            namaMapel: 'Fiqih',
            nilaiAkhir: 88,
          ),
        ];
      });
      await _pump(t, repo, const NilaiView());
      await loadingThenSettle(t, c);
      expect(find.text('Fiqih'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.scores(1)).thenAnswer((_) async => []);
      await _pump(t, repo, const NilaiView());
      await t.pumpAndSettle();
      expect(find.text('Belum ada nilai yang masuk.'), findsOneWidget);
    });

    testWidgets('error 403 ramah', (t) async {
      when(() => repo.scores(1)).thenThrow(
        const ApiException(
          message: 'x',
          statusCode: 403,
          code: 'MODULE_NOT_ENTITLED',
        ),
      );
      await _pump(t, repo, const NilaiView());
      await t.pumpAndSettle();
      expect(find.textContaining('belum aktif'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('Rapor', () {
    const rapor = Rapor(
      id: 5,
      tahunAjaran: '2025/2026',
      semester: 'ganjil',
      bisaUnduh: true,
    );

    testWidgets('loading -> data, unduh membuka PDF', (t) async {
      final c = Completer<void>();
      when(() => repo.rapor(1)).thenAnswer((_) async {
        await c.future;
        return [rapor];
      });
      when(() => repo.downloadRapor(5)).thenAnswer((_) async => [1, 2]);
      String? opened;
      await _pump(
        t,
        repo,
        const RaporView(),
        opener: (b, n) async => opened = n,
      );
      await loadingThenSettle(t, c);
      expect(find.textContaining('2025/2026'), findsOneWidget);
      await t.tap(find.byIcon(Icons.download));
      await t.pumpAndSettle();
      expect(opened, 'rapor-5.pdf');
    });

    testWidgets('kosong', (t) async {
      when(() => repo.rapor(1)).thenAnswer((_) async => []);
      await _pump(t, repo, const RaporView());
      await t.pumpAndSettle();
      expect(find.text('Belum ada rapor yang diterbitkan.'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      when(() => repo.rapor(1))
          .thenThrow(const ApiException(message: 'Gagal muat'));
      await _pump(t, repo, const RaporView());
      await t.pumpAndSettle();
      expect(find.text('Gagal muat'), findsOneWidget);
    });
  });

  group('Tahfidz', () {
    testWidgets('loading -> data', (t) async {
      final c = Completer<void>();
      when(() => repo.tahfidz(1)).thenAnswer((_) async {
        await c.future;
        return const Tahfidz(
          santriId: 1,
          nama: 'A',
          totalSetoran: 3,
          totalBaris: 300,
          riwayat: [Setoran(id: 1, dariSurah: 'An-Naba', dariAyat: 1)],
        );
      });
      await _pump(t, repo, const TahfidzView());
      await loadingThenSettle(t, c);
      expect(find.textContaining('dari 30 juz'), findsOneWidget);
      expect(find.text('An-Naba 1'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.tahfidz(1)).thenAnswer((_) async => null);
      await _pump(t, repo, const TahfidzView());
      await t.pumpAndSettle();
      expect(find.text('Belum ada setoran hafalan.'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      when(() => repo.tahfidz(1))
          .thenThrow(const ApiException(message: 'Rusak'));
      await _pump(t, repo, const TahfidzView());
      await t.pumpAndSettle();
      expect(find.text('Rusak'), findsOneWidget);
    });
  });

  group('Sertifikat', () {
    testWidgets('loading -> data', (t) async {
      final c = Completer<void>();
      when(() => repo.sertifikat(1)).thenAnswer((_) async {
        await c.future;
        return [
          const Sertifikat(id: 1, nomor: 'SRT-1', jenis: 'Tahfidz', juzKe: 30),
        ];
      });
      await _pump(t, repo, const SertifikatView());
      await loadingThenSettle(t, c);
      expect(find.text('Tahfidz · Juz 30'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      when(() => repo.sertifikat(1)).thenAnswer((_) async => []);
      await _pump(t, repo, const SertifikatView());
      await t.pumpAndSettle();
      expect(find.text('Belum ada sertifikat.'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      when(() => repo.sertifikat(1))
          .thenThrow(const ApiException(message: 'Offline'));
      await _pump(t, repo, const SertifikatView());
      await t.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  testWidgets('AkademikPage punya 4 tab', (t) async {
    when(() => repo.scores(1)).thenAnswer((_) async => []);
    await _pump(t, repo, const AkademikPage());
    await t.pumpAndSettle();
    for (final l in ['Nilai', 'Rapor', 'Hafalan', 'Sertifikat']) {
      expect(find.text(l), findsWidgets);
    }
  });
}
