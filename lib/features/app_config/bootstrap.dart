import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

class PesantrenContact {
  const PesantrenContact({
    required this.role,
    required this.label,
    required this.whatsapp,
  });

  factory PesantrenContact.fromJson(Map<String, dynamic> j) => PesantrenContact(
    role: j['role'] as String,
    label: j['label'] as String? ?? j['role'] as String,
    whatsapp: j['whatsapp'] as String,
  );

  final String role;
  final String label;

  /// Digit E.164 tanpa '+', mis. `6281234567890`.
  final String whatsapp;
}

/// Rekening tujuan transfer pesantren (`Bootstrap.payment_accounts`).
class PaymentAccount {
  const PaymentAccount({
    required this.id,
    required this.bank,
    required this.accountNumber,
    required this.accountName,
    this.note,
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> j) => PaymentAccount(
    id: '${j['id']}',
    bank: j['bank'] as String? ?? '',
    accountNumber: j['account_number'] as String? ?? '',
    accountName: j['account_name'] as String? ?? '',
    note: j['note'] as String?,
  );

  final String id;
  final String bank;
  final String accountNumber;
  final String accountName;
  final String? note;
}

class AppBootstrap {
  const AppBootstrap({
    required this.tenantName,
    required this.activeModules,
    required this.contacts,
    this.paymentAccounts = const [],
  });

  factory AppBootstrap.fromJson(Map<String, dynamic> j) {
    final modules = (j['modules'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((m) => m['status'] == 'active')
        .map((m) => m['code'] as String)
        .toSet();
    final tenant = j['tenant'] as Map<String, dynamic>? ?? const {};
    return AppBootstrap(
      tenantName: tenant['nama'] as String? ?? tenant['name'] as String? ?? '',
      activeModules: modules,
      contacts: (j['contacts'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PesantrenContact.fromJson)
          .toList(),
      paymentAccounts: (j['payment_accounts'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PaymentAccount.fromJson)
          .toList(),
    );
  }

  final String tenantName;

  /// Kode modul yang ter-entitle (`akademik`, `keamanan`, `keuangan`, ...).
  /// UI menyembunyikan menu modul non-aktif; backend tetap otoritatif (403).
  final Set<String> activeModules;
  final List<PesantrenContact> contacts;
  final List<PaymentAccount> paymentAccounts;

  bool has(String module) => activeModules.contains(module);
}

final bootstrapProvider = FutureProvider<AppBootstrap>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.value?.id));
  final res = await ref
      .watch(dioProvider)
      .get<Map<String, dynamic>>('/app/bootstrap');
  return AppBootstrap.fromJson(envelopeData(res.data));
});
