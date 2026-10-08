import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../children/child.dart';

String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.isNotEntitled) {
      return 'Fitur ini belum aktif untuk pesantren Anda. '
          'Silakan hubungi pengurus pesantren.';
    }
    return e.message;
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}

/// Kerangka semua layar akademik: pilih anak -> loading / error / kosong / data,
/// plus tarik-untuk-muat-ulang. [isEmpty] menentukan tampilan kosong.
class AsyncChildBody<T> extends ConsumerWidget {
  const AsyncChildBody({
    super.key,
    required this.provider,
    required this.emptyText,
    required this.builder,
    this.isEmpty,
  });

  final FutureProvider<T> Function(int santriId) provider;
  final String emptyText;
  final bool Function(T data)? isEmpty;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final child = ref.watch(selectedChildProvider);
    if (child == null) {
      return children.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.error_outline,
          text: friendlyError(e),
          onRetry: () => ref.invalidate(childrenProvider),
        ),
        data: (_) => const _Message(
          icon: Icons.person_off,
          text: 'Belum ada santri yang terhubung dengan akun Anda.',
        ),
      );
    }
    final p = provider(child.id);
    final async = ref.watch(p);
    return Column(
      children: [
        if ((children.value?.length ?? 0) > 1)
          _ChildChips(list: children.value!, selectedId: child.id),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(p);
              try {
                await ref.read(p.future);
              } catch (_) {}
            },
            child: async.when(
              loading: () => ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (e, _) => _Message(
                icon: Icons.error_outline,
                text: friendlyError(e),
                onRetry: () => ref.invalidate(p),
              ),
              data: (d) => (isEmpty?.call(d) ?? false)
                  ? _Message(icon: Icons.inbox_outlined, text: emptyText)
                  : builder(context, d),
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChildChips extends ConsumerWidget {
  const _ChildChips({required this.list, required this.selectedId});

  final List<Child> list;
  final int selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.panggilan ?? c.nama.split(' ').first),
                selected: c.id == selectedId,
                onSelected: (_) =>
                    ref.read(selectedChildIdProvider.notifier).select(c.id),
              ),
            ),
        ],
      ),
    );
  }
}
