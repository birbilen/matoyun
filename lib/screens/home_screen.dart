import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Page;

import '../data/game_data.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'room_entry_screen.dart';
import 'settings_screen.dart';
import 'training_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final Map<String, dynamic> profile;
  const HomeScreen({super.key, required this.user, required this.profile});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final xp = asInt(profile['xp']);
    return Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarCircle(profile['avatar'] as String? ?? 'piyon', size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['name'] as String? ?? '',
                        style: t.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        'Seviye ${levelOf(xp)} · ${leagueOf(asInt(profile['lp']))} ligi',
                        style: t.textTheme.bodySmall),
                  ],
                ),
              ),
              Chip(
                avatar: Icon(Icons.diamond, color: t.colorScheme.primary),
                label: Text('${asInt(profile['tas'])} Taş'),
              ),
              IconButton(
                tooltip: 'Ayarlar',
                onPressed: () => _open(context, const SettingsScreen()),
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          if (user.isAnonymous) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Misafir hesabı'),
                subtitle: const Text(
                    'İlerlemen yalnızca bu cihazda. Kaybetmemek için Google hesabına bağla.'),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await AuthService.linkGoogle();
                      if (context.mounted) {
                        showMessage(context, 'Hesabın Google\'a bağlandı.');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, AuthService.errorText(e));
                      }
                    }
                  },
                  child: const Text('Bağla'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: Text('♞',
                style: TextStyle(fontSize: 72, color: t.colorScheme.primary)),
          ),
          Center(child: Text('Mat Düellosu', style: t.textTheme.headlineMedium)),
          const SizedBox(height: 32),
          _MenuButton(
            icon: Icons.groups,
            title: 'Oyna',
            subtitle: 'Arkadaş odası kur ya da koda katıl',
            primary: true,
            onTap: () => _open(context, const RoomEntryScreen()),
          ),
          _MenuButton(
            icon: Icons.fitness_center,
            title: 'Antrenman',
            subtitle: 'Süre baskısı olmadan çalış',
            onTap: () => _open(context, const TrainingScreen()),
          ),
          _MenuButton(
            icon: Icons.person,
            title: 'Profil',
            subtitle: 'Seviye, rozetler ve konu istatistikleri',
            onTap: () => _open(context, ProfileScreen(uid: user.uid)),
          ),
          const _MenuButton(
            icon: Icons.storefront,
            title: 'Market',
            subtitle: 'Yakında',
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;
  const _MenuButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.primary = false});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: primary ? c.primaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          enabled: onTap != null,
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Icon(icon, size: 32),
          title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          subtitle: Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
