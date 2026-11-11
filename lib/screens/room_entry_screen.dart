import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../data/game_data.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

/// Oda kur ya da 6 haneli kodla odaya katıl.
class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key});

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  String _topic = 'karisik';
  int _count = 5;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _enter(String code) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => RoomScreen(code: code)));
  }

  Future<void> _create() async {
    final res = await Api.call(
        'createRoom', {'topic': _topic, 'questionCount': _count});
    if (mounted) _enter(res['code'] as String);
  }

  Future<void> _join() async {
    final res = await Api.call('joinRoom', {'code': _code.text.trim()});
    if (mounted) _enter(res['code'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Page(
      title: 'Arkadaş Odası',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Odaya katıl', style: t.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '000000',
              labelText: 'Oda kodu',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          BusyButton(
            label: 'Katıl',
            icon: Icons.login,
            onPressed: _code.text.trim().length == 6 ? _join : null,
          ),
          const Divider(height: 48),
          Text('Oda kur', style: t.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _topic,
            isExpanded: true,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Konu'),
            items: [
              for (final e in topicNames.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _topic = v ?? 'karisik'),
          ),
          const SizedBox(height: 16),
          Text('Soru sayısı', style: t.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final n in questionCounts)
                ButtonSegment(value: n, label: Text('$n')),
            ],
            selected: {_count},
            onSelectionChanged: (s) => setState(() => _count = s.first),
          ),
          const SizedBox(height: 16),
          BusyButton(
            label: 'Oda kur',
            icon: Icons.add,
            tonal: true,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}
