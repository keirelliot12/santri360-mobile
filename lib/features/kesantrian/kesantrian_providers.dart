import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response.dart';
import 'kesantrian_models.dart';
import 'kesantrian_repository.dart';

/// Daftar bertahap (halaman 1..n) untuk satu santri.
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
}

typedef PageFetcher<T> = Future<Paginated<T>> Function(
  KesantrianRepository,
  int santriId,
  int page,
);

class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  PagedNotifier(this.santriId, this._fetch);

  final int santriId;
  final PageFetcher<T> _fetch;

  @override
  Future<PagedState<T>> build() async {
    final p = await _fetch(ref.read(kesantrianRepositoryProvider), santriId, 1);
    return PagedState(items: p.items, page: 1, hasMore: p.hasMore);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(
      PagedState(
        items: cur.items,
        page: cur.page,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final p = await _fetch(
        ref.read(kesantrianRepositoryProvider),
        santriId,
        cur.page + 1,
      );
      state = AsyncData(
        PagedState(
          items: [...cur.items, ...p.items],
          page: cur.page + 1,
          hasMore: p.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncData(
        PagedState(items: cur.items, page: cur.page, hasMore: true),
      );
    }
  }
}

final permissionsProvider =
    AsyncNotifierProvider.family<
      PagedNotifier<Permission>,
      PagedState<Permission>,
      int
    >((id) => PagedNotifier(id, (r, s, p) => r.permissions(s, page: p)));

final violationsProvider =
    AsyncNotifierProvider.family<
      PagedNotifier<Violation>,
      PagedState<Violation>,
      int
    >((id) => PagedNotifier(id, (r, s, p) => r.violations(s, page: p)));

final healthProvider =
    AsyncNotifierProvider.family<
      PagedNotifier<HealthRecord>,
      PagedState<HealthRecord>,
      int
    >((id) => PagedNotifier(id, (r, s, p) => r.health(s, page: p)));
