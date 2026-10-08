import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.name ?? '-'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Ajukan Hapus Akun'),
            subtitle: const Text(
              'Data diproses pengurus sesuai kebijakan privasi',
            ),
            onTap: () => _requestDeletion(context, ref),
          ),
        ],
      ),
    );
  }

  /// G20 — syarat Google Play (penghapusan data atas permintaan pengguna).
  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: const Text(
          'Permintaan akan dikirim ke pengurus pesantren untuk diproses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/me/deletion-request',
            options: idempotent(newIdempotencyKey()),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Permintaan terkirim.')),
      );
    } on DioException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.fromDio(e).message)),
      );
    }
  }
}
