import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async_views.dart';
import 'finance_repository.dart';

/// Chip status pembayaran: pending / confirmed / rejected.
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'confirmed' => ('Diterima', Colors.green.shade800),
      'rejected' => ('Ditolak', Colors.red.shade800),
      _ => ('Menunggu verifikasi', Colors.orange.shade900),
    };
    return StatusBadge(label: label, color: color);
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

/// Footer infinite scroll: spinner / tombol ulang bila gagal memuat.
class PagedFooter extends StatelessWidget {
  const PagedFooter({
    super.key,
    required this.loading,
    this.error,
    this.onMore,
  });

  final bool loading;
  final Object? error;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return TextButton(
        onPressed: onMore,
        child: const Text('Gagal memuat. Ketuk untuk coba lagi'),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// Daftar berpaginasi + pull-to-refresh + loading/kosong/error.
/// [header] tampil di atas item (mis. kartu total) dan hanya bila ada data.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.async,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox,
    this.header,
  });

  final AsyncValue<PagedState<T>> async;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget Function(PagedState<T>)? header;

  @override
  Widget build(BuildContext context) => async.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => ErrorView(error: e, onRetry: () => onRefresh()),
    data: (s) => RefreshIndicator(
      onRefresh: onRefresh,
      child: s.items.isEmpty
          ? EmptyView(message: emptyMessage, icon: emptyIcon)
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                  onLoadMore();
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ?header?.call(s),
                  for (final it in s.items) itemBuilder(context, it),
                  PagedFooter(
                    loading: s.loadingMore,
                    error: s.moreError,
                    onMore: onLoadMore,
                  ),
                ],
              ),
            ),
    ),
  );
}
