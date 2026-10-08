import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/async_views.dart';
import 'finance_models.dart';
import 'finance_repository.dart';
import 'finance_widgets.dart';

/// Kelompokkan mutasi (urut terbaru) per hari lokal.
List<(DateTime, List<WalletTransaction>)> groupByDay(
  List<WalletTransaction> items,
) {
  final out = <(DateTime, List<WalletTransaction>)>[];
  for (final t in items) {
    final d = DateTime(t.waktu.year, t.waktu.month, t.waktu.day);
    if (out.isNotEmpty && out.last.$1 == d) {
      out.last.$2.add(t);
    } else {
      out.add((d, [t]));
    }
  }
  return out;
}

Future<void> _refresh(WidgetRef ref) {
  ref
    ..invalidate(walletProvider)
    ..invalidate(walletTxProvider);
  return Future.wait([
    ref.read(walletProvider.future),
    ref.read(walletTxProvider.future),
  ]);
}

class UangSakuTab extends ConsumerWidget {
  const UangSakuTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return wallet.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => _refresh(ref)),
      data: (w) => w == null
          ? const EmptyView(
              message: 'Belum ada data anak.',
              icon: Icons.account_balance_wallet,
            )
          : RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                    ref.read(walletTxProvider.notifier).loadMore();
                  }
                  return false;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BalanceCard(w: w),
                    const _MonthPicker(),
                    ..._transactions(context, ref),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _transactions(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(walletTxProvider);
    return tx.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                friendlyError(e),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(walletTxProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ],
      data: (s) {
        final masuk = s.meta['total_masuk'] ?? 0;
        final keluar = s.meta['total_keluar'] ?? 0;
        return [
          _MonthSummary(masuk: masuk as num, keluar: keluar as num),
          if (s.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Belum ada mutasi bulan ini.',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          for (final (day, list) in groupByDay(s.items)) ...[
            _DayHeader(day: day, list: list),
            for (final t in list) _TxTile(t: t),
          ],
          PagedFooter(
            loading: s.loadingMore,
            error: s.moreError,
            onMore: () => ref.read(walletTxProvider.notifier).loadMore(),
          ),
        ];
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.w});

  final WalletSummary w;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo uang saku', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            formatRupiah(w.saldo),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          ),
          if (w.nomorVa != null)
            Text('No. VA: ${w.nomorVa}', style: const TextStyle(fontSize: 16)),
          const Divider(height: 24),
          const Text('Hari ini', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Masuk ${formatRupiah(w.masukHariIni)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Keluar ${formatRupiah(w.keluarHariIni)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(walletMonthProvider);
    final notifier = ref.read(walletMonthProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          iconSize: 32,
          icon: const Icon(Icons.chevron_left),
          onPressed: notifier.previous,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y', 'id_ID').format(month),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          iconSize: 32,
          icon: const Icon(Icons.chevron_right),
          onPressed: notifier.isCurrent ? null : notifier.next,
        ),
      ],
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.masuk, required this.keluar});

  final num masuk;
  final num keluar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Total masuk\n${formatRupiah(masuk)}',
            style: TextStyle(fontSize: 16, color: Colors.green.shade800),
          ),
        ),
        Expanded(
          child: Text(
            'Total keluar\n${formatRupiah(keluar)}',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 16, color: Colors.red.shade800),
          ),
        ),
      ],
    ),
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.list});

  final DateTime day;
  final List<WalletTransaction> list;

  @override
  Widget build(BuildContext context) {
    final keluar = list
        .where((t) => t.keluar)
        .fold<int>(0, (a, t) => a + t.nominal);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM y', 'id_ID').format(day),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (keluar > 0)
            Text(
              'Keluar ${formatRupiah(keluar)}',
              style: TextStyle(fontSize: 15, color: Colors.red.shade800),
            ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.t});

  final WalletTransaction t;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      t.keterangan ?? (t.keluar ? 'Pengeluaran' : 'Pemasukan'),
      style: const TextStyle(fontSize: 17),
    ),
    subtitle: Text(DateFormat('HH.mm', 'id_ID').format(t.waktu)),
    trailing: Text(
      '${t.keluar ? '-' : '+'}${formatRupiah(t.nominal)}',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: t.keluar ? Colors.red.shade700 : Colors.green.shade700,
      ),
    ),
  );
}
