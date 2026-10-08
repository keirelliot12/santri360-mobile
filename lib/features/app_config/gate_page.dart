import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_gate.dart';

/// Layar blok: wajib update atau maintenance.
class GatePage extends StatelessWidget {
  const GatePage({super.key, required this.gate});

  final AppGate gate;

  @override
  Widget build(BuildContext context) {
    final maintenance = gate.status == GateStatus.maintenance;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                maintenance ? Icons.build_circle : Icons.system_update,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                maintenance ? 'Sedang Pemeliharaan' : 'Pembaruan Wajib',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                gate.message ?? 'Versi aplikasi Anda sudah tidak didukung. Silakan perbarui.',
                textAlign: TextAlign.center,
              ),
              if (!maintenance && gate.storeUrl != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(gate.storeUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Perbarui Sekarang'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
