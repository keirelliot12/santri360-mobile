import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../children/child.dart';
import 'kesantrian_providers.dart';

String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.isNotEntitled) {
      return 'Fitur ini belum diaktifkan oleh pesantren Anda.';
    }
    return e.message;
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String tgl(DateTime? d) =>
    d == null ? '-' : '${d.day} ${_bulan[d.month - 1]} ${d.year}';

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}

/// Kerangka halaman daftar per santri terpilih: loading/kosong/error,
/// pull-to-refresh, dan "Muat lebih banyak".
class KesantrianListPage<T> extends ConsumerWidget {
  const KesantrianListPage({
    super.key,
    required this.title,
    required this.emptyText,
    required this.providerFor,
    required this.itemBuilder,
    this.headerBuilder,
    this.actions = const [],
    this.footer,
  });

  final String title;
  final String emptyText;
  final AsyncNotifierProvider<PagedNotifier<T>, PagedState<T>> Function(int)
  providerFor;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, Child, List<T>)? headerBuilder;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: child == null
          ? ListView(
              children: const [
                _Message('Pilih anak terlebih dahulu di Beranda.'),
              ],
            )
          : _body(context, ref, child),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Child child) {
    final provider = providerFor(child.id);
    final async = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(children: [_Message(friendlyError(e), retry: refresh)]),
      ),
      data: (s) => RefreshIndicator(
        onRefresh: refresh,
        child: s.items.isEmpty
            ? ListView(
                children: [
                  ?headerBuilder?.call(context, child, s.items),
                  _Message(emptyText),
                  ?footer,
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ?headerBuilder?.call(context, child, s.items),
                  for (final it in s.items) itemBuilder(context, it),
                  if (s.hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: s.loadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : OutlinedButton(
                              onPressed: () =>
                                  ref.read(provider.notifier).loadMore(),
                              child: const Text('Muat lebih banyak'),
                            ),
                    ),
                  ?footer,
                ],
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.retry});

  final String text;
  final Future<void> Function()? retry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        const SizedBox(height: 48),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        if (retry != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Coba lagi')),
        ],
      ],
    ),
  );
}
