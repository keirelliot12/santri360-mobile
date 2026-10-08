import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/providers.dart';

/// Dari schema `Announcement` (OpenAPI).
class Announcement {
  const Announcement({
    required this.id,
    required this.judul,
    required this.isi,
    this.kategori,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id: (j['id'] as num).toInt(),
    judul: j['judul'] as String? ?? '',
    isi: j['isi'] as String? ?? '',
    kategori: j['kategori'] as String?,
    tanggalMulai: DateTime.tryParse(j['tanggal_mulai'] as String? ?? ''),
    tanggalSelesai: DateTime.tryParse(j['tanggal_selesai'] as String? ?? ''),
  );

  final int id;
  final String judul;
  final String isi;
  final String? kategori;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;
}

class AnnouncementRepository {
  AnnouncementRepository(this._dio);

  final Dio _dio;

  Future<Paginated<Announcement>> list({int page = 1, int perPage = 15}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/announcements',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      return Paginated.fromEnvelope(res.data!, Announcement.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(ref.watch(dioProvider)),
);

class AnnouncementListState {
  const AnnouncementListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.moreError,
  });

  final List<Announcement> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? moreError;

  AnnouncementListState copyWith({bool? loadingMore, Object? moreError}) =>
      AnnouncementListState(
        items: items,
        page: page,
        hasMore: hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: moreError,
      );
}

/// Daftar pengumuman dengan infinite scroll.
class AnnouncementListNotifier extends AsyncNotifier<AnnouncementListState> {
  @override
  Future<AnnouncementListState> build() async {
    final p = await ref.watch(announcementRepositoryProvider).list();
    return AnnouncementListState(
      items: p.items,
      page: p.currentPage,
      hasMore: p.hasMore,
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await ref
          .read(announcementRepositoryProvider)
          .list(page: s.page + 1);
      state = AsyncData(
        AnnouncementListState(
          items: [...s.items, ...p.items],
          page: p.currentPage,
          hasMore: p.hasMore,
        ),
      );
    } catch (e) {
      state = AsyncData(s.copyWith(loadingMore: false, moreError: e));
    }
  }
}

final announcementListProvider =
    AsyncNotifierProvider<AnnouncementListNotifier, AnnouncementListState>(
      AnnouncementListNotifier.new,
    );
