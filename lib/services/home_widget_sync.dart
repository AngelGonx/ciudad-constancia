import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';
import '../ui/pixel.dart' show fmt;
import 'reminders.dart';

/// Sincroniza la app con el widget de pantalla de inicio.
class HomeWidgetSync {
  static const String _provider = 'com.angelgonx.ciudad_constancia.PixelTodoWidget';
  static const int maxRows = 5;
  static Timer? _debounce;

  static Future<void> init() async {
    try {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (_) {}
  }

  static void pushSoon(GameState g) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => push(g));
  }

  /// Pendientes primero (misiones con fecha más cercana arriba) y luego lo completado hoy.
  static List<Task> _rows(GameState g) {
    final pending = g.tasks.where((t) => !t.doneToday && (t.isHabit || t.done == null)).toList()
      ..sort((a, b) => (a.due ?? 1 << 62).compareTo(b.due ?? 1 << 62));
    final done = g.tasks.where((t) => t.doneToday).toList();
    return [...pending, ...done].take(maxRows).toList();
  }

  static Future<void> push(GameState g, {String? message}) async {
    try {
      final rows = _rows(g);
      final pending = g.tasks.where((t) => !t.doneToday && (t.isHabit || t.done == null)).length;
      final data = <String, Object>{
        'day': today(),
        'title': L.t('w.title'),
        'subtitle': L.f('w.subtitle', {'level': g.level, 'gold': fmt(g.gold), 'today': fmt(g.goldToday)}),
        'footer': message ?? (pending == 0 ? L.t('w.allDone') : L.f('w.footer', {'n': pending})),
        'footer_stale': L.t('w.newDay'),
        'count': rows.length,
      };
      for (var i = 0; i < rows.length; i++) {
        final t = rows[i];
        final d = difficulties[t.diff]!;
        data['task_${i}_id'] = t.id;
        data['task_${i}_title'] = t.title;
        data['task_${i}_meta'] = '+${d.gold}';
        data['task_${i}_habit'] = t.isHabit;
        data['task_${i}_done'] = t.doneToday;
      }
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (_) {
      // Sin widget en la pantalla (o en pruebas) no pasa nada.
    }
  }
}

/// Se ejecuta en segundo plano cuando se toca un pendiente del widget.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null || uri.host != 'complete') return;
  final id = uri.queryParameters['id'];
  final g = GameState();
  await g.load();
  String? message;
  final matches = g.tasks.where((t) => t.id == id);
  if (matches.isNotEmpty) {
    final t = matches.first;
    if (t.doneToday) {
      message = L.t('w.already');
    } else if (t.freshInkLeft > 0) {
      message = L.f('m.freshInk', {'n': t.freshInkLeft});
    } else {
      final r = g.complete(t);
      message = L.f('w.done', {'xp': r.xp, 'gold': r.gold});
      await g.saveNow();
      try {
        await Reminders.init();
        await Reminders.reschedule(g);
      } catch (_) {}
    }
  }
  await HomeWidgetSync.push(g, message: message);
}
