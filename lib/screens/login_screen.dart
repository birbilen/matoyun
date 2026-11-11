import 'dart:math';

import 'package:flutter/material.dart' hide Page;

import '../data/game_data.dart';
import '../data/names.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'privacy_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showMessage(context, AuthService.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Page(
      child: Column(
        children: [
          const SizedBox(height: 48),
          const Logo(size: 110),
          const SizedBox(height: 8),
          Text('Mat Düellosu', style: t.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Arkadaşlarınla LGS matematik düellosu',
              style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 48),
          BusyButton(
            label: 'Google ile giriş yap',
            icon: Icons.login,
            onPressed: () => _run(context, AuthService.signInWithGoogle),
          ),
          const SizedBox(height: 8),
          Text('İlerlemen hesabına kaydedilir; her cihazdan devam edebilirsin.',
              style: t.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          BusyButton(
            label: 'Misafir olarak dene',
            icon: Icons.person_outline,
            tonal: true,
            onPressed: () => _run(context, AuthService.signInAsGuest),
          ),
          const SizedBox(height: 8),
          Text(
              'Misafir ilerlemesi yalnızca bu cihazda kalır. '
              'Sonradan Google hesabına bağlayabilirsin.',
              style: t.textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            child: const Text('Gizlilik politikası'),
          ),
        ],
      ),
    );
  }
}

/// İlk girişte: kullanıcı adı (hazır kelimelerden), avatar ve veli onayı.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static final _rnd = Random();
  String _adjective = adjectives[_rnd.nextInt(adjectives.length)];
  String _noun = nouns[_rnd.nextInt(nouns.length)];
  String _avatar = 'piyon';
  bool _consent = false;

  Widget _chips(List<String> items, String selected, ValueChanged<String> on) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item),
            selected: item == selected,
            onSelected: (_) => setState(() => on(item)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Page(
      title: 'Profilini oluştur',
      actions: [
        IconButton(
            tooltip: 'Çıkış yap',
            onPressed: AuthService.signOut,
            icon: const Icon(Icons.logout)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kullanıcı adın', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Güvenliğin için gerçek adını kullanmıyoruz. İki kelime seç:',
              style: t.textTheme.bodySmall),
          const SizedBox(height: 12),
          Center(
            child: Text('$_adjective$_noun##',
                style: t.textTheme.headlineSmall
                    ?.copyWith(color: t.colorScheme.primary)),
          ),
          Center(
              child: Text('Sondaki sayı otomatik verilir',
                  style: t.textTheme.bodySmall)),
          const SizedBox(height: 12),
          _chips(adjectives, _adjective, (v) => _adjective = v),
          const Divider(height: 24),
          _chips(nouns, _noun, (v) => _noun = v),
          const SizedBox(height: 24),
          Text('Avatarın', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Seviye atladıkça yeni avatarlar açılır.',
              style: t.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final e in avatars.entries.where((e) => e.value.level == 1))
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _avatar = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            width: 3,
                            color: _avatar == e.key
                                ? t.colorScheme.primary
                                : Colors.transparent),
                      ),
                      child: AvatarCircle(e.key, size: 64),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text('Velimin bu oyunu oynamama izni var.'),
          ),
          const SizedBox(height: 16),
          BusyButton(
            label: 'Başla',
            onPressed: !_consent
                ? null
                : () => Api.call('createProfile', {
                      'adjective': _adjective,
                      'noun': _noun,
                      'avatar': _avatar,
                      'consent': true,
                    }),
          ),
        ],
      ),
    );
  }
}
