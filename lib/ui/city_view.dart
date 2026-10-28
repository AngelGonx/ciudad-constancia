import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'sprites.dart';

// Medidas en píxeles lógicos de la ciudad.
const int _cols = 8;
const int _lotW = 20;
const int _band = 26; // 18 de lote + 8 de calle
const int _top = 6;
const int cityWidth = _cols * _lotW + 8;

int cityRows(int buildingCount) => max(3, ((buildingCount + 1) / _cols).ceil());
int cityHeight(int rows) => _top + rows * _band + 2;

class Walker {
  double x;
  int row;
  int dir;
  double lane;
  double speed;
  Color skin;
  Color shirt;
  bool isMayor;
  Walker(this.x, this.row, this.dir, this.lane, this.speed, this.skin, this.shirt, this.isMayor);
}

/// Ciudad animada: lotes, calles y vecinos caminando.
class CityView extends StatefulWidget {
  final GameState game;
  const CityView({super.key, required this.game});

  @override
  State<CityView> createState() => _CityViewState();
}

class _CityViewState extends State<CityView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final _rnd = Random();
  List<Walker> _walkers = [];
  int _rows = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _syncWalkers() {
    final rows = cityRows(widget.game.buildings.length);
    final n = min(widget.game.population, 60);
    if (rows == _rows && n == _walkers.length) return;
    _rows = rows;
    _walkers = List.generate(n, (i) {
      final dir = _rnd.nextBool() ? 1 : -1;
      return Walker(
        _rnd.nextDouble() * cityWidth,
        _rnd.nextInt(rows),
        dir,
        dir > 0 ? 3.0 : -1.0,
        0.12 + _rnd.nextDouble() * 0.22,
        skinColors[_rnd.nextInt(skinColors.length)],
        clothColors[_rnd.nextInt(clothColors.length)],
        i == 0,
      );
    });
  }

  void _tick() {
    if (_reduceMotion) return;
    for (final w in _walkers) {
      w.x += w.dir * w.speed;
      if (w.x > cityWidth + 2) w.x = -2;
      if (w.x < -2) w.x = cityWidth + 2.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncWalkers();
    final rows = _rows;
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = w * cityHeight(rows) / cityWidth;
      return CustomPaint(
        size: Size(w, h),
        painter: _CityPainter(
          buildings: List.of(widget.game.buildings),
          walkers: _walkers,
          rows: rows,
          avatar: widget.game.avatar,
          repaint: _ctl,
        ),
      );
    });
  }
}

class _CityPainter extends CustomPainter {
  final List<String> buildings;
  final List<Walker> walkers;
  final int rows;
  final Avatar avatar;

  _CityPainter({
    required this.buildings,
    required this.walkers,
    required this.rows,
    required this.avatar,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const _grass = Color(0xFF3F6A35);
  static const _tuft = Color(0xFF4A7A3C);
  static const _road = Color(0xFF3A3540);
  static const _line = Color(0xFFC9B458);
  static const _ink = Color(0xFF0F0B14);
  static const _gold = Color(0xFFF4B942);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / cityWidth;
    final p = Px(canvas, s: s);
    final h = cityHeight(rows);

    p.r(_grass, 0, 0, cityWidth, h);
    for (var r = 0; r < rows; r++) {
      final ry = _top + r * _band + 18;
      p.r(_road, 0, ry, cityWidth, 8);
      for (var x = 2; x < cityWidth; x += 8) {
        p.r(_line, x, ry + 3, 4, 1);
      }
    }

    for (var i = 0; i < rows * _cols; i++) {
      final x = 4 + (i % _cols) * _lotW + 1;
      final y = _top + (i ~/ _cols) * _band;
      if (i < buildings.length) {
        drawBuilding(p, buildings[i], x.toDouble(), y.toDouble());
      } else {
        const tufts = [[3, 4], [12, 9], [7, 14], [15, 3]];
        for (var k = 0; k < tufts.length; k++) {
          if ((i + k).isEven) p.r(_tuft, x + tufts[k][0], y + tufts[k][1], 1, 2);
        }
      }
    }

    for (final w in walkers) {
      final x = w.x.roundToDouble();
      final y = _top + w.row * _band + 18 + w.lane;
      final skin = w.isMayor ? skinColors[avatar.skin.clamp(0, skinColors.length - 1).toInt()] : w.skin;
      final shirt = w.isMayor ? clothColors[avatar.shirt.clamp(0, clothColors.length - 1).toInt()] : w.shirt;
      p.r(skin, x, y, 2, 2);
      p.r(shirt, x, y + 2, 2, 2);
      final step = (w.x / 2).floor() % 2 == 1 ? 1 : 0;
      p.r(_ink, x + step, y + 4, 1, 1);
      if (w.isMayor) p.r(_gold, x, y - 2, 2, 1);
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) => true;
}
