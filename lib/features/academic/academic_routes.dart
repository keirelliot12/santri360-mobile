import 'package:go_router/go_router.dart';

import 'academic_pages.dart';

/// Rute detail akademik (dari menu beranda). Harus didaftarkan sebelum
/// catch-all `/:section/:feature`.
final academicRoutes = <GoRoute>[
  GoRoute(path: '/akademik/nilai', builder: (_, _) => const NilaiPage()),
  GoRoute(path: '/akademik/rapor', builder: (_, _) => const RaporPage()),
  GoRoute(path: '/akademik/tahfidz', builder: (_, _) => const TahfidzPage()),
  GoRoute(
    path: '/akademik/sertifikat',
    builder: (_, _) => const SertifikatPage(),
  ),
];
