import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_config/bootstrap.dart';
import '../children/child.dart';
import '../contacts/whatsapp.dart';

/// Menu cepat beranda. `module` = kode modul entitlement; null = selalu tampil.
class QuickMenu {
  const QuickMenu(this.label, this.icon, this.route, {this.module});

  final String label;
  final IconData icon;
  final String route;
  final String? module;
}

const quickMenus = [
  QuickMenu('Nilai', Icons.grade, '/akademik/nilai', module: 'akademik'),
  QuickMenu('Rapor', Icons.description, '/akademik/rapor', module: 'akademik'),
  QuickMenu(
    'Hafalan',
    Icons.menu_book,
    '/akademik/tahfidz',
    module: 'akademik',
  ),
  QuickMenu('Izin', Icons.directions_walk, '/kesantrian/izin'),
  QuickMenu('Pelanggaran', Icons.gavel, '/kesantrian/pelanggaran'),
  QuickMenu('Kesehatan', Icons.healing, '/kesantrian/kesehatan'),
  QuickMenu(
    'Tabungan',
    Icons.savings,
    '/keuangan/tabungan',
    module: 'keuangan',
  ),
  QuickMenu('Pengumuman', Icons.campaign, '/pengumuman'),
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final selected = ref.watch(selectedChildProvider);
    final boot = ref.watch(bootstrapProvider).value;
    final menus = quickMenus
        .where((m) => m.module == null || boot == null || boot.has(m.module!))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          boot?.tenantName.isNotEmpty == true ? boot!.tenantName : 'Beranda',
        ),
        actions: [
          IconButton(
            tooltip: 'Hubungi Pengurus',
            icon: const Icon(Icons.support_agent),
            onPressed: () =>
                showContactSheet(context, ref, childName: selected?.nama),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(childrenProvider);
          ref.invalidate(bootstrapProvider);
          await ref.read(childrenProvider.future);
        },
        child: children.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            ],
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (list.isEmpty)
                const Text('Belum ada santri yang terhubung dengan akun Anda.')
              else ...[
                if (list.length > 1)
                  _ChildSwitcher(list: list, selected: selected),
                if (selected != null) _ChildCard(child: selected),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final m in menus)
                      InkWell(
                        onTap: () => context.push(m.route),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(m.icon, size: 32),
                            const SizedBox(height: 4),
                            Text(m.label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildSwitcher extends ConsumerWidget {
  const _ChildSwitcher({required this.list, required this.selected});

  final List<Child> list;
  final Child? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.panggilan ?? c.nama.split(' ').first),
                selected: c.id == selected?.id,
                onSelected: (_) =>
                    ref.read(selectedChildIdProvider.notifier).select(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(child.initials)),
        title: Text(child.nama),
        subtitle: Text(
          [
            if (child.nis != null) 'NIS ${child.nis}',
            if (child.kelas != null) child.kelas!,
            if (child.asrama != null) child.asrama!,
          ].join(' · '),
        ),
      ),
    );
  }
}
