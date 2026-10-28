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
