import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'config/tenant_config.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

/// Di-override di `main.dart` dengan konfigurasi tenant hasil build.
final tenantConfigProvider = Provider<TenantConfig>(
  (_) => throw UnimplementedError('tenantConfigProvider belum di-override'),
);

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final dioProvider = Provider<Dio>((ref) {
  return createDio(
    config: ref.watch(tenantConfigProvider),
    tokens: ref.watch(tokenStorageProvider),
    onUnauthorized: () =>
        ref.read(authControllerProvider.notifier).forceLogout(),
  );
});
