import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../i18n/strings.dart';
import 'pixel.dart';

/// Cuántas frases tiene el gatito en cada idioma (claves cat.1 … cat.N).
const int catPhraseCount = 30;

/// El gatito oficial al fondo de Misiones: al tocarlo da un saltito y dice algo.
class CatBuddy extends StatefulWidget {
  final GameState game;
  const CatBuddy({super.key, required this.game});

  @override
  State<CatBuddy> createState() => _CatBuddyState();
}

class _CatBuddyState extends State<CatBuddy> with SingleTickerProviderStateMixin {
  late final AnimationController _hop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  final _rnd = Random();
  String? _phrase;
  int _last = -1;
  Timer? _hide;
  bool _blink = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    // Parpadea de vez en cuando.
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      setState(() => _blink = true);
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (mounted) setState(() => _blink = false);
    });
  }

  @override
  void dispose() {
    _hop.dispose();
    _hide?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _talk() {
    final g = widget.game;
    var i = _rnd.nextInt(catPhraseCount) + 1;
    if (i == _last) i = i % catPhraseCount + 1;
    _last = i;
    final pending = g.tasks.where((t) => !t.doneToday && (t.isHabit || t.done == null)).length;
    final streak = g.tasks.where((t) => t.isHabit).fold<int>(0, (m, t) => max(m, t.currentStreak));
    setState(() {
      _phrase = L.f('cat.$i', {
        'name': g.name,
        'level': g.level,
        'pending': pending,
        'gold': fmt(g.gold),
        'streak': streak,
        'next': fmt(g.level < 2 ? 2000 - g.xp : (g.level + 1) * 1000 - g.xp),
      });
    });
    _hop.forward(from: 0);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _phrase = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _phrase;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Column(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: phrase == null
              ? const SizedBox(height: 8, key: ValueKey('none'))
              : _Bubble(key: ValueKey(phrase), text: phrase),
        ),
        Semantics(
          button: true,
          label: L.t('cat.label'),
          child: GestureDetector(
            onTap: _talk,
            child: AnimatedBuilder(
              animation: _hop,
              builder: (context, child) {
                // Saltito: sube y baja en pasos, como sprite.
                final t = _hop.value;
                final dy = -(sin(t * pi) * 14).roundToDouble();
                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: SizedBox(
                width: 96,
                height: 84,
                child: CustomPaint(painter: _CatPainter(blink: _blink)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(L.t('cat.hint'), style: T.body(12, C.dim)),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: C.fg,
          border: Border.all(color: C.ink, width: 3),
          boxShadow: hardShadow(3),
        ),
        child: Text(text, textAlign: TextAlign.center, style: T.body(14, C.bg)),
      ),
      // Piquito de la burbuja
      Container(width: 9, height: 6, color: C.ink),
      Container(width: 3, height: 3, color: C.ink),
      const SizedBox(height: 4),
    ]);
  }
}

/// Gatito negro de ojos verdes, 16 × 14 píxeles.
class _CatPainter extends CustomPainter {
  final bool blink;
  _CatPainter({required this.blink});

  static const _cat = Color(0xFF18121E);
  static const _hi = Color(0xFF3A2F45);
  static const _eye = Color(0xFF6FE36B);
  static const _eyeHi = Color(0xFFDCFFD2);
  static const _pink = Color(0xFFE88AA0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / 16, size.height / 14);
    final ox = (size.width - 16 * s) / 2;
    final paint = Paint()..isAntiAlias = false;
    void r(Color c, num x, num y, [num w = 1, num h = 1]) {
      paint.color = c;
      canvas.drawRect(
        Rect.fromLTWH(ox + x.toDouble() * s, y.toDouble() * s, w.toDouble() * s, h.toDouble() * s),
        paint,
      );
    }

    // Orejas
    for (final p in const [[2, 1], [3, 0], [3, 1], [4, 1], [13, 1], [12, 0], [12, 1], [11, 1]]) {
      r(_cat, p[0], p[1]);
    }
    r(_pink, 3, 1);
    r(_pink, 12, 1);
    // Cabeza y cuerpo
    r(_cat, 2, 2, 12, 8);
    r(_cat, 1, 4, 14, 5);
    r(_hi, 3, 3, 3, 1);
    // Ojos
    if (blink) {
      r(_eye, 4, 6, 2, 1);
      r(_eye, 10, 6, 2, 1);
    } else {
      r(_eye, 4, 5, 2, 2);
      r(_eye, 10, 5, 2, 2);
      r(_eyeHi, 4, 5);
      r(_eyeHi, 10, 5);
    }
    r(_pink, 7, 7, 2, 1);
    // Bigotes
    r(const Color(0xFF8A7A96), 0, 7, 2, 1);
    r(const Color(0xFF8A7A96), 14, 7, 2, 1);
    // Cuerpo y patitas
    r(_cat, 3, 10, 10, 3);
    r(_cat, 3, 13, 3, 1);
    r(_cat, 10, 13, 3, 1);
    r(_hi, 4, 13);
    r(_hi, 11, 13);
    // Cola
    r(_cat, 13, 10, 2, 1);
    r(_cat, 14, 8, 1, 2);
  }

  @override
  bool shouldRepaint(_CatPainter old) => old.blink != blink;
}
