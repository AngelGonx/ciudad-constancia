import 'game_state.dart';

/// Qué se mide para cada logro.
enum Metric { tasks, streak, level, population, goldRecord, happyDays, buildings, palace, mapSize, goldTotal }

class Achievement {
  final String id;
  final Metric metric;
  final int goal;
  final int gold;
  final String? cosmetic; // accesorio de avatar que desbloquea
  const Achievement(this.id, this.metric, this.goal, this.gold, [this.cosmetic]);
}

const List<Achievement> achievements = [
  Achievement('tareas_10', Metric.tasks, 10, 50),
  Achievement('tareas_50', Metric.tasks, 50, 150, 'audifonos'),
  Achievement('tareas_200', Metric.tasks, 200, 400, 'capa'),
  Achievement('tareas_500', Metric.tasks, 500, 1000, 'corona'),
  Achievement('racha_3', Metric.streak, 3, 50),
  Achievement('racha_7', Metric.streak, 7, 150, 'bufanda'),
  Achievement('racha_30', Metric.streak, 30, 600, 'sombrero'),
  Achievement('nivel_5', Metric.level, 5, 200),
  Achievement('nivel_10', Metric.level, 10, 500, 'lentes_sol'),
  Achievement('nivel_20', Metric.level, 20, 1500, 'diadema'),
  Achievement('pop_10', Metric.population, 10, 100),
  Achievement('pop_50', Metric.population, 50, 400, 'flor'),
  Achievement('pop_150', Metric.population, 150, 1200),
  Achievement('record_200', Metric.goldRecord, 200, 100),
  Achievement('record_500', Metric.goldRecord, 500, 300),
  Achievement('feliz_7', Metric.happyDays, 7, 500, 'mono'),
  Achievement('feliz_30', Metric.happyDays, 30, 1500),
  Achievement('edificios_10', Metric.buildings, 10, 150),
  Achievement('edificios_30', Metric.buildings, 30, 600),
  Achievement('palacio', Metric.palace, 1, 1000, 'banda'),
  Achievement('terreno_max', Metric.mapSize, 20, 1000),
  Achievement('oro_10k', Metric.goldTotal, 10000, 1000),
];

/// Felicidad mínima para que un día cuente como "día feliz".
const int happyDayThreshold = 80;

int metricValue(GameState g, Metric m) {
  switch (m) {
    case Metric.tasks:
      return g.totalDone;
    case Metric.streak:
      return g.bestStreak;
    case Metric.level:
      return g.level;
    case Metric.population:
      return g.population;
    case Metric.goldRecord:
      return g.goldRecord;
    case Metric.happyDays:
      return g.history.values.where((h) => h.happy >= happyDayThreshold).length;
    case Metric.buildings:
      return g.buildings.where((b) => b.type != 'hogar').length;
    case Metric.palace:
      return g.hasPalace ? 1 : 0;
    case Metric.mapSize:
      return g.mapSize;
    case Metric.goldTotal:
      return g.goldTotal;
  }
}

/// Accesorios gratis y los que se ganan con logros.
const List<String> freeAccessories = ['ninguno', 'lentes', 'gorra'];

Achievement? achievementForCosmetic(String cosmetic) {
  for (final a in achievements) {
    if (a.cosmetic == cosmetic) return a;
  }
  return null;
}
