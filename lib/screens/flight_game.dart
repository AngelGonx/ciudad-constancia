import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';
import '../i18n/strings.dart';
import '../services/sounds.dart';
import '../ui/pixel.dart';

/// Minijuego secreto: el gatito vuela en un avioncito de juguete esquivando
/// edificios y nubes. Se abre tocando 25 veces al gatito en 10 segundos.
class FlightGame extends StatefulWidget {
  final GameState game;
  const FlightGame({super.key, required this.game});

  @override
  State<FlightGame> createState() => _FlightGameState();
}

enum _Phase { ready, playing, over }

class _Obstacle {
  double x;
  final double gapY; // centro del hueco
  final double gap;
  final int style; // variante de dibujo
  bool passed = false;
  _Obstacle(this.x, this.gapY, this.gap, this.style);
}

class _Coin {
  double x;
  final double y;
  bool taken = false;
  _Coin(this.x, this.y);
}

class _FlightGameState extends State<FlightGame> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Mundo en píxeles lógicos: 160 de ancho; el alto depende de la pantalla.
  static const double worldW = 160;
  static const double groundH = 14;
  static const double planeX = 38;
  static const double obstacleW = 22;
  static const double spacing = 92;

  late final AnimationController _ticker;
  final _rnd = Random();
  final _clock = Stopwatch();
  double _last = 0;
  double worldH = 280;

  _Phase phase = _Phase.ready;
  bool paused = false;
  double y = 120;
  double vy = 0;
  double speed = 52;
  double time = 0;
  double scroll = 0; // para el fondo en parallax
  int score = 0;
  int coins = 0;
  int obstaclesMade = 0;
  int lastGold = 0;
  bool newRecord = false;
  double overAt = 0;
  final List<_Obstacle> obstacles = [];
  final List<_Coin> coinList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
    _clock.start();
    _reset();
    Sounds.startMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    Sounds.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Sounds.resumeMusic();
    } else {
      Sounds.pauseMusic();
      if (phase == _Phase.playing) paused = true;
    }
  }

  void _reset() {
    y = worldH * 0.45;
    vy = 0;
    speed = 52;
    time = 0;
    score = 0;
    coins = 0;
    obstaclesMade = 0;
    newRecord = false;
    obstacles.clear();
    coinList.clear();
    for (var i = 0; i < 3; i++) {
      _spawn(worldW + 40 + i * spacing);
    }
  }

  void _spawn(double x) {
    final playH = worldH - groundH;
    final gap = max(56.0, 78.0 - obstaclesMade * 0.8);
    final margin = gap / 2 + 14;
    final gapY = margin + _rnd.nextDouble() * (playH - margin * 2);
    obstacles.add(_Obstacle(x, gapY, gap, _rnd.nextInt(4)));
    obstaclesMade++;
    // Moneda flotante cada tercer obstáculo, entre este y el siguiente.
    if (obstaclesMade % 3 == 0) {
      final cy = (gapY + (_rnd.nextDouble() - 0.5) * 30).clamp(20.0, playH - 20).toDouble();
      coinList.add(_Coin(x + obstacleW + spacing / 2 - 4, cy));
    }
  }

  void _tap() {
    switch (phase) {
      case _Phase.ready:
        phase = _Phase.playing;
        vy = -150;
        Sounds.flap();
        break;
      case _Phase.playing:
        if (paused) {
          paused = false;
          _last = _clock.elapsedMilliseconds / 1000;
        }
        vy = -150;
        Sounds.flap();
        break;
      case _Phase.over:
        // Pequeña pausa para no reiniciar sin querer al chocar.
        if (time - overAt < 0.6) return;
        _reset();
        phase = _Phase.ready;
        break;
    }
    HapticFeedback.selectionClick();
  }

  void _crash() {
    phase = _Phase.over;
    overAt = time;
    newRecord = score > widget.game.flightRecord;
    lastGold = widget.game.finishFlight(score, coins);
    Sounds.crash();
    HapticFeedback.mediumImpact();
  }

  void _tick() {
    final now = _clock.elapsedMilliseconds / 1000;
    final dt = min(0.05, now - _last);
    _last = now;
    time += dt;
    if (phase == _Phase.ready) {
      // Flota suavemente esperando el primer toque.
      y = worldH * 0.45 + sin(time * 3) * 4;
      scroll += 20 * dt;
      return;
    }
    if (phase != _Phase.playing || paused) return;

    speed = min(95, 52 + time * 0.9);
    vy = min(260, vy + 520 * dt);
    y += vy * dt;
    scroll += speed * dt;

    for (final o in obstacles) {
      o.x -= speed * dt;
      if (!o.passed && o.x + obstacleW < planeX - 6) {
        o.passed = true;
        score++;
        HapticFeedback.selectionClick();
      }
    }
    for (final c in coinList) {
      c.x -= speed * dt;
    }
    obstacles.removeWhere((o) => o.x < -obstacleW - 4);
    coinList.removeWhere((c) => c.x < -10 || c.taken);
    if (obstacles.isNotEmpty && obstacles.last.x < worldW + 40 - spacing) {
      _spawn(obstacles.last.x + spacing);
    }

    // Choques: avión de unos 15 × 9 píxeles.
    final plane = Rect.fromLTWH(planeX - 7, y - 4, 14, 8);
    if (y + 4 >= worldH - groundH || y - 4 <= 0) {
      _crash();
      return;
    }
    for (final o in obstacles) {
      final top = Rect.fromLTWH(o.x, 0, obstacleW, o.gapY - o.gap / 2);
      final bottom = Rect.fromLTWH(o.x, o.gapY + o.gap / 2, obstacleW, worldH);
      if (plane.overlaps(top) || plane.overlaps(bottom)) {
        _crash();
        return;
      }
    }
    for (final c in coinList) {
      if (!c.taken && plane.inflate(2).overlaps(Rect.fromLTWH(c.x, c.y - 4, 8, 8))) {
        c.taken = true;
        coins++;
        Sounds.coin();
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1530),
      body: LayoutBuilder(builder: (context, c) {
        final scale = c.maxWidth / worldW;
        final newH = c.maxHeight / scale;
        if (phase == _Phase.ready && (newH - worldH).abs() > 1) {
          worldH = newH;
          _reset(); // acomoda los obstáculos al alto real de la pantalla
        } else {
          worldH = newH;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _FlightPainter(this, scale, _ticker))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PixelButton(
                    label: '< ${L.t('egg.exit')}',
                    color: C.panel2,
                    textColor: C.fg,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _MusicButton(game: widget.game),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _ticker,
                    builder: (context, _) => _Hud(state: this),
                  ),
                ]),
              ),
            ),
            AnimatedBuilder(
              animation: _ticker,
              builder: (context, _) => _Overlay(state: this),
            ),
          ]),
        );
      }),
    );
  }
}

class _Hud extends StatelessWidget {
  final _FlightGameState state;
  const _Hud({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${state.score}', style: T.display(28, const Color(0xFFF3E9D6))),
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Coin(size: 12),
        const SizedBox(width: 6),
        Text('${state.coins}', style: T.display(14, const Color(0xFFF4B942))),
      ]),
      const SizedBox(height: 2),
      Text(L.f('egg.best', {'n': state.widget.game.flightRecord}), style: T.body(12, const Color(0xFFB3A5C0))),
    ]);
  }
}

class _Overlay extends StatelessWidget {
  final _FlightGameState state;
  const _Overlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final g = state.widget.game;
    final lines = <Widget>[];
    switch (state.phase) {
      case _Phase.ready:
        lines.addAll([
          Text(L.t('egg.title'), textAlign: TextAlign.center, style: T.display(22, const Color(0xFFF4B942))),
          const SizedBox(height: 8),
          Text(L.t('egg.howTo'), textAlign: TextAlign.center, style: T.body(15, const Color(0xFFF3E9D6))),
          const SizedBox(height: 6),
          Text(L.f('egg.goldLeft', {'n': g.flightGoldLeft}), textAlign: TextAlign.center,
              style: T.body(13, const Color(0xFFB3A5C0))),
        ]);
        break;
      case _Phase.playing:
        if (!state.paused) return const SizedBox.shrink();
        lines.add(Text(L.t('egg.paused'), textAlign: TextAlign.center, style: T.display(18, const Color(0xFFF3E9D6))));
        break;
      case _Phase.over:
        lines.addAll([
          Text(state.newRecord ? L.t('egg.newRecord') : L.t('egg.over'), textAlign: TextAlign.center,
              style: T.display(22, const Color(0xFFF4B942))),
          const SizedBox(height: 8),
          Text(L.f('egg.score', {'n': state.score}), style: T.display(16, const Color(0xFFF3E9D6))),
          const SizedBox(height: 4),
          Text(
            state.coins == 0
                ? L.t('egg.noCoins')
                : (state.lastGold > 0 ? L.f('egg.gold', {'n': state.lastGold}) : L.t('egg.capReached')),
            textAlign: TextAlign.center,
            style: T.body(14, const Color(0xFFB3A5C0)),
          ),
          const SizedBox(height: 12),
          Text(L.t('egg.retry'), textAlign: TextAlign.center, style: T.body(14, const Color(0xFFF3E9D6))),
        ]);
        break;
    }
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xE6241C2E),
            border: Border.all(color: const Color(0xFF0F0B14), width: 3),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: lines),
        ),
      ),
    );
  }
}

class _FlightPainter extends CustomPainter {
  final _FlightGameState s;
  final double scale;
  _FlightPainter(this.s, this.scale, Listenable repaint) : super(repaint: repaint);

  final Paint _p = Paint()..isAntiAlias = false;

  void r(Canvas c, Color color, double x, double y, double w, double h) {
    _p.color = color;
    c.drawRect(Rect.fromLTWH((x * scale).floorToDouble(), (y * scale).floorToDouble(), (w * scale).ceilToDouble(),
        (h * scale).ceilToDouble()), _p);
  }

  static const _ink = Color(0xFF0F0B14);
  static const _sky = [Color(0xFF2A2048), Color(0xFF3A2A5C), Color(0xFF55356E), Color(0xFF7A4478), Color(0xFFA85A76)];

  @override
  void paint(Canvas canvas, Size size) {
    final h = s.worldH;
    const w = _FlightGameState.worldW;
    final playH = h - _FlightGameState.groundH;

    // Cielo en franjas
    final band = playH / _sky.length;
    for (var i = 0; i < _sky.length; i++) {
      r(canvas, _sky[i], 0, i * band, w, band + 1);
    }
    // Estrellas fijas
    for (var i = 0; i < 24; i++) {
      final sx = (i * 37 % 160).toDouble();
      final sy = (i * 23 % (playH * 0.5)).toDouble();
      r(canvas, const Color(0xFFE8E0F0), sx, sy, 1, 1);
    }
    // Luna
    r(canvas, const Color(0xFFFFF1C2), 122, 18, 10, 10);
    r(canvas, _sky[0], 126, 17, 7, 7);

    // Ciudad lejana en parallax
    final far = s.scroll * 0.25 % 40;
    for (var i = -1; i < 6; i++) {
      final bx = i * 40 - far;
      final bh = 24.0 + (i * 13 % 3) * 10;
      r(canvas, const Color(0xFF2E2440), bx, playH - bh, 18, bh);
      r(canvas, const Color(0xFF2E2440), bx + 22, playH - bh * 0.7, 14, bh * 0.7);
      for (var wy = playH - bh + 4; wy < playH - 3; wy += 5) {
        r(canvas, const Color(0xFF6B5A30), bx + 4, wy, 2, 2);
        r(canvas, const Color(0xFF6B5A30), bx + 11, wy, 2, 2);
      }
    }

    // Obstáculos
    for (final o in s.obstacles) {
      final topH = o.gapY - o.gap / 2;
      final botY = o.gapY + o.gap / 2;
      _cloudColumn(canvas, o.x, topH, o.style);
      _building(canvas, o.x, botY, playH, o.style);
    }

    // Monedas
    for (final c in s.coinList) {
      if (c.taken) continue;
      final bob = sin(s.time * 5 + c.x) * 1.5;
      r(canvas, _ink, c.x, c.y - 4 + bob, 8, 8);
      r(canvas, const Color(0xFFF4B942), c.x + 1, c.y - 3 + bob, 6, 6);
      r(canvas, const Color(0xFFFFE28A), c.x + 2, c.y - 2 + bob, 2, 2);
      r(canvas, const Color(0xFFB07A1C), c.x + 4, c.y + 1 + bob, 2, 1);
    }

    // Suelo con calle
    r(canvas, const Color(0xFF3F6A35), 0, playH, w, 4);
    r(canvas, const Color(0xFF4A4552), 0, playH + 4, w, _FlightGameState.groundH);
    final lane = s.scroll % 16;
    for (var x = -lane; x < w; x += 16) {
      r(canvas, const Color(0xFFE8D27A), x, playH + 9, 7, 1);
    }

    _plane(canvas, _FlightGameState.planeX, s.y);
  }

  void _cloudColumn(Canvas c, double x, double bottom, int style) {
    const cloud = Color(0xFFE8E0F0);
    const shade = Color(0xFFB8AFC8);
    r(c, shade, x + 2, 0, 18, bottom - 4);
    r(c, cloud, x + 4, 0, 14, bottom - 6);
    // Borde esponjoso abajo
    r(c, shade, x - 1, bottom - 8, 24, 8);
    r(c, cloud, x, bottom - 9, 22, 6);
    r(c, cloud, x + 3, bottom - 3, 6, 3);
    r(c, cloud, x + 12, bottom - 3, 7, 3);
    if (style.isOdd) {
      // Globo atorado en la nube
      r(c, const Color(0xFFD24C4C), x + 8, bottom + 2, 5, 6);
      r(c, const Color(0xFFDDDDDD), x + 10, bottom - 1, 1, 3);
    }
  }

  void _building(Canvas c, double x, double top, double ground, int style) {
    const colors = [Color(0xFFD9805B), Color(0xFF6F8FCF), Color(0xFF8C5A8F), Color(0xFF5F9C6A)];
    final base = colors[style % colors.length];
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    r(c, _ink, x, top, _FlightGameState.obstacleW, ground - top);
    r(c, base, x + 1, top + 1, _FlightGameState.obstacleW - 2, ground - top);
    r(c, dark, x - 1, top, _FlightGameState.obstacleW + 2, 3);
    for (var wy = top + 6; wy < ground - 4; wy += 6) {
      r(c, const Color(0xFFFFE28A), x + 4, wy, 4, 3);
      r(c, const Color(0xFF9FD8FF), x + 13, wy, 4, 3);
    }
    if (style == 2) {
      // Antena con foquito rojo
      r(c, const Color(0xFFAAAAAA), x + 10, top - 6, 1, 6);
      r(c, const Color(0xFFE3655B), x + 9, top - 8, 3, 2);
    }
  }

  void _plane(Canvas c, double cx, double cy) {
    final tilt = (s.vy / 260).clamp(-1.0, 1.0).toDouble();
    final x = cx - 8, y = cy - 4 + tilt * 1.5;
    const red = Color(0xFFD24C4C);
    const redDark = Color(0xFFA83A3A);
    const wing = Color(0xFFF4B942);
    const cat = Color(0xFF18121E);
    const eye = Color(0xFF6FE36B);
    // Cola
    r(c, redDark, x, y - 2, 2, 4);
    r(c, wing, x, y + 2, 3, 1);
    // Fuselaje
    r(c, _ink, x + 1, y + 1, 14, 6);
    r(c, red, x + 2, y + 2, 12, 4);
    r(c, redDark, x + 2, y + 5, 12, 1);
    // Ala
    r(c, wing, x + 5, y + 4, 6, 2);
    r(c, Color.lerp(wing, Colors.black, 0.3)!, x + 5, y + 6, 6, 1);
    // Gatito piloto
    r(c, cat, x + 7, y - 3, 5, 4);
    r(c, cat, x + 7, y - 4, 1, 1);
    r(c, cat, x + 11, y - 4, 1, 1);
    r(c, eye, x + 8, y - 2, 1, 1);
    r(c, eye, x + 10, y - 2, 1, 1);
    r(c, const Color(0xFFE88AA0), x + 9, y - 1, 1, 1);
    // Bufanda al viento
    r(c, const Color(0xFFF3E9D6), x + 5, y, 3, 1);
    // Hélice girando
    final spin = (s.time * 20).floor().isEven;
    r(c, const Color(0xFF8C8F9C), x + 15, y + 3, 1, 2);
    r(c, const Color(0xFFDDDDDD), x + 16, spin ? y : y + 4, 1, 4);
  }

  @override
  bool shouldRepaint(_FlightPainter old) => true;
}

/// Botón para apagar o prender la música del minijuego.
class _MusicButton extends StatefulWidget {
  final GameState game;
  const _MusicButton({required this.game});

  @override
  State<_MusicButton> createState() => _MusicButtonState();
}

class _MusicButtonState extends State<_MusicButton> {
  @override
  Widget build(BuildContext context) {
    final on = widget.game.musicOn;
    return PixelButton(
      label: on ? L.t('egg.musicOn') : L.t('egg.musicOff'),
      color: on ? C.panel2 : C.bad,
      textColor: C.fg,
      fontSize: 11,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onPressed: () {
        widget.game.setMusic(!on);
        Sounds.musicOn = !on;
        if (on) {
          Sounds.stopMusic();
        } else {
          Sounds.startMusic();
        }
        setState(() {});
      },
    );
  }
}
