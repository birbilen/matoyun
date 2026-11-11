import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../data/game_data.dart';
import '../services/api.dart';
import '../services/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Bekleme salonu, maç, soru sonucu ve maç sonucu.
/// Hangi görünümün açılacağını sunucudaki oda durumu belirler.
class RoomScreen extends StatefulWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  Timer? _phaseTimer;
  Timer? _ticker;
  Map<String, dynamic>? _room;
  bool _leaving = false;
  bool _syncing = false;
  final _choices = <int, int>{}; // soru sırası -> seçtiğim şık

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = Api.roomStream(widget.code).listen((snap) {
      if (!snap.exists) return _closed();
      setState(() => _room = snap.data());
      _schedulePhase();
    }, onError: (_) => _closed());
    // "Buradayım" sinyali.
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _sync());
    // Geri sayımların akıcı görünmesi için.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _deadline != null) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _heartbeat?.cancel();
    _phaseTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  /// İçinde bulunulan aşamanın sunucu saatine göre bitiş anı.
  int? get _deadline {
    final r = _room;
    if (r == null) return null;
    switch (r['status']) {
      case 'countdown':
        return asInt(r['countdownEndsAt']);
      case 'playing':
        return asInt(r['question']['endsAt']);
      case 'reveal':
        return asInt(r['reveal']['endsAt']);
    }
    return null;
  }

  // Aşamanın süresi dolunca sunucudan odayı ilerletmesini ister.
  void _schedulePhase() {
    _phaseTimer?.cancel();
    final d = _deadline;
    if (d == null) return;
    final wait = d - Api.serverNow + 150;
    _phaseTimer = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () async {
      await _sync();
      // Hâlâ aynı aşamadaysak (ör. saat farkı) biraz sonra yeniden dene.
      if (mounted && _deadline == d) {
        _phaseTimer = Timer(const Duration(seconds: 1), _schedulePhase);
      }
    });
  }

  Future<void> _sync() async {
    if (_syncing || _leaving) return;
    _syncing = true;
    try {
      await Api.call('syncRoom', {'code': widget.code});
    } on ApiError catch (e) {
      if (e.code == 'not-found' || e.code == 'permission-denied') _closed();
    } finally {
      _syncing = false;
    }
  }

  void _closed() {
    if (_leaving || !mounted) return;
    _leaving = true;
    showMessage(context, 'Oda kapandı.');
    Navigator.of(context).pop();
  }

  Future<void> _leave() async {
    final inMatch = _room != null &&
        _room!['status'] != 'lobby' &&
        _room!['status'] != 'finished';
    if (inMatch) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Maçtan çık'),
          content: const Text(
              'Çıkarsan kalan soruları boş bırakmış sayılırsın. Emin misin?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Çık')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _leaving = true;
    await _sub?.cancel();
    Api.call('leaveRoom', {'code': widget.code}).catchError((_) => <String, dynamic>{});
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _answer(int index, int choice) async {
    if (_choices.containsKey(index)) return;
    setState(() => _choices[index] = choice);
    Prefs.click();
    try {
      await Api.call('submitAnswer',
          {'code': widget.code, 'index': index, 'choice': choice});
    } on ApiError catch (e) {
      // Süre dolduysa ya da soru kapandıysa seçim geçersizdir.
      if (mounted && e.code != 'already-exists') {
        setState(() => _choices.remove(index));
        showMessage(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _room;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Page(
        title: 'Oda ${widget.code}',
        scroll: r == null || r['status'] != 'countdown',
        actions: [
          IconButton(
              tooltip: 'Odadan çık',
              onPressed: _leave,
              icon: const Icon(Icons.exit_to_app)),
        ],
        child: r == null
            ? const Center(child: CircularProgressIndicator())
            : switch (r['status']) {
                'lobby' => _lobby(r),
                'countdown' => _countdown(r),
                'playing' || 'reveal' => _question(r),
                _ => _result(r),
              },
      ),
    );
  }

  Map<String, dynamic> _players(Map<String, dynamic> r) =>
      Map<String, dynamic>.from(r['players'] as Map);

  List<MapEntry<String, dynamic>> _sorted(Map<String, dynamic> r,
      {bool byScore = false}) {
    final list = _players(r).entries.toList();
    list.sort((a, b) => byScore
        ? asInt(b.value['score']).compareTo(asInt(a.value['score']))
        : asInt(a.value['joinedAt']).compareTo(asInt(b.value['joinedAt'])));
    return list;
  }

  bool _online(dynamic p) =>
      p['left'] != true && Api.serverNow - asInt(p['lastSeen']) < staleMs;

  // ---------- bekleme salonu ----------

  Widget _lobby(Map<String, dynamic> r) {
    final t = Theme.of(context);
    final isHost = r['hostUid'] == _uid;
    final players = _sorted(r);
    final ready = players.where((e) => _online(e.value)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Oda kodu', style: t.textTheme.labelLarge, textAlign: TextAlign.center),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(widget.code,
                style: t.textTheme.displayMedium?.copyWith(
                    letterSpacing: 6, color: t.colorScheme.primary)),
            IconButton(
              tooltip: 'Kodu kopyala',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                showMessage(context, 'Kod kopyalandı.');
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        Text('Bu kodu arkadaşlarınla paylaş',
            style: t.textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(topicNames[r['topic']] ?? '${r['topic']}'),
            subtitle: Text('${asInt(r['total'])} soru · soru başına 20 saniye'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Oyuncular (${players.length}/4)', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in players)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AvatarCircle(e.value['avatar'] as String),
            title: Text(
                '${e.value['name']}${e.key == _uid ? ' (sen)' : ''}'),
            subtitle: Text(_online(e.value)
                ? (e.key == r['hostUid'] ? 'Oda yöneticisi' : 'Hazır')
                : 'Bağlantı yok'),
            trailing: e.key == r['hostUid']
                ? Icon(Icons.star, color: t.colorScheme.primary)
                : null,
          ),
        const SizedBox(height: 24),
        if (isHost)
          BusyButton(
            label: ready < 2 ? 'En az 2 oyuncu gerekli' : 'Maçı başlat',
            icon: Icons.play_arrow,
            onPressed: ready < 2
                ? null
                : () => Api.call('startMatch', {'code': widget.code}),
          )
        else
          Text('Oda yöneticisinin maçı başlatması bekleniyor…',
              textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
      ],
    );
  }

  // ---------- geri sayım ----------

  Widget _countdown(Map<String, dynamic> r) {
    final left = asInt(r['countdownEndsAt']) - Api.serverNow;
    final n = (left / 1000).ceil().clamp(1, 3);
    final t = Theme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Hazır ol!', style: t.textTheme.headlineSmall),
        PopIn(
          key: ValueKey(n),
          child: Text('$n',
              style: t.textTheme.displayLarge?.copyWith(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  color: t.colorScheme.primary,
                  shadows: const [
                    Shadow(color: Color(0xFF7A5A12), offset: Offset(0, 6)),
                    Shadow(
                        color: Colors.black87,
                        offset: Offset(0, 12),
                        blurRadius: 14),
                  ])),
        ),
      ]),
    );
  }

  // ---------- soru ve soru sonucu ----------

  Widget _question(Map<String, dynamic> r) {
    final t = Theme.of(context);
    final q = r['question'] as Map;
    final index = asInt(r['index']);
    final reveal = r['status'] == 'reveal' ? r['reveal'] as Map : null;
    final me = _players(r)[_uid];
    final results = reveal == null ? null : reveal['results'] as Map;
    final myChoice = results != null
        ? (results[_uid]?['choice'] as int?)
        : _choices[index];
    final locked = reveal != null || myChoice != null || me?['answered'] == true;
    final remaining = (asInt(q['endsAt']) - Api.serverNow).clamp(0, questionMs);
    final options = (q['options'] as List).cast<String>();
    final correctIndex = reveal == null ? null : asInt(reveal['correctIndex']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Soru ${index + 1}/${asInt(r['total'])}',
                style: t.textTheme.titleMedium),
            const Spacer(),
            if (reveal == null)
              Text('${(remaining / 1000).ceil()} sn',
                  style: t.textTheme.titleMedium?.copyWith(
                      color: remaining < 5000 ? t.colorScheme.error : null)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: reveal == null ? remaining / questionMs : 0,
            color: remaining < 5000 ? t.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: 20),
        if (q['image'] != null) ...[
          Image.network(q['image'] as String,
              height: 160, errorBuilder: (_, _, _) => const SizedBox()),
          const SizedBox(height: 12),
        ],
        MathText(q['text'] as String,
            style: t.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OptionTile(
              letter: 'ABCD'[i],
              text: options[i],
              state: correctIndex != null
                  ? (i == correctIndex
                      ? OptState.correct
                      : i == myChoice
                          ? OptState.wrong
                          : OptState.idle)
                  : (i == myChoice ? OptState.selected : OptState.idle),
              onTap: locked ? null : () => _answer(index, i),
            ),
          ),
        if (reveal != null) ...[
          const SizedBox(height: 4),
          PopIn(
            child: Text(
              myChoice == null
                  ? 'Boş bıraktın'
                  : results![_uid]['correct'] == true
                      ? 'Doğru!'
                      : 'Yanlış',
              textAlign: TextAlign.center,
              style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: results?[_uid]?['correct'] == true
                      ? Brand.correct
                      : Brand.wrong),
            ),
          ),
          if ((reveal['solution'] as String).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Çözüm', style: t.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    MathText(reveal['solution'] as String),
                  ],
                ),
              ),
            ),
        ] else if (locked)
          Text('Cevabın alındı. Diğer oyuncular bekleniyor…',
              textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _scoreStrip(r, results),
      ],
    );
  }

  Widget _scoreStrip(Map<String, dynamic> r, Map? results) {
    final t = Theme.of(context);
    return Row(
      children: [
        for (final e in _sorted(r, byScore: results != null))
          Expanded(
            child: Opacity(
              opacity: _online(e.value) ? 1 : 0.4,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarCircle(e.value['avatar'] as String, size: 40),
                      if (results == null && e.value['answered'] == true)
                        const Positioned(
                          right: -6,
                          bottom: -4,
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.key == _uid ? 'Sen' : e.value['name'] as String,
                      style: t.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                  AnimatedCount(asInt(e.value['score']),
                      style: t.textTheme.titleMedium),
                  if (results != null)
                    Text(
                      () {
                        final d = asInt(results[e.key]?['delta']);
                        return d > 0 ? '+$d' : '$d';
                      }(),
                      style: t.textTheme.bodySmall?.copyWith(
                          color: results[e.key]?['correct'] == true
                              ? Colors.green
                              : t.colorScheme.outline),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------- maç sonucu ----------

  Widget _result(Map<String, dynamic> r) {
    final t = Theme.of(context);
    final ranking = ((r['result'] as Map)['ranking'] as List).cast<Map>();
    final players = _players(r);
    final mine = ranking.firstWhere((x) => x['uid'] == _uid, orElse: () => {});
    final isHost = r['hostUid'] == _uid;
    final won = ranking.isNotEmpty && ranking.first['uid'] == _uid;
    const medals = ['🥇', '🥈', '🥉', '4.'];
    return Stack(children: [
      _resultBody(r, t, ranking, players, mine, isHost, won, medals),
      if (won) const Positioned.fill(child: Confetti()),
    ]);
  }

  Widget _resultBody(Map<String, dynamic> r, ThemeData t, List<Map> ranking,
      Map<String, dynamic> players, Map mine, bool isHost, bool won,
      List<String> medals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopIn(
          child: Text(won ? 'Şah mat!' : 'Maç bitti',
              style: t.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: won ? Brand.primary : null),
              textAlign: TextAlign.center),
        ),
        if (won)
          Text('Kazandın', style: t.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        for (var i = 0; i < ranking.length; i++)
          Card(
            color: ranking[i]['uid'] == _uid
                ? t.colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 32,
                    child: Text(medals[i], style: t.textTheme.titleLarge)),
                AvatarCircle(ranking[i]['avatar'] as String, size: 40),
              ]),
              title: Text('${ranking[i]['name']}',
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${asInt(ranking[i]['correct'])} doğru · ${(asInt(ranking[i]['totalMs']) / 1000).toStringAsFixed(1)} sn'
                  '${ranking[i]['left'] == true ? ' · ayrıldı' : ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (players[ranking[i]['uid']]?['reaction'] != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                        '${players[ranking[i]['uid']]['reaction']['emoji']}',
                        style: const TextStyle(fontSize: 24)),
                  ),
                AnimatedCount(asInt(ranking[i]['score']),
                    style: t.textTheme.titleLarge),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
                avatar: Icon(Icons.diamond, color: t.colorScheme.primary),
                label: Text('+${asInt(mine['tas'])} Taş')),
            const SizedBox(width: 12),
            Chip(
                avatar: const Icon(Icons.trending_up),
                label: Text('+${asInt(mine['xp'])} XP')),
          ],
        ),
        const SizedBox(height: 16),
        Text('Tepki gönder', style: t.textTheme.labelLarge, textAlign: TextAlign.center),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final e in reactions)
              IconButton(
                onPressed: () => Api.call('sendReaction',
                    {'code': widget.code, 'emoji': e}).catchError((_) => <String, dynamic>{}),
                icon: Text(e, style: const TextStyle(fontSize: 26)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (isHost)
          BusyButton(
            label: 'Tekrar oyna',
            icon: Icons.replay,
            onPressed: () => Api.call('playAgain', {'code': widget.code}),
          )
        else
          Text('Oda yöneticisi yeni maç başlatabilir.',
              textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _leave,
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          child: const Text('Ana menü'),
        ),
      ],
    );
  }
}
