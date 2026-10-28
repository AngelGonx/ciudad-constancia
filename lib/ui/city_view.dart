import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import 'building_art.dart';
import 'sprites.dart';

/// Medidas en píxeles lógicos.
const int tile = 18;
const int _topPad = 6; // aire arriba para banderas y antenas
const double _px = 3; // píxeles de pantalla por píxel lógico antes del zoom

/// Momento del día según la hora del teléfono: 0 = día pleno, 1 = noche cerrada.
double darknessAt(DateTime t) {
  final h = t.hour + t.minute / 60;
  if (h >= 7 && h < 18) return 0;
  if (h >= 18 && h < 21) return (h - 18) / 3;
  if (h >= 5 && h < 7) return 1 - (h - 5) / 2;
  return 1;
}

bool isNightAt(DateTime t) => darknessAt(t) >= 0.7;

enum CityMode { view, place, move }

/// Mapa de la ciudad con zoom, construcciones, vecinos, camiones y ciclo día/noche.
class CityMap extends StatefulWidget {
  final List<Placed> buildings;
  final int mapSize;
  final int population;
  final Avatar avatar;
  final CityMode mode;
  final int? selectedId;
  final int? movingId;
  final BuildingType? ghostType;
  final Color? ghostColor;
  final void Function(int x, int y)? onTapTile;
  final bool interactive;

  const CityMap({
    super.key,
    required this.buildings,
    required this.mapSize,
    required this.population,
    required this.avatar,
    this.mode = CityMode.view,
    this.selectedId,
    this.movingId,
    this.ghostType,
    this.ghostColor,
    this.onTapTile,
    this.interactive = true,
  });

  @override
  State<CityMap> createState() => CityMapState();
}

/// Algo que camina por el mapa; x, y es la posición de los pies en píxeles lógicos.
class _Mover {
  double x, y;
  _Mover(this.x, this.y);
}

class _Walker extends _Mover {
  int homeId;
  int? destId;
  int state; // 0 en casa, 1 yendo, 2 dentro del destino, 3 regresando
  double wait;
  final double speed;
  final Color skin, shirt;
  _Walker(super.x, super.y, this.homeId, this.speed, this.skin, this.shirt)
      : state = 0,
        wait = 0;
}

class _Truck extends _Mover {
  final int stationId;
  List<int> route = [];
  bool home = true;
  double wait;
  _Truck(this.stationId, super.x, super.y, this.wait);
}

class CityMapState extends State<CityMap> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final TransformationController _zoom = TransformationController();
  final _rnd = Random();
  final _clock = Stopwatch()..start();
  double _last = 0;
  bool _fitted = false;
  Size _viewport = Size.zero;

  List<_Walker> _walkers = [];
  List<_Truck> _trucks = [];
  _Walker? _mayor;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _zoom.dispose();
    super.dispose();
  }

  double get _mapW => (widget.mapSize * tile).toDouble();
  double get _mapH => (widget.mapSize * tile + _topPad).toDouble();

  Map<int, Placed> get _byId => {for (final b in widget.buildings) b.id: b};

  /// Puerta de una construcción: abajo al centro de su cuadro.
  Offset _door(Placed b) => Offset(b.x * tile + 9.0, b.y * tile + _topPad + 17.0);

  // ---------- vecinos ----------

  void _sync() {
    final sig = '${widget.population}|${widget.mapSize}|'
        '${widget.buildings.map((b) => '${b.id}:${b.x},${b.y}').join(';')}';
    if (sig == _signature) return;
    _signature = sig;
    final byId = _byId;
    final homes = widget.buildings.where((b) => (b.kind.capacity['vivienda'] ?? 0) > 0).toList();
    final hogar = widget.buildings.where((b) => b.type == 'hogar');

    // Alcalde: vive en su casa y siempre está afuera paseando.
    if (hogar.isNotEmpty) {
      final home = hogar.first;
      final d = _door(home);
      final keep = _mayor;
      final keepDest = keep?.destId;
      _mayor = _Walker(keep?.x ?? d.dx, keep?.y ?? d.dy, home.id, 0.35, Color(widget.avatar.skin),
          Color(widget.avatar.shirt))
        ..state = 1
        ..destId = (keepDest != null && byId.containsKey(keepDest)) ? keepDest : home.id;
    } else {
      _mayor = null;
    }

    // Vecinos repartidos según el cupo de cada casa.
    final count = min(max(0, widget.population - 1), 60);
    final slots = <int>[];
    for (final h in homes) {
      final cap = h.kind.capacity['vivienda']!;
      for (var i = 0; i < cap; i++) {
        if (h.type != 'hogar') slots.add(h.id);
      }
    }
    final old = {for (final w in _walkers) w.homeId: w};
    _walkers = [];
    for (var i = 0; i < count && i < slots.length; i++) {
      final home = byId[slots[i]]!;
      final d = _door(home);
      final prev = old[home.id];
      _walkers.add(_Walker(d.dx, d.dy, home.id, 0.18 + _rnd.nextDouble() * 0.2,
          skinColors[_rnd.nextInt(skinColors.length)], clothColors[_rnd.nextInt(clothColors.length)])
        ..wait = prev == null ? _rnd.nextDouble() * 6 : _rnd.nextDouble() * 3);
    }

    // Un camión por cada estación de basura.
    final stations = widget.buildings.where((b) => b.type == 'basura').toList();
    final oldTrucks = {for (final t in _trucks) t.stationId: t};
    _trucks = [
      for (final s in stations)
        oldTrucks[s.id] ?? _Truck(s.id, _door(s).dx, _door(s).dy, 3 + _rnd.nextDouble() * 4),
    ];
  }

  /// Avanza hacia el punto: primero en horizontal y luego en vertical. Regresa true al llegar.
  bool _stepTo(_Mover who, Offset target, double step) {
    double x = who.x, y = who.y;
    if ((x - target.dx).abs() > 0.5) {
      x += (target.dx - x).sign * min(step, (target.dx - x).abs());
    } else if ((y - target.dy).abs() > 0.5) {
      x = target.dx;
      y += (target.dy - y).sign * min(step, (target.dy - y).abs());
    } else {
      who.x = target.dx;
      who.y = target.dy;
      return true;
    }
    who.x = x;
    who.y = y;
    return false;
  }

  int? _randomDestination(int homeId) {
    final places = widget.buildings
        .where((b) => b.id != homeId && (b.kind.capacity['vivienda'] ?? 0) == 0)
        .toList();
    if (places.isEmpty) return null;
    return places[_rnd.nextInt(places.length)].id;
  }

  void _tick() {
    final now = _clock.elapsedMilliseconds / 1000;
    final dt = min(0.1, now - _last);
    _last = now;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final byId = _byId;
    final night = isNightAt(DateTime.now());
    final frames = dt * 60;

    for (final w in _walkers) {
      final home = byId[w.homeId];
      if (home == null) continue;
      switch (w.state) {
        case 0: // en casa
          if (night) break;
          w.wait -= dt;
          if (w.wait <= 0) {
            w.destId = _randomDestination(w.homeId);
            if (w.destId != null) {
              final out = _door(home);
              w.x = out.dx;
              w.y = out.dy;
              w.state = 1;
            } else {
              w.wait = 5;
            }
          }
          break;
        case 1: // yendo
          final going = byId[w.destId];
          if (going == null || night) {
            w.state = 3;
            break;
          }
          if (_stepTo(w, _door(going), w.speed * frames)) {
            w.state = 2;
            w.wait = 4 + _rnd.nextDouble() * 8;
          }
          break;
        case 2: // dentro del destino
          w.wait -= dt;
          if (w.wait <= 0 || night) {
            final inside = byId[w.destId];
            if (inside != null) {
              final d = _door(inside);
              w.x = d.dx;
              w.y = d.dy;
            }
            w.state = 3;
          }
          break;
        case 3: // regresando a casa
          if (_stepTo(w, _door(home), w.speed * frames)) {
            w.state = 0;
            w.wait = 3 + _rnd.nextDouble() * 10;
          }
          break;
      }
    }

    final m = _mayor;
    if (m != null) {
      final dest = byId[m.destId];
      if (dest == null) {
        m.destId = m.homeId;
      } else if (_stepTo(m, _door(dest), m.speed * frames)) {
        m.wait -= dt;
        if (m.wait <= 0) {
          m.wait = 2 + _rnd.nextDouble() * 4;
          m.destId = night ? m.homeId : (_rnd.nextInt(3) == 0 ? m.homeId : (_randomDestination(m.homeId) ?? m.homeId));
        }
      }
    }

    for (final t in _trucks) {
      final station = byId[t.stationId];
      if (station == null) continue;
      if (t.home) {
        t.wait -= dt;
        if (t.wait <= 0) {
          final stops = widget.buildings.where((b) => b.id != t.stationId).toList()..shuffle(_rnd);
          t.route = [for (final b in stops.take(5)) b.id, t.stationId];
          t.home = false;
        }
        continue;
      }
      if (t.route.isEmpty) {
        t.home = true;
        t.wait = 8 + _rnd.nextDouble() * 10;
        continue;
      }
      final target = byId[t.route.first];
      if (target == null) {
        t.route.removeAt(0);
        continue;
      }
      if (_stepTo(t, _door(target), 0.5 * frames)) t.route.removeAt(0);
    }
  }

  // ---------- zoom ----------

  void _fit(Size viewport) {
    _viewport = viewport;
    if (_fitted || viewport.width == 0) return;
    _fitted = true;
    final s = min(viewport.width / (_mapW * _px), viewport.height / (_mapH * _px));
    final dx = (viewport.width - _mapW * _px * s) / 2;
    final dy = (viewport.height - _mapH * _px * s) / 2;
    _zoom.value = Matrix4.translationValues(dx, dy, 0).multiplied(Matrix4.diagonal3Values(s, s, 1));
  }

  void zoomBy(double factor) {
    final current = _zoom.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.2, 5.0);
    final f = target / current;
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    _zoom.value = Matrix4.translationValues(c.dx, c.dy, 0)
        .multiplied(Matrix4.diagonal3Values(f, f, 1))
        .multiplied(Matrix4.translationValues(-c.dx, -c.dy, 0))
        .multiplied(_zoom.value);
  }

  void refit() {
    _fitted = false;
    _fit(_viewport);
  }

  @override
  void didUpdateWidget(CityMap old) {
    super.didUpdateWidget(old);
    if (old.mapSize != widget.mapSize) refit();
  }

  void _onTap(TapUpDetails d) {
    final cb = widget.onTapTile;
    if (cb == null) return;
    final lx = d.localPosition.dx / _px;
    final ly = d.localPosition.dy / _px - _topPad;
    if (lx < 0 || ly < 0) return;
    final x = (lx / tile).floor();
    final y = (ly / tile).floor();
    if (x >= widget.mapSize || y >= widget.mapSize) return;
    cb(x, y);
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final map = GestureDetector(
      onTapUp: widget.interactive ? _onTap : null,
      child: CustomPaint(
        size: Size(_mapW * _px, _mapH * _px),
        painter: _CityPainter(
          state: this,
          repaint: _ticker,
        ),
      ),
    );
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit(size);
      });
      return ClipRect(
        child: InteractiveViewer(
          transformationController: _zoom,
          constrained: false,
          minScale: 0.2,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(400),
          panEnabled: widget.interactive,
          scaleEnabled: widget.interactive,
          child: map,
        ),
      );
    });
  }
}

class _CityPainter extends CustomPainter {
  final CityMapState state;
  _CityPainter({required this.state, required Listenable repaint}) : super(repaint: repaint);

  static const _grass = Color(0xFF3F6A35);
  static const _grassAlt = Color(0xFF43703A);
  static const _tuft = Color(0xFF4F7F40);
  static const _ink = Color(0xFF0F0B14);
  static const _gold = Color(0xFFF4B942);

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    final p = Px(canvas, s: _px);
    final n = w.mapSize;
    final mapW = n * tile;

    // Suelo
    p.r(_grass, 0, 0, mapW, n * tile + _topPad);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final ox = x * tile, oy = y * tile + _topPad;
        if ((x + y).isOdd) p.r(_grassAlt, ox, oy, tile, tile);
        final h = (x * 31 + y * 17) % 7;
        if (h < 3) p.r(_tuft, ox + 3 + h * 4, oy + 5 + h * 3, 1, 2);
      }
    }

    // Cuadrícula al colocar o mover
    final editing = w.mode != CityMode.view;
    if (editing) {
      final line = Paint()..color = const Color(0x40FFFFFF);
      for (var i = 0; i <= n; i++) {
        canvas.drawRect(Rect.fromLTWH(i * tile * _px, _topPad * _px, 1, n * tile * _px), line);
        canvas.drawRect(Rect.fromLTWH(0, (i * tile + _topPad) * _px, mapW * _px, 1), line);
      }
      for (final b in w.buildings) {
        if (b.id == w.movingId) continue;
        p.r(const Color(0x30E3655B), b.x * tile, b.y * tile + _topPad, tile, tile);
      }
    }

    // Construcciones, de atrás hacia adelante
    final sorted = [...w.buildings]..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    final lights = <Rect>[];
    for (final b in sorted) {
      final ox = b.x * tile, oy = b.y * tile + _topPad;
      if (b.id == w.movingId) {
        canvas.saveLayer(null, Paint()..color = const Color(0x80FFFFFF));
        drawBuildingArt(p, b.kind, Color(b.color), ox.toDouble(), oy.toDouble());
        canvas.restore();
        continue;
      }
      final wins = drawBuildingArt(p, b.kind, Color(b.color), ox.toDouble(), oy.toDouble());
      for (final r in wins) {
        lights.add(r.shift(Offset(ox.toDouble(), oy.toDouble())));
      }
      if (b.id == w.selectedId) {
        final sel = Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px;
        canvas.drawRect(Rect.fromLTWH(ox * _px, oy * _px, tile * _px, tile * _px).deflate(_px / 2), sel);
      }
    }

    // Vecinos, camiones y alcalde
    for (final wk in state._walkers) {
      if (wk.state == 0 || wk.state == 2) continue;
      _person(p, wk.x, wk.y, wk.skin, wk.shirt);
    }
    for (final t in state._trucks) {
      if (t.home) continue;
      final station = state._byId[t.stationId];
      _truck(p, t.x, t.y, Color(station?.color ?? 0xFF5F9C6A));
    }
    final m = state._mayor;
    if (m != null) _mayorSprite(p, m.x, m.y, w.avatar);

    // Día y noche
    final dark = darknessAt(DateTime.now());
    if (dark > 0) {
      final overlay = Color.lerp(const Color(0x40FF8A50), const Color(0x990B1030), dark)!;
      canvas.drawRect(Offset.zero & size, Paint()..color = overlay);
      if (dark > 0.4) {
        final glow = Paint()..color = litColor.withValues(alpha: min(1.0, dark * 1.2));
        for (var i = 0; i < lights.length; i++) {
          if (i % 5 == 3) continue; // algunas ventanas apagadas
          final r = lights[i];
          canvas.drawRect(Rect.fromLTWH(r.left * _px, r.top * _px, r.width * _px, r.height * _px), glow);
        }
      }
    }
  }

  void _person(Px p, double fx, double fy, Color skin, Color shirt) {
    final x = fx.roundToDouble() - 1, y = fy.roundToDouble() - 5;
    p.r(skin, x, y, 2, 2);
    p.r(shirt, x, y + 2, 2, 2);
    final step = (fx / 2).floor().isOdd || (fy / 2).floor().isOdd ? 1 : 0;
    p.r(_ink, x + step, y + 4, 1, 1);
  }

  void _mayorSprite(Px p, double fx, double fy, Avatar a) {
    final x = fx.roundToDouble() - 2, y = fy.roundToDouble() - 8;
    p.r(Color(a.hairColor), x, y, 4, 1);
    p.r(Color(a.skin), x, y + 1, 4, 2);
    p.r(_ink, x + 1, y + 2);
    p.r(_ink, x + 3, y + 2);
    p.r(Color(a.shirt), x, y + 3, 4, 3);
    p.r(Color(a.pants), x, y + 6, 4, 1);
    final step = (fx / 2).floor().isOdd || (fy / 2).floor().isOdd;
    p.r(_ink, x + (step ? 0 : 1), y + 7, 1, 1);
    p.r(_ink, x + (step ? 3 : 2), y + 7, 1, 1);
    p.r(_gold, x + 1, y - 2, 2, 1);
  }

  void _truck(Px p, double fx, double fy, Color c) {
    final x = fx.roundToDouble() - 4, y = fy.roundToDouble() - 5;
    p.r(c, x, y, 5, 4);
    p.r(Color.lerp(c, Colors.black, 0.3)!, x + 1, y + 1, 3, 1);
    p.r(c, x + 5, y + 1, 3, 3);
    p.r(glassColor, x + 6, y + 1, 1, 1);
    p.r(_ink, x + 1, y + 4, 2, 1);
    p.r(_ink, x + 5, y + 4, 2, 1);
  }

  @override
  bool shouldRepaint(_CityPainter old) => true;
}
