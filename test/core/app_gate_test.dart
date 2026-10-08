import 'package:flutter_test/flutter_test.dart';
import 'package:santri360/features/app_config/app_gate.dart';
import 'package:santri360/shared/version.dart';

void main() {
  group('compareVersions', () {
    test('urutan semver', () {
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0+12', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });
  });

  group('AppGate.evaluate', () {
    const base = {
      'min_supported_version': '1.2.0',
      'latest_version': '1.5.0',
      'maintenance': false,
      'store_url_android': 'https://play.google.com/x',
      'store_url_ios': 'https://apps.apple.com/x',
    };

    test('maintenance menang atas semua', () {
      final g = AppGate.evaluate(
        app: {...base, 'maintenance': true, 'maintenance_message': 'Libur'},
        currentVersion: '9.0.0',
        isIos: false,
      );
      expect(g.status, GateStatus.maintenance);
      expect(g.message, 'Libur');
      expect(g.blocking, isTrue);
    });

    test(
      'di bawah minimum → wajib update dengan URL store sesuai platform',
      () {
        final g = AppGate.evaluate(
          app: base,
          currentVersion: '1.1.9',
          isIos: true,
        );
        expect(g.status, GateStatus.updateRequired);
        expect(g.storeUrl, 'https://apps.apple.com/x');
      },
    );

    test('di bawah latest → update opsional (tidak blok)', () {
      final g = AppGate.evaluate(
        app: base,
        currentVersion: '1.3.0',
        isIos: false,
      );
      expect(g.status, GateStatus.updateAvailable);
      expect(g.blocking, isFalse);
    });

    test('nilai null dari backend → ok', () {
      final g = AppGate.evaluate(
        app: const {'maintenance': false},
        currentVersion: '1.0.0',
        isIos: false,
      );
      expect(g.status, GateStatus.ok);
    });
  });
}
