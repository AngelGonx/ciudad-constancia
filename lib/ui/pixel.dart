import 'package:flutter/material.dart';

/// Paleta "plaza de noche".
class C {
  static const bg = Color(0xFF241C2E);
  static const panel = Color(0xFF33283F);
  static const panel2 = Color(0xFF3F3150);
  static const ink = Color(0xFF0F0B14);
  static const fg = Color(0xFFF3E9D6);
  static const dim = Color(0xFFB3A5C0);
  static const gold = Color(0xFFF4B942);
  static const xp = Color(0xFF62CFC0);
  static const bad = Color(0xFFE3655B);
  static const good = Color(0xFF93CF63);
  static const epic = Color(0xFFC27CE0);
  static const grass = Color(0xFF3F6A35);

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
  static TextStyle display(double size, [Color color = C.fg]) =>
      TextStyle(fontFamily: 'Silkscreen', fontSize: size, color: color, height: 1.25);
  static TextStyle body(double size, [Color color = C.fg]) =>
      TextStyle(fontFamily: 'PixelifySans', fontSize: size, color: color, height: 1.35);
}

ThemeData pixelTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    fontFamily: 'PixelifySans',
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: C.ink,
      secondary: C.xp,
      surface: C.panel,
      onSurface: C.fg,
      error: C.bad,
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.gold),
    splashFactory: NoSplash.splashFactory,
  );
}

const _hardShadow = [BoxShadow(color: C.ink, offset: Offset(0, 4))];

/// Caja con borde grueso y sombra dura, sin esquinas redondeadas.
class PixelBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  const PixelBox({
    super.key,
    required this.child,
    this.color = C.panel,
    this.padding = const EdgeInsets.all(14),
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: C.ink, width: 3),
        boxShadow: shadow ? _hardShadow : null,
      ),
      child: child,
    );
  }
}

class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = C.gold,
    this.textColor = C.ink,
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
    final bg = enabled ? widget.color : C.panel2;
    final fg = enabled ? widget.textColor : C.dim;
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
              boxShadow: (_down || !enabled) ? null : const [BoxShadow(color: C.ink, offset: Offset(0, 3))],
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
  final Color color;
  final double height;
  const PixelBar({super.key, required this.value, this.color = C.xp, this.height = 12});

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
          child: CustomPaint(painter: _StripePainter(color)),
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
  final Color color;
  final Color textColor;
  const PixelChip(this.text, {super.key, this.color = C.dim, this.textColor = C.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: color,
      child: Text(text, style: T.display(10, textColor)),
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
          child: Text(label, style: T.display(11, selected ? C.ink : C.fg)),
        ),
      ),
    );
  }
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
      content: Text(message, style: T.display(12, C.ink)),
      backgroundColor: C.gold,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
      shape: const RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
    ));
}

Future<void> showPixelDialog(BuildContext context, String title, String body) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: T.display(22, C.gold)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: T.body(16, C.dim)),
            const SizedBox(height: 16),
            PixelButton(label: 'Seguir', onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    ),
  );
}
