import 'dart:math';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import 'pixel.dart';

/// "8:30 PM" a partir de minutos desde medianoche.
String formatMinutes(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
}

/// "mié 28 oct" en el idioma activo.
String formatDay(DateTime d) => '${L.t('wd.${d.weekday}')} ${d.day} ${L.t('mo.${d.month}')}';

/// "mié 28 oct · 5:00 PM".
String formatDue(DateTime d) => '${formatDay(d)} · ${formatMinutes(d.hour * 60 + d.minute)}';

/// Resultado del selector: la hora (o fecha y hora) elegida, o [removed] si se quitó.
class TimeChoice {
  final int? minutes;
  final DateTime? date;
  final bool removed;
  const TimeChoice(this.minutes, [this.date]) : removed = false;
  const TimeChoice.remove()
      : minutes = null,
        date = null,
        removed = true;
}

/// Selector de hora pixel: hora, minutos y AM/PM. Regresa null si se cancela.
Future<TimeChoice?> pickTime(BuildContext context, int initial, {bool allowRemove = false}) =>
    _open(context, _PickerBody(initialMinutes: initial, allowRemove: allowRemove));

/// Selector de fecha límite: día y hora. Regresa null si se cancela.
Future<TimeChoice?> pickDateTime(BuildContext context, DateTime initial, {bool allowRemove = false}) => _open(
      context,
      _PickerBody(
        initialMinutes: initial.hour * 60 + initial.minute,
        initialDate: DateTime(initial.year, initial.month, initial.day),
        allowRemove: allowRemove,
      ),
    );

Future<TimeChoice?> _open(BuildContext context, Widget body) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<TimeChoice>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: body,
    ),
  );
}

class _PickerBody extends StatefulWidget {
  final int initialMinutes;
  final DateTime? initialDate;
  final bool allowRemove;
  const _PickerBody({required this.initialMinutes, this.initialDate, required this.allowRemove});

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  late int _h12;
  late int _m;
  late bool _pm;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final h24 = (widget.initialMinutes ~/ 60) % 24;
    _h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _m = (widget.initialMinutes % 60) ~/ 5 * 5;
    _pm = h24 >= 12;
    _date = widget.initialDate;
  }

  int get _minutes => ((_h12 % 12) + (_pm ? 12 : 0)) * 60 + _m;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Widget _stepper(String label, String value, VoidCallback minus, VoidCallback plus, {double width = 56}) {
    return Column(children: [
      SectionTitle(label),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        PixelButton(
          label: '-',
          onPressed: minus,
          color: C.panel2,
          textColor: C.fg,
          fontSize: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        SizedBox(width: width, child: Text(value, textAlign: TextAlign.center, style: T.display(22))),
        PixelButton(
          label: '+',
          onPressed: plus,
          color: C.panel2,
          textColor: C.fg,
          fontSize: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const PixelBell(size: 28),
          const SizedBox(height: 8),
          Text(L.t(date == null ? 'r.pickTitle' : 'r.dueTitle'), textAlign: TextAlign.center, style: T.display(14)),
          const SizedBox(height: 14),
          if (date != null) ...[
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              PixelChoice(label: L.t('r.today'), selected: date == _today, onTap: () => setState(() => _date = _today)),
              PixelChoice(
                label: L.t('r.tomorrow'),
                selected: date == _today.add(const Duration(days: 1)),
                onTap: () => setState(() => _date = _today.add(const Duration(days: 1))),
              ),
              PixelChoice(
                label: L.t('r.nextWeek'),
                selected: date == _today.add(const Duration(days: 7)),
                onTap: () => setState(() => _date = _today.add(const Duration(days: 7))),
              ),
            ]),
            const SizedBox(height: 12),
            _stepper(
              L.t('r.day'),
              formatDay(date),
              () => setState(() {
                final prev = date.subtract(const Duration(days: 1));
                if (!prev.isBefore(_today)) _date = prev;
              }),
              () => setState(() => _date = date.add(const Duration(days: 1))),
              width: 128,
            ),
            const SizedBox(height: 14),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: _stepper(L.t('r.hour'), '$_h12', () => setState(() => _h12 = _h12 == 1 ? 12 : _h12 - 1),
                  () => setState(() => _h12 = _h12 == 12 ? 1 : _h12 + 1),
                  width: 36),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _stepper(L.t('r.minute'), _m.toString().padLeft(2, '0'),
                  () => setState(() => _m = (_m + 55) % 60), () => setState(() => _m = (_m + 5) % 60),
                  width: 36),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            PixelChoice(label: 'AM', selected: !_pm, onTap: () => setState(() => _pm = false)),
            PixelChoice(label: 'PM', selected: _pm, onTap: () => setState(() => _pm = true)),
          ]),
          const SizedBox(height: 10),
          Text(
            date == null ? formatMinutes(_minutes) : formatDue(date.add(Duration(minutes: _minutes))),
            style: T.body(15, C.gold),
          ),
          const SizedBox(height: 16),
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
            PixelButton(
              label: L.t('r.save'),
              onPressed: () => Navigator.of(context).pop(
                TimeChoice(_minutes, date?.add(Duration(minutes: _minutes))),
              ),
            ),
          ]),
        ]),
      ),
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
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _GlyphPainter(_bell, color ?? C.gold)));
  }
}

/// Calendario pixel de 8 × 8, para fechas límite.
class PixelCalendar extends StatelessWidget {
  final double size;
  final Color? color;
  const PixelCalendar({super.key, this.size = 12, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(_calendar, color ?? C.gold)),
    );
  }
}

const _bell = [
  '...XX...',
  '..XXXX..',
  '.XXXXXX.',
  '.XXXXXX.',
  '.XXXXXX.',
  'XXXXXXXX',
  '........',
  '...XX...',
];

const _calendar = [
  '.X....X.',
  'XXXXXXXX',
  'XXXXXXXX',
  'X......X',
  'X.X.X..X',
  'X......X',
  'X.X.X..X',
  'XXXXXXXX',
];

class _GlyphPainter extends CustomPainter {
  final List<String> rows;
  final Color color;
  _GlyphPainter(this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 8;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (rows[y][x] == 'X') canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color || old.rows != rows;
}
