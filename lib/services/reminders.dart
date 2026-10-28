import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';

/// Recordatorios con notificaciones estilo pixel: ícono del gatito, color dorado
/// y una imagen de la ciudad al atardecer en el recordatorio diario.
class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  static const int _dailyId = 1;
  static const int _testId = 2;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_pixel')),
      );
      _ready = true;
    } catch (_) {
      _ready = false; // la app sigue funcionando sin notificaciones
    }
  }

  /// Pide permiso de notificaciones (Android 13+). Regresa false si se negó.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _details(String title, String body, {bool banner = false}) {
    const cat = DrawableResourceAndroidBitmap('notif_cat');
    final style = banner
        ? BigPictureStyleInformation(
            const DrawableResourceAndroidBitmap('notif_banner'),
            largeIcon: cat,
            contentTitle: title,
            summaryText: body,
            hideExpandedLargeIcon: true,
          )
        : BigTextStyleInformation(body, contentTitle: title);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'recordatorios',
        L.t('r.channel'),
        channelDescription: L.t('r.channelDesc'),
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_pixel',
        color: const Color(0xFFF4B942),
        largeIcon: cat,
        styleInformation: style,
      ),
    );
  }

  /// Muestra una notificación de prueba ahora mismo.
  static Future<void> showTest() async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _testId,
        title: L.t('r.dailyTitle'),
        body: L.t('r.testBody'),
        notificationDetails: _details(L.t('r.dailyTitle'), L.t('r.testBody'), banner: true),
      );
    } catch (_) {}
  }

  /// Reprograma los recordatorios un momento después del último cambio.
  static void scheduleSoon(GameState g) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => reschedule(g));
  }

  static DateTime _next(int minutes, {bool skipToday = false}) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (skipToday || !at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  static Future<void> _at(int id, DateTime when, String title, String body,
      {bool daily = false, bool banner = false}) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: _details(title, body, banner: banner),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
    );
  }

  static int _taskId(Task t) => 1000 + (t.id.hashCode & 0x0FFFFFFF);

  static Future<void> reschedule(GameState g) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!g.remindersOn) return;

      final pending = g.tasks.where((t) => !t.doneToday && (t.isHabit || t.done == null)).length;
      await _at(
        _dailyId,
        _next(g.reminderMinutes),
        L.t('r.dailyTitle'),
        pending > 0 ? L.f('r.dailyBody', {'n': pending}) : L.t('r.dailyBodyNone'),
        daily: true,
        banner: true,
      );

      for (final t in g.tasks) {
        final m = t.reminder;
        if (m == null) continue;
        final d = difficulties[t.diff]!;
        final body = L.f('r.taskBody', {'xp': d.xp, 'gold': d.gold});
        if (t.isHabit) {
          // Si ya se cumplió hoy, el primer aviso es mañana.
          await _at(_taskId(t), _next(m, skipToday: t.doneToday), L.f('r.habitTitle', {'t': t.title}), body,
              daily: true);
        } else if (t.done == null) {
          await _at(_taskId(t), _next(m), L.f('r.missionTitle', {'t': t.title}), body);
        }
      }
    } catch (_) {
      // Un error al programar no debe romper la app.
    }
  }
}
