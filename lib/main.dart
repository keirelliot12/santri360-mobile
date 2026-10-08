import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/tenant_config.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_config/app_gate.dart';
import 'features/app_config/gate_page.dart';

Future<void> main() async {
  await initializeDateFormatting('id_ID');
  final config = TenantConfig.fromEnvironment();
  final app = ProviderScope(
    overrides: [
      tenantConfigProvider.overrideWithValue(config),
      isIosProvider.overrideWithValue(
        defaultTargetPlatform == TargetPlatform.iOS,
      ),
    ],
    child: const Santri360App(),
  );

  if (config.sentryDsn.isEmpty) return runApp(app);
  await SentryFlutter.init((o) {
    o.dsn = config.sentryDsn;
    o.environment = config.tenantCode;
    o.sendDefaultPii = false;
  }, appRunner: () => runApp(app));
}

class Santri360App extends ConsumerWidget {
  const Santri360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tenantConfigProvider);
    final gate = ref.watch(appGateProvider).value;

    if (gate != null && gate.blocking) {
      return MaterialApp(
        title: config.appName,
        theme: buildTheme(config.primaryColor, Brightness.light),
        home: GatePage(gate: gate),
      );
    }
    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(config.primaryColor, Brightness.light),
      darkTheme: buildTheme(config.primaryColor, Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
