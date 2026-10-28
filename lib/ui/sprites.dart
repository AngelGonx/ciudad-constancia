import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';

// Colores sugeridos del avatar (además del color libre).
const List<Color> skinColors = [
  Color(0xFFF6D2B0), Color(0xFFEBC097), Color(0xFFE0AC7E), Color(0xFFC98E5E), Color(0xFFB9784F),
  Color(0xFF8F5A3A), Color(0xFF7A4A2E), Color(0xFF5A3420),
];
const List<Color> hairColors = [
  Color(0xFF2A1D17), Color(0xFF6B3F2A), Color(0xFFC98A3C), Color(0xFFE8D27A), Color(0xFFB84A3A),
  Color(0xFF8A8A9A), Color(0xFFEFEFEF), Color(0xFF4F6FD8), Color(0xFFD86BB0), Color(0xFF3E8C56),
];
const List<Color> clothColors = [
  Color(0xFF3D78A8), Color(0xFFD24C4C), Color(0xFF3E8C56), Color(0xFFF4B942), Color(0xFF8C5A8F),
  Color(0xFFEFE6D6), Color(0xFF2F2F3A), Color(0xFFE07A3A), Color(0xFF62CFC0), Color(0xFFD86BB0),
];
const List<String> hairStyles = [
  'corto', 'flequillo', 'raya', 'picos', 'rizado', 'afro', 'mohicano', 'largo', 'coleta', 'trenzas', 'chongo', 'calvo',
];
const List<String> accessories = ['ninguno', 'lentes', 'gorra'];

/// Dibuja rectángulos en una cuadrícula de píxeles lógicos.
class Px {
  final Canvas canvas;
  final double ox, oy, s;
  final Paint _paint = Paint()..isAntiAlias = false;
  Px(this.canvas, {this.ox = 0, this.oy = 0, this.s = 1});

  void r(Color c, num x, num y, [num w = 1, num h = 1]) {
    _paint.color = c;
    canvas.drawRect(
      Rect.fromLTWH(ox + x.toDouble() * s, oy + y.toDouble() * s, w.toDouble() * s, h.toDouble() * s),
      _paint,
    );
  }

  /// Techo escalonado que sube desde la fila y.
  void roof(Color c, int x, int y, int w) {
    for (var i = 0; w - 2 * i > 0; i++) {
      r(c, x + i, y - i, w - 2 * i, 1);
    }
  }
}

const _ink = Color(0xFF0F0B14);

/// Avatar de 16 × 16 píxeles.
void drawAvatar(Canvas canvas, Avatar a, double ox, double oy, double s) {
  final p = Px(canvas, ox: ox, oy: oy, s: s);
  final sk = Color(a.skin);
  final hc = Color(a.hairColor);
  final sh = Color(a.shirt);
  final pa = Color(a.pants);
  const shoe = Color(0xFF2A1D17);

  p.r(_ink, 4, 2, 8, 8);
  p.r(sk, 5, 3, 6, 6);
  p.r(_ink, 6, 5);
  p.r(_ink, 9, 5);
  p.r(const Color(0x40000000), 7, 7, 2, 1);
  p.r(_ink, 3, 9, 10, 5);
  p.r(sh, 4, 9, 8, 4);
  p.r(sk, 3, 10, 1, 2);
  p.r(sk, 12, 10, 1, 2);
  p.r(_ink, 4, 13, 8, 2);
  p.r(pa, 5, 13, 6, 1);
  p.r(pa, 5, 14, 2, 1);
  p.r(pa, 9, 14, 2, 1);
  p.r(shoe, 5, 15, 2, 1);
  p.r(shoe, 9, 15, 2, 1);

  // Base corta que comparten varios peinados.
  void base() {
    p.r(hc, 5, 2, 6, 2);
    p.r(hc, 4, 3, 1, 2);
    p.r(hc, 11, 3, 1, 2);
  }

  switch (a.hair) {
    case 'corto':
      base();
      break;
    case 'flequillo':
      base();
      p.r(hc, 5, 4, 6, 1);
      break;
    case 'raya':
      p.r(hc, 5, 2, 6, 2);
      p.r(hc, 4, 3, 1, 3);
      p.r(hc, 11, 3, 1, 2);
      p.r(hc, 5, 4, 3, 1);
      break;
    case 'picos':
      base();
      p.r(hc, 5, 1);
      p.r(hc, 7, 1);
      p.r(hc, 9, 1);
      p.r(hc, 10, 1);
      break;
    case 'rizado':
      p.r(hc, 4, 1, 8, 3);
      for (var x = 4; x < 12; x += 2) {
        p.r(hc, x, 0);
      }
      p.r(hc, 4, 4, 1, 2);
      p.r(hc, 11, 4, 1, 2);
      break;
    case 'afro':
      p.r(hc, 3, 0, 10, 4);
      p.r(hc, 3, 4, 2, 4);
      p.r(hc, 11, 4, 2, 4);
      break;
    case 'mohicano':
      p.r(hc, 7, 0, 2, 4);
      break;
    case 'largo':
      base();
      p.r(hc, 4, 3, 1, 7);
      p.r(hc, 11, 3, 1, 7);
      break;
    case 'coleta':
      base();
      p.r(hc, 12, 3, 1, 2);
      p.r(hc, 13, 4, 1, 5);
      break;
    case 'trenzas':
      base();
      p.r(hc, 4, 5, 1, 6);
      p.r(hc, 11, 5, 1, 6);
      p.r(const Color(0xFFD24C4C), 4, 11);
      p.r(const Color(0xFFD24C4C), 11, 11);
      break;
    case 'chongo':
      base();
      p.r(hc, 7, 0, 2, 2);
      break;
    case 'calvo':
      p.r(const Color(0x59FFFFFF), 6, 3, 2, 1);
      break;
    default:
      base();
  }
  if (a.accessory == 'lentes') {
    p.r(_ink, 5, 5, 6, 1);
    p.r(const Color(0xFF9FD8FF), 6, 5);
    p.r(const Color(0xFF9FD8FF), 9, 5);
  } else if (a.accessory == 'gorra') {
    p.r(const Color(0xFFD24C4C), 4, 1, 8, 3);
    p.r(const Color(0xFFA83A3A), 8, 3, 5, 1);
    p.r(const Color(0xFFEFE6D6), 7, 2, 2, 1);
  }
}

class AvatarPainter extends CustomPainter {
  final Avatar avatar;
  final int version;
  AvatarPainter(this.avatar, this.version);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 16;
    drawAvatar(canvas, avatar, (size.width - 16 * s) / 2, (size.height - 16 * s) / 2, s);
  }

  @override
  bool shouldRepaint(AvatarPainter old) => true;
}

class AvatarView extends StatelessWidget {
  final Avatar avatar;
  final double size;
  const AvatarView({super.key, required this.avatar, required this.size});

  @override
  Widget build(BuildContext context) {
    final a = avatar;
    final v = Object.hash(a.skin, a.hair, a.hairColor, a.shirt, a.pants, a.accessory);
    return CustomPaint(size: Size.square(size), painter: AvatarPainter(a, v));
  }
}

/// Dibuja un edificio en un lote de 18 × 18 cuyo borde superior izquierdo es (x, y).
void drawBuilding(Px base, String id, double x, double y) {
  final p = Px(base.canvas, ox: base.ox + x * base.s, oy: base.oy + y * base.s, s: base.s);
  const win = Color(0xFF9FD8FF);
  const lit = Color(0xFFFFE28A);
  const door = Color(0xFF6B3F2A);
  const gold = Color(0xFFF4B942);
  switch (id) {
    case 'hogar':
      p.r(const Color(0xFFE8D7B0), 3, 11, 12, 7);
      p.roof(const Color(0xFFB8473D), 2, 10, 14);
      p.r(door, 8, 14, 2, 4);
      p.r(win, 4, 13, 2, 2);
      p.r(win, 12, 13, 2, 2);
      p.r(const Color(0xFFDDDDDD), 16, 2, 1, 9);
      p.r(gold, 17, 2, 1, 2);
      break;
    case 'casa':
      p.r(const Color(0xFFD9C9A6), 3, 11, 12, 7);
      p.roof(const Color(0xFF8C5A8F), 2, 10, 14);
      p.r(door, 7, 14, 2, 4);
      p.r(win, 11, 13, 2, 2);
      break;
    case 'casa2':
      p.r(const Color(0xFFC7D3E0), 3, 6, 12, 12);
      p.r(const Color(0xFF4F6FA8), 2, 5, 14, 2);
      for (final yy in [8, 12]) {
        p.r(win, 5, yy, 2, 2);
        p.r(win, 11, yy, 2, 2);
      }
      p.r(door, 8, 15, 2, 3);
      break;
    case 'depas':
      p.r(const Color(0xFFB9A28C), 2, 1, 14, 17);
      p.r(const Color(0xFF8F7A66), 2, 1, 14, 1);
      for (var yy = 3; yy < 15; yy += 3) {
        final xs = [4, 8, 12];
        for (var i = 0; i < xs.length; i++) {
          p.r((yy + i).isOdd ? lit : win, xs[i], yy, 2, 2);
        }
      }
      p.r(_ink, 8, 15, 2, 3);
      break;
    case 'tiendita':
      p.r(const Color(0xFFF0E0C0), 2, 10, 14, 8);
      for (var i = 0; i < 7; i++) {
        p.r(i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFFD24C4C), 2 + i * 2, 8, 2, 2);
      }
      p.r(door, 10, 13, 3, 5);
      p.r(win, 4, 12, 4, 3);
      break;
    case 'tortilleria':
      p.r(const Color(0xFFF2C94C), 2, 9, 14, 9);
      p.r(const Color(0xFFA8743A), 2, 8, 14, 1);
      p.r(const Color(0xFFFFFFFF), 4, 10, 10, 2);
      p.r(const Color(0xFFD24C4C), 5, 10, 8, 1);
      p.r(door, 10, 14, 3, 4);
      p.r(win, 4, 13, 3, 3);
      p.r(const Color(0xFFDDDDDD), 6, 5, 1, 2);
      p.r(const Color(0xFFDDDDDD), 7, 3, 1, 2);
      break;
    case 'mercado':
      const stripes = [Color(0xFFD24C4C), Color(0xFFF4B942), Color(0xFF3E8C56)];
      for (var i = 0; i < 8; i++) {
        p.r(stripes[i % 3], 1 + i * 2, 7, 2, 3);
      }
      p.r(const Color(0xFFE7D3B5), 2, 10, 14, 8);
      p.r(_ink, 4, 12, 3, 6);
      p.r(_ink, 11, 12, 3, 6);
      p.r(const Color(0xFF8A5A3A), 7, 14, 4, 1);
      break;
    case 'fabrica':
      p.r(const Color(0xFF8C8F9C), 1, 9, 13, 9);
      for (var k = 0; k < 3; k++) {
        p.r(const Color(0xFF6B6E7A), 1 + k * 4, 7, 3, 2);
        p.r(const Color(0xFF6B6E7A), 1 + k * 4, 6, 1, 1);
      }
      p.r(const Color(0xFF6B4A3A), 14, 3, 3, 15);
      p.r(const Color(0xFFCCCCCC), 15, 1, 2, 1);
      p.r(const Color(0xFFBBBBBB), 16, 0, 2, 1);
      for (final xx in [3, 7, 11]) {
        p.r(lit, xx, 12, 2, 2);
      }
      p.r(_ink, 6, 15, 3, 3);
      break;
    case 'escuela':
      p.r(const Color(0xFFD9805B), 1, 9, 16, 9);
      p.r(const Color(0xFF7A3F2A), 1, 8, 16, 1);
      p.r(const Color(0xFFD9805B), 7, 4, 4, 5);
      p.roof(const Color(0xFF7A3F2A), 6, 4, 6);
      p.r(gold, 8, 6, 2, 1);
      for (final yy in [11, 14]) {
        p.r(win, 3, yy, 2, 2);
        p.r(win, 13, yy, 2, 2);
      }
      p.r(door, 8, 14, 2, 4);
      break;
    case 'secundaria':
      p.r(const Color(0xFFCF6F6F), 1, 5, 16, 13);
      p.r(const Color(0xFF8A3F3F), 1, 4, 16, 1);
      for (var yy = 7; yy < 15; yy += 3) {
        for (final xx in [3, 7, 11, 14]) {
          p.r(win, xx, yy, 2, 2);
        }
      }
      p.r(door, 8, 15, 2, 3);
      break;
    case 'pozo':
      p.r(const Color(0xFF5AA0D8), 4, 2, 10, 7);
      p.r(const Color(0xFF3D78A8), 4, 2, 10, 1);
      p.r(const Color(0xFF8FC4EA), 5, 4, 2, 3);
      p.r(const Color(0xFF555555), 5, 9, 1, 9);
      p.r(const Color(0xFF555555), 12, 9, 1, 9);
      p.r(const Color(0xFF555555), 6, 13, 6, 1);
      break;
    case 'agua2':
      p.r(const Color(0xFF5AA0D8), 1, 9, 16, 9);
      p.r(const Color(0xFF3D78A8), 2, 13, 14, 2);
      p.r(const Color(0xFF8FC4EA), 5, 3, 8, 6);
      p.r(const Color(0xFF3D78A8), 5, 3, 8, 1);
      p.r(_ink, 7, 15, 3, 3);
      break;
    case 'poste':
      p.r(const Color(0xFF7A5A3A), 8, 1, 2, 17);
      p.r(const Color(0xFF7A5A3A), 4, 3, 10, 1);
      p.r(const Color(0xFF8C8F9C), 10, 7, 3, 4);
      p.r(gold, 4, 2);
      p.r(gold, 13, 2);
      break;
    case 'luz2':
      const steel = Color(0xFF99AAAA);
      const fence = Color(0xFF555555);
      p.r(steel, 4, 2, 1, 11);
      p.r(steel, 13, 2, 1, 11);
      p.r(steel, 2, 4, 5, 1);
      p.r(steel, 11, 4, 5, 1);
      p.r(const Color(0xFF8C8F9C), 6, 12, 6, 5);
      p.r(gold, 8, 13, 2, 2);
      p.r(fence, 1, 11, 16, 1);
      p.r(fence, 1, 17, 16, 1);
      for (var xx = 1; xx < 17; xx += 3) {
        p.r(fence, xx, 11, 1, 7);
      }
      break;
    case 'basura':
      p.r(const Color(0xFF3E8C56), 2, 10, 10, 6);
      p.r(const Color(0xFF2E6A40), 4, 11, 6, 1);
      p.r(const Color(0xFF3E8C56), 12, 12, 4, 4);
      p.r(win, 13, 12, 2, 2);
      p.r(_ink, 3, 16, 3, 2);
      p.r(_ink, 11, 16, 3, 2);
      break;
    case 'reciclaje':
      p.r(const Color(0xFF5F9C6A), 2, 8, 14, 10);
      p.r(const Color(0xFF3E7A4A), 2, 7, 14, 1);
      p.r(const Color(0xFFFFFFFF), 6, 10, 6, 4);
      p.r(const Color(0xFF3E8C56), 7, 11, 4, 2);
      p.r(_ink, 8, 15, 2, 3);
      break;
    case 'parque':
      p.r(const Color(0xFF5F9A4A), 0, 14, 18, 4);
      p.r(const Color(0xFF6B4A3A), 5, 9, 2, 6);
      p.r(const Color(0xFF3F7A37), 2, 3, 8, 7);
      p.r(const Color(0xFF5AA04A), 3, 4, 4, 3);
      p.r(const Color(0xFF8A5A3A), 11, 13, 5, 1);
      p.r(const Color(0xFF8A5A3A), 11, 14, 1, 2);
      p.r(const Color(0xFF8A5A3A), 15, 14, 1, 2);
      p.r(const Color(0xFFE3655B), 13, 16);
      p.r(gold, 9, 16);
      p.r(const Color(0xFFE3655B), 2, 16);
      break;
    case 'palacio':
      const stone = Color(0xFFEFE6D6);
      const trim = Color(0xFFD8CCB4);
      p.r(stone, 0, 6, 18, 12);
      p.r(trim, 0, 5, 18, 1);
      p.r(stone, 6, 1, 6, 5);
      p.r(trim, 6, 0, 6, 1);
      p.r(gold, 8, 2, 2, 2);
      for (final xx in [1, 4, 12, 15]) {
        p.r(const Color(0xFF6B5A4A), xx, 12, 2, 6);
        p.r(win, xx, 8, 2, 2);
      }
      p.r(door, 8, 12, 2, 6);
      p.r(const Color(0xFFDDDDDD), 9, -5, 1, 5);
      p.r(const Color(0xFF3E8C56), 10, -5, 1, 2);
      p.r(const Color(0xFFFFFFFF), 11, -5, 1, 2);
      p.r(const Color(0xFFD24C4C), 12, -5, 1, 2);
      break;
  }
}

/// Miniatura de un edificio para la tienda.
class BuildingThumb extends StatelessWidget {
  final String id;
  const BuildingThumb(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(color: const Color(0xFF3F6A35), border: Border.all(color: _ink, width: 2)),
      child: CustomPaint(painter: _ThumbPainter(id)),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final String id;
  _ThumbPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final top = (size.height - 18 * s) - s; // deja aire arriba para banderas
    drawBuilding(Px(canvas, s: s), id, 0, top / s);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.id != id;
}
