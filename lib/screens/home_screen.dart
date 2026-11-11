import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Page;

import '../data/game_data.dart';
import '../services/api.dart';
import '../theme.dart';
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
          const Center(child: Logo(size: 96)),
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
    final t = Theme.of(context).textTheme;
    final fg = primary ? const Color(0xFF2B2005) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Raised(
        color: primary ? Brand.primary : Brand.surface,
        depth: 6,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 36, color: fg),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.titleLarge?.copyWith(
                          color: fg, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: t.bodyMedium
                          ?.copyWith(color: fg.withValues(alpha: 0.8))),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: fg),
          ],
        ),
      ),
    );
  }
}
