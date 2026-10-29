import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';
import '../services/reminders.dart';
import '../services/sounds.dart';
import '../ui/cat_buddy.dart';
import '../ui/pixel.dart';
import '../ui/time_picker.dart';

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
  int? _reminder; // hábitos
  DateTime? _due; // misiones únicas

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
    final habit = _kind == 'habito';
    final wantsAlert = habit ? _reminder != null : _due != null;
    widget.game.addTask(text, _kind, _diff, reminder: _reminder, due: _due);
    _title.clear();
    setState(() {
      _reminder = null;
      _due = null;
    });
    _hideKeyboard();
    if (wantsAlert) _turnOnAlerts();
  }

  /// Al poner un recordatorio o fecha límite se activan los avisos y se pide permiso.
  Future<void> _turnOnAlerts() async {
    final g = widget.game;
    if (g.remindersOn) return;
    final ok = await Reminders.ensureEnabled(g);
    if (!mounted) return;
    showToast(context, ok ? L.t('r.enabled') : L.t('r.denied'));
  }

  Future<void> _editAlert(Task t) async {
    if (t.isHabit) {
      final choice = await pickTime(context, t.reminder ?? 9 * 60, allowRemove: t.reminder != null);
      if (choice == null || !mounted) return;
      widget.game.setTaskReminder(t, choice.removed ? null : choice.minutes);
      if (!choice.removed) _turnOnAlerts();
    } else {
      final choice = await pickDateTime(context, t.dueDate ?? _defaultDue(), allowRemove: t.due != null);
      if (choice == null || !mounted) return;
      widget.game.setTaskDue(t, choice.removed ? null : choice.date);
      if (!choice.removed) _turnOnAlerts();
    }
  }

  void _toggle(Task t) {
    // Al marcar una tarea nunca debe abrirse el teclado (ni al cerrar el aviso de nivel).
    _hideKeyboard();
    final g = widget.game;
    if (t.doneToday) {
      g.undo(t);
      return;
    }
    final wait = t.freshInkLeft;
    if (wait > 0) {
      showToast(context, L.f('m.freshInk', {'n': wait}));
      return;
    }
    final r = g.complete(t);
    if (r.levelTo > r.levelFrom) {
      Sounds.levelUp();
      final unlocked = catalog.where((b) => b.level > r.levelFrom && b.level <= r.levelTo).map((b) => b.name);
      showPixelDialog(
        context,
        L.f('m.levelUp', {'n': r.levelTo}),
        unlocked.isEmpty ? L.t('m.keepGoing') : L.f('m.unlocked', {'list': unlocked.join(', ')}),
      );
      return;
    }
    Sounds.task();
    var msg = L.f('m.gain', {'xp': r.xp, 'gold': r.gold});
    if (r.streakBonusPct > 0) msg += L.f('m.streakBonus', {'n': r.streakBonusPct});
    if (r.reduced) msg += L.t('m.reduced');
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

    Widget row(Task t) => _TaskRow(
          task: t,
          streakBonusPct: g.nextStreakBonusPct(t),
          onToggle: () => _toggle(t),
          onDelete: () => g.deleteTask(t),
          onReminder: () => _editAlert(t),
        );

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
                const SizedBox(height: 8),
                Text(
                  g.fullRewardsLeft > 0
                      ? L.f('m.fullLeft', {'n': g.fullRewardsLeft, 'max': fullRewardsPerDay})
                      : L.t('m.fullNone'),
                  style: T.body(13, g.fullRewardsLeft > 0 ? C.fg : C.bad),
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
            reminder: _reminder,
            due: _due,
            onKind: (v) => setState(() => _kind = v),
            onDiff: (v) => setState(() => _diff = v),
            onReminder: (v) => setState(() => _reminder = v),
            onDue: (v) => setState(() => _due = v),
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
          CatBuddy(game: g),
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
  final int? reminder;
  final DateTime? due;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onDiff;
  final ValueChanged<int?> onReminder;
  final ValueChanged<DateTime?> onDue;
  final VoidCallback onSubmit;
  const _AddForm({
    required this.controller,
    required this.focusNode,
    required this.kind,
    required this.diff,
    required this.reminder,
    required this.due,
    required this.onKind,
    required this.onDiff,
    required this.onReminder,
    required this.onDue,
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
          const SizedBox(height: 12),
          if (kind == 'habito') ...[
            Text(L.t('r.reminder'), style: T.body(13, C.dim)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PixelChoice(label: L.t('r.none'), selected: reminder == null, onTap: () => onReminder(null)),
              PixelChoice(
                label: reminder == null ? '+ ${L.t('r.hour')}' : formatMinutes(reminder!),
                selected: reminder != null,
                onTap: () async {
                  final choice = await pickTime(context, reminder ?? 9 * 60);
                  if (choice != null && !choice.removed) onReminder(choice.minutes);
                },
              ),
            ]),
          ] else ...[
            Text(L.t('r.due'), style: T.body(13, C.dim)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PixelChoice(label: L.t('r.noDue'), selected: due == null, onTap: () => onDue(null)),
              PixelChoice(
                label: due == null ? '+ ${L.t('r.due')}' : formatDue(due!),
                selected: due != null,
                onTap: () async {
                  final choice = await pickDateTime(context, due ?? _defaultDue());
                  if (choice != null && !choice.removed) onDue(choice.date);
                },
              ),
            ]),
          ],
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
  final VoidCallback onReminder;
  final int streakBonusPct;
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onReminder,
    this.streakBonusPct = 0,
  });

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
                  if (streakBonusPct > 0) PixelChip(L.f('m.streakChip', {'n': streakBonusPct}), color: C.gold),
                  _AlertChip(task: task, onTap: onReminder),
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

/// Por defecto, la fecha límite es mañana a las 6:00 p. m.
DateTime _defaultDue() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + 1, 18);
}

/// Campanita (hábitos) o calendario (misiones) con la hora o fecha límite.
class _AlertChip extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const _AlertChip({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habit = task.isHabit;
    final due = task.dueDate;
    final hasAlert = habit ? task.reminder != null : due != null;
    final isLate = task.overdue;
    final color = !hasAlert ? C.dim : (isLate ? C.bad : C.gold);
    final label = habit
        ? (task.reminder == null ? null : formatMinutes(task.reminder!))
        : (due == null ? null : L.f(isLate ? 'm.overdue' : 'm.due', {'d': formatDue(due)}));
    return Semantics(
      button: true,
      label: L.t(habit ? 'r.reminder' : 'r.due'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: hasAlert ? color : C.panel, width: 2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (habit) PixelBell(size: 10, color: color) else PixelCalendar(size: 10, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: T.display(10, color))),
            ],
          ]),
        ),
      ),
    );
  }
}
