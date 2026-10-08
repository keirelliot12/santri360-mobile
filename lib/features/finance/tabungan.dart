import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../children/child.dart';

String formatRupiah(num v) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(v);

num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

class MutasiTabungan {
  const MutasiTabungan({
    required this.id,
    required this.jenis,
    required this.nominal,
    this.keterangan,
    this.tanggal,
  });

  factory MutasiTabungan.fromJson(Map<String, dynamic> j) => MutasiTabungan(
    id: (j['id'] as num).toInt(),
    jenis: j['jenis_mutasi'] as String? ?? '',
    nominal: _num(j['nominal']),
    keterangan: j['keterangan'] as String?,
    tanggal: DateTime.tryParse(j['tanggal_mutasi'] as String? ?? ''),
  );

  final int id;
  final String jenis;
  final num nominal;
  final String? keterangan;
  final DateTime? tanggal;

  /// Enum `jenis_mutasi` belum terverifikasi (TODO verify di spec); heuristik.
  bool get keluar {
    final j = jenis.toLowerCase();
    return j.contains('debit') || j.contains('keluar') || j.contains('tarik');
  }
}

class Tabungan {
  const Tabungan({
    required this.id,
    required this.santriId,
    required this.saldo,
    this.nomorVa,
    this.status,
    this.mutasi = const [],
  });

  factory Tabungan.fromJson(Map<String, dynamic> j) => Tabungan(
    id: (j['id'] as num).toInt(),
    santriId: (j['santri_id'] as num).toInt(),
    saldo: _num(j['saldo']),
    nomorVa: j['nomor_va'] as String?,
    status: j['status'] as String?,
    mutasi: ((j['mutasi_terakhir'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MutasiTabungan.fromJson)
        .toList(),
  );

  final int id;
  final int santriId;
  final num saldo;
  final String? nomorVa;
  final String? status;
  final List<MutasiTabungan> mutasi;
}

class TabunganResult {
  const TabunganResult({required this.items, required this.saldoTotal});

  final List<Tabungan> items;
  final num saldoTotal;
}

class FinanceRepository {
  FinanceRepository(this._dio);

  final Dio _dio;

  Future<TabunganResult> tabungan({int? santriId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/keuangan/portal-wali/tabungan',
        queryParameters: {'santri_id': ?santriId},
      );
      final body = res.data!;
      final items = ((body['data'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Tabungan.fromJson)
          .toList();
      final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
      return TabunganResult(
        items: items,
        saldoTotal: meta['saldo_total'] == null
            ? items.fold<num>(0, (a, b) => a + b.saldo)
            : _num(meta['saldo_total']),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(dioProvider)),
);

final tabunganProvider = FutureProvider<TabunganResult>((ref) async {
  final child = ref.watch(selectedChildProvider);
  return ref.watch(financeRepositoryProvider).tabungan(santriId: child?.id);
});
