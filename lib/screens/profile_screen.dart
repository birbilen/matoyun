import 'package:flutter/material.dart' hide Page;

import '../data/game_data.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: Api.userStream(uid),
      builder: (context, snap) {
        final p = snap.data;
        return Page(
          title: 'Profil',
          child: p == null
              ? const Center(child: CircularProgressIndicator())
              : _body(context, p),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> p) {
    final t = Theme.of(context);
    final xp = asInt(p['xp']);
    final level = levelOf(xp);
    final badges = (p['badges'] as List? ?? []).cast<String>();
    final stats = Map<String, dynamic>.from(p['stats'] as Map? ?? {});
    // Zayıf konular üstte görünsün diye doğruluk oranına göre sırala.
    final rows = stats.entries
        .where((e) => asInt(e.value['total']) > 0)
        .map((e) => (
              e.key,
              asInt(e.value['correct']),
              asInt(e.value['total']),
            ))
        .toList()
      ..sort((a, b) => (a.$2 / a.$3).compareTo(b.$2 / b.$3));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: AvatarCircle(p['avatar'] as String, size: 88)),
        const SizedBox(height: 8),
        Text('${p['name']}',
            style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
        Text('${leagueOf(asInt(p['lp']))} ligi · ${asInt(p['lp'])} LP',
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text('Seviye $level', style: t.textTheme.titleMedium),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              minHeight: 10, value: (xp % xpPerLevel) / xpPerLevel),
        ),
        const SizedBox(height: 4),
        Text('${xp % xpPerLevel}/$xpPerLevel XP', style: t.textTheme.bodySmall),
        const SizedBox(height: 16),
        Row(children: [
          _stat(context, '${asInt(p['matches'])}', 'Maç'),
          _stat(context, '${asInt(p['wins'])}', 'Galibiyet'),
          _stat(context, '${asInt(p['tas'])}', 'Taş'),
        ]),
        const SizedBox(height: 24),
        Text('Avatarlar', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final e in avatars.entries)
              _AvatarChoice(
                id: e.key,
                locked: level < e.value.level,
                selected: p['avatar'] == e.key,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Rozetler', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (badges.isEmpty)
          Text('Henüz rozetin yok. İlk maçını oyna!',
              style: t.textTheme.bodyMedium)
        else
          Wrap(spacing: 8, children: [
            for (final b in badges)
              Chip(
                  avatar: const Icon(Icons.military_tech),
                  label: Text(badgeNames[b] ?? b)),
          ]),
        const SizedBox(height: 24),
        Text('Konu bazında doğruluk', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('Soru çözdükçe burada hangi konuda ne kadar iyi olduğunu göreceksin.',
              style: t.textTheme.bodyMedium),
        for (final (topic, correct, total) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(topicNames[topic] ?? topic,
                          overflow: TextOverflow.ellipsis)),
                  if (total >= 3 && correct / total < 0.5)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('Zayıf konu',
                          style: t.textTheme.labelSmall
                              ?.copyWith(color: t.colorScheme.error)),
                    ),
                  Text('%${(100 * correct / total).round()} ($correct/$total)',
                      style: t.textTheme.bodySmall),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: correct / total,
                    color: correct / total < 0.5 ? t.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text(value, style: t.headlineSmall),
            Text(label, style: t.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String id;
  final bool locked;
  final bool selected;
  const _AvatarChoice(
      {required this.id, required this.locked, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final info = avatars[id]!;
    return Column(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: locked || selected
              ? null
              : () async {
                  try {
                    await Api.call('updateAvatar', {'avatar': id});
                  } catch (e) {
                    if (context.mounted) showMessage(context, e.toString());
                  }
                },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 3, color: selected ? c.primary : Colors.transparent),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                    opacity: locked ? 0.3 : 1,
                    child: AvatarCircle(id, size: 52)),
                if (locked) const Icon(Icons.lock, size: 22),
              ],
            ),
          ),
        ),
        Text(locked ? 'Seviye ${info.level}' : info.name,
            style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
