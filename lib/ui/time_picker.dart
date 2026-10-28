import 'dart:math';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import 'pixel.dart';

/// "08:30" a partir de minutos desde medianoche.
String formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Resultado del selector: la hora elegida, o [removed] si se quitó el recordatorio.
class TimeChoice {
  final int? minutes;
  final bool removed;
  const TimeChoice(this.minutes) : removed = false;
  const TimeChoice.remove()
      : minutes = null,
        removed = true;
}

/// Selector de hora pixel con botones + y −. Regresa null si se cancela.
Future<TimeChoice?> pickTime(BuildContext context, int initial, {bool allowRemove = false}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<TimeChoice>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: _TimeBody(initial: initial, allowRemove: allowRemove),
    ),
  );
}

class _TimeBody extends StatefulWidget {
  final int initial;
  final bool allowRemove;
  const _TimeBody({required this.initial, required this.allowRemove});

  @override
  State<_TimeBody> createState() => _TimeBodyState();
}

class _TimeBodyState extends State<_TimeBody> {
  late int _h = widget.initial ~/ 60;
  late int _m = (widget.initial % 60) ~/ 5 * 5;

  Widget _stepper(String label, String value, VoidCallback minus, VoidCallback plus) {
    return Column(children: [
      SectionTitle(label),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        PixelButton(label: '-', onPressed: minus, color: C.panel2, textColor: C.fg, fontSize: 16),
        SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: T.display(28))),
        PixelButton(label: '+', onPressed: plus, color: C.panel2, textColor: C.fg, fontSize: 16),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const PixelBell(size: 28),
        const SizedBox(height: 8),
        Text(L.t('r.pickTitle'), style: T.display(14)),
        const SizedBox(height: 16),
        _stepper(L.t('r.hour'), _h.toString().padLeft(2, '0'), () => setState(() => _h = (_h + 23) % 24),
            () => setState(() => _h = (_h + 1) % 24)),
        const SizedBox(height: 12),
        _stepper(L.t('r.minute'), _m.toString().padLeft(2, '0'), () => setState(() => _m = (_m + 55) % 60),
            () => setState(() => _m = (_m + 5) % 60)),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          if (widget.allowRemove)
            PixelButton(
              label: L.t('r.remove'),
              color: C.bad,
              onPressed: () => Navigator.of(context).pop(const TimeChoice.remove()),
            ),
          PixelButton(
            label: L.t('cancel'),
            color: C.panel2,
            textColor: C.fg,
            onPressed: () => Navigator.of(context).pop(),
          ),
          PixelButton(label: L.t('r.save'), onPressed: () => Navigator.of(context).pop(TimeChoice(_h * 60 + _m))),
        ]),
      ]),
    );
  }
}

/// Campanita pixel de 8 × 8.
class PixelBell extends StatelessWidget {
  final double size;
  final Color? color;
  const PixelBell({super.key, this.size = 12, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _BellPainter(color ?? C.gold)));
  }
}

class _BellPainter extends CustomPainter {
  final Color color;
  _BellPainter(this.color);

  static const _rows = [
    '...XX...',
    '..XXXX..',
    '.XXXXXX.',
    '.XXXXXX.',
    '.XXXXXX.',
    'XXXXXXXX',
    '........',
    '...XX...',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 8;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (_rows[y][x] == 'X') canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.color != color;
}
