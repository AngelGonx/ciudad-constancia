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
  final List<String> _steps = []; // checklist opcional
  final _stepInput = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _stepInput.dispose();
    super.dispose();
  }

  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _add() {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    final habit = _kind == 'habito';
    final wantsAlert = habit ? _reminder != null : _due != null;
    final pendingStep = _stepInput.text.trim();
    if (pendingStep.isNotEmpty) _steps.add(pendingStep);
    widget.game.addTask(text, _kind, _diff, reminder: _reminder, due: _due, steps: List.of(_steps));
    _title.clear();
    _stepInput.clear();
    setState(() {
      _reminder = null;
      _due = null;
      _steps.clear();
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
    if (t.hasSteps && t.stepsDone < t.steps.length) {
      showToast(context, L.f('m.stepsLeft', {'n': t.steps.length - t.stepsDone}));
      return;
    }
    final wait = t.freshInkLeft;
    if (wait > 0) {
      showToast(context, L.f('m.freshInk', {'n': wait}));
      return;
    }
    _celebrate(g.complete(t));
  }

  void _toggleStep(Task t, int i) {
    _hideKeyboard();
    final r = widget.game.toggleStep(t, i);
    if (r.freshInkWait > 0) {
      showToast(context, L.f('m.freshInk', {'n': r.freshInkWait}));
    } else if (r.completed != null) {
      _celebrate(r.completed!);
    }
  }

  /// Sonido y aviso al completar una tarea.
  void _celebrate(CompleteResult r) {
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

    if (g.lastFreezeUsed > 0) {
      final used = g.lastFreezeUsed, saved = g.lastFreezeSaved;
      g.lastFreezeUsed = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showToast(context, L.f('m.freezeUsed', {'n': used, 'h': saved}));
      });
    }

    Widget row(Task t) => _TaskRow(
          key: ValueKey(t.id),
          task: t,
          onStep: (i) => _toggleStep(t, i),
          onAddStep: (text) => g.addStep(t, text),
          onRemoveStep: (i) => g.removeStep(t, i),
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
            steps: _steps,
            stepInput: _stepInput,
            onAddStep: () {
              final v = _stepInput.text.trim();
              if (v.isEmpty || _steps.length >= 12) return;
              setState(() => _steps.add(v));
              _stepInput.clear();
            },
            onRemoveStep: (i) => setState(() => _steps.removeAt(i)),
            onSubmit: _add,
          ),
          const SizedBox(height: 20),
          SectionTitle(L.t('m.habits')),
          const SizedBox(height: 8),
          if (g.tasks.any((t) => t.isHabit)) ...[
            _FreezeBox(game: g),
            const SizedBox(height: 8),
          ],
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
  final List<String> steps;
  final TextEditingController stepInput;
  final VoidCallback onAddStep;
  final ValueChanged<int> onRemoveStep;
  final VoidCallback onSubmit;
  const _AddForm({
    required this.steps,
    required this.stepInput,
    required this.onAddStep,
    required this.onRemoveStep,
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
          const SizedBox(height: 12),
          Text(L.t(kind == 'habito' ? 'm.checklistHabit' : 'm.checklist'), style: T.body(13, C.dim)),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(border: Border.all(color: C.dim, width: 2))),
                const SizedBox(width: 8),
                Expanded(child: Text(steps[i], style: T.body(14))),
                GestureDetector(
                  onTap: () => onRemoveStep(i),
                  child: Padding(padding: const EdgeInsets.all(6), child: Text('X', style: T.display(11, C.dim))),
                ),
              ]),
            ),
          _StepInput(controller: stepInput, onAdd: onAddStep),
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

class _TaskRow extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onReminder;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onAddStep;
  final ValueChanged<int> onRemoveStep;
  final int streakBonusPct;
  const _TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onReminder,
    required this.onStep,
    required this.onAddStep,
    required this.onRemoveStep,
    this.streakBonusPct = 0,
  });

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool? _open; // null = automático: abierta si tiene pasos y no está completada
  final _stepInput = TextEditingController();

  @override
  void dispose() {
    _stepInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final d = difficulties[task.diff]!;
    final done = task.doneToday;
    final streak = task.isHabit ? task.currentStreak : 0;
    final hasSteps = task.hasSteps;
    final open = _open ?? (hasSteps && !done);
    final progress = '${task.stepsDone}/${task.steps.length}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: done ? 0.6 : 1,
        child: PixelBox(
          color: C.panel2,
          shadow: false,
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Semantics(
                button: true,
                label: L.f(done ? 'm.uncheck' : 'm.complete', {'t': task.title}),
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? C.good : C.bg,
                      border: Border.all(color: C.ink, width: 3),
                    ),
                    child: done
                        ? Text('✓', style: T.display(18, C.onAccent))
                        : (hasSteps ? Text(progress, style: T.display(10, C.gold)) : null),
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
                    if (widget.streakBonusPct > 0)
                      PixelChip(L.f('m.streakChip', {'n': widget.streakBonusPct}), color: C.gold),
                    _AlertChip(task: task, onTap: widget.onReminder),
                    GestureDetector(
                      onTap: () => setState(() => _open = !open),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: hasSteps ? C.xp : C.panel, width: 2)),
                        child: Text(
                          hasSteps ? '${L.t('m.steps')} $progress ${open ? '-' : '+'}' : '+ ${L.t('m.steps')}',
                          style: T.display(10, hasSteps ? C.xp : C.dim),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
              Semantics(
                button: true,
                label: L.f('m.delete', {'t': task.title}),
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Text('X', style: T.display(14, C.dim)),
                  ),
                ),
              ),
            ]),
            if (open) ...[
              const SizedBox(height: 8),
              if (hasSteps) ...[
                PixelBar(value: task.stepsDone / task.steps.length, height: 8, color: C.xp),
                const SizedBox(height: 6),
              ],
              for (var i = 0; i < task.steps.length; i++)
                _StepRow(
                  title: task.steps[i].title,
                  done: task.stepDone(task.steps[i]),
                  onTap: () => widget.onStep(i),
                  onRemove: () => widget.onRemoveStep(i),
                ),
              if (task.isHabit && hasSteps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(L.t('m.stepsDaily'), style: T.body(12, C.dim)),
                ),
              _StepInput(
                controller: _stepInput,
                onAdd: () {
                  widget.onAddStep(_stepInput.text);
                  _stepInput.clear();
                },
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Un paso de la checklist dentro de una tarea.
class _StepRow extends StatelessWidget {
  final String title;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _StepRow({required this.title, required this.done, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? C.good : C.bg,
                    border: Border.all(color: C.ink, width: 2),
                  ),
                  child: done ? Text('✓', style: T.display(12, C.onAccent)) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: T.body(14, done ? C.dim : C.fg)
                        .copyWith(decoration: done ? TextDecoration.lineThrough : null),
                  ),
                ),
              ]),
            ),
          ),
        ),
        GestureDetector(
          onTap: onRemove,
          child: Padding(padding: const EdgeInsets.all(8), child: Text('X', style: T.display(10, C.dim))),
        ),
      ]),
    );
  }
}

/// Campo para agregar un paso a la checklist.
class _StepInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  const _StepInput({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          maxLength: 60,
          style: T.body(14),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: pixelInput(hint: L.t('m.stepHint')),
        ),
      ),
      const SizedBox(width: 8),
      PixelButton(
        label: '+',
        onPressed: onAdd,
        color: C.panel,
        textColor: C.fg,
        fontSize: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ]);
  }
}

/// Días libres: cuántos tienes y botón para comprar más.
class _FreezeBox extends StatelessWidget {
  final GameState game;
  const _FreezeBox({required this.game});

  @override
  Widget build(BuildContext context) {
    final n = game.streakFreezes;
    final full = n >= GameState.maxFreezes;
    final poor = game.gold < GameState.freezePrice;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: C.xp, width: 2)),
      child: Row(children: [
        for (var i = 0; i < GameState.maxFreezes; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _FreezeIcon(active: i < n),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.f('m.freezes', {'n': n, 'max': GameState.maxFreezes}), style: T.display(11, C.xp)),
            const SizedBox(height: 2),
            Text(L.t('m.freezeText'), style: T.body(12, C.dim)),
          ]),
        ),
        const SizedBox(width: 6),
        PixelButton(
          label: full ? L.t('m.freezeFull') : (poor ? L.t('c.reasonGold') : L.f('m.freezeBuy', {'n': GameState.freezePrice})),
          onPressed: full || poor
              ? null
              : () {
                  if (game.buyFreeze()) {
                    Sounds.build();
                    showToast(context, L.t('m.freezeBought'));
                  }
                },
          fontSize: 10,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ]),
    );
  }
}

/// Copo de nieve pixel: día libre disponible (azul) o vacío.
class _FreezeIcon extends StatelessWidget {
  final bool active;
  const _FreezeIcon({required this.active});

  static const _rows = [
    '...X...',
    '.X.X.X.',
    '..XXX..',
    'XXXXXXX',
    '..XXX..',
    '.X.X.X.',
    '...X...',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GlyphPainter(_rows, active ? C.xp : C.panel)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final List<String> rows;
  final Color color;
  _GlyphPainter(this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / rows.length;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == 'X') canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
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
