import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';

/// Pesan ramah untuk error API (403 modul tidak aktif, dll).
String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.isNotEntitled) {
      return 'Fitur ini belum aktif untuk pesantren Anda. '
          'Silakan hubungi pihak pesantren.';
    }
    return e.message;
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            friendlyError(error),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}

/// Kosong yang tetap bisa di-pull-to-refresh.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: c.maxHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    ),
  );
}
