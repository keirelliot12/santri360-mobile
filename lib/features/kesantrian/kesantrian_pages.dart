import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config/bootstrap.dart';
import '../children/child.dart';
import '../contacts/whatsapp.dart';
import 'kesantrian_models.dart';
import 'kesantrian_providers.dart';
import 'kesantrian_widgets.dart';

const _big = TextStyle(fontSize: 17);
const _bold = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

Widget _line(String label, String? v) => v == null || v.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('$label: $v', style: _big),
      );

(String, Color) izinStatus(String s) => switch (s) {
  'pending' || 'menunggu' => ('Menunggu', Colors.orange.shade800),
  'disetujui' || 'approved' => ('Disetujui', Colors.green.shade700),
  'ditolak' || 'rejected' => ('Ditolak', Colors.red.shade700),
  'keluar' || 'checkout' => ('Sedang keluar', Colors.blue.shade700),
  'kembali' || 'selesai' => ('Sudah kembali', Colors.teal.shade700),
  _ => (s.isEmpty ? '-' : s, Colors.grey.shade700),
};

class IzinPage extends StatelessWidget {
  const IzinPage({super.key});

  @override
  Widget build(BuildContext context) => KesantrianListPage<Permission>(
    title: 'Izin',
    emptyText: 'Belum ada data izin.',
    providerFor: permissionsProvider.call,
    itemBuilder: (_, p) {
      final (label, color) = izinStatus(p.status);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.jenis ?? 'Izin', style: _bold)),
                  StatusChip(label, color),
                ],
              ),
              const SizedBox(height: 4),
              Text('${tgl(p.mulai)} - ${tgl(p.selesai)}', style: _big),
              _line('Alasan', p.alasan),
              if (p.kembaliAktual != null)
                _line('Kembali', tgl(p.kembaliAktual)),
              _line('Alasan ditolak', p.alasanPenolakan),
              _line('Catatan pengurus', p.catatan),
            ],
          ),
        ),
      );
    },
    footer: const _AjukanIzin(),
  );
}

class _AjukanIzin extends ConsumerWidget {
  const _AjukanIzin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Child? child = ref.watch(selectedChildProvider);
    final contacts = ref.watch(bootstrapProvider).value?.contacts ?? const [];
    if (contacts.isEmpty) return const SizedBox.shrink();
    final sec = contacts.where((c) => c.role == 'keamanan').firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        icon: const Icon(Icons.chat),
        label: const Text('Ajukan izin via WhatsApp'),
        onPressed: () => sec == null
            ? showContactSheet(context, ref, childName: child?.nama)
            : launchUrl(
                whatsappUri(
                  sec.whatsapp,
                  text:
                      'Assalamualaikum, saya wali dari ${child?.nama ?? ''}. '
                      'Saya ingin mengajukan izin.',
                ),
                mode: LaunchMode.externalApplication,
              ),
      ),
    );
  }
}

class PelanggaranPage extends StatelessWidget {
  const PelanggaranPage({super.key});

  @override
  Widget build(BuildContext context) => KesantrianListPage<Violation>(
    title: 'Pelanggaran',
    emptyText: 'Alhamdulillah, belum ada pelanggaran.',
    providerFor: violationsProvider.call,
    headerBuilder: (context, _, items) {
      final total = items.fold<int>(0, (a, v) => a + v.poin);
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text('Total poin pelanggaran', style: _bold),
              ),
              Text(
                '$total',
                key: const Key('total_poin'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    },
    itemBuilder: (_, v) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(v.kategori ?? 'Pelanggaran', style: _bold),
                ),
                StatusChip('${v.poin} poin', Colors.red.shade700),
              ],
            ),
            const SizedBox(height: 4),
            Text(tgl(v.tanggal), style: _big),
            _line('Keterangan', v.deskripsi),
            _line('Tindakan', v.tindakan),
          ],
        ),
      ),
    ),
  );
}

class KesehatanPage extends StatelessWidget {
  const KesehatanPage({super.key});

  @override
  Widget build(BuildContext context) => KesantrianListPage<HealthRecord>(
    title: 'Kesehatan',
    emptyText: 'Belum ada riwayat kesehatan.',
    providerFor: healthProvider.call,
    itemBuilder: (_, h) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tgl(h.tanggal), style: _bold)),
                if (h.perluDirujuk) StatusChip('Dirujuk', Colors.red.shade700),
              ],
            ),
            _line('Keluhan', h.keluhan),
            _line('Diagnosa', h.diagnosa),
            _line('Tindakan', h.tindakanMedis),
            _line('Obat', h.obat),
          ],
        ),
      ),
    ),
  );
}
