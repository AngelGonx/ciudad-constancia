import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/roads.dart';
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

/// Algo que se mueve por el mapa siguiendo puntos (en píxeles lógicos).
class _Mover {
  double x, y;
  List<Offset> path = [];
  _Mover(this.x, this.y);

  /// Avanza [step] píxeles por el camino. Regresa true cuando ya no quedan puntos.
  bool advance(double step) {
    var left = step;
    while (path.isNotEmpty && left > 0) {
      final t = path.first;
      final dx = t.dx - x, dy = t.dy - y;
      final dist = dx.abs() + dy.abs();
      if (dist <= left) {
        x = t.dx;
        y = t.dy;
        left -= dist;
        path.removeAt(0);
      } else {
        // Movimiento en un solo eje a la vez, como en una cuadrícula.
        if (dx.abs() > 0.01) {
          x += dx.sign * min(left, dx.abs());
        } else {
          y += dy.sign * min(left, dy.abs());
        }
        left = 0;
      }
    }
    return path.isEmpty;
  }
}

class _Walker extends _Mover {
  final int homeId;
  int? destId;
  int state; // 0 en casa, 1 yendo, 2 dentro del destino, 3 regresando
  double wait;
  final double speed;
  final double side; // de qué banqueta camina
  final Color skin, shirt;
  _Walker(super.x, super.y, this.homeId, this.speed, this.side, this.skin, this.shirt)
      : state = 0,
        wait = 0;
}

class _Vehicle extends _Mover {
  final int baseId; // estación del camión o primera parada del autobús
  bool parked = true;
  double wait;
  int stopIndex = 0;
  _Vehicle(this.baseId, super.x, super.y, this.wait);
}

class CityMapState extends State<CityMap> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final TransformationController _zoom = TransformationController();
  final _rnd = Random();
  final _clock = Stopwatch()..start();
  double _last = 0;
  bool _fitted = false;
  Size _viewport = Size.zero;

  RoadNetwork? _net;
  String _netSig = '';
  List<_Walker> _walkers = [];
  List<_Vehicle> _trucks = [];
  _Vehicle? _bus;
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

  RoadNetwork get net {
    final sig = RoadNetwork.signature(widget.buildings, widget.mapSize);
    if (_net == null || sig != _netSig) {
      _net = RoadNetwork.build(widget.buildings, widget.mapSize);
      _netSig = sig;
    }
    return _net!;
  }

  /// Centro de un cuadro, en píxeles lógicos.
  Offset _center(int k) {
    final n = net;
    return Offset(n.xOf(k) * tile + 9.0, n.yOf(k) * tile + _topPad + 9.0);
  }

  /// Puntos para ir de la entrada de [from] a la entrada de [to]. Con [side] se va por la banqueta.
  List<Offset>? _route(int fromId, int toId, double side) {
    final n = net;
    final a = n.entrances[fromId], b = n.entrances[toId];
    if (a == null || b == null) return null;
    final tiles = n.path(a, b);
    if (tiles == null) return null;
    final off = Offset(side * 6, side * 6);
    return [for (final k in tiles) _center(k) + off];
  }

  Offset? _entrancePoint(int id, double side) {
    final k = net.entrances[id];
    if (k == null) return null;
    return _center(k) + Offset(side * 6, side * 6);
  }

  // ---------- vecinos y vehículos ----------

  void _sync() {
    final sig = '${widget.population}|${RoadNetwork.signature(widget.buildings, widget.mapSize)}';
    if (sig == _signature) return;
    _signature = sig;
    final byId = _byId;
    final homes = widget.buildings.where((b) => (b.kind.capacity['vivienda'] ?? 0) > 0).toList();
    final hogar = widget.buildings.where((b) => b.type == 'hogar');

    // Alcalde: vive en su casa y siempre está afuera paseando.
    if (hogar.isNotEmpty) {
      final home = hogar.first;
      final start = _entrancePoint(home.id, 1) ?? Offset(home.x * tile + 9.0, home.y * tile + _topPad + 17.0);
      _mayor = _Walker(start.dx, start.dy, home.id, 0.35, 1, Color(widget.avatar.skin), Color(widget.avatar.shirt))
        ..state = 1
        ..wait = 1;
    } else {
      _mayor = null;
    }

    // Vecinos repartidos según el cupo de cada casa.
    final count = min(max(0, widget.population - 1), 60);
    final slots = <int>[];
    for (final h in homes) {
      if (h.type == 'hogar') continue;
      final cap = h.kind.capacity['vivienda']!;
      for (var i = 0; i < cap; i++) {
        slots.add(h.id);
      }
    }
    _walkers = [];
    for (var i = 0; i < count && i < slots.length; i++) {
      final home = byId[slots[i]]!;
      _walkers.add(_Walker(0, 0, home.id, 0.18 + _rnd.nextDouble() * 0.2, _rnd.nextBool() ? 1 : -1,
          skinColors[_rnd.nextInt(skinColors.length)], clothColors[_rnd.nextInt(clothColors.length)])
        ..wait = _rnd.nextDouble() * 6);
    }

    // Un camión de basura por estación.
    _trucks = [];
    for (final s in widget.buildings.where((b) => b.type == 'basura')) {
      final p = _entrancePoint(s.id, 0);
      if (p != null) _trucks.add(_Vehicle(s.id, p.dx, p.dy, 3 + _rnd.nextDouble() * 4));
    }

    // Autobús si hay al menos dos paradas.
    final stops = widget.buildings.where((b) => b.type == 'parada').toList();
    if (stops.length >= 2) {
      final p = _entrancePoint(stops.first.id, 0);
      _bus = p == null ? null : (_Vehicle(stops.first.id, p.dx, p.dy, 2)..parked = false);
    } else {
      _bus = null;
    }
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
    final night = isNightAt(DateTime.now());
    final frames = dt * 60;

    for (final w in _walkers) {
      switch (w.state) {
        case 0: // en casa
          if (night) break;
          w.wait -= dt;
          if (w.wait > 0) break;
          final dest = _randomDestination(w.homeId);
          final route = dest == null ? null : _route(w.homeId, dest, w.side);
          if (route == null || route.isEmpty) {
            w.wait = 6;
            break;
          }
          w.destId = dest;
          w.x = route.first.dx;
          w.y = route.first.dy;
          w.path = route;
          w.state = 1;
          break;
        case 1: // yendo
          if (w.advance(w.speed * frames)) {
            w.state = 2;
            w.wait = 4 + _rnd.nextDouble() * 8;
          }
          break;
        case 2: // dentro del destino
          w.wait -= dt;
          if (w.wait > 0 && !night) break;
          final back = w.destId == null ? null : _route(w.destId!, w.homeId, w.side);
          if (back == null || back.isEmpty) {
            w.state = 0;
            w.wait = 5;
            break;
          }
          w.x = back.first.dx;
          w.y = back.first.dy;
          w.path = back;
          w.state = 3;
          break;
        case 3: // regresando a casa
          if (w.advance(w.speed * (night ? 1.6 : 1) * frames)) {
            w.state = 0;
            w.wait = 3 + _rnd.nextDouble() * 10;
          }
          break;
      }
    }

    final m = _mayor;
    if (m != null && m.advance(m.speed * frames)) {
      m.wait -= dt;
      if (m.wait <= 0) {
        m.wait = 2 + _rnd.nextDouble() * 4;
        final from = m.destId ?? m.homeId;
        final next = night || _rnd.nextInt(3) == 0 ? m.homeId : (_randomDestination(m.homeId) ?? m.homeId);
        final route = _route(from, next, 1);
        if (route != null) {
          m.path = route;
          m.destId = next;
        }
      }
    }

    for (final t in _trucks) {
      if (t.parked) {
        t.wait -= dt;
        if (t.wait > 0) continue;
        // Recorrido: cinco construcciones al azar y de regreso a la estación.
        final stops = widget.buildings.where((b) => b.id != t.baseId).toList()..shuffle(_rnd);
        var from = t.baseId;
        final path = <Offset>[];
        for (final s in [...stops.take(5).map((b) => b.id), t.baseId]) {
          final leg = _route(from, s, 0);
          if (leg == null) continue;
          path.addAll(leg);
          from = s;
        }
        if (path.isEmpty) {
          t.wait = 10;
          continue;
        }
        t.path = path;
        t.parked = false;
      } else if (t.advance(0.45 * frames)) {
        t.parked = true;
        t.wait = 8 + _rnd.nextDouble() * 10;
      }
    }

    final bus = _bus;
    if (bus != null) {
      final stops = widget.buildings.where((b) => b.type == 'parada').toList();
      if (bus.path.isEmpty) {
        bus.wait -= dt;
        if (bus.wait <= 0 && stops.length >= 2) {
          final from = stops[bus.stopIndex % stops.length].id;
          bus.stopIndex = (bus.stopIndex + 1) % stops.length;
          final to = stops[bus.stopIndex].id;
          final leg = _route(from, to, 0);
          if (leg != null) bus.path = leg;
          bus.wait = 1.5;
        }
      } else {
        bus.advance(0.4 * frames);
      }
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
        painter: _CityPainter(state: this, repaint: _ticker),
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
  static const _asphalt = Color(0xFF4A4552);
  static const _curb = Color(0xFFB9B2A6);
  static const _lane = Color(0xFFE8D27A);
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

    // Calles con banqueta y líneas
    final net = state.net;
    for (final k in net.roads) {
      final x = net.xOf(k), y = net.yOf(k);
      final ox = x * tile, oy = y * tile + _topPad;
      final up = net.isRoad(x, y - 1), down = net.isRoad(x, y + 1);
      final left = net.isRoad(x - 1, y), right = net.isRoad(x + 1, y);
      p.r(_asphalt, ox, oy, tile, tile);
      if (!up) p.r(_curb, ox, oy, tile, 3);
      if (!down) p.r(_curb, ox, oy + tile - 3, tile, 3);
      if (!left) p.r(_curb, ox, oy, 3, tile);
      if (!right) p.r(_curb, ox + tile - 3, oy, 3, tile);
      final horizontal = (left || right) && !up && !down;
      final vertical = (up || down) && !left && !right;
      if (horizontal) {
        p.r(_lane, ox + 2, oy + 8, 5, 1);
        p.r(_lane, ox + 11, oy + 8, 5, 1);
      } else if (vertical) {
        p.r(_lane, ox + 8, oy + 2, 1, 5);
        p.r(_lane, ox + 8, oy + 11, 1, 5);
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

    // Vehículos, vecinos y alcalde
    final byId = state._byId;
    for (final t in state._trucks) {
      if (t.parked) continue;
      _vehicle(p, t.x, t.y, Color(byId[t.baseId]?.color ?? 0xFF5F9C6A), bus: false);
    }
    final bus = state._bus;
    if (bus != null) _vehicle(p, bus.x, bus.y, Color(byId[bus.baseId]?.color ?? 0xFFF4B942), bus: true);
    for (final wk in state._walkers) {
      if (wk.state == 0 || wk.state == 2) continue;
      _person(p, wk.x, wk.y, wk.skin, wk.shirt);
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

  void _vehicle(Px p, double fx, double fy, Color c, {required bool bus}) {
    final len = bus ? 10 : 8;
    final x = fx.roundToDouble() - len / 2, y = fy.roundToDouble() - 3;
    final dark = Color.lerp(c, Colors.black, 0.3)!;
    if (bus) {
      p.r(c, x, y, len, 5);
      for (var i = 1; i < len - 1; i += 2) {
        p.r(glassColor, x + i, y + 1, 1, 2);
      }
      p.r(dark, x, y + 4, len, 1);
    } else {
      p.r(c, x, y, 5, 4);
      p.r(dark, x + 1, y + 1, 3, 1);
      p.r(c, x + 5, y + 1, 3, 3);
      p.r(glassColor, x + 6, y + 1, 1, 1);
    }
    p.r(_ink, x + 1, y + 5, 2, 1);
    p.r(_ink, x + len - 3, y + 5, 2, 1);
  }

  @override
  bool shouldRepaint(_CityPainter old) => true;
}
