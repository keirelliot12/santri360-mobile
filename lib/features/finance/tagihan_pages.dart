import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/async_views.dart';
import 'finance_models.dart';
import 'finance_repository.dart';
import 'finance_widgets.dart';

const _bold18 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

Future<void> _refreshBills(WidgetRef ref) {
  ref.invalidate(billsProvider);
  return ref.read(billsProvider.future);
}

class TagihanTab extends ConsumerWidget {
  const TagihanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(billFilterProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'unpaid', label: Text('Belum lunas')),
              ButtonSegment(value: 'paid', label: Text('Lunas')),
              ButtonSegment(value: 'all', label: Text('Semua')),
            ],
            selected: {filter},
            onSelectionChanged: (v) =>
                ref.read(billFilterProvider.notifier).set(v.first),
          ),
        ),
        Expanded(
          child: PagedListView<Bill>(
            async: ref.watch(billsProvider),
            onRefresh: () => _refreshBills(ref),
            onLoadMore: () => ref.read(billsProvider.notifier).loadMore(),
            emptyMessage: switch (filter) {
              'unpaid' => 'Tidak ada tagihan yang belum lunas.',
              'paid' => 'Belum ada tagihan lunas.',
              _ => 'Belum ada tagihan.',
            },
            emptyIcon: Icons.receipt_long,
            header: (s) {
              final total = s.meta['total_outstanding'];
              if (total == null) return const SizedBox.shrink();
              return Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total sisa tagihan',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(total as num),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            itemBuilder: (context, b) => _BillCard(bill: b),
          ),
        ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final lunas = bill.outstandingAmount <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/keuangan/tagihan/${bill.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bill.title, style: _bold18),
              const SizedBox(height: 6),
              Text(
                lunas
                    ? 'Lunas · ${formatRupiah(bill.totalAmount)}'
                    : 'Sisa ${formatRupiah(bill.outstandingAmount)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: lunas ? Colors.green.shade800 : null,
                ),
              ),
              if (bill.dueAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Jatuh tempo ${formatTanggal(bill.dueAt)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              if (bill.isOverdue || bill.pendingPayments > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (bill.isOverdue)
                        StatusBadge(
                          label: 'Terlambat',
                          color: Colors.red.shade800,
                        ),
                      if (bill.pendingPayments > 0)
                        StatusBadge(
                          label: 'Menunggu verifikasi',
                          color: Colors.orange.shade900,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(billDetailProvider(id));
    Future<void> refresh() {
      ref.invalidate(billDetailProvider(id));
      return ref.read(billDetailProvider(id).future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Tagihan')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: refresh),
        data: (b) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                b.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No. ${b.invoiceNumber}',
                style: const TextStyle(fontSize: 16),
              ),
              if (b.dueAt != null)
                Text(
                  'Jatuh tempo ${formatTanggal(b.dueAt)}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (b.isOverdue || b.pendingPayments > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (b.isOverdue)
                        StatusBadge(
                          label: 'Terlambat',
                          color: Colors.red.shade800,
                        ),
                      if (b.pendingPayments > 0)
                        StatusBadge(
                          label: 'Menunggu verifikasi',
                          color: Colors.orange.shade900,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (b.lines.isNotEmpty) ...[
                const Text('Rincian', style: _bold18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final l in b.lines)
                          _AmountRow(l.description, formatRupiah(l.amount)),
                      ],
                    ),
                  ),
                ),
              ],
              const Text('Ringkasan', style: _bold18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _AmountRow('Total', formatRupiah(b.totalAmount)),
                      _AmountRow('Sudah dibayar', formatRupiah(b.paidAmount)),
                      const Divider(),
                      _AmountRow(
                        'Sisa',
                        formatRupiah(b.outstandingAmount),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Riwayat pembayaran', style: _bold18),
              if (b.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Belum ada pembayaran.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              for (final p in b.payments) PaymentTile(payment: p),
              if (b.outstandingAmount > 0) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Kirim Bukti Transfer'),
                  onPressed: () async {
                    await context.push('/keuangan/tagihan/$id/bukti');
                    // Refresh detail + daftar setelah kembali dari form bukti.
                    ref
                      ..invalidate(billDetailProvider(id))
                      ..invalidate(billsProvider)
                      ..invalidate(paymentsProvider);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 17,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Satu pembayaran: nominal, tanggal, chip status, alasan bila ditolak.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, this.onTap});

  final BillPayment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final reason = p.rejectionReason;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(formatRupiah(p.amount), style: _bold18)),
                  PaymentStatusChip(status: p.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (p.invoiceNumber != null) p.invoiceNumber!,
                  formatTanggal(p.paidAt ?? p.submittedAt),
                ].where((e) => e.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 15),
              ),
              if (p.status == 'rejected' && reason != null && reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Alasan: $reason',
                    style: TextStyle(fontSize: 16, color: Colors.red.shade800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
