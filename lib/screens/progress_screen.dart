import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../ui/pixel.dart';

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class ProgressScreen extends StatefulWidget {
  final GameState game;
  const ProgressScreen({super.key, required this.game});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _confirmReset = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final stats = <List<String>>[
      ['${g.level}', 'Nivel'],
      [fmt(g.xp), 'XP total'],
      [fmt(g.goldRecord), 'Récord de oro en un día'],
      [fmt(g.totalDone), 'Misiones completadas'],
      ['${g.bestStreak}', 'Mejor racha de hábito'],
      [fmt(g.goldTotal), 'Oro ganado en total'],
    ];

    final days = <_Day>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final s = g.history[dayKey(d)];
      days.add(_Day(i == 0 ? 'Hoy' : _weekdays[d.weekday - 1], s?.xp ?? 0, s?.gold ?? 0, i == 0));
    }

    final statRows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      statRows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Stat(stats[i][0], stats[i][1])),
            const SizedBox(width: 10),
            Expanded(child: _Stat(stats[i + 1][0], stats[i + 1][1])),
          ]),
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ...statRows,
        const SizedBox(height: 6),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('XP · últimos 7 días', style: T.display(16)),
            const SizedBox(height: 10),
            _BarChart(values: days.map((d) => d.xp).toList(), days: days, color: C.xp),
          ]),
        ),
        const SizedBox(height: 16),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Oro · últimos 7 días', style: T.display(16)),
            const SizedBox(height: 10),
            _BarChart(values: days.map((d) => d.gold).toList(), days: days, color: C.gold),
          ]),
        ),
        const SizedBox(height: 16),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Reglas de nivel'),
            const SizedBox(height: 6),
            Text(
              'Empiezas en nivel 1. El nivel n se alcanza al juntar n × 1000 XP en total: '
              'nivel 2 con 2000, nivel 3 con 3000, nivel 10 con 10000.',
              style: T.body(14, C.dim),
            ),
            const SizedBox(height: 14),
            if (!_confirmReset)
              PixelButton(
                label: g.isSample ? 'Borrar ejemplo y empezar de cero' : 'Reiniciar ciudad',
                color: C.panel2,
                textColor: C.fg,
                onPressed: () => setState(() => _confirmReset = true),
              )
            else ...[
              Text('Se borran misiones, oro, XP y edificios. Tu avatar se queda.', style: T.body(14, C.dim)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                PixelButton(
                  label: 'Sí, empezar de cero',
                  color: C.bad,
                  onPressed: () {
                    g.reset();
                    setState(() => _confirmReset = false);
                    showToast(context, 'Ciudad nueva: una casita y mucho por hacer');
                  },
                ),
                PixelButton(
                  label: 'Cancelar',
                  color: C.panel2,
                  textColor: C.fg,
                  onPressed: () => setState(() => _confirmReset = false),
                ),
              ]),
            ],
          ]),
        ),
      ],
    );
  }
}

class _Day {
  final String label;
  final int xp;
  final int gold;
  final bool isToday;
  const _Day(this.label, this.xp, this.gold, this.isToday);
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      color: C.panel2,
      shadow: false,
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: T.display(20)),
        Text(label, style: T.body(12, C.dim)),
      ]),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<int> values;
  final List<_Day> days;
  final Color color;
  const _BarChart({required this.values, required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    final top = max(1, values.fold<int>(0, (a, b) => max(a, b)));
    const maxBar = 120.0;
    final faded = Color.lerp(color, C.panel2, 0.55)!;
    return Column(children: [
      SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(fmt(values[i]), style: T.display(10, days[i].isToday ? C.fg : C.dim)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: max(2.0, values[i] / top * maxBar),
                      decoration: BoxDecoration(
                        color: days[i].isToday ? color : faded,
                        border: const Border(
                          top: BorderSide(color: C.ink, width: 2),
                          left: BorderSide(color: C.ink, width: 2),
                          right: BorderSide(color: C.ink, width: 2),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
      Container(height: 3, color: C.ink),
      const SizedBox(height: 4),
      Row(children: [
        for (final d in days)
          Expanded(
            child: Text(d.label, textAlign: TextAlign.center, style: T.body(12, d.isToday ? C.fg : C.dim)),
          ),
      ]),
    ]);
  }
}
