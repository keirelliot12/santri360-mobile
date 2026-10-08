import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import '../../shared/version.dart';

enum GateStatus { ok, updateAvailable, updateRequired, maintenance }

class AppGate {
  const AppGate(this.status, {this.message, this.storeUrl});

  final GateStatus status;
  final String? message;
  final String? storeUrl;

  bool get blocking =>
      status == GateStatus.updateRequired || status == GateStatus.maintenance;

  /// Logika murni (mudah di-test) dari blok `app` backend (G14).
  static AppGate evaluate({
    required Map<String, dynamic> app,
    required String currentVersion,
    required bool isIos,
  }) {
    final storeUrl =
        (isIos ? app['store_url_ios'] : app['store_url_android']) as String?;
    if (app['maintenance'] == true) {
      return AppGate(
        GateStatus.maintenance,
        message:
            app['maintenance_message'] as String? ??
            'Aplikasi sedang dalam pemeliharaan.',
      );
    }
    final min = app['min_supported_version'] as String?;
    if (min != null && compareVersions(currentVersion, min) < 0) {
      return AppGate(GateStatus.updateRequired, storeUrl: storeUrl);
    }
    final latest = app['latest_version'] as String?;
    if (latest != null && compareVersions(currentVersion, latest) < 0) {
      return AppGate(GateStatus.updateAvailable, storeUrl: storeUrl);
    }
    return const AppGate(GateStatus.ok);
  }
}

/// Dicek sebelum login. Gagal jaringan → jangan blok pengguna (fail-open).
final appGateProvider = FutureProvider<AppGate>((ref) async {
  try {
    final res = await ref
        .watch(dioProvider)
        .get<Map<String, dynamic>>('/app/version');
    final info = await PackageInfo.fromPlatform();
    return AppGate.evaluate(
      app: envelopeData(res.data),
      currentVersion: info.version,
      isIos: ref.watch(isIosProvider),
    );
  } on DioException {
    return const AppGate(GateStatus.ok);
  }
});

final isIosProvider = Provider<bool>((_) => false);
