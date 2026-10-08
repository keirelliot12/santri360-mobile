import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'academic_models.dart';
import 'academic_repository.dart';
import 'academic_widgets.dart';

/// Menyimpan byte PDF lalu membukanya di aplikasi PDF perangkat.
/// Di-override di tes. Pelempar error = pesan ramah ke pengguna.
typedef PdfOpener = Future<void> Function(List<int> bytes, String name);

final pdfOpenerProvider = Provider<PdfOpener>(
  (_) => (bytes, name) async {
    // Cache app (bukan storage publik); dibuka via FileProvider — aman Android 7+.
    final file = File('${(await getTemporaryDirectory()).path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    final r = await OpenFilex.open(file.path, type: 'application/pdf');
    if (r.type != ResultType.done) throw StateError(r.message);
  },
);

TextStyle? _big(BuildContext c) => Theme.of(c).textTheme.titleMedium;

// ---------------------------------------------------------------- Nilai

class NilaiView extends StatelessWidget {
  const NilaiView({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncChildBody<List<WaliScore>>(
      provider: scoresProvider.call,
      emptyText: 'Belum ada nilai yang masuk.',
      isEmpty: (d) => d.isEmpty,
      builder: (context, list) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = list[i];
          return Card(
            child: ExpansionTile(
              title: Text(s.namaMapel, style: _big(context)),
              trailing: Text(
                s.nilaiAkhir.toStringAsFixed(s.nilaiAkhir % 1 == 0 ? 0 : 1),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              children: [
                for (final k in s.komponen)
                  ListTile(
                    dense: false,
                    title: Text(k.komponen ?? 'Komponen'),
                    subtitle: Text('Bobot ${_pct(k.bobot)}'),
                    trailing: Text('${k.nilai}', style: _big(context)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Bobot di API bisa pecahan (0.3) atau persen (30).
  static String _pct(num b) => '${(b <= 1 ? b * 100 : b).round()}%';
}

class NilaiPage extends StatelessWidget {
  const NilaiPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nilai')),
    body: const NilaiView(),
  );
}

// ---------------------------------------------------------------- Rapor

class RaporView extends ConsumerWidget {
  const RaporView({super.key});

  Future<void> _unduh(BuildContext context, WidgetRef ref, Rapor r) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Mengunduh rapor...')));
    try {
      final bytes = await ref
          .read(academicRepositoryProvider)
          .downloadRapor(r.id);
      await ref.read(pdfOpenerProvider)(bytes, 'rapor-${r.id}.pdf');
      messenger.hideCurrentSnackBar();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? 'Rapor terunduh, tetapi tidak ada aplikasi untuk '
                        'membuka PDF di perangkat ini.'
                  : 'Gagal mengunduh rapor. ${friendlyError(e)}',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChildBody<List<Rapor>>(
      provider: raporProvider.call,
      emptyText: 'Belum ada rapor yang diterbitkan.',
      isEmpty: (d) => d.isEmpty,
      builder: (context, list) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = list[i];
          final judul = [
            if (r.tahunAjaran != null) r.tahunAjaran!,
            if (r.semester != null) 'Semester ${r.semester}',
          ].join(' · ');
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.description, size: 32),
              title: Text(
                judul.isEmpty ? 'Rapor' : judul,
                style: _big(context),
              ),
              subtitle: Text(
                [
                  if (r.nomor != null) 'No. ${r.nomor}',
                  if (shortDate(r.publishedAt) != null)
                    'Terbit ${shortDate(r.publishedAt)}',
                  if (r.catatan != null && r.catatan!.isNotEmpty) r.catatan!,
                ].join('\n'),
              ),
              trailing: r.bisaUnduh
                  ? IconButton(
                      tooltip: 'Unduh PDF',
                      icon: const Icon(Icons.download),
                      onPressed: () => _unduh(context, ref, r),
                    )
                  : const Text('PDF belum\ntersedia'),
            ),
          );
        },
      ),
    );
  }
}

class RaporPage extends StatelessWidget {
  const RaporPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rapor')),
    body: const RaporView(),
  );
}

// ---------------------------------------------------------------- Tahfidz

class TahfidzView extends StatelessWidget {
  const TahfidzView({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncChildBody<Tahfidz?>(
      provider: tahfidzProvider.call,
      emptyText: 'Belum ada setoran hafalan.',
      isEmpty: (d) => d == null || (d.totalSetoran == 0 && d.riwayat.isEmpty),
      builder: (context, t) {
        final juz = t!.perkiraanJuz;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progres Hafalan', style: _big(context)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: juz / 30,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Perkiraan ${juz.toStringAsFixed(1)} dari 30 juz',
                      style: _big(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.totalSetoran} kali setoran · ${t.totalBaris} baris',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Setoran Terakhir', style: _big(context)),
            const SizedBox(height: 8),
            if (t.riwayat.isEmpty) const Text('Belum ada riwayat setoran.'),
            for (final s in t.riwayat)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(s.rentang, style: _big(context)),
                  subtitle: Text(
                    [
                      if (shortDate(s.tanggal) != null) shortDate(s.tanggal)!,
                      if (s.jumlahBaris != null) '${s.jumlahBaris} baris',
                      if (s.kelancaran != null) 'Kelancaran: ${s.kelancaran}',
                      if (s.catatan != null && s.catatan!.isNotEmpty)
                        s.catatan!,
                    ].join(' · '),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TahfidzPage extends StatelessWidget {
  const TahfidzPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hafalan')),
    body: const TahfidzView(),
  );
}

// ---------------------------------------------------------------- Sertifikat

class SertifikatView extends StatelessWidget {
  const SertifikatView({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncChildBody<List<Sertifikat>>(
      provider: sertifikatProvider.call,
      emptyText: 'Belum ada sertifikat.',
      isEmpty: (d) => d.isEmpty,
      builder: (context, list) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = list[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.workspace_premium, size: 32),
              title: Text(
                [
                  s.jenis ?? 'Sertifikat',
                  if (s.juzKe != null) 'Juz ${s.juzKe}',
                ].join(' · '),
                style: _big(context),
              ),
              subtitle: Text(
                [
                  if (s.nomor != null) 'No. ${s.nomor}',
                  if (shortDate(s.issuedAt) != null) shortDate(s.issuedAt)!,
                ].join('\n'),
              ),
              trailing: s.verifyUrl == null
                  ? null
                  : IconButton(
                      tooltip: 'Verifikasi',
                      icon: const Icon(Icons.verified),
                      onPressed: () => launchUrl(
                        Uri.parse(s.verifyUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class SertifikatPage extends StatelessWidget {
  const SertifikatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sertifikat')),
    body: const SertifikatView(),
  );
}

// ---------------------------------------------------------------- Tab

class AkademikPage extends StatelessWidget {
  const AkademikPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Akademik'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Nilai'),
              Tab(text: 'Rapor'),
              Tab(text: 'Hafalan'),
              Tab(text: 'Sertifikat'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [NilaiView(), RaporView(), TahfidzView(), SertifikatView()],
        ),
      ),
    );
  }
}
