import 'package:flutter/material.dart';

import '../game/rules.dart';
import 'sprites.dart';

/// Dibujo de construcciones en un lote de 18 × 18 píxeles lógicos.
/// Las construcciones altas pueden sobresalir un poco hacia arriba.

const Color _ink = Color(0xFF0F0B14);
const Color glassColor = Color(0xFF9FD8FF);
const Color litColor = Color(0xFFFFE28A);
const Color _door = Color(0xFF6B3F2A);
const Color _gold = Color(0xFFF4B942);
const Color _white = Color(0xFFF3EEE4);
const Color _gray = Color(0xFF8C8F9C);
const Color _leaf = Color(0xFF3F7A37);
const Color _leafLight = Color(0xFF5AA04A);
const Color _trunk = Color(0xFF6B4A3A);
const Color _water = Color(0xFF5AA0D8);
const Color _red = Color(0xFFD24C4C);

Color shade(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;
Color tintLight(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

class _Art {
  final Px p;
  final Color base;
  final Color accent;
  final int floors;
  final List<String> extras;
  final List<Rect> windows;
  _Art(this.p, this.base, this.accent, this.floors, this.extras, this.windows);

  bool has(String e) => extras.contains(e);
  void r(Color c, num x, num y, [num w = 1, num h = 1]) => p.r(c, x, y, w, h);

  /// Ventana: se guarda para encenderla de noche.
  void win(num x, num y, [num w = 2, num h = 2]) {
    p.r(glassColor, x, y, w, h);
    windows.add(Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()));
  }

  void roof(Color c, int x, int y, int w) => p.roof(c, x, y, w);
}

/// Dibuja [type] en el lote cuyo borde superior izquierdo es (x, y), con el color principal [base].
/// Regresa las ventanas (en coordenadas del lote) para iluminarlas de noche.
List<Rect> drawBuildingArt(Px base, BuildingType type, Color main, double x, double y) {
  final p = Px(base.canvas, ox: base.ox + x * base.s, oy: base.oy + y * base.s, s: base.s);
  final windows = <Rect>[];
  final a = _Art(p, main, Color(type.accent), type.floors, type.extras, windows);
  switch (type.art) {
    case 'home':
      _home(a);
      break;
    case 'house':
      _house(a);
      break;
    case 'cabin':
      _cabin(a);
      break;
    case 'tower':
      _tower(a);
      break;
    case 'shop':
      _shop(a);
      break;
    case 'market':
      _market(a);
      break;
    case 'factory':
      _factory(a);
      break;
    case 'civic':
      _civic(a);
      break;
    case 'tank':
      _tank(a);
      break;
    case 'waterplant':
      _waterPlant(a);
      break;
    case 'watertower':
      _waterTower(a);
      break;
    case 'pole':
      _pole(a);
      break;
    case 'solar':
      _solar(a);
      break;
    case 'substation':
      _substation(a);
      break;
    case 'wind':
      _wind(a);
      break;
    case 'bins':
      _bins(a);
      break;
    case 'garage':
      _garage(a);
      break;
    case 'recycle':
      _recycle(a);
      break;
    case 'dump':
      _dump(a);
      break;
    case 'tree':
      _tree(a, 5, 4);
      _tree(a, 11, 8);
      break;
    case 'fountain':
      _fountain(a);
      break;
    case 'park':
      _park(a);
      break;
    case 'court':
      _court(a);
      break;
    case 'kiosk':
      _kiosk(a);
      break;
    case 'palace':
      _palace(a);
      break;
    case 'busstop':
      _busStop(a);
      break;
  }
  return windows;
}

// ---------------- Vivienda ----------------

void _home(_Art a) {
  a.r(a.base, 3, 11, 12, 7);
  a.roof(a.accent, 2, 10, 14);
  a.r(_door, 8, 14, 2, 4);
  a.win(4, 13);
  a.win(12, 13);
  a.r(const Color(0xFFDDDDDD), 16, 2, 1, 9);
  a.r(_gold, 17, 2, 1, 2);
}

void _house(_Art a) {
  final wall = a.base;
  final roofC = a.accent;
  if (a.floors >= 2) {
    a.r(wall, 3, 6, 12, 12);
    a.r(shade(wall, 0.15), 3, 6, 12, 1);
    a.r(roofC, 2, 4, 14, 2);
    if (a.has('twin')) {
      a.r(shade(wall, 0.2), 8, 6, 2, 12);
      a.win(4, 8);
      a.win(12, 8);
      a.win(4, 12);
      a.win(12, 12);
      a.r(_door, 6, 15, 2, 3);
      a.r(_door, 10, 15, 2, 3);
    } else {
      a.win(5, 8);
      a.win(11, 8);
      a.win(5, 12);
      a.win(11, 12);
      a.r(_door, 8, 15, 2, 3);
    }
  } else {
    a.r(wall, 3, 11, 12, 7);
    a.roof(roofC, 2, 10, 14);
    if (a.has('chimney')) a.r(shade(roofC, 0.3), 11, 5, 2, 3);
    a.r(_door, 7, 14, 2, 4);
    a.win(4, 13);
    a.win(11, 13);
  }
  if (a.has('garden')) {
    a.r(_leaf, 0, 15, 2, 3);
    a.r(_leaf, 16, 15, 2, 3);
    a.r(_red, 0, 15);
    a.r(_gold, 17, 16);
  }
}

void _cabin(_Art a) {
  a.r(a.base, 3, 10, 12, 8);
  for (var y = 11; y < 18; y += 2) {
    a.r(shade(a.base, 0.25), 3, y, 12, 1);
  }
  a.roof(a.accent, 2, 9, 14);
  a.r(_door, 8, 13, 2, 5);
  a.win(4, 12);
  a.win(12, 12);
  a.r(_gray, 12, 3, 2, 3);
}

void _tower(_Art a) {
  final n = a.floors;
  final h = 4 + n * 3;
  final top = 18 - h;
  final glass = a.has('glass');
  a.r(a.base, 2, top, 14, h);
  a.r(a.accent, 2, top, 14, 1);
  for (var i = 0; i < n; i++) {
    final wy = top + 2 + i * 3;
    if (glass) {
      for (final x in [3, 7, 11]) {
        a.win(x, wy, 3, 2);
      }
    } else {
      for (final x in [4, 8, 12]) {
        if (i == n - 1 && x == 8) continue; // espacio para la puerta
        a.win(x, wy);
      }
    }
  }
  a.r(_ink, 8, 15, 2, 3);
  if (a.has('antenna')) {
    a.r(_gray, 8, top - 4, 1, 4);
    a.r(_red, 8, top - 5);
  }
  if (a.has('roofgarden')) {
    a.r(_leaf, 3, top - 1, 12, 1);
    a.r(_leafLight, 4, top - 2, 2, 1);
    a.r(_leafLight, 11, top - 2, 2, 1);
  }
}

// ---------------- Tiendas y empleo ----------------

void _shop(_Art a) {
  a.r(a.base, 2, 9, 14, 9);
  a.r(shade(a.base, 0.2), 2, 9, 14, 1);
  if (a.has('awning')) {
    for (var i = 0; i < 7; i++) {
      a.r(i.isOdd ? _white : a.accent, 2 + i * 2, 8, 2, 2);
    }
  } else {
    a.r(a.accent, 2, 8, 14, 1);
  }
  if (a.has('sign')) {
    a.r(_white, 4, 10, 10, 2);
    a.r(a.accent, 5, 10, 8, 1);
  }
  a.win(4, 12, 4, 3);
  a.r(_door, 10, 13, 3, 5);
  if (a.has('steam')) {
    a.r(const Color(0xFFDDDDDD), 6, 5, 1, 2);
    a.r(const Color(0xFFDDDDDD), 7, 3, 1, 2);
  }
  // Letrero con dibujo sobre el techo
  final icon = ['bread', 'cross', 'cup', 'taco', 'book'].where(a.has);
  if (icon.isNotEmpty) {
    a.r(_ink, 6, 2, 6, 6);
    a.r(_white, 7, 3, 4, 4);
    switch (icon.first) {
      case 'bread':
        a.r(const Color(0xFFC98A3C), 7, 4, 4, 2);
        a.r(const Color(0xFFE8B86A), 8, 4, 2, 1);
        break;
      case 'cross':
        a.r(const Color(0xFF3E8C56), 8, 3, 2, 4);
        a.r(const Color(0xFF3E8C56), 7, 4, 4, 2);
        break;
      case 'cup':
        a.r(const Color(0xFF6B3F2A), 7, 4, 3, 3);
        a.r(const Color(0xFF6B3F2A), 10, 5);
        break;
      case 'taco':
        a.r(const Color(0xFFF2C94C), 7, 4, 4, 2);
        a.r(const Color(0xFF3E8C56), 8, 4, 2, 1);
        a.r(_red, 9, 4);
        break;
      case 'book':
        a.r(const Color(0xFF4F6FD8), 7, 3, 4, 4);
        a.r(_white, 8, 4, 2, 2);
        break;
    }
  }
  a.r(_ink, 8, 7, 2, 1);
}

void _market(_Art a) {
  const stripes = [Color(0xFFD24C4C), Color(0xFFF4B942), Color(0xFF3E8C56)];
  for (var i = 0; i < 8; i++) {
    a.r(stripes[i % 3], 1 + i * 2, 7, 2, 3);
  }
  a.r(a.base, 2, 10, 14, 8);
  a.r(_ink, 4, 12, 3, 6);
  a.r(_ink, 11, 12, 3, 6);
  a.r(const Color(0xFF8A5A3A), 7, 14, 4, 1);
  a.r(_red, 7, 13);
  a.r(_gold, 9, 13);
}

void _factory(_Art a) {
  a.r(a.base, 1, 9, 13, 9);
  for (var k = 0; k < 3; k++) {
    a.r(shade(a.base, 0.25), 1 + k * 4, 7, 3, 2);
    a.r(shade(a.base, 0.25), 1 + k * 4, 6, 1, 1);
  }
  a.r(const Color(0xFF6B4A3A), 14, 3, 3, 15);
  a.r(const Color(0xFFCCCCCC), 15, 1, 2, 1);
  a.r(const Color(0xFFBBBBBB), 16, 0, 2, 1);
  for (final x in [3, 7, 11]) {
    a.win(x, 12);
  }
  a.r(_ink, 6, 15, 3, 3);
}

// ---------------- Escuelas y edificios públicos ----------------

void _civic(_Art a) {
  final h = 6 + a.floors * 3;
  final top = 18 - h;
  final right = a.has('playground') ? 12 : 16;
  final width = right - 1;
  a.r(a.base, 1, top, width, h);
  a.r(a.accent, 1, top - 1, width, 1);
  final cols = a.has('columns');
  for (var i = 0; i < a.floors; i++) {
    final wy = top + 2 + i * 3;
    if (wy > 13) break;
    final xs = right == 16 ? [3, 6, 10, 13] : [3, 9];
    for (final x in xs) {
      if (cols && (x == 6 || x == 10)) continue;
      a.win(x, wy);
    }
  }
  if (cols) {
    for (final x in [5, 7, 10, 12]) {
      a.r(_white, x, top + 1, 1, h - 1);
    }
  }
  final doorX = right == 16 ? 8 : 6;
  a.r(_door, doorX, 14, 2, 4);
  if (a.has('sign')) {
    a.r(_white, 3, top + 1, 12, 2);
    a.r(a.accent, 4, top + 1, 10, 1);
  }
  if (a.has('bell')) {
    a.r(a.base, 7, top - 5, 4, 4);
    a.roof(a.accent, 6, top - 5, 6);
    a.r(_gold, 8, top - 3, 2, 1);
  }
  if (a.has('dome')) {
    a.r(a.accent, 6, top - 2, 6, 1);
    a.r(a.accent, 7, top - 3, 4, 1);
    a.r(a.accent, 8, top - 4, 2, 1);
  }
  if (a.has('flag')) {
    a.r(const Color(0xFFDDDDDD), 16, top - 6, 1, 6);
    a.r(const Color(0xFF3E8C56), 17, top - 6, 1, 2);
  }
  if (a.has('book')) {
    a.r(const Color(0xFF4F6FD8), 11, 15, 3, 2);
    a.r(_white, 12, 15, 1, 2);
  }
  if (a.has('playground')) {
    a.r(_red, 13, 10, 1, 8);
    a.r(_red, 17, 10, 1, 8);
    a.r(_red, 13, 10, 5, 1);
    a.r(_ink, 15, 11, 1, 3);
    a.r(_gold, 14, 14, 3, 1);
  }
}

// ---------------- Agua ----------------

void _tank(_Art a) {
  a.r(a.base, 4, 2, 10, 7);
  a.r(shade(a.base, 0.3), 4, 2, 10, 1);
  a.r(tintLight(a.base, 0.4), 5, 4, 2, 3);
  a.r(const Color(0xFF555555), 5, 9, 1, 9);
  a.r(const Color(0xFF555555), 12, 9, 1, 9);
  a.r(const Color(0xFF555555), 6, 13, 6, 1);
}

void _waterPlant(_Art a) {
  a.r(a.base, 1, 9, 16, 9);
  a.r(shade(a.base, 0.3), 2, 13, 14, 2);
  a.r(tintLight(a.base, 0.4), 5, 3, 8, 6);
  a.r(shade(a.base, 0.3), 5, 3, 8, 1);
  a.win(3, 10);
  a.win(13, 10);
  a.r(_ink, 7, 15, 3, 3);
}

void _waterTower(_Art a) {
  a.r(const Color(0xFF555555), 6, 8, 1, 10);
  a.r(const Color(0xFF555555), 11, 8, 1, 10);
  a.r(const Color(0xFF555555), 7, 12, 4, 1);
  a.r(a.base, 3, 0, 12, 8);
  a.r(shade(a.base, 0.3), 3, 0, 12, 1);
  a.r(shade(a.base, 0.3), 3, 7, 12, 1);
  a.r(tintLight(a.base, 0.4), 4, 2, 2, 4);
  a.r(_white, 7, 3, 4, 2);
}

// ---------------- Luz ----------------

void _pole(_Art a) {
  a.r(a.base, 8, 1, 2, 17);
  a.r(a.base, 4, 3, 10, 1);
  a.r(_gray, 10, 7, 3, 4);
  a.r(_gold, 4, 2);
  a.r(_gold, 13, 2);
}

void _solar(_Art a) {
  for (final y in [3, 10]) {
    a.r(a.base, 1, y, 16, 6);
    for (var x = 2; x < 16; x += 3) {
      a.r(const Color(0xFF2F4F8F), x, y + 1, 2, 4);
      a.r(const Color(0xFF6F8FCF), x, y + 1, 1, 1);
    }
  }
}

void _substation(_Art a) {
  const steel = Color(0xFF99AAAA);
  const fence = Color(0xFF555555);
  a.r(steel, 4, 2, 1, 11);
  a.r(steel, 13, 2, 1, 11);
  a.r(steel, 2, 4, 5, 1);
  a.r(steel, 11, 4, 5, 1);
  a.r(a.base, 6, 12, 6, 5);
  a.r(_gold, 8, 13, 2, 2);
  a.r(fence, 1, 11, 16, 1);
  a.r(fence, 1, 17, 16, 1);
  for (var x = 1; x < 17; x += 3) {
    a.r(fence, x, 11, 1, 7);
  }
}

void _wind(_Art a) {
  a.r(a.base, 8, 6, 2, 12);
  a.r(_gray, 7, 16, 4, 2);
  a.r(_gray, 8, 4, 2, 2);
  a.r(a.base, 8, 0, 1, 4); // aspas
  a.r(a.base, 10, 5, 5, 1);
  a.r(a.base, 3, 6, 5, 1);
  a.r(_red, 9, 5);
}

// ---------------- Basura ----------------

void _bins(_Art a) {
  final colors = [a.base, shade(a.base, 0.2), tintLight(a.base, 0.25)];
  for (var i = 0; i < 3; i++) {
    final x = 2 + i * 5;
    a.r(colors[i], x, 10, 4, 7);
    a.r(shade(colors[i], 0.3), x - 1, 9, 6, 1);
    a.r(_white, x + 1, 12, 2, 1);
  }
}

void _garage(_Art a) {
  a.r(a.base, 1, 7, 16, 11);
  a.r(shade(a.base, 0.3), 1, 6, 16, 1);
  a.r(_ink, 4, 10, 10, 8);
  for (var y = 11; y < 18; y += 2) {
    a.r(const Color(0xFF2E2A33), 4, y, 10, 1);
  }
  a.r(_white, 6, 8, 6, 1);
}

void _recycle(_Art a) {
  a.r(a.base, 2, 8, 14, 10);
  a.r(shade(a.base, 0.3), 2, 7, 14, 1);
  a.r(_white, 6, 10, 6, 4);
  a.r(const Color(0xFF3E8C56), 7, 11, 4, 2);
  a.win(3, 10);
  a.win(13, 10);
  a.r(_ink, 8, 15, 2, 3);
}

void _dump(_Art a) {
  a.r(a.base, 1, 8, 13, 10);
  a.r(shade(a.base, 0.3), 1, 7, 13, 1);
  a.r(const Color(0xFF6B4A3A), 14, 2, 3, 16);
  a.r(const Color(0xFFCCCCCC), 14, 0, 2, 1);
  a.r(_ink, 4, 12, 6, 6);
  a.win(11, 10);
  a.r(const Color(0xFF3E8C56), 3, 9, 3, 2);
}

// ---------------- Recreación ----------------

void _tree(_Art a, int x, int y) {
  a.r(_trunk, x + 1, y + 6, 2, 4);
  a.r(a.base, x - 1, y, 6, 6);
  a.r(tintLight(a.base, 0.25), x, y + 1, 3, 2);
}

void _fountain(_Art a) {
  a.r(a.base, 2, 9, 14, 8);
  a.r(_water, 3, 10, 12, 6);
  a.r(a.base, 8, 6, 2, 8);
  a.r(const Color(0xFF8FC4EA), 7, 4, 4, 2);
  a.r(const Color(0xFF8FC4EA), 6, 6, 1, 2);
  a.r(const Color(0xFF8FC4EA), 11, 6, 1, 2);
}

void _park(_Art a) {
  a.r(a.base, 0, 14, 18, 4);
  _tree(a, 3, 3);
  a.r(const Color(0xFF8A5A3A), 11, 13, 5, 1);
  a.r(const Color(0xFF8A5A3A), 11, 14, 1, 2);
  a.r(const Color(0xFF8A5A3A), 15, 14, 1, 2);
  a.r(_red, 13, 16);
  a.r(_gold, 9, 16);
  a.r(_red, 2, 16);
}

void _court(_Art a) {
  a.r(a.base, 1, 4, 16, 14);
  a.r(_white, 1, 4, 16, 1);
  a.r(_white, 1, 17, 16, 1);
  a.r(_white, 1, 4, 1, 14);
  a.r(_white, 16, 4, 1, 14);
  a.r(_white, 1, 10, 16, 1);
  a.r(_white, 7, 9, 4, 3);
  a.r(a.base, 8, 10, 2, 1);
  a.r(_gray, 8, 2, 2, 3);
  a.r(_red, 8, 5, 2, 1);
}

void _kiosk(_Art a) {
  a.r(const Color(0xFFD8CCB4), 2, 15, 14, 3);
  for (final x in [3, 7, 10, 14]) {
    a.r(_white, x, 8, 1, 7);
  }
  a.r(a.base, 1, 7, 16, 2);
  a.r(a.base, 3, 5, 12, 2);
  a.r(a.base, 6, 3, 6, 2);
  a.r(_gold, 8, 1, 2, 2);
}

// ---------------- Transporte ----------------

void _busStop(_Art a) {
  a.r(const Color(0xFFB9B2A6), 1, 15, 16, 3);
  a.r(a.base, 3, 6, 12, 2);
  a.r(shade(a.base, 0.3), 3, 8, 12, 1);
  a.r(_gray, 3, 8, 1, 8);
  a.r(_gray, 14, 8, 1, 8);
  a.win(5, 9, 8, 3);
  a.r(const Color(0xFF8A5A3A), 5, 13, 8, 1);
  a.r(_gray, 16, 3, 1, 13);
  a.r(_white, 15, 1, 3, 3);
  a.r(const Color(0xFF3D78A8), 16, 2);
}

// ---------------- Gobierno ----------------

void _palace(_Art a) {
  final stone = a.base;
  final trim = shade(a.base, 0.12);
  a.r(stone, 0, 6, 18, 12);
  a.r(trim, 0, 5, 18, 1);
  a.r(stone, 6, 1, 6, 5);
  a.r(trim, 6, 0, 6, 1);
  a.r(_gold, 8, 2, 2, 2);
  for (final x in [1, 4, 12, 15]) {
    a.r(const Color(0xFF6B5A4A), x, 12, 2, 6);
    a.win(x, 8);
  }
  a.r(_door, 8, 12, 2, 6);
  a.r(const Color(0xFFDDDDDD), 9, -5, 1, 5);
  a.r(const Color(0xFF3E8C56), 10, -5, 1, 2);
  a.r(const Color(0xFFFFFFFF), 11, -5, 1, 2);
  a.r(_red, 12, -5, 1, 2);
}

/// Miniatura de una construcción para la tienda y el selector de color.
class BuildingThumb extends StatelessWidget {
  final BuildingType type;
  final Color? color;
  final double width;
  const BuildingThumb(this.type, {super.key, this.color, this.width = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 4 / 3,
      decoration: BoxDecoration(color: const Color(0xFF3F6A35), border: Border.all(color: _ink, width: 2)),
      child: CustomPaint(painter: _ThumbPainter(type, color ?? Color(type.base))),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final BuildingType type;
  final Color color;
  _ThumbPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final top = (size.height - 18 * s) - s; // aire arriba para banderas y antenas
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawBuildingArt(Px(canvas, s: s), type, color, 0, top / s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.type.id != type.id || old.color != color;
}
