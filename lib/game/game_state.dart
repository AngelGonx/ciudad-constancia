import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import 'rules.dart';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String dayOffset(int days) => dayKey(DateTime.now().add(Duration(days: days)));
String today() => dayKey(DateTime.now());

class Task {
  String id;
  String title;
  String kind; // 'habito' o 'mision'
  String diff;
  int streak;
  String? last; // hábito: último día completado
  String? done; // misión: día en que se completó
  String? prevLast;
  int prevStreak;
  int earnedXp;
  int earnedGold;
  int earnedPeople;

  Task({
    required this.id,
    required this.title,
    required this.kind,
    required this.diff,
    this.streak = 0,
    this.last,
    this.done,
    this.prevLast,
    this.prevStreak = 0,
    this.earnedXp = 0,
    this.earnedGold = 0,
    this.earnedPeople = 0,
  });

  bool get isHabit => kind == 'habito';
  bool get doneToday => isHabit ? last == today() : done == today();

  /// Racha visible: se pierde si no se cumplió ayer ni hoy.
  int get currentStreak => (last == today() || last == dayOffset(-1)) ? streak : 0;

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'kind': kind, 'diff': diff, 'streak': streak,
        'last': last, 'done': done, 'prevLast': prevLast, 'prevStreak': prevStreak,
        'earnedXp': earnedXp, 'earnedGold': earnedGold, 'earnedPeople': earnedPeople,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: j['kind'] as String,
        diff: j['diff'] as String,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        last: j['last'] as String?,
        done: j['done'] as String?,
        prevLast: j['prevLast'] as String?,
        prevStreak: (j['prevStreak'] as num?)?.toInt() ?? 0,
        earnedXp: (j['earnedXp'] as num?)?.toInt() ?? 0,
        earnedGold: (j['earnedGold'] as num?)?.toInt() ?? 0,
        earnedPeople: (j['earnedPeople'] as num?)?.toInt() ?? 0,
      );
}

/// Avatar: los colores se guardan como ARGB para permitir cualquier color.
class Avatar {
  int skin;
  String hair;
  int hairColor;
  int shirt;
  int pants;
  String accessory;

  Avatar({
    this.skin = 0xFFE0AC7E,
    this.hair = 'corto',
    this.hairColor = 0xFF2A1D17,
    this.shirt = 0xFF3D78A8,
    this.pants = 0xFF2F2F3A,
    this.accessory = 'ninguno',
  });

  Map<String, dynamic> toJson() =>
      {'skin': skin, 'hair': hair, 'hairColor': hairColor, 'shirt': shirt, 'pants': pants, 'accessory': accessory};

  // Versiones anteriores guardaban un índice de paleta; se convierte a color.
  static const _oldSkin = [0xFFF6D2B0, 0xFFE0AC7E, 0xFFB9784F, 0xFF7A4A2E];
  static const _oldHair = [0xFF2A1D17, 0xFF6B3F2A, 0xFFC98A3C, 0xFFE8D27A, 0xFFB84A3A, 0xFF8A8A9A];
  static const _oldCloth = [0xFF3D78A8, 0xFFD24C4C, 0xFF3E8C56, 0xFFF4B942, 0xFF8C5A8F, 0xFFEFE6D6, 0xFF2F2F3A];

  static int _color(Object? v, List<int> old, int fallback) {
    if (v is! num) return fallback;
    final i = v.toInt();
    if (i >= 0 && i < old.length) return old[i];
    return i;
  }

  factory Avatar.fromJson(Map<String, dynamic> j) => Avatar(
        skin: _color(j['skin'], _oldSkin, 0xFFE0AC7E),
        hair: j['hair'] as String? ?? 'corto',
        hairColor: _color(j['hairColor'], _oldHair, 0xFF2A1D17),
        shirt: _color(j['shirt'], _oldCloth, 0xFF3D78A8),
        pants: _color(j['pants'], _oldCloth, 0xFF2F2F3A),
        accessory: j['accessory'] as String? ?? 'ninguno',
      );
}

class DayStat {
  int xp;
  int gold;
  DayStat({this.xp = 0, this.gold = 0});
  Map<String, dynamic> toJson() => {'xp': xp, 'gold': gold};
  factory DayStat.fromJson(Map<String, dynamic> j) =>
      DayStat(xp: (j['xp'] as num?)?.toInt() ?? 0, gold: (j['gold'] as num?)?.toInt() ?? 0);
}

class CityStats {
  final Map<String, int> capacity;
  final Map<String, int> need;
  final int population;
  final int happiness;
  final double bonus;
  const CityStats(this.capacity, this.need, this.population, this.happiness, this.bonus);

  int get housing => capacity['vivienda'] ?? 0;
  bool get acceptsNewcomers => happiness >= 60 || population < 5;
}

class CompleteResult {
  final int xp;
  final int gold;
  final int arrived;
  final int levelFrom;
  final int levelTo;
  final bool newRecord;
  const CompleteResult(this.xp, this.gold, this.arrived, this.levelFrom, this.levelTo, this.newRecord);
}

class GameState extends ChangeNotifier {
  static const _storageKey = 'pixel_todo_state_v1';

  /// Idioma elegido ('es' o 'en'); null hasta que se elige en el primer inicio.
  String? language;
  bool lightTheme = false;
  String name = 'Alcalde';
  int xp = 0;
  int gold = 100;
  int population = 1;
  int totalDone = 0;
  int bestStreak = 0;
  bool isSample = false;
  Avatar avatar = Avatar();
  List<String> buildings = ['hogar'];
  List<Task> tasks = [];
  Map<String, DayStat> history = {};

  int _idCounter = DateTime.now().millisecondsSinceEpoch;
  String _newId() => 't${_idCounter++}';

  int get level => levelOf(xp);

  // ---------- persistencia ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) {
        _fillSample();
      } else {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      _fillSample();
    }
    L.lang = language ?? 'es';
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (_) {
      // Si falla el guardado, el juego sigue funcionando en memoria.
    }
  }

  void _commit() {
    notifyListeners();
    _save();
  }

  Map<String, dynamic> _toJson() => {
        'language': language, 'lightTheme': lightTheme, 'name': name, 'xp': xp, 'gold': gold, 'population': population, 'totalDone': totalDone,
        'bestStreak': bestStreak, 'isSample': isSample, 'avatar': avatar.toJson(), 'buildings': buildings,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'history': history.map((k, v) => MapEntry(k, v.toJson())),
      };

  void _fromJson(Map<String, dynamic> j) {
    language = j['language'] as String?;
    lightTheme = j['lightTheme'] as bool? ?? false;
    name = j['name'] as String? ?? 'Alcalde';
    xp = (j['xp'] as num?)?.toInt() ?? 0;
    gold = (j['gold'] as num?)?.toInt() ?? 0;
    population = (j['population'] as num?)?.toInt() ?? 1;
    totalDone = (j['totalDone'] as num?)?.toInt() ?? 0;
    bestStreak = (j['bestStreak'] as num?)?.toInt() ?? 0;
    isSample = j['isSample'] as bool? ?? false;
    avatar = Avatar.fromJson((j['avatar'] as Map?)?.cast<String, dynamic>() ?? {});
    buildings = ((j['buildings'] as List?) ?? ['hogar']).map((e) => e as String).toList();
    tasks = ((j['tasks'] as List?) ?? [])
        .map((e) => Task.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    history = ((j['history'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, DayStat.fromJson((v as Map).cast<String, dynamic>())));
  }

  /// Datos de ejemplo para la primera vez que se abre la app.
  void _fillSample() {
    isSample = true;
    name = L.t('mayor');
    xp = 2350;
    gold = 480;
    population = 4;
    totalDone = 41;
    bestStreak = 6;
    buildings = ['hogar', 'casa', 'tiendita', 'pozo', 'poste'];
    history = {};
    const week = [[420, 70], [780, 135], [300, 55], [950, 160], [600, 100], [520, 90]];
    for (var i = 0; i < week.length; i++) {
      history[dayOffset(i - 6)] = DayStat(xp: week[i][0], gold: week[i][1]);
    }
    history[today()] = DayStat();
    final y = dayOffset(-1);
    tasks = [
      Task(id: _newId(), title: L.t('ex.1'), kind: 'habito', diff: 'facil', streak: 6, last: y),
      Task(id: _newId(), title: L.t('ex.2'), kind: 'habito', diff: 'media', streak: 3, last: y),
      Task(id: _newId(), title: L.t('ex.3'), kind: 'habito', diff: 'dificil', streak: 1, last: y),
      Task(id: _newId(), title: L.t('ex.4'), kind: 'mision', diff: 'media'),
      Task(id: _newId(), title: L.t('ex.5'), kind: 'mision', diff: 'facil'),
      Task(id: _newId(), title: L.t('ex.6'), kind: 'mision', diff: 'epica'),
    ];
  }

  /// Borra todo y empieza con una casita. El avatar se conserva.
  void reset() {
    name = isSample ? L.t('mayor') : name;
    isSample = false;
    xp = 0;
    gold = 100;
    population = 1;
    totalDone = 0;
    bestStreak = 0;
    buildings = ['hogar'];
    tasks = [];
    history = {today(): DayStat()};
    _commit();
  }

  // ---------- estadísticas ----------

  DayStat get todayStat => history.putIfAbsent(today(), () => DayStat());
  int get goldToday => history[today()]?.gold ?? 0;
  int get goldRecord => history.values.fold<int>(0, (m, h) => max(m, h.gold));
  int get goldTotal => history.values.fold<int>(0, (s, h) => s + h.gold);

  CityStats city() {
    final cap = <String, int>{for (final k in [...needKeys, 'felicidad']) k: 0};
    for (final id in buildings) {
      buildingById(id).capacity.forEach((k, v) => cap[k] = (cap[k] ?? 0) + v);
    }
    final p = population;
    final need = <String, int>{
      'vivienda': p,
      'empleo': (p * 0.6).ceil(),
      'escuela': (p * 0.3).ceil(),
      'agua': p,
      'luz': p,
      'basura': p,
    };
    var sum = 0.0;
    for (final k in needKeys) {
      final n = need[k]!;
      sum += n == 0 ? 1 : min(1.0, cap[k]! / n);
    }
    final happiness = min(100, (sum / needKeys.length * 100).round() + cap['felicidad']!);
    final bonus = happiness >= 90 ? 0.2 : (happiness >= 70 ? 0.1 : 0.0);
    return CityStats(cap, need, p, happiness, bonus);
  }

  bool get hasPalace => buildings.contains('palacio');

  // ---------- acciones ----------

  void addTask(String title, String kind, String diff) {
    tasks.insert(0, Task(id: _newId(), title: title, kind: kind, diff: diff));
    _commit();
  }

  void deleteTask(Task t) {
    tasks.remove(t);
    _commit();
  }

  CompleteResult complete(Task t) {
    final d = difficulties[t.diff]!;
    final c = city();
    final prevRecord = goldRecord;
    final before = level;
    final earned = (d.gold * (1 + c.bonus)).round();

    if (t.isHabit) {
      t.prevLast = t.last;
      t.prevStreak = t.streak;
      t.streak = t.last == dayOffset(-1) ? t.streak + 1 : 1;
      t.last = today();
      bestStreak = max(bestStreak, t.streak);
    } else {
      t.done = today();
    }

    var arrived = 0;
    if (population < c.housing && c.acceptsNewcomers) {
      final wanted = (t.diff == 'dificil' || t.diff == 'epica') ? 2 : 1;
      arrived = min(c.housing - population, wanted);
      population += arrived;
    }

    t.earnedXp = d.xp;
    t.earnedGold = earned;
    t.earnedPeople = arrived;
    xp += d.xp;
    gold += earned;
    totalDone++;
    final h = todayStat;
    h.xp += d.xp;
    h.gold += earned;

    _commit();
    return CompleteResult(d.xp, earned, arrived, before, level, h.gold > prevRecord && prevRecord > 0);
  }

  /// Desmarca una tarea completada hoy y regresa sus recompensas.
  void undo(Task t) {
    if (t.isHabit) {
      t.last = t.prevLast;
      t.streak = t.prevStreak;
    } else {
      t.done = null;
    }
    xp = max(0, xp - t.earnedXp);
    gold = max(0, gold - t.earnedGold);
    population = max(1, population - t.earnedPeople);
    totalDone = max(0, totalDone - 1);
    final h = todayStat;
    h.xp = max(0, h.xp - t.earnedXp);
    h.gold = max(0, h.gold - t.earnedGold);
    t.earnedXp = 0;
    t.earnedGold = 0;
    t.earnedPeople = 0;
    _commit();
  }

  /// Motivo por el que no se puede construir, o null si sí se puede.
  String? blockReason(BuildingType b) {
    if (level < b.level) return L.f('c.reasonLevel', {'n': b.level});
    if (b.unique && buildings.contains(b.id)) return L.t('c.reasonBuilt');
    if (b.id == 'palacio') {
      final c = city();
      if (c.happiness < palaceHappiness) return L.f('c.reasonHappy', {'n': palaceHappiness});
      if (population < palacePopulation) return L.f('c.reasonPop', {'n': palacePopulation});
    }
    if (gold < b.cost) return L.t('c.reasonGold');
    return null;
  }

  bool build(BuildingType b) {
    if (blockReason(b) != null) return false;
    gold -= b.cost;
    buildings.add(b.id);
    _commit();
    return true;
  }

  /// Elige idioma. En el primer inicio, los datos de ejemplo se rehacen en ese idioma.
  void setLanguage(String lang) {
    final firstTime = language == null;
    language = lang;
    L.lang = lang;
    if (firstTime && isSample && lang != 'es') _fillSample();
    _commit();
  }

  void setLightTheme(bool light) {
    lightTheme = light;
    _commit();
  }

  void setName(String value) {
    name = value.trim().isEmpty ? L.t('mayor') : value.trim();
    _commit();
  }

  void updateAvatar(void Function(Avatar a) change) {
    change(avatar);
    _commit();
  }
}
