import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';
import '../ui/pixel.dart';

class MissionsScreen extends StatefulWidget {
  final GameState game;
  const MissionsScreen({super.key, required this.game});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  String _kind = 'habito';
  String _diff = 'media';

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _add() {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    widget.game.addTask(text, _kind, _diff);
    _title.clear();
    _hideKeyboard();
  }

  void _toggle(Task t) {
    // Al marcar una tarea nunca debe abrirse el teclado (ni al cerrar el aviso de nivel).
    _hideKeyboard();
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
        L.f('m.levelUp', {'n': r.levelTo}),
        unlocked.isEmpty ? L.t('m.keepGoing') : L.f('m.unlocked', {'list': unlocked.join(', ')}),
      );
      return;
    }
    var msg = L.f('m.gain', {'xp': r.xp, 'gold': r.gold});
    if (r.newRecord) {
      msg += L.t('m.newRecord');
    } else if (r.arrived > 0) {
      msg += r.arrived > 1 ? L.f('m.manyArrived', {'n': r.arrived}) : L.t('m.oneArrived');
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

    Widget row(Task t) => _TaskRow(task: t, onToggle: () => _toggle(t), onDelete: () => g.deleteTask(t));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _hideKeyboard,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (g.isSample) ...[
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: C.gold, width: 4))),
              child: Text(L.t('m.sample'), style: T.body(14, C.dim)),
            ),
            const SizedBox(height: 16),
          ],
          PixelBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _Figure(label: L.t('m.goldToday'), value: fmt(goldToday), color: C.gold)),
                  Expanded(child: _Figure(label: L.t('m.record'), value: fmt(record))),
                ]),
                const SizedBox(height: 12),
                PixelBar(value: record == 0 ? 0.0 : goldToday / record, color: C.gold),
                const SizedBox(height: 4),
                Text(
                  record > 0 && goldToday >= record
                      ? L.t('m.bestDay')
                      : L.f('m.toRecord', {'n': fmt((record - goldToday).clamp(0, record).toInt())}),
                  style: T.body(13, C.dim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AddForm(
            controller: _title,
            focusNode: _titleFocus,
            kind: _kind,
            diff: _diff,
            onKind: (v) => setState(() => _kind = v),
            onDiff: (v) => setState(() => _diff = v),
            onSubmit: _add,
          ),
          const SizedBox(height: 20),
          SectionTitle(L.t('m.habits')),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            _Empty(g.tasks.any((t) => t.isHabit) ? L.t('m.habitsDone') : L.t('m.habitsEmpty'))
          else
            ...habits.map(row),
          const SizedBox(height: 20),
          SectionTitle(L.t('m.missions')),
          const SizedBox(height: 8),
          if (missions.isEmpty) _Empty(L.t('m.missionsEmpty')) else ...missions.map(row),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionTitle(L.t('m.doneToday')),
            const SizedBox(height: 8),
            ...done.map(row),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Figure({required this.label, required this.value, this.color});

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
  final FocusNode focusNode;
  final String kind;
  final String diff;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onDiff;
  final VoidCallback onSubmit;
  const _AddForm({
    required this.controller,
    required this.focusNode,
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
          SectionTitle(L.t('m.new')),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: 80,
            style: T.body(16),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            onTapOutside: (_) => focusNode.unfocus(),
            decoration: pixelInput(hint: L.t('m.hint')),
          ),
          const SizedBox(height: 12),
          Text(L.t('m.type'), style: T.body(13, C.dim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            PixelChoice(label: L.t('m.habit'), selected: kind == 'habito', onTap: () => onKind('habito')),
            PixelChoice(label: L.t('m.once'), selected: kind == 'mision', onTap: () => onKind('mision')),
          ]),
          const SizedBox(height: 12),
          Text(L.t('m.difficulty'), style: T.body(13, C.dim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in difficulties.values)
              PixelChoice(label: e.name, selected: diff == e.id, onTap: () => onDiff(e.id)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(L.f('m.reward', {'xp': d.xp, 'gold': d.gold}), style: T.body(13, C.dim))),
            const SizedBox(width: 10),
            PixelButton(label: L.t('m.add'), onPressed: onSubmit),
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
              label: L.f(done ? 'm.uncheck' : 'm.complete', {'t': task.title}),
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
                  child: done ? Text('✓', style: T.display(18, C.onAccent)) : null,
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
                  Text(L.f('m.gain', {'xp': d.xp, 'gold': d.gold}), style: T.body(12, C.dim)),
                  if (streak > 0) PixelChip(L.f('m.streak', {'n': streak}), color: C.bad, textColor: C.fg),
                ]),
              ]),
            ),
            Semantics(
              button: true,
              label: L.f('m.delete', {'t': task.title}),
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
