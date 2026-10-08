import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tenant_config.dart';

Map<String, dynamic> _cfg([Map<String, dynamic> override = const {}]) => {
  'TENANT_CODE': 'DEMO',
  'APP_NAME': 'Santri360 Demo',
  'APP_ID': 'id.santri360.demo',
  'API_BASE_URL': 'https://api.santri360.com',
  'PRIMARY_COLOR': '0xFF0F766E',
  'SENTRY_DSN': '',
  ...override,
};

void main() {
  group('validateConfig', () {
    test('config valid tanpa error', () {
      expect(validateConfig('demo', _cfg()), isEmpty);
    });

    test('kunci wajib hilang & kunci asing ditolak', () {
      final json = _cfg()
        ..remove('APP_ID')
        ..['EXTRA'] = 'x';
      expect(
        validateConfig('demo', json),
        containsAll(['APP_ID wajib (string)', 'kunci tak dikenal: EXTRA']),
      );
    });

    test('format nilai ditolak', () {
      final errors = validateConfig(
        'Demo-1',
        _cfg({
          'TENANT_CODE': 'demo kecil',
          'APP_NAME': '',
          'APP_ID': 'Id.Santri360',
          'API_BASE_URL': 'http://api.santri360.com',
          'PRIMARY_COLOR': '#0F766E',
        }),
      );
      expect(errors, hasLength(6));
    });
  });

  test('APP_NAME berisi // atau \$ ditolak (rusak di xcconfig)', () {
    for (final name in ['Ponpes A//B', r'Ponpes $(HOME)']) {
      expect(
        validateConfig('demo', _cfg({'APP_NAME': name})),
        contains('APP_NAME tidak boleh berisi "//" atau "\$"'),
      );
    }
  });

  group('loadTenants', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('tenants'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String slug, Map<String, dynamic> json) {
      Directory('${root.path}/$slug').createSync();
      File('${root.path}/$slug/config.json')
          .writeAsStringSync(jsonEncode(json));
    }

    test('memuat tenant terurut', () {
      write('beta', _cfg({'TENANT_CODE': 'BETA', 'APP_ID': 'id.s.beta'}));
      write('alfa', _cfg());
      expect(loadTenants(root).map((t) => t.slug), ['alfa', 'beta']);
    });

    test('APP_ID & TENANT_CODE harus unik antar tenant', () {
      write('alfa', _cfg());
      write('beta', _cfg());
      expect(
        () => loadTenants(root),
        throwsA(
          isA<TenantConfigException>().having(
            (e) => e.errors,
            'errors',
            hasLength(2),
          ),
        ),
      );
    });

    test('config.json hilang ditolak', () {
      Directory('${root.path}/kosong').createSync();
      expect(() => loadTenants(root), throwsA(isA<TenantConfigException>()));
    });

    test('tenant repo valid', () {
      expect(loadTenants(Directory('tenants')), isNotEmpty);
    });
  });

  test('xcconfig memuat bundle id & nama', () {
    final out = iosXcconfig(Tenant('demo', _cfg().cast<String, String>()));
    expect(out, contains('APP_BUNDLE_ID=id.santri360.demo'));
    expect(out, contains('APP_DISPLAY_NAME=Santri360 Demo'));
  });
}
