import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../ui/pixel.dart';

class MissionsScreen extends StatefulWidget {
  final GameState game;
  const MissionsScreen({super.key, required this.game});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _title = TextEditingController();
  String _kind = 'habito';
  String _diff = 'media';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    widget.game.addTask(text, _kind, _diff);
    _title.clear();
    FocusScope.of(context).unfocus();
  }

  void _toggle(Task t) {
    final g = widget.game;
    if (t.doneToday) {
      g.undo(t);
      return;
    }
    final r = g.complete(t);
    if (r.levelTo > r.levelFrom) {
      final unlocked = catalog.where((b) => b.level > r.levelFrom && b.level <= r.levelTo).map((b) => b.name);
      showPixelDialog(
        context,
        '¡Nivel ${r.levelTo}!',
        unlocked.isEmpty ? 'Sigue así, alcalde.' : 'Desbloqueaste: ${unlocked.join(', ')}.',
      );
      return;
    }
    var msg = '+${r.xp} XP · +${r.gold} oro';
    if (r.newRecord) {
      msg += ' · Nuevo récord';
    } else if (r.arrived > 0) {
      msg += r.arrived > 1 ? ' · Llegaron ${r.arrived} vecinos' : ' · Llegó un vecino';
    }
    showToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final habits = g.tasks.where((t) => t.isHabit && !t.doneToday).toList();
    final missions = g.tasks.where((t) => !t.isHabit && t.done == null).toList();
    final done = g.tasks.where((t) => t.doneToday).toList();
    final goldToday = g.goldToday;
    final record = g.goldRecord;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (g.isSample) ...[
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.gold, width: 4))),
            child: Text(
              'Estás viendo datos de ejemplo. Puedes jugar con ellos o empezar de cero desde la pestaña Avance.',
              style: T.body(14, C.dim),
            ),
          ),
          const SizedBox(height: 16),
        ],
        PixelBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: _Figure(label: 'Oro de hoy', value: fmt(goldToday), color: C.gold)),
                Expanded(child: _Figure(label: 'Récord diario', value: fmt(record))),
              ]),
              const SizedBox(height: 12),
              PixelBar(value: record == 0 ? 0.0 : goldToday / record, color: C.gold),
              const SizedBox(height: 4),
              Text(
                record > 0 && goldToday >= record
                    ? 'Hoy es tu mejor día'
                    : 'Te faltan ${fmt((record - goldToday).clamp(0, record).toInt())} de oro para el récord',
                style: T.body(13, C.dim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AddForm(
          controller: _title,
          kind: _kind,
          diff: _diff,
          onKind: (v) => setState(() => _kind = v),
          onDiff: (v) => setState(() => _diff = v),
          onSubmit: _add,
        ),
        const SizedBox(height: 20),
        const SectionTitle('Hábitos diarios'),
        const SizedBox(height: 8),
        if (habits.isEmpty)
          _Empty(g.tasks.any((t) => t.isHabit)
              ? 'Todos los hábitos de hoy están hechos'
              : 'Agrega un hábito que quieras repetir cada día')
        else
          ...habits.map((t) => _TaskRow(task: t, onToggle: () => _toggle(t), onDelete: () => g.deleteTask(t))),
        const SizedBox(height: 20),
        const SectionTitle('Misiones'),
        const SizedBox(height: 8),
        if (missions.isEmpty)
          const _Empty('Sin misiones pendientes. Agrega una arriba.')
        else
          ...missions.map((t) => _TaskRow(task: t, onToggle: () => _toggle(t), onDelete: () => g.deleteTask(t))),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionTitle('Completadas hoy'),
          const SizedBox(height: 8),
          ...done.map((t) => _TaskRow(task: t, onToggle: () => _toggle(t), onDelete: () => g.deleteTask(t))),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Figure({required this.label, required this.value, this.color = C.fg});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(label),
      const SizedBox(height: 2),
      Text(value, style: T.display(24, color)),
    ]);
  }
}

class _AddForm extends StatelessWidget {
  final TextEditingController controller;
  final String kind;
  final String diff;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onDiff;
  final VoidCallback onSubmit;
  const _AddForm({
    required this.controller,
    required this.kind,
    required this.diff,
    required this.onKind,
    required this.onDiff,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final d = difficulties[diff]!;
    return PixelBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Nueva misión o hábito'),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLength: 80,
            style: T.body(16),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Ej. Caminar 20 minutos',
              hintStyle: T.body(16, C.dim),
              counterText: '',
              filled: true,
              fillColor: C.bg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.ink, width: 3)),
              enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.ink, width: 3)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.xp, width: 3)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Tipo', style: T.body(13, C.dim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            PixelChoice(label: 'Hábito diario', selected: kind == 'habito', onTap: () => onKind('habito')),
            PixelChoice(label: 'Misión única', selected: kind == 'mision', onTap: () => onKind('mision')),
          ]),
          const SizedBox(height: 12),
          Text('Dificultad', style: T.body(13, C.dim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in difficulties.values)
              PixelChoice(label: e.name, selected: diff == e.id, onTap: () => onDiff(e.id)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('Recompensa: +${d.xp} XP · +${d.gold} oro', style: T.body(13, C.dim))),
            const SizedBox(width: 10),
            PixelButton(label: 'Agregar', onPressed: onSubmit),
          ]),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TaskRow({required this.task, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = difficulties[task.diff]!;
    final done = task.doneToday;
    final streak = task.isHabit ? task.currentStreak : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: done ? 0.6 : 1,
        child: PixelBox(
          color: C.panel2,
          shadow: false,
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Semantics(
              button: true,
              label: done ? 'Desmarcar ${task.title}' : 'Completar ${task.title}',
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? C.good : C.bg,
                    border: Border.all(color: C.ink, width: 3),
                  ),
                  child: done ? Text('✓', style: T.display(18, C.ink)) : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  task.title,
                  style: T.body(16).copyWith(decoration: done ? TextDecoration.lineThrough : null),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  PixelChip(d.name, color: C.forDifficulty(d.id)),
                  Text('+${d.xp} XP · +${d.gold} oro', style: T.body(12, C.dim)),
                  if (streak > 0) PixelChip('Racha $streak', color: C.bad, textColor: C.fg),
                ]),
              ]),
            ),
            Semantics(
              button: true,
              label: 'Borrar ${task.title}',
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Text('X', style: T.display(14, C.dim)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: C.panel2, width: 3)),
      child: Text(text, textAlign: TextAlign.center, style: T.body(14, C.dim)),
    );
  }
}
