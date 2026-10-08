import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import '../children/child.dart';
import 'finance_models.dart';

class FinanceRepository {
  FinanceRepository(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<WalletSummary> wallet(int santriId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$santriId/wallet',
    );
    return WalletSummary.fromJson(envelopeData(res.data));
  });

  /// [month] format `YYYY-MM`. `meta` berisi `month`, `total_masuk`, `total_keluar`.
  Future<Paginated<WalletTransaction>> walletTransactions(
    int santriId, {
    String? month,
    int page = 1,
    int perPage = 20,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$santriId/wallet/transactions',
      queryParameters: {'month': ?month, 'page': page, 'per_page': perPage},
    );
    return Paginated.fromEnvelope(res.data!, WalletTransaction.fromJson);
  });

  /// [status]: `unpaid` | `paid` | `all`. `meta.total_outstanding` ada di `meta`.
  Future<Paginated<Bill>> bills(
    int santriId, {
    String status = 'unpaid',
    int page = 1,
    int perPage = 15,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$santriId/bills',
      queryParameters: {'status': status, 'page': page, 'per_page': perPage},
    );
    return Paginated.fromEnvelope(res.data!, Bill.fromJson);
  });

  Future<BillDetail> bill(String id) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/bills/$id');
    return BillDetail.fromJson(envelopeData(res.data));
  });

  Future<Paginated<BillPayment>> payments(
    int santriId, {
    int page = 1,
    int perPage = 15,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$santriId/payments',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return Paginated.fromEnvelope(res.data!, BillPayment.fromJson);
  });

  /// Pakai [idempotencyKey] yang SAMA untuk retry form yang sama. FormData
  /// dibuat ulang tiap panggilan (hanya bisa dikirim sekali).
  Future<BillPayment> submitProof(
    String billId,
    ProofSubmission s, {
    required String idempotencyKey,
    ProgressCallback? onSendProgress,
  }) => _guard(() async {
    final name = s.proofPath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap({
      'amount': s.amount,
      'transferred_at': DateFormat('yyyy-MM-dd').format(s.transferredAt),
      'sender_name': s.senderName,
      if (_filled(s.senderBank)) 'sender_bank': s.senderBank,
      if (_filled(s.destinationAccountId))
        'destination_account_id': s.destinationAccountId,
      if (_filled(s.note)) 'note': s.note,
      'proof': await MultipartFile.fromFile(
        s.proofPath,
        filename: name,
        contentType: _mediaType(name),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/bills/$billId/payment-proofs',
      data: form,
      options: idempotent(idempotencyKey),
      onSendProgress: onSendProgress,
    );
    return BillPayment.fromJson(envelopeData(res.data));
  });
}

bool _filled(String? v) => v != null && v.trim().isNotEmpty;

DioMediaType? _mediaType(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => DioMediaType('image', 'jpeg'),
    'png' => DioMediaType('image', 'png'),
    'webp' => DioMediaType('image', 'webp'),
    'pdf' => DioMediaType('application', 'pdf'),
    _ => null,
  };
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(dioProvider)),
);

// ---- Paginasi generik (infinite scroll) ----

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreError,
    this.meta = const {},
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? moreError;
  final Map<String, dynamic> meta;
}

/// [P] = parameter permintaan (mis. id anak + filter); `null` bila belum ada anak.
abstract class PagedNotifier<T, P extends Object>
    extends AsyncNotifier<PagedState<T>> {
  /// [watch] true di `build` (reaktif), false saat `loadMore`.
  Future<P?> params({required bool watch});

  Future<Paginated<T>> fetch(P p, int page);

  @override
  Future<PagedState<T>> build() async {
    final p = await params(watch: true);
    if (p == null) return PagedState<T>();
    final r = await fetch(p, 1);
    return PagedState(
      items: r.items,
      page: r.currentPage,
      hasMore: r.hasMore,
      meta: r.meta,
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(
      PagedState(
        items: s.items,
        page: s.page,
        hasMore: s.hasMore,
        loadingMore: true,
        meta: s.meta,
      ),
    );
    try {
      final p = await params(watch: false);
      if (p == null) return;
      final r = await fetch(p, s.page + 1);
      state = AsyncData(
        PagedState(
          items: [...s.items, ...r.items],
          page: r.currentPage,
          hasMore: r.hasMore,
          meta: r.meta,
        ),
      );
    } catch (e) {
      state = AsyncData(
        PagedState(
          items: s.items,
          page: s.page,
          hasMore: s.hasMore,
          moreError: e,
          meta: s.meta,
        ),
      );
    }
  }
}

Future<int?> _childId(Ref ref, {required bool watch}) async {
  if (watch) await ref.watch(childrenProvider.future);
  final c = watch
      ? ref.watch(selectedChildProvider)
      : ref.read(selectedChildProvider);
  return c?.id;
}

// ---- Tagihan ----

/// `unpaid` | `paid` | `all`.
final billFilterProvider = NotifierProvider<BillFilterNotifier, String>(
  BillFilterNotifier.new,
);

class BillFilterNotifier extends Notifier<String> {
  @override
  String build() => 'unpaid';

  void set(String v) => state = v;
}

class BillsNotifier extends PagedNotifier<Bill, (int, String)> {
  @override
  Future<(int, String)?> params({required bool watch}) async {
    final id = await _childId(ref, watch: watch);
    if (id == null) return null;
    final f = watch
        ? ref.watch(billFilterProvider)
        : ref.read(billFilterProvider);
    return (id, f);
  }

  @override
  Future<Paginated<Bill>> fetch((int, String) p, int page) =>
      ref.read(financeRepositoryProvider).bills(p.$1, status: p.$2, page: page);
}

final billsProvider = AsyncNotifierProvider<BillsNotifier, PagedState<Bill>>(
  BillsNotifier.new,
);

final billDetailProvider = FutureProvider.family<BillDetail, String>(
  (ref, id) => ref.watch(financeRepositoryProvider).bill(id),
);

// ---- Riwayat bayar ----

class PaymentsNotifier extends PagedNotifier<BillPayment, int> {
  @override
  Future<int?> params({required bool watch}) => _childId(ref, watch: watch);

  @override
  Future<Paginated<BillPayment>> fetch(int p, int page) =>
      ref.read(financeRepositoryProvider).payments(p, page: page);
}

final paymentsProvider =
    AsyncNotifierProvider<PaymentsNotifier, PagedState<BillPayment>>(
      PaymentsNotifier.new,
    );

// ---- Uang saku ----

final walletProvider = FutureProvider<WalletSummary?>((ref) async {
  final id = await _childId(ref, watch: true);
  if (id == null) return null;
  return ref.watch(financeRepositoryProvider).wallet(id);
});

/// Awal bulan yang sedang dilihat (default: bulan berjalan).
final walletMonthProvider = NotifierProvider<WalletMonthNotifier, DateTime>(
  WalletMonthNotifier.new,
);

class WalletMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  bool get isCurrent {
    final n = DateTime.now();
    return state.year == n.year && state.month == n.month;
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  /// Tidak melewati bulan berjalan.
  void next() {
    if (!isCurrent) state = DateTime(state.year, state.month + 1);
  }
}

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

class WalletTxNotifier extends PagedNotifier<WalletTransaction, (int, String)> {
  @override
  Future<(int, String)?> params({required bool watch}) async {
    final id = await _childId(ref, watch: watch);
    if (id == null) return null;
    final m = watch
        ? ref.watch(walletMonthProvider)
        : ref.read(walletMonthProvider);
    return (id, monthKey(m));
  }

  @override
  Future<Paginated<WalletTransaction>> fetch((int, String) p, int page) => ref
      .read(financeRepositoryProvider)
      .walletTransactions(p.$1, month: p.$2, page: page);
}

final walletTxProvider =
    AsyncNotifierProvider<WalletTxNotifier, PagedState<WalletTransaction>>(
      WalletTxNotifier.new,
    );
