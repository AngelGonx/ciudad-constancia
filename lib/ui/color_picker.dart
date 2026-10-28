import 'dart:math';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import 'pixel.dart';

/// Abre el círculo cromático pixel y regresa el color elegido (o null si se cancela).
Future<Color?> pickColor(BuildContext context, Color initial) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<Color>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: _PickerBody(initial: initial),
    ),
  );
}

class _PickerBody extends StatefulWidget {
  final Color initial;
  const _PickerBody({required this.initial});

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  static const double _wheel = 220;
  static const int _steps = 10; // celdas de la barra de brillo

  void _pickAt(Offset local) {
    const r = _wheel / 2;
    final dx = local.dx - r;
    final dy = local.dy - r;
    final dist = min(1.0, sqrt(dx * dx + dy * dy) / r);
    final hue = (atan2(dy, dx) * 180 / pi + 360) % 360;
    setState(() => _hsv = HSVColor.fromAHSV(1, hue, dist, _hsv.value == 0 ? 1 : _hsv.value));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('a.pick'), style: T.display(16)),
        const SizedBox(height: 14),
        GestureDetector(
          onPanDown: (d) => _pickAt(d.localPosition),
          onPanUpdate: (d) => _pickAt(d.localPosition),
          child: CustomPaint(size: const Size.square(_wheel), painter: _WheelPainter(_hsv)),
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: SectionTitle(L.t('a.brightness'))),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 1; i <= _steps; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _hsv = _hsv.withValue(i / _steps)),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: _hsv.withValue(i / _steps).toColor(),
                    border: Border.all(
                      color: (_hsv.value * _steps).round() == i ? C.gold : C.ink,
                      width: (_hsv.value * _steps).round() == i ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, border: Border.all(color: C.ink, width: 3)),
          ),
          const Spacer(),
          PixelButton(
            label: L.t('cancel'),
            color: C.panel2,
            textColor: C.fg,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          PixelButton(label: L.t('a.use'), onPressed: () => Navigator.of(context).pop(color)),
        ]),
      ]),
    );
  }
}

/// Círculo cromático dibujado en celdas, para que se vea pixelado.
class _WheelPainter extends CustomPainter {
  final HSVColor current;
  _WheelPainter(this.current);

  static const int _cells = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _cells;
    final r = size.width / 2;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < _cells; y++) {
      for (var x = 0; x < _cells; x++) {
        final cx = (x + 0.5) * cell - r;
        final cy = (y + 0.5) * cell - r;
        final dist = sqrt(cx * cx + cy * cy) / r;
        if (dist > 1) continue;
        final hue = (atan2(cy, cx) * 180 / pi + 360) % 360;
        paint.color = HSVColor.fromAHSV(1, hue, dist, current.value).toColor();
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
    // Marcador de la selección
    final a = current.hue * pi / 180;
    final px = r + cos(a) * current.saturation * r;
    final py = r + sin(a) * current.saturation * r;
    final marker = Rect.fromCenter(center: Offset(px, py), width: cell * 1.6, height: cell * 1.6);
    canvas.drawRect(marker, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawRect(marker.inflate(2), Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.current != current;
}
