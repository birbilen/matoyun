import 'package:flutter/material.dart' hide Page;

import '../data/game_data.dart';
import '../services/api.dart';
import '../widgets/common.dart';

/// Antrenman: süre yok, ipucu var, her sorudan sonra çözüm gösterilir.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  String? _topic;
  Map<String, dynamic>? _q;
  Map<String, dynamic>? _result;
  List<int> _removed = [];
  int? _choice;
  bool _busy = false;
  int _correct = 0;
  int _total = 0;

  Future<void> _guard(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next(String topic) => _guard(() async {
        final res = await Api.call('trainingNext', {'topic': topic});
        setState(() {
          _topic = topic;
          _q = Map<String, dynamic>.from(res['question'] as Map);
          _result = null;
          _removed = [];
          _choice = null;
        });
      });

  Future<void> _hint() => _guard(() async {
        final res = await Api.call('trainingHint');
        setState(() => _removed = (res['remove'] as List).map(asInt).toList());
      });

  Future<void> _answer(int i) => _guard(() async {
        setState(() => _choice = i);
        try {
          final res = await Api.call('trainingAnswer', {'choice': i});
          setState(() {
            _result = res;
            _total++;
            if (res['correct'] == true) _correct++;
          });
        } catch (_) {
          setState(() => _choice = null);
          rethrow;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Page(
      title: _q == null ? 'Antrenman' : (topicNames[_q!['topic']] ?? 'Antrenman'),
      child: _q == null ? _topics() : _question(),
    );
  }

  Widget _topics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bir konu seç', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_busy) const LinearProgressIndicator(),
        for (final e in topicNames.entries)
          Card(
            child: ListTile(
              title: Text(e.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _next(e.key),
            ),
          ),
      ],
    );
  }

  Widget _question() {
    final t = Theme.of(context);
    final q = _q!;
    final options = (q['options'] as List).cast<String>();
    final res = _result;
    final correctIndex = res == null ? null : asInt(res['correctIndex']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('Zorluk: ${'★' * asInt(q['difficulty'])}',
              style: t.textTheme.bodyMedium),
          const Spacer(),
          Text('$_correct/$_total doğru', style: t.textTheme.bodyMedium),
        ]),
        const SizedBox(height: 16),
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
            child: Opacity(
              opacity: res == null && _removed.contains(i) ? 0.3 : 1,
              child: Material(
                color: correctIndex == null
                    ? (i == _choice
                        ? t.colorScheme.primary
                        : t.colorScheme.surfaceContainerHigh)
                    : i == correctIndex
                        ? const Color(0xFF2E7D32)
                        : i == _choice
                            ? t.colorScheme.error
                            : t.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: res != null || _busy || _removed.contains(i)
                      ? null
                      : () => _answer(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Text('ABCD'[i],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: MathText(options[i],
                              style: const TextStyle(fontSize: 20))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (res == null)
          OutlinedButton.icon(
            onPressed: _busy || _removed.isNotEmpty ? null : _hint,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_removed.isEmpty
                ? 'İpucu: iki yanlış şıkkı ele'
                : 'İpucu kullanıldı'),
          )
        else ...[
          Text(res['correct'] == true ? 'Doğru!' : 'Yanlış',
              textAlign: TextAlign.center,
              style: t.textTheme.titleLarge?.copyWith(
                  color: res['correct'] == true
                      ? Colors.green
                      : t.colorScheme.error)),
          if ((res['solution'] as String).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Çözüm', style: t.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    MathText(res['solution'] as String),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          BusyButton(
            label: 'Sonraki soru',
            icon: Icons.arrow_forward,
            onPressed: () => _next(_topic!),
          ),
        ],
      ],
    );
  }
}
