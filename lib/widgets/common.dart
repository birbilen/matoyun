import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../data/game_data.dart';

/// Metin içinde `$...$` arasındaki LaTeX ifadelerini düzgün gösterir.
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  const MathText(this.text,
      {super.key, this.style, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final parts = text.split(r'$');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i.isOdd) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            parts[i],
            textStyle: base,
            onErrorFallback: (_) => Text(parts[i], style: base),
          ),
        ));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return Text.rich(TextSpan(style: base, children: spans),
        textAlign: textAlign);
  }
}

class AvatarCircle extends StatelessWidget {
  final String id;
  final double size;
  const AvatarCircle(this.id, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final a = avatars[id] ?? avatars['piyon']!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
      child: Text(a.glyph,
          style: TextStyle(
              fontSize: size * 0.58, color: Colors.white, height: 1.1)),
    );
  }
}

/// Dikey telefon düzeni: geniş ekranda içerik ortada dar bir sütunda kalır.
class Page extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool scroll;
  const Page(
      {super.key,
      this.title,
      required this.child,
      this.actions,
      this.scroll = true});

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: const EdgeInsets.all(16), child: child);
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: scroll ? SingleChildScrollView(child: body) : body,
          ),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// İşlem sürerken kendini kilitleyen ve dönen simge gösteren düğme.
class BusyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final bool tonal;
  const BusyButton(
      {super.key,
      required this.label,
      this.icon,
      required this.onPressed,
      this.tonal = false});

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _busy || widget.onPressed == null ? null : _run;
    final child = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20),
              const SizedBox(width: 8)
            ],
            Flexible(child: Text(widget.label)),
          ]);
    const style = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)));
    return widget.tonal
        ? FilledButton.tonal(onPressed: onPressed, style: style, child: child)
        : FilledButton(onPressed: onPressed, style: style, child: child);
  }
}
