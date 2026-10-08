import 'package:go_router/go_router.dart';

import 'bukti_page.dart';
import 'keuangan_page.dart';
import 'tagihan_pages.dart';

/// Tab `/keuangan` ada di shell (app_router); ini rute mandiri dari menu cepat Beranda.
List<RouteBase> financeRoutes() => [
  // Menu beranda lama "Tabungan" → tab Uang Saku.
  GoRoute(
    path: '/keuangan/tabungan',
    builder: (_, _) => const KeuanganPage(initialTab: 1),
  ),
  GoRoute(path: '/keuangan/tagihan', builder: (_, _) => const KeuanganPage()),
  GoRoute(
    path: '/keuangan/tagihan/:id',
    builder: (_, s) => BillDetailPage(id: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/keuangan/tagihan/:id/bukti',
    builder: (_, s) => BuktiTransferPage(billId: s.pathParameters['id']!),
  ),
];
