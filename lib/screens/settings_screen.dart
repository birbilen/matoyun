import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Page;

import '../services/api.dart';
import '../services/prefs.dart';
import '../widgets/common.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _signOut() async {
    final guest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    if (guest) {
      final ok = await _confirm(
        'Çıkış yap',
        'Misafir hesabındasın. Çıkış yaparsan ilerlemen kaybolur. '
            'Kaybetmemek için önce ana menüden Google hesabına bağla.',
        'Yine de çık',
      );
      if (!ok) return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await AuthService.signOut();
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      'Hesabımı sil',
      'Hesabın ve tüm ilerlemen (seviye, Taş, rozetler, istatistikler) '
          'kalıcı olarak silinir. Bu işlem geri alınamaz.',
      'Kalıcı olarak sil',
    );
    if (!ok) return;
    try {
      await Api.call('deleteAccount');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      await AuthService.signOut();
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Page(
      title: 'Ayarlar',
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Ses'),
            subtitle: const Text('Şık seçerken tıklama sesi (Android)'),
            value: Prefs.sound,
            onChanged: (v) async {
              await Prefs.setSound(v);
              setState(() {});
            },
          ),
          const SwitchListTile(
            secondary: Icon(Icons.notifications),
            title: Text('Bildirimler'),
            subtitle: Text('Yakında'),
            value: false,
            onChanged: null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik politikası'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış yap'),
            onTap: _signOut,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: c.error),
            title: Text('Hesabımı sil', style: TextStyle(color: c.error)),
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}
