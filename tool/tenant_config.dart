import 'dart:convert';
import 'dart:io';

/// Kunci wajib di `tenants/<slug>/config.json`.
const requiredKeys = [
  'TENANT_CODE',
  'APP_NAME',
  'APP_ID',
  'API_BASE_URL',
  'PRIMARY_COLOR',
  'SENTRY_DSN',
];

final _slug = RegExp(r'^[a-z][a-z0-9_]*$');
final _code = RegExp(r'^[A-Z0-9_-]{2,32}$');
// Reverse-domain, tiap segmen huruf kecil diawali huruf (aman untuk Android & iOS).
final _appId = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$');
final _color = RegExp(r'^0x[0-9A-Fa-f]{8}$');

class Tenant {
  Tenant(this.slug, this.config);

  final String slug;
  final Map<String, String> config;

  String get appId => config['APP_ID']!;
  String get appName => config['APP_NAME']!;
  String get code => config['TENANT_CODE']!;
}

/// Validasi satu config; kembalikan daftar error (kosong = valid).
List<String> validateConfig(String slug, Map<String, dynamic> json) {
  final errors = <String>[];
  for (final k in requiredKeys) {
    if (json[k] is! String) errors.add('$k wajib (string)');
  }
  for (final k in json.keys) {
    if (!requiredKeys.contains(k)) errors.add('kunci tak dikenal: $k');
  }
  if (errors.isNotEmpty) return errors;

  if (!_slug.hasMatch(slug)) errors.add('slug "$slug" harus [a-z0-9_]');
  final appName = (json['APP_NAME'] as String).trim();
  final url = Uri.tryParse(json['API_BASE_URL'] as String);
  if (!_code.hasMatch(json['TENANT_CODE'] as String)) {
    errors.add('TENANT_CODE harus [A-Z0-9_-]{2,32}');
  }
  if (appName.isEmpty || appName.length > 30) {
    errors.add('APP_NAME 1–30 karakter (batas label launcher)');
  }
  if (!_appId.hasMatch(json['APP_ID'] as String)) {
    errors.add(
      'APP_ID harus reverse-domain huruf kecil, mis. id.santri360.$slug',
    );
  }
  if (url == null || url.scheme != 'https' || url.host.isEmpty) {
    errors.add('API_BASE_URL wajib https://');
  }
  if (!_color.hasMatch(json['PRIMARY_COLOR'] as String)) {
    errors.add('PRIMARY_COLOR format 0xAARRGGBB');
  }
  return errors;
}

/// Muat & validasi semua tenant, termasuk keunikan APP_ID & TENANT_CODE.
List<Tenant> loadTenants(Directory root) {
  final dirs = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final tenants = <Tenant>[];
  final errors = <String>[];
  final seenIds = <String, String>{};
  final seenCodes = <String, String>{};

  for (final dir in dirs) {
    final slug = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final file = File('${dir.path}/config.json');
    if (!file.existsSync()) {
      errors.add('$slug: config.json tidak ada');
      continue;
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      errors.add('$slug: JSON tidak valid (${e.message})');
      continue;
    }
    final errs = validateConfig(slug, json);
    if (errs.isNotEmpty) {
      errors.addAll(errs.map((e) => '$slug: $e'));
      continue;
    }
    final t = Tenant(slug, json.cast<String, String>());
    final dupId = seenIds[t.appId];
    final dupCode = seenCodes[t.code];
    if (dupId != null) errors.add('$slug: APP_ID sama dengan $dupId');
    if (dupCode != null) errors.add('$slug: TENANT_CODE sama dengan $dupCode');
    seenIds[t.appId] = slug;
    seenCodes[t.code] = slug;
    tenants.add(t);
  }
  if (errors.isNotEmpty) throw TenantConfigException(errors);
  return tenants;
}

class TenantConfigException implements Exception {
  TenantConfigException(this.errors);
  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

/// Isi `ios/Flutter/Tenant.xcconfig` (di-include Debug/Release.xcconfig).
String iosXcconfig(Tenant t) =>
    '// GENERATED oleh tool/tenant.dart — jangan diedit.\n'
    'APP_BUNDLE_ID=${t.appId}\n'
    'APP_DISPLAY_NAME=${t.appName}\n';

/// Config flutter_launcher_icons untuk ikon tenant.
String launcherIconsYaml(Tenant t, {required bool adaptive}) {
  final dir = 'tenants/${t.slug}';
  return [
    'flutter_launcher_icons:',
    '  image_path: "$dir/icon.png"',
    '  android: true',
    '  ios: true',
    '  remove_alpha_ios: true',
    if (adaptive) ...[
      '  adaptive_icon_foreground: "$dir/icon_foreground.png"',
      '  adaptive_icon_background: "#FFFFFF"',
    ],
    '',
  ].join('\n');
}
