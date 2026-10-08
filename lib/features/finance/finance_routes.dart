import 'package:go_router/go_router.dart';

import 'keuangan_page.dart';

/// Tab `/keuangan` ada di shell (app_router); ini rute mandiri dari menu cepat Beranda.
List<RouteBase> financeRoutes() => [
  GoRoute(path: '/keuangan/tabungan', builder: (_, _) => const KeuanganPage()),
];
