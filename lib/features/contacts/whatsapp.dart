import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config/bootstrap.dart';

Uri whatsappUri(String phone, {String? text}) =>
    Uri.https('wa.me', '/$phone', text == null ? null : {'text': text});

/// Pengganti chat in-app (keputusan 8 Okt 2026): kontak WA pengurus per peran.
Future<void> showContactSheet(
  BuildContext context,
  WidgetRef ref, {
  String? childName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final contacts = ref.watch(bootstrapProvider).value?.contacts ?? const [];
      if (contacts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Kontak pengurus belum diatur oleh pesantren.'),
        );
      }
      return ListView(
        shrinkWrap: true,
        children: [
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.chat),
              title: Text(c.label),
              subtitle: Text('+${c.whatsapp}'),
              onTap: () => launchUrl(
                whatsappUri(
                  c.whatsapp,
                  text: childName == null
                      ? null
                      : 'Assalamualaikum, saya wali dari $childName.',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      );
    },
  );
}
