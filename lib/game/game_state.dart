import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import 'achievements.dart';
import 'rules.dart';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String dayOffset(int days) => dayKey(DateTime.now().add(Duration(days: days)));
String today() => dayKey(DateTime.now());

/// Paso de una checklist. En hábitos se reinicia cada día.
class SubStep {
  String title;
  String? doneOn; // día en que se marcó
  SubStep(this.title, {this.doneOn});

  Map<String, dynamic> toJson() => {'title': title, 'doneOn': doneOn};
  factory SubStep.fromJson(Map<String, dynamic> j) =>
      SubStep(j['title'] as String? ?? '', doneOn: j['doneOn'] as String?);
}

/// Resultado de marcar un paso.
class StepResult {
  final CompleteResult? completed; // la tarea se completó con este paso
  final int freshInkWait; // minutos que faltan si aún no se puede completar
  final bool undone; // se desmarcó una tarea que estaba completada
  final int done;
  final int total;
  const StepResult({this.completed, this.freshInkWait = 0, this.undone = false, this.done = 0, this.total = 0});
}

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

  /// Cómo contó la última vez que se completó (para regresarlo al desmarcar).
  String? countedAs;

  /// Checklist opcional; la tarea se completa al marcar todos los pasos.
  List<SubStep> steps = [];

  bool get hasSteps => steps.isNotEmpty;
  bool stepDone(SubStep s) => isHabit ? s.doneOn == today() : s.doneOn != null;
  int get stepsDone => steps.where(stepDone).length;

  /// Cuándo se creó (ms). Las tareas recién creadas esperan unos minutos ("tinta fresca").
  int? createdAt;

  /// Hábitos: minutos desde medianoche para el recordatorio diario, o null.
  int? reminder;

  /// Misiones únicas: fecha límite (milisegundos desde 1970), o null.
  int? due;

  DateTime? get dueDate => due == null ? null : DateTime.fromMillisecondsSinceEpoch(due!);
  bool get overdue => !isHabit && done == null && due != null && DateTime.now().millisecondsSinceEpoch > due!;

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
    this.reminder,
    this.due,
    this.countedAs,
    this.createdAt,
  });

  /// Minutos que faltan para poder completarla, o 0.
  int get freshInkLeft {
    final c = createdAt;
    if (c == null) return 0;
    final left = freshInkMinutes * 60000 - (DateTime.now().millisecondsSinceEpoch - c);
    return left <= 0 ? 0 : (left / 60000).ceil();
  }

  bool get isHabit => kind == 'habito';
  bool get doneToday => isHabit ? last == today() : done == today();

  /// Racha visible: se pierde si no se cumplió ayer ni hoy.
  int get currentStreak => (last == today() || last == dayOffset(-1)) ? streak : 0;

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'kind': kind, 'diff': diff, 'streak': streak,
        'last': last, 'done': done, 'prevLast': prevLast, 'prevStreak': prevStreak,
        'earnedXp': earnedXp, 'earnedGold': earnedGold, 'earnedPeople': earnedPeople, 'reminder': reminder, 'due': due,
        'countedAs': countedAs, 'createdAt': createdAt,
        'steps': steps.map((s) => s.toJson()).toList(),
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
        reminder: (j['reminder'] as num?)?.toInt(),
        due: (j['due'] as num?)?.toInt(),
        countedAs: j['countedAs'] as String?,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      )..steps = ((j['steps'] as List?) ?? const [])
          .map((e) => SubStep.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
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
  int happy; // felicidad más alta de la ciudad ese día
  int done; // tareas completadas ese día
  int epic; // épicas que pagaron como épicas
  int hard; // difíciles que pagaron como difíciles
  DayStat({this.xp = 0, this.gold = 0, this.happy = 0, this.done = 0, this.epic = 0, this.hard = 0});
  Map<String, dynamic> toJson() => {'xp': xp, 'gold': gold, 'happy': happy, 'done': done, 'epic': epic, 'hard': hard};
  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        gold: (j['gold'] as num?)?.toInt() ?? 0,
        happy: (j['happy'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        epic: (j['epic'] as num?)?.toInt() ?? 0,
        hard: (j['hard'] as num?)?.toInt() ?? 0,
      );
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

/// Construcción colocada en el mapa.
class Placed {
  final int id;
  final String type;
  int x;
  int y;
  int color;
  Placed({required this.id, required this.type, required this.x, required this.y, required this.color});

  BuildingType get kind => buildingById(type);

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'x': x, 'y': y, 'color': color};

  factory Placed.fromJson(Map<String, dynamic> j) => Placed(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        x: (j['x'] as num).toInt(),
        y: (j['y'] as num).toInt(),
        color: (j['color'] as num?)?.toInt() ?? buildingById(j['type'] as String).base,
      );
}

class CompleteResult {
  final int xp;
  final int gold;
  final int arrived;
  final int levelFrom;
  final int levelTo;
  final bool newRecord;
  final int streakBonusPct; // bonus de racha aplicado al oro
  final bool reduced; // pagó menos por rendimiento decreciente o límite de dificultad
  const CompleteResult(this.xp, this.gold, this.arrived, this.levelFrom, this.levelTo, this.newRecord,
      {this.streakBonusPct = 0, this.reduced = false});
}

class GameState extends ChangeNotifier {
  static const _storageKey = 'pixel_todo_state_v1';

  /// Idioma elegido ('es' o 'en'); null hasta que se elige en el primer inicio.
  String? language;
  bool lightTheme = false;
  bool soundOn = true;
  bool musicOn = true;
  String name = 'Alcalde';
  int xp = 0;
  int gold = 100;
  int population = 1;
  int totalDone = 0;
  int bestStreak = 0;

  /// Días libres: protegen las rachas si un día no se cumplen los hábitos.
  int streakFreezes = 0;
  static const int maxFreezes = 3;
  static const int freezePrice = 250;

  /// Último uso automático de días libres (para avisar en pantalla una vez).
  int lastFreezeUsed = 0;
  int lastFreezeSaved = 0;

  /// Minijuego secreto del gatito piloto.
  int flightRecord = 0;
  bool foundSecret = false; // ya abrió alguna vez el minijuego
  bool tutorialSeen = false; // ya vio (o saltó) el tutorial del primer inicio
  String flightGoldDay = '';
  int flightGoldToday = 0;
  static const int flightGoldPerDay = 20;
  bool isSample = false;
  Avatar avatar = Avatar();
  /// La ciudad (y con ella logros y cosméticos) es la parte de paga.
  bool cityPurchased = false;

  /// Modo prueba de la beta: desbloquea la ciudad sin comprar.
  bool testMode = false;
  bool get cityUnlocked => cityPurchased || testMode;

  Set<String> unlockedAchievements = {};

  /// Logros recién ganados que la interfaz todavía no ha mostrado.
  final List<String> pendingAchievements = [];

  bool remindersOn = false;
  int reminderMinutes = 20 * 60; // recordatorio diario a las 8:00 p. m.
  int mapSize = 8;
  List<Placed> buildings = [];
  List<Task> tasks = [];
  Map<String, DayStat> history = {};

  int _idCounter = DateTime.now().millisecondsSinceEpoch;
  String _newId() => 't${_idCounter++}';

  int get level => levelOf(xp);

  // ---------- persistencia ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // El widget puede haber cambiado los datos desde otro proceso.
      await prefs.reload();
      final raw = prefs.getString(_storageKey);
      if (_demo) return; // durante el tutorial no se tocan los datos de ejemplo
      if (raw == null) {
        _freshStart();
      } else {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (_applyFreezes()) await _save();
      }
    } catch (_) {
      _freshStart();
    }
    L.lang = language ?? 'es';
    notifyListeners();
  }

  static int _dayNum(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ 86400000;
  }

  /// Si hubo días sin cumplir hábitos, usa días libres para salvar las rachas.
  /// Un día libre cubre todos los hábitos de ese día. Regresa true si cambió algo.
  bool _applyFreezes() {
    if (streakFreezes <= 0) return false;
    final todayN = _dayNum(today());
    final gaps = <Task, int>{};
    for (final t in tasks) {
      final last = t.last;
      if (!t.isHabit || t.streak <= 0 || last == null) continue;
      final missed = todayN - _dayNum(last) - 1;
      if (missed > 0) gaps[t] = missed;
    }
    final saveable = gaps.values.where((g) => g <= streakFreezes);
    if (saveable.isEmpty) return false;
    final used = saveable.reduce(max);
    streakFreezes -= used;
    var saved = 0;
    final yesterday = dayOffset(-1);
    gaps.forEach((t, g) {
      if (g <= used) {
        t.last = yesterday; // la racha sigue como si se hubiera cumplido ayer
        saved++;
      }
    });
    lastFreezeUsed = used;
    lastFreezeSaved = saved;
    return true;
  }

  bool buyFreeze() {
    if (streakFreezes >= maxFreezes || gold < freezePrice) return false;
    gold -= freezePrice;
    streakFreezes++;
    _commit();
    return true;
  }

  /// Guarda y espera a que termine (para tareas en segundo plano).
  Future<void> saveNow() => _save();

  Future<void> _save() async {
    if (_demo) return; // los datos de ejemplo del tutorial nunca se guardan
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (_) {
      // Si falla el guardado, el juego sigue funcionando en memoria.
    }
  }

  /// Se llama después de cada cambio guardado (lo usa el servicio de recordatorios).
  void Function(GameState)? onChanged;

  void _commit() {
    if (cityUnlocked) {
      final h = todayStat;
      h.happy = max(h.happy, city().happiness);
      _checkAchievements();
    }
    notifyListeners();
    _save();
    if (!_demo) onChanged?.call(this);
  }

  // ---------- modo ejemplo del tutorial ----------

  bool _demo = false;
  Map<String, dynamic>? _realData;
  bool get inDemo => _demo;

  /// Cambia a datos de ejemplo para el tutorial, sin guardar nada.
  void enterDemo() {
    if (_demo) return;
    _realData = _toJson();
    _demo = true;
    final keepAvatar = avatar, keepName = name;
    _fillSample();
    avatar = keepAvatar;
    name = keepName;
    notifyListeners();
  }

  /// Regresa los datos reales tal como estaban antes del tutorial.
  void exitDemo() {
    if (!_demo) return;
    final real = _realData;
    _demo = false;
    _realData = null;
    pendingAchievements.clear();
    lastFreezeUsed = 0;
    if (real != null) _fromJson(real);
    L.lang = language ?? 'es';
    notifyListeners();
  }

  /// Primer inicio: todo desde cero, con los recordatorios apagados.
  void _freshStart() {
    isSample = false;
    tutorialSeen = false;
    remindersOn = false;
    name = L.t('mayor');
    xp = 0;
    gold = 100;
    population = 1;
    totalDone = 0;
    bestStreak = 0;
    mapSize = mapExpansions.first.size;
    buildings = [Placed(id: 1, type: 'hogar', x: 3, y: 3, color: homeBuilding.base)];
    tasks = [];
    history = {today(): DayStat()};
  }

  void _checkAchievements() {
    for (final a in achievements) {
      if (unlockedAchievements.contains(a.id)) continue;
      if (metricValue(this, a.metric) >= a.goal) {
        unlockedAchievements.add(a.id);
        gold += a.gold;
        pendingAchievements.add(a.id);
      }
    }
  }

  /// Un accesorio está disponible si es gratis o si ya se ganó su logro con la ciudad desbloqueada.
  bool hasCosmetic(String id) {
    if (freeAccessories.contains(id)) return true;
    final a = achievementForCosmetic(id);
    return a != null && cityUnlocked && unlockedAchievements.contains(a.id);
  }

  Map<String, dynamic> _toJson() => {
        'language': language, 'lightTheme': lightTheme, 'soundOn': soundOn, 'musicOn': musicOn, 'name': name, 'xp': xp, 'gold': gold, 'population': population, 'totalDone': totalDone,
        'bestStreak': bestStreak, 'isSample': isSample, 'avatar': avatar.toJson(),
        'streakFreezes': streakFreezes,
        'flightRecord': flightRecord, 'foundSecret': foundSecret, 'tutorialSeen': tutorialSeen, 'flightGoldDay': flightGoldDay, 'flightGoldToday': flightGoldToday,
        'cityUnlocked': testMode, 'cityPurchased': cityPurchased, 'mapSize': mapSize,
        'achievements': unlockedAchievements.toList(),
        'remindersOn': remindersOn, 'reminderMinutes': reminderMinutes,
        'buildings': buildings.map((b) => b.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'history': history.map((k, v) => MapEntry(k, v.toJson())),
      };

  void _fromJson(Map<String, dynamic> j) {
    language = j['language'] as String?;
    lightTheme = j['lightTheme'] as bool? ?? false;
    soundOn = j['soundOn'] as bool? ?? true;
    musicOn = j['musicOn'] as bool? ?? true;
    name = j['name'] as String? ?? 'Alcalde';
    xp = (j['xp'] as num?)?.toInt() ?? 0;
    gold = (j['gold'] as num?)?.toInt() ?? 0;
    population = (j['population'] as num?)?.toInt() ?? 1;
    totalDone = (j['totalDone'] as num?)?.toInt() ?? 0;
    bestStreak = (j['bestStreak'] as num?)?.toInt() ?? 0;
    flightRecord = (j['flightRecord'] as num?)?.toInt() ?? 0;
    foundSecret = j['foundSecret'] as bool? ?? flightRecord > 0;
    streakFreezes = (j['streakFreezes'] as num?)?.toInt() ?? 0;
    flightGoldDay = j['flightGoldDay'] as String? ?? '';
    flightGoldToday = (j['flightGoldToday'] as num?)?.toInt() ?? 0;
    isSample = j['isSample'] as bool? ?? false;
    // Quien ya tenía la app instalada no ve el tutorial a la fuerza (puede abrirlo en Ajustes).
    tutorialSeen = j['tutorialSeen'] as bool? ?? true;
    avatar = Avatar.fromJson((j['avatar'] as Map?)?.cast<String, dynamic>() ?? {});
    testMode = j['cityUnlocked'] as bool? ?? false;
    cityPurchased = j['cityPurchased'] as bool? ?? false;
    unlockedAchievements = ((j['achievements'] as List?) ?? const []).map((e) => e as String).toSet();
    remindersOn = j['remindersOn'] as bool? ?? false;
    reminderMinutes = (j['reminderMinutes'] as num?)?.toInt() ?? 20 * 60;
    mapSize = (j['mapSize'] as num?)?.toInt() ?? mapExpansions.first.size;
    buildings = [];
    for (final e in (j['buildings'] as List?) ?? const ['hogar']) {
      if (e is Map) {
        buildings.add(Placed.fromJson(e.cast<String, dynamic>()));
      } else if (e is String) {
        // Versiones anteriores guardaban solo el tipo; se acomoda en el primer lugar libre.
        _addAtFreeSpot(e, buildingById(e).base);
      }
    }
    if (!buildings.any((b) => b.type == 'hogar')) _addAtFreeSpot('hogar', homeBuilding.base);
    tasks = ((j['tasks'] as List?) ?? [])
        .map((e) => Task.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    // Antes las misiones únicas también tenían solo hora; se vuelve fecha límite de hoy.
    for (final t in tasks) {
      final m = t.reminder;
      if (!t.isHabit && m != null) {
        final n = DateTime.now();
        t.due ??= DateTime(n.year, n.month, n.day, m ~/ 60, m % 60).millisecondsSinceEpoch;
        t.reminder = null;
      }
    }
    history = ((j['history'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, DayStat.fromJson((v as Map).cast<String, dynamic>())));
  }

  /// Datos de ejemplo para la primera vez que se abre la app.
  void _fillSample() {
    isSample = true;
    tutorialSeen = false;
    name = L.t('mayor');
    xp = 2350;
    gold = 480;
    population = 4;
    totalDone = 41;
    bestStreak = 6;
    mapSize = mapExpansions.first.size;
    buildings = [];
    const layout = [['hogar', 3, 4], ['casa', 2, 4], ['tiendita', 5, 3], ['pozo', 4, 2], ['poste', 5, 5]];
    for (final l in layout) {
      final type = l[0] as String;
      buildings.add(Placed(id: _newBuildingId(), type: type, x: l[1] as int, y: l[2] as int, color: buildingById(type).base));
    }
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
    mapSize = mapExpansions.first.size;
    buildings = [Placed(id: _newBuildingId(), type: 'hogar', x: 3, y: 3, color: homeBuilding.base)];
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
    for (final b in buildings) {
      b.kind.capacity.forEach((k, v) => cap[k] = (cap[k] ?? 0) + v);
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

  bool get hasPalace => buildings.any((b) => b.type == 'palacio');

  // ---------- mapa ----------

  int _newBuildingId() => buildings.fold<int>(0, (m, b) => max(m, b.id)) + 1;

  Placed? buildingAt(int x, int y) {
    for (final b in buildings) {
      if (b.x == x && b.y == y) return b;
    }
    return null;
  }

  Placed? placedById(int id) {
    for (final b in buildings) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool canPlace(int x, int y, {int? ignoreId}) {
    if (x < 0 || y < 0 || x >= mapSize || y >= mapSize) return false;
    final other = buildingAt(x, y);
    return other == null || other.id == ignoreId;
  }

  /// Busca un lugar libre empezando por el centro del mapa.
  void _addAtFreeSpot(String type, int color) {
    final c = mapSize ~/ 2;
    for (var r = 0; r < mapSize; r++) {
      for (var y = c - r; y <= c + r; y++) {
        for (var x = c - r; x <= c + r; x++) {
          if (canPlace(x, y)) {
            buildings.add(Placed(id: _newBuildingId(), type: type, x: x, y: y, color: color));
            return;
          }
        }
      }
    }
    // Sin espacio: se agranda el terreno un poco.
    mapSize += 2;
    _addAtFreeSpot(type, color);
  }

  MapExpansion? get nextExpansion {
    for (final e in mapExpansions) {
      if (e.size > mapSize) return e;
    }
    return null;
  }

  String? expansionBlock(MapExpansion e) {
    if (level < e.level) return L.f('c.reasonLevel', {'n': e.level});
    if (gold < e.cost) return L.t('c.reasonGold');
    return null;
  }

  bool expand() {
    final e = nextExpansion;
    if (e == null || expansionBlock(e) != null) return false;
    gold -= e.cost;
    mapSize = e.size;
    _commit();
    return true;
  }

  bool place(BuildingType type, int color, int x, int y) {
    if (blockReason(type) != null || !canPlace(x, y)) return false;
    gold -= costOf(type);
    buildings.add(Placed(id: _newBuildingId(), type: type.id, x: x, y: y, color: color));
    _commit();
    return true;
  }

  bool moveBuilding(int id, int x, int y) {
    final b = placedById(id);
    if (b == null || !canPlace(x, y, ignoreId: id)) return false;
    b.x = x;
    b.y = y;
    _commit();
    return true;
  }

  /// Demuele y devuelve parte del oro. Regresa el oro devuelto, o -1 si no se puede.
  int demolish(int id) {
    final b = placedById(id);
    if (b == null || !b.kind.demolishable) return -1;
    final refund = refundOf(b.kind);
    buildings.remove(b);
    gold += refund;
    population = max(1, min(population, city().housing));
    _commit();
    return refund;
  }

  void recolor(int id, int color) {
    final b = placedById(id);
    if (b == null) return;
    b.color = color;
    _commit();
  }

  /// Oro que todavía se puede ganar hoy en el minijuego.
  int get flightGoldLeft =>
      flightGoldDay == today() ? max(0, flightGoldPerDay - flightGoldToday) : flightGoldPerDay;

  /// Termina una partida: guarda el récord y entrega el oro (con tope diario). Regresa el oro entregado.
  int finishFlight(int score, int coins) {
    if (flightGoldDay != today()) {
      flightGoldDay = today();
      flightGoldToday = 0;
    }
    final given = min(coins, flightGoldLeft);
    flightGoldToday += given;
    gold += given;
    if (score > flightRecord) flightRecord = score;
    _commit();
    return given;
  }

  void markTutorialSeen() {
    tutorialSeen = true;
    _commit();
  }

  void markSecretFound() {
    if (foundSecret) return;
    foundSecret = true;
    _commit();
  }

  void setTestMode(bool value) {
    testMode = value;
    _commit();
  }

  void setCityPurchased(bool value) {
    if (cityPurchased == value) return;
    cityPurchased = value;
    _commit();
  }

  void setReminders(bool on) {
    remindersOn = on;
    _commit();
  }

  void setReminderMinutes(int minutes) {
    reminderMinutes = minutes % (24 * 60);
    _commit();
  }

  void setTaskReminder(Task t, int? minutes) {
    t.reminder = minutes;
    _commit();
  }

  void setTaskDue(Task t, DateTime? due) {
    t.due = due?.millisecondsSinceEpoch;
    _commit();
  }

  // ---------- acciones ----------

  void addTask(String title, String kind, String diff,
      {int? reminder, DateTime? due, List<String> steps = const []}) {
    final isHabit = kind == 'habito';
    tasks.insert(
      0,
      Task(
        id: _newId(),
        title: title,
        kind: kind,
        diff: diff,
        reminder: isHabit ? reminder : null,
        due: isHabit ? null : due?.millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      )..steps = [for (final s in steps) if (s.trim().isNotEmpty) SubStep(s.trim())],
    );
    _commit();
  }

  void deleteTask(Task t) {
    tasks.remove(t);
    _commit();
  }

  /// Tareas que todavía pagan completo hoy.
  int get fullRewardsLeft => max(0, fullRewardsPerDay - (history[today()]?.done ?? 0));

  /// Bonus de oro (en %) que daría completar hoy este hábito.
  int nextStreakBonusPct(Task t) {
    if (!t.isHabit) return 0;
    final next = t.doneToday ? t.streak : (t.last == dayOffset(-1) ? t.streak + 1 : 1);
    return (streakBonus(next) * 100).round();
  }

  CompleteResult complete(Task t) {
    final c = city();
    final prevRecord = goldRecord;
    final before = level;
    final h = todayStat;

    // Límite de dificultad: después de cierto número al día, paga como media.
    var counted = t.diff;
    if (counted == 'epica') {
      if (h.epic < epicPerDay) {
        h.epic++;
      } else {
        counted = 'media';
      }
    } else if (counted == 'dificil') {
      if (h.hard < hardPerDay) {
        h.hard++;
      } else {
        counted = 'media';
      }
    }
    t.countedAs = counted;
    final d = difficulties[counted]!;
    final factor = rewardFactor(h.done);
    h.done++;

    if (t.isHabit) {
      t.prevLast = t.last;
      t.prevStreak = t.streak;
      t.streak = t.last == dayOffset(-1) ? t.streak + 1 : 1;
      t.last = today();
      bestStreak = max(bestStreak, t.streak);
    } else {
      t.done = today();
    }

    final streakB = t.isHabit ? streakBonus(t.streak) : 0.0;
    final gainedXp = max(1, (d.xp * factor).round());
    final earned = max(1, (d.gold * factor * (1 + c.bonus + streakB)).round());

    var arrived = 0;
    if (population < c.housing && c.acceptsNewcomers) {
      final wanted = (t.diff == 'dificil' || t.diff == 'epica') ? 2 : 1;
      arrived = min(c.housing - population, wanted);
      population += arrived;
    }

    t.earnedXp = gainedXp;
    t.earnedGold = earned;
    t.earnedPeople = arrived;
    xp += gainedXp;
    gold += earned;
    totalDone++;
    h.xp += gainedXp;
    h.gold += earned;

    _commit();
    return CompleteResult(gainedXp, earned, arrived, before, level, h.gold > prevRecord && prevRecord > 0,
        streakBonusPct: (streakB * 100).round(), reduced: factor < 1 || counted != t.diff);
  }

  /// Desmarca una tarea completada hoy y regresa sus recompensas.
  // ---------- checklist ----------

  void addStep(Task t, String title) {
    final clean = title.trim();
    if (clean.isEmpty || t.steps.length >= 12) return;
    t.steps.add(SubStep(clean));
    _commit();
  }

  void removeStep(Task t, int i) {
    if (i < 0 || i >= t.steps.length) return;
    t.steps.removeAt(i);
    _commit();
  }

  /// Marca o desmarca un paso. Al marcar el último, la tarea se completa sola.
  StepResult toggleStep(Task t, int i) {
    if (i < 0 || i >= t.steps.length) return const StepResult();
    final s = t.steps[i];
    if (t.stepDone(s)) {
      if (t.doneToday) undo(t, keepSteps: true); // se regresan las recompensas
      s.doneOn = null;
      _commit();
      return StepResult(undone: true, done: t.stepsDone, total: t.steps.length);
    }
    final isLast = t.stepsDone == t.steps.length - 1;
    if (isLast && t.freshInkLeft > 0) {
      return StepResult(freshInkWait: t.freshInkLeft, done: t.stepsDone, total: t.steps.length);
    }
    s.doneOn = today();
    if (isLast && !t.doneToday) {
      final r = complete(t);
      return StepResult(completed: r, done: t.stepsDone, total: t.steps.length);
    }
    _commit();
    return StepResult(done: t.stepsDone, total: t.steps.length);
  }

  /// Para el widget: marca el siguiente paso pendiente.
  StepResult checkNextStep(Task t) {
    for (var i = 0; i < t.steps.length; i++) {
      if (!t.stepDone(t.steps[i])) return toggleStep(t, i);
    }
    return StepResult(done: t.stepsDone, total: t.steps.length);
  }

  void undo(Task t, {bool keepSteps = false}) {
    // Al desmarcar una tarea con checklist se desmarca su último paso.
    if (!keepSteps && t.hasSteps && t.stepsDone == t.steps.length) t.steps.last.doneOn = null;
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
    h.done = max(0, h.done - 1);
    if (t.countedAs == 'epica') h.epic = max(0, h.epic - 1);
    if (t.countedAs == 'dificil') h.hard = max(0, h.hard - 1);
    t.countedAs = null;
    t.earnedXp = 0;
    t.earnedGold = 0;
    t.earnedPeople = 0;
    _commit();
  }

  /// Motivo por el que no se puede construir, o null si sí se puede.
  String? blockReason(BuildingType b) {
    if (level < b.level) return L.f('c.reasonLevel', {'n': b.level});
    if (b.unique && buildings.any((p) => p.type == b.id)) return L.t('c.reasonBuilt');
    if (b.id == 'palacio') {
      final c = city();
      if (c.happiness < palaceHappiness) return L.f('c.reasonHappy', {'n': palaceHappiness});
      if (population < palacePopulation) return L.f('c.reasonPop', {'n': palacePopulation});
    }
    if (gold < costOf(b)) return L.t('c.reasonGold');
    return null;
  }

  int _countOf(String typeId) => buildings.where((p) => p.type == typeId).length;

  /// Precio actual con inflación: sube 15% por cada copia ya construida.
  int costOf(BuildingType b) => inflatedCost(b.cost, _countOf(b.id));

  /// Al demoler se recupera la mitad de lo que costó la última copia.
  int refundOf(BuildingType b) => (inflatedCost(b.cost, max(0, _countOf(b.id) - 1)) * demolishRefund).round();

  /// Elige idioma. En el primer inicio, los datos de ejemplo se rehacen en ese idioma.
  void setLanguage(String lang) {
    final firstTime = language == null;
    language = lang;
    L.lang = lang;
    // El nombre por defecto del alcalde se traduce al elegir idioma.
    if (firstTime && (name == 'Alcalde' || name == 'Mayor')) name = L.t('mayor');
    _commit();
  }

  void setSound(bool on) {
    soundOn = on;
    _commit();
  }

  void setMusic(bool on) {
    musicOn = on;
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
