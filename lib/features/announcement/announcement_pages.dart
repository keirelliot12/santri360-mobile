import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/async_views.dart';
import 'announcement.dart';

String formatTanggal(DateTime? d) =>
    d == null ? '' : DateFormat('d MMMM y', 'id_ID').format(d);

String _meta(Announcement a) => [
  if (a.kategori != null) a.kategori!,
  formatTanggal(a.tanggalMulai),
].where((e) => e.isNotEmpty).join(' · ');

class AnnouncementListPage extends ConsumerWidget {
  const AnnouncementListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(announcementListProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(announcementListProvider.future),
          child: s.items.isEmpty
              ? const EmptyView(
                  message: 'Belum ada pengumuman.',
                  icon: Icons.campaign,
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                      ref.read(announcementListProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: s.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i == s.items.length) return _Footer(state: s);
                      final a = s.items[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            a.judul,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _meta(a),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/pengumuman/${a.id}'),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});

  final AnnouncementListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.moreError != null) {
      return TextButton(
        onPressed: () => ref.read(announcementListProvider.notifier).loadMore(),
        child: const Text('Gagal memuat. Ketuk untuk coba lagi'),
      );
    }
    return const SizedBox(height: 8);
  }
}

class AnnouncementDetailPage extends ConsumerWidget {
  const AnnouncementDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API v1 tidak punya endpoint detail; cari di daftar yang sudah dimuat.
    final async = ref.watch(announcementListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(announcementListProvider),
        ),
        data: (s) {
          final a = s.items.where((e) => e.id == id).firstOrNull;
          if (a == null) {
            return const EmptyView(message: 'Pengumuman tidak ditemukan.');
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                a.judul,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(_meta(a), style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              SelectableText(
                a.isi,
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
              if (a.tanggalSelesai != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Berlaku sampai ${formatTanggal(a.tanggalSelesai)}',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
