import 'package:go_router/go_router.dart';

import 'kesantrian_pages.dart';

/// Disisipkan di app_router sebelum catch-all `/:section/:feature`.
final kesantrianRoutes = <GoRoute>[
  GoRoute(path: '/kesantrian/izin', builder: (_, _) => const IzinPage()),
  GoRoute(
    path: '/kesantrian/pelanggaran',
    builder: (_, _) => const PelanggaranPage(),
  ),
  GoRoute(
    path: '/kesantrian/kesehatan',
    builder: (_, _) => const KesehatanPage(),
  ),
];
