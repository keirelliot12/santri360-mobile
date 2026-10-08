import 'package:go_router/go_router.dart';

import 'announcement_pages.dart';

List<RouteBase> announcementRoutes() => [
  GoRoute(
    path: '/pengumuman',
    builder: (_, _) => const AnnouncementListPage(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (_, s) => AnnouncementDetailPage(
          id: int.tryParse(s.pathParameters['id']!) ?? 0,
        ),
      ),
    ],
  ),
];
