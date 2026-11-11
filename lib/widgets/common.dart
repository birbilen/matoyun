import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../data/game_data.dart';
import '../theme.dart';

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

/// Kabartmalı (3B görünümlü) yüzey: alt kenarı koyu, basınca içeri çöker.
class Raised extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final EdgeInsets padding;
  const Raised(
      {super.key,
      required this.child,
      required this.color,
      this.onTap,
      this.radius = 16,
      this.depth = 5,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14)});

  @override
  State<Raised> createState() => _RaisedState();
}

class _RaisedState extends State<Raised> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final face = enabled
        ? widget.color
        : Color.lerp(widget.color, Brand.background, 0.55)!;
    final edge = Color.lerp(face, Colors.black, 0.45)!;
    final light = Color.lerp(face, Colors.white, 0.14)!;
    final d = widget.depth;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            margin: EdgeInsets.only(top: _down ? d : 0, bottom: _down ? 0 : d),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [light, face],
              ),
              boxShadow: [
                BoxShadow(color: edge, offset: Offset(0, _down ? 0 : d)),
                if (!_down)
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: Offset(0, d + 4),
                      blurRadius: 8),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Küre gibi görünen avatar: ışık yansıması, kenar ve gölge.
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.95,
          colors: [
            Color.lerp(a.color, Colors.white, 0.45)!,
            a.color,
            Color.lerp(a.color, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.55), width: size * 0.04),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: Offset(0, size * 0.08),
              blurRadius: size * 0.14),
        ],
      ),
      child: Text(a.glyph,
          style: TextStyle(
              fontSize: size * 0.56,
              color: Colors.white,
              height: 1.1,
              shadows: const [
                Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 3)
              ])),
    );
  }
}

/// Logo: assets/logo.png varsa onu, yoksa at simgesini gösterir.
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      errorBuilder: (_, _, _) => Text('♞',
          style: TextStyle(
              fontSize: size * 0.9,
              height: 1.1,
              color: Brand.primary,
              shadows: const [
                Shadow(color: Colors.black87, offset: Offset(0, 6), blurRadius: 10),
                Shadow(color: Color(0xFF7A5A12), offset: Offset(0, 3)),
              ])),
    );
  }
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Brand.backgroundTop, Brand.background],
          ).createShader(Offset.zero & size));
    // Hafif satranç tahtası deseni.
    const cell = 56.0;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        if ((x + y).isEven) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      extendBodyBehindAppBar: true,
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: Stack(
        children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: CustomPaint(painter: _BoardPainter()))),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: scroll ? SingleChildScrollView(child: body) : body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// İşlem sürerken kendini kilitleyen kabartmalı düğme.
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
    final fg = widget.tonal ? Colors.white : const Color(0xFF2B2005);
    final style =
        TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700);
    return Raised(
      color: widget.tonal ? Brand.surface : Brand.primary,
      onTap: _busy || widget.onPressed == null ? null : _run,
      child: SizedBox(
        height: 26,
        child: Center(
          child: _busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 22, color: fg),
                    const SizedBox(width: 8)
                  ],
                  Flexible(child: Text(widget.label, style: style)),
                ]),
        ),
      ),
    );
  }
}

enum OptState { idle, selected, correct, wrong }

/// Soru şıkkı (A/B/C/D).
class OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final OptState state;
  final VoidCallback? onTap;
  const OptionTile(
      {super.key,
      required this.letter,
      required this.text,
      this.state = OptState.idle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      OptState.idle => (Brand.surface, Colors.white),
      OptState.selected => (Brand.primary, const Color(0xFF2B2005)),
      OptState.correct => (Brand.correct, Colors.white),
      OptState.wrong => (Brand.wrong, Colors.white),
    };
    // Sonuç gösterilirken de renkler canlı kalsın diye "etkin" çizilir.
    final showAsEnabled = onTap != null || state != OptState.idle;
    return Raised(
      color: bg,
      onTap: onTap ?? (showAsEnabled ? () {} : null),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle),
            child: Text(letter,
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: MathText(text, style: TextStyle(color: fg, fontSize: 20))),
          if (state == OptState.correct)
            Icon(Icons.check_circle, color: fg)
          else if (state == OptState.wrong)
            Icon(Icons.cancel, color: fg),
        ],
      ),
    );
  }
}

/// Değeri değişince sayarak ilerleyen sayı (puan animasyonu).
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// İçeriği büyüyerek "fırlatan" giriş animasyonu.
class PopIn extends StatelessWidget {
  final Widget child;
  const PopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// Kazanınca ekrana yağan konfeti.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
            painter: _ConfettiPainter(_c.value), size: Size.infinite),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    Brand.primary,
    Color(0xFFE85D75),
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    for (var i = 0; i < 90; i++) {
      final x0 = rnd.nextDouble();
      final delay = rnd.nextDouble() * 0.35;
      final speed = 0.9 + rnd.nextDouble() * 0.7;
      final sway = (rnd.nextDouble() - 0.5) * 80;
      final spin = rnd.nextDouble() * 12;
      final w = 6 + rnd.nextDouble() * 6;
      final color = _colors[i % _colors.length];
      final p = (t - delay) * speed;
      if (p <= 0) continue;
      final y = -20 + p * (size.height + 60);
      final x = x0 * size.width + sin(p * 6 + i) * sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * spin);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.6),
          Paint()..color = color.withValues(alpha: (1.2 - t).clamp(0, 1)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
