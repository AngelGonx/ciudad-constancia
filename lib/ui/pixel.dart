import 'dart:math';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';

/// Paleta de la app. Oscuro "plaza de noche" por defecto; claro "papel de día".
class Palette {
  final Color bg, panel, panel2, ink, fg, dim, gold, xp, bad, good, epic, onAccent;
  const Palette({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.ink,
    required this.fg,
    required this.dim,
    required this.gold,
    required this.xp,
    required this.bad,
    required this.good,
    required this.epic,
    required this.onAccent,
  });
}

const Palette darkPalette = Palette(
  bg: Color(0xFF241C2E),
  panel: Color(0xFF33283F),
  panel2: Color(0xFF3F3150),
  ink: Color(0xFF0F0B14),
  fg: Color(0xFFF3E9D6),
  dim: Color(0xFFB3A5C0),
  gold: Color(0xFFF4B942),
  xp: Color(0xFF62CFC0),
  bad: Color(0xFFE3655B),
  good: Color(0xFF93CF63),
  epic: Color(0xFFC27CE0),
  onAccent: Color(0xFF0F0B14),
);

const Palette lightPalette = Palette(
  bg: Color(0xFFF1E8D8),
  panel: Color(0xFFE4D6BF),
  panel2: Color(0xFFD6C5A9),
  ink: Color(0xFF2A1F33),
  fg: Color(0xFF2A1F33),
  dim: Color(0xFF6B5A78),
  gold: Color(0xFFE0A22A),
  xp: Color(0xFF3FB3A4),
  bad: Color(0xFFD0503F),
  good: Color(0xFF6FAE45),
  epic: Color(0xFFA864C9),
  onAccent: Color(0xFF2A1F33),
);

/// Colores activos. Se cambian con [C.useLight] antes de reconstruir la app.
class C {
  static Palette p = darkPalette;
  static bool get isLight => identical(p, lightPalette);
  static void useLight(bool light) => p = light ? lightPalette : darkPalette;

  static Color get bg => p.bg;
  static Color get panel => p.panel;
  static Color get panel2 => p.panel2;
  static Color get ink => p.ink;
  static Color get fg => p.fg;
  static Color get dim => p.dim;
  static Color get gold => p.gold;
  static Color get xp => p.xp;
  static Color get bad => p.bad;
  static Color get good => p.good;
  static Color get epic => p.epic;
  static Color get onAccent => p.onAccent;
  static const Color grass = Color(0xFF3F6A35);

  static Color forDifficulty(String id) {
    switch (id) {
      case 'facil':
        return good;
      case 'media':
        return xp;
      case 'dificil':
        return gold;
      default:
        return epic;
    }
  }
}

/// Tipografías pixel: Silkscreen para títulos y números, Pixelify Sans para texto.
class T {
  static TextStyle display(double size, [Color? color]) =>
      TextStyle(fontFamily: 'Silkscreen', fontSize: size, color: color ?? C.fg, height: 1.25);
  static TextStyle body(double size, [Color? color]) =>
      TextStyle(fontFamily: 'PixelifySans', fontSize: size, color: color ?? C.fg, height: 1.35);
}

ThemeData pixelTheme() {
  final light = C.isLight;
  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    fontFamily: 'PixelifySans',
    colorScheme: (light ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: C.gold,
      onPrimary: C.onAccent,
      secondary: C.xp,
      surface: C.panel,
      onSurface: C.fg,
      error: C.bad,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: C.gold),
    splashFactory: NoSplash.splashFactory,
  );
}

List<BoxShadow> hardShadow([double dy = 4]) => [BoxShadow(color: C.ink, offset: Offset(0, dy))];

/// Caja con borde grueso y sombra dura, sin esquinas redondeadas.
class PixelBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  const PixelBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? C.panel,
        border: Border.all(color: C.ink, width: 3),
        boxShadow: shadow ? hardShadow() : null,
      ),
      child: child,
    );
  }
}

class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.fontSize = 12,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  void _set(bool v) {
    if (mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = enabled ? (widget.color ?? C.gold) : C.panel2;
    final fg = enabled ? (widget.textColor ?? C.onAccent) : C.dim;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Transform.translate(
          offset: Offset(0, _down ? 3 : 0),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: C.ink, width: 3),
              boxShadow: (_down || !enabled) ? null : hardShadow(3),
            ),
            child: Text(widget.label, textAlign: TextAlign.center, style: T.display(widget.fontSize, fg)),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso con rayas tipo segmento.
class PixelBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const PixelBar({super.key, required this.value, this.color, this.height = 12});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return Container(
      height: height,
      decoration: BoxDecoration(color: C.ink, border: Border.all(color: C.ink, width: 2)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: CustomPaint(painter: _StripePainter(color ?? C.xp)),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  _StripePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final p = Paint()..color = const Color(0x2E000000);
    for (double x = 6; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

class PixelChip extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  const PixelChip(this.text, {super.key, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: color ?? C.dim,
      child: Text(text, style: T.display(10, textColor ?? C.onAccent)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: T.display(12, C.dim).copyWith(letterSpacing: 1));
  }
}

/// Moneda pixel para acompañar cantidades de oro.
class Coin extends StatelessWidget {
  final double size;
  const Coin({super.key, this.size = 12});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.gold,
        border: Border.all(color: C.ink, width: 2),
      ),
      alignment: Alignment.bottomRight,
      child: Container(width: size / 3, height: size / 3, color: const Color(0xFFB07A1C)),
    );
  }
}

/// Opción seleccionable tipo botón de texto.
class PixelChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const PixelChoice({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? C.gold : C.panel2,
            border: Border.all(color: C.ink, width: 3),
          ),
          child: Text(label, style: T.display(11, selected ? C.onAccent : C.fg)),
        ),
      ),
    );
  }
}

/// Campo de texto con borde pixel.
InputDecoration pixelInput({String? hint}) {
  OutlineInputBorder border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: 3));
  return InputDecoration(
    hintText: hint,
    hintStyle: T.body(16, C.dim),
    counterText: '',
    filled: true,
    fillColor: C.bg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    border: border(C.ink),
    enabledBorder: border(C.ink),
    focusedBorder: border(C.xp),
  );
}

/// Botón redondo con un engranaje pixel.
class GearButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const GearButton({super.key, required this.onTap, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: L.t('hdr.settings'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.panel2,
            border: Border.all(color: C.ink, width: 3),
          ),
          padding: EdgeInsets.all(size * 0.18),
          child: CustomPaint(painter: _GearPainter(C.fg, C.panel2)),
        ),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  final Color color;
  final Color hole;
  _GearPainter(this.color, this.hole);

  // Engranaje de 12 × 12 píxeles.
  static const _rows = [
    '....XXXX....',
    '..X.XXXX.X..',
    '.XXXXXXXXXX.',
    '..XXXXXXXX..',
    'XXXXX..XXXXX',
    'XXXX....XXXX',
    'XXXX....XXXX',
    'XXXXX..XXXXX',
    '..XXXXXXXX..',
    '.XXXXXXXXXX.',
    '..X.XXXX.X..',
    '....XXXX....',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 12;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 12; x++) {
        if (_rows[y][x] == 'X') canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.color != color;
}

String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: T.display(12, C.onAccent)),
      backgroundColor: C.gold,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
    ));
}

Future<void> showPixelDialog(BuildContext context, String title, String body) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: T.display(22, C.gold)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: T.body(16, C.dim)),
            const SizedBox(height: 16),
            PixelButton(label: L.t('ok'), onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    ),
  ).then((_) => FocusManager.instance.primaryFocus?.unfocus());
}
