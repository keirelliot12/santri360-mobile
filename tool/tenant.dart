// CLI white-label per pesantren.
//
//   dart run tool/tenant.dart validate          # cek semua tenants/*/config.json
//   dart run tool/tenant.dart list --json       # slug tenant (untuk matrix CI)
//   dart run tool/tenant.dart apply <slug>      # siapkan native iOS + ikon tenant
//
// Android tidak butuh `apply`: applicationId & label dibaca Gradle langsung
// dari --dart-define-from-file. `apply` wajib sebelum build iOS dan untuk ikon.
import 'dart:convert';
import 'dart:io';

import 'tenant_config.dart';

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? '' : args.first;
  final List<Tenant> tenants;
  try {
    tenants = loadTenants(Directory('tenants'));
  } on TenantConfigException catch (e) {
    stderr.writeln('Config tenant tidak valid:\n$e');
    exit(1);
  }

  switch (cmd) {
    case 'validate':
      stdout.writeln('OK: ${tenants.length} tenant valid.');
    case 'list':
      final slugs = tenants.map((t) => t.slug).toList();
      stdout.writeln(
        args.contains('--json') ? jsonEncode(slugs) : slugs.join('\n'),
      );
    case 'apply' when args.length == 2:
      final t = tenants.where((t) => t.slug == args[1]).firstOrNull;
      if (t == null) {
        stderr.writeln('Tenant "${args[1]}" tidak ditemukan.');
        exit(1);
      }
      await _apply(t);
    default:
      stderr.writeln('Pakai: validate | list [--json] | apply <slug>');
      exit(64);
  }
}

Future<void> _apply(Tenant t) async {
  File('ios/Flutter/Tenant.xcconfig').writeAsStringSync(iosXcconfig(t));
  stdout.writeln('iOS: ${t.appId} "${t.appName}"');

  final dir = 'tenants/${t.slug}';
  if (!File('$dir/icon.png').existsSync()) {
    stdout.writeln('Ikon: $dir/icon.png tidak ada, pakai ikon bawaan.');
    return;
  }
  final adaptive = File('$dir/icon_foreground.png').existsSync();
  final cfg = File('${Directory.systemTemp.path}/launcher_icons_${t.slug}.yaml')
    ..writeAsStringSync(launcherIconsYaml(t, adaptive: adaptive));
  final r = await Process.start(
    'dart',
    ['run', 'flutter_launcher_icons', '-f', cfg.path],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await r.exitCode != 0) exit(1);
}
