import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/async_views.dart';
import 'tabungan.dart';

/// Keuangan ber-tab. [initialTab]: 0 Tagihan, 1 Uang Saku, 2 Tabungan, 3 Riwayat.
class KeuanganPage extends ConsumerWidget {
  const KeuanganPage({super.key, this.initialTab = 2});

  final int initialTab;

  // TODO(security): aktifkan FLAG_SECURE (blok screenshot) untuk layar keuangan
  // saat plugin/MethodChannel disetujui; sengaja tanpa dependency baru di F1.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Keuangan'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tagihan'),
              Tab(text: 'Uang Saku'),
              Tab(text: 'Tabungan'),
              Tab(text: 'Riwayat Bayar'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Soon(), _Soon(), TabunganTab(), _Soon()],
        ),
      ),
    );
  }
}

class _Soon extends StatelessWidget {
  const _Soon();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Segera hadir', style: TextStyle(fontSize: 18)));
}

class TabunganTab extends ConsumerWidget {
  const TabunganTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tabunganProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(tabunganProvider)),
      data: (r) => RefreshIndicator(
        onRefresh: () => ref.refresh(tabunganProvider.future),
        child: r.items.isEmpty
            ? const EmptyView(
                message: 'Belum ada data tabungan.',
                icon: Icons.savings,
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  for (final t in r.items) _TabunganCard(t: t),
                  if (r.items.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Total saldo: ${formatRupiah(r.saldoTotal)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TabunganCard extends StatelessWidget {
  const _TabunganCard({required this.t});

  final Tabungan t;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saldo tabungan', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              formatRupiah(t.saldo),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (t.nomorVa != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No. VA: ${t.nomorVa}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const Divider(height: 24),
            const Text(
              'Mutasi terakhir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (t.mutasi.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Belum ada mutasi.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            for (final m in t.mutasi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  m.keterangan ?? m.jenis,
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: Text(
                  m.tanggal == null
                      ? ''
                      : DateFormat('d MMM y', 'id_ID').format(m.tanggal!),
                ),
                trailing: Text(
                  '${m.keluar ? '-' : '+'}${formatRupiah(m.nominal)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: m.keluar
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
