import 'package:flutter/material.dart';

/// Konfigurasi white-label per pesantren, di-inject saat build:
/// `flutter run --dart-define-from-file=tenants/<slug>/config.json`.
class TenantConfig {
  const TenantConfig({
    required this.tenantCode,
    required this.appName,
    required this.apiBaseUrl,
    required this.primaryColor,
    required this.sentryDsn,
  });

  factory TenantConfig.fromEnvironment() {
    const color = String.fromEnvironment(
      'PRIMARY_COLOR',
      defaultValue: '0xFF0F766E',
    );
    return TenantConfig(
      tenantCode: const String.fromEnvironment('TENANT_CODE'),
      appName: const String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'Santri360',
      ),
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.santri360.com',
      ),
      primaryColor: Color(int.tryParse(color) ?? 0xFF0F766E),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    );
  }

  /// Kode pesantren — dikirim sebagai header `X-Pesantren-Code` di setiap request.
  final String tenantCode;
  final String appName;
  final String apiBaseUrl;
  final Color primaryColor;
  final String sentryDsn;

  bool get isValid =>
      tenantCode.isNotEmpty && apiBaseUrl.startsWith('https://');
}
