import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// Dari `SantriResource` backend (NIK/NISN sudah dimasking server).
class Child {
  const Child({
    required this.id,
    required this.nama,
    this.nis,
    this.panggilan,
    this.kelas,
    this.asrama,
    this.status,
  });

  factory Child.fromJson(Map<String, dynamic> j) => Child(
    id: (j['id'] as num).toInt(),
    nama: j['nama_lengkap'] as String? ?? '',
    nis: j['nis'] as String?,
    panggilan: j['nama_panggilan'] as String?,
    kelas: (j['kelas'] as Map<String, dynamic>?)?['nama'] as String?,
    asrama: (j['asrama'] as Map<String, dynamic>?)?['nama'] as String?,
    status: j['status'] as String?,
  );

  final int id;
  final String nama;
  final String? nis;
  final String? panggilan;
  final String? kelas;
  final String? asrama;
  final String? status;

  String get initials => nama
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

final childrenProvider = FutureProvider<List<Child>>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.value?.id));
  final res = await ref
      .watch(dioProvider)
      .get<Map<String, dynamic>>(
        '/children',
        queryParameters: {'per_page': 50},
      );
  return Paginated.fromEnvelope(res.data!, Child.fromJson).items;
});

/// Anak yang sedang dipilih (multi-anak switcher).
final selectedChildIdProvider = NotifierProvider<SelectedChildNotifier, int?>(
  SelectedChildNotifier.new,
);

class SelectedChildNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) => state = id;
}

final selectedChildProvider = Provider<Child?>((ref) {
  final children = ref.watch(childrenProvider).value ?? const [];
  if (children.isEmpty) return null;
  final id = ref.watch(selectedChildIdProvider);
  return children.firstWhere((c) => c.id == id, orElse: () => children.first);
});
