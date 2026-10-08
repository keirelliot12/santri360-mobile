import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'finance_models.dart';
import 'finance_repository.dart';
import 'finance_widgets.dart';
import 'tagihan_pages.dart';
import 'uang_saku_tab.dart';

/// Keuangan ber-tab. [initialTab]: 0 Tagihan, 1 Uang Saku, 2 Riwayat.
class KeuanganPage extends StatelessWidget {
  const KeuanganPage({super.key, this.initialTab = 0});

  final int initialTab;

  // TODO(security): aktifkan FLAG_SECURE (blok screenshot) untuk layar keuangan
  // saat plugin/MethodChannel disetujui; sengaja tanpa dependency baru di F1.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Keuangan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tagihan'),
              Tab(text: 'Uang Saku'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [TagihanTab(), UangSakuTab(), RiwayatTab()],
        ),
      ),
    );
  }
}

class RiwayatTab extends ConsumerWidget {
  const RiwayatTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PagedListView<BillPayment>(
        async: ref.watch(paymentsProvider),
        onRefresh: () {
          ref.invalidate(paymentsProvider);
          return ref.read(paymentsProvider.future);
        },
        onLoadMore: () => ref.read(paymentsProvider.notifier).loadMore(),
        emptyMessage: 'Belum ada riwayat pembayaran.',
        emptyIcon: Icons.history,
        itemBuilder: (context, p) => PaymentTile(
          payment: p,
          onTap: p.billId == null
              ? null
              : () => context.push('/keuangan/tagihan/${p.billId}'),
        ),
      );
}
