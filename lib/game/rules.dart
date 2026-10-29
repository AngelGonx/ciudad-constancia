// Reglas del juego: dificultades, niveles y catálogo de edificios.

import 'dart:math';

import '../i18n/strings.dart';

class Difficulty {
  final String id;
  final int xp;
  final int gold;
  const Difficulty(this.id, this.xp, this.gold);
  String get name => L.t('d.$id');
}

const Map<String, Difficulty> difficulties = {
  'facil': Difficulty('facil', 50, 10),
  'media': Difficulty('media', 150, 25),
  'dificil': Difficulty('dificil', 300, 50),
  'epica': Difficulty('epica', 600, 100),
};

/// Nivel 1 desde 0 XP. El nivel n se alcanza con n × 1000 XP (nivel 2 = 2000).
int levelOf(int xp) => xp < 2000 ? 1 : xp ~/ 1000;
int levelStart(int level) => level == 1 ? 0 : level * 1000;
int levelNext(int level) => (level + 1) * 1000;

/// Servicios que necesita la ciudad, en el orden en que se muestran.
const List<String> needKeys = ['vivienda', 'empleo', 'escuela', 'agua', 'luz', 'basura'];

String categoryName(String id) => L.t('cat.$id');

class BuildingType {
  final String id;
  final String category;
  final int cost;
  final int level;
  final Map<String, int> capacity;
  final bool unique;

  /// Plantilla de dibujo (ver ui/building_art.dart) y sus parámetros.
  final String art;
  final int base;
  final int accent;
  final int floors;
  final List<String> extras;

  const BuildingType({
    required this.id,
    required this.category,
    required this.cost,
    required this.level,
    required this.capacity,
    required this.art,
    this.base = 0xFFD9C9A6,
    this.accent = 0xFF8C5A8F,
    this.floors = 1,
    this.extras = const [],
    this.unique = false,
  });

  String get name => L.t('b.$id');


  /// Tu casa y el palacio no se pueden demoler, solo mover.
  bool get demolishable => id != 'hogar' && id != 'palacio';

  String get effect {
    if (id == 'palacio') return L.t('c.effGov');
    return capacity.entries.map((e) {
      switch (e.key) {
        case 'vivienda':
          return L.f('c.effHome', {'n': e.value});
        case 'empleo':
          return L.f('c.effJobs', {'n': e.value});
        case 'escuela':
          return L.f('c.effSchool', {'n': e.value});
        case 'felicidad':
          return L.f('c.effHappy', {'n': e.value});
        default:
          return L.f('c.effService', {'cat': categoryName(e.key), 'n': e.value});
      }
    }).join(', ');
  }
}

const BuildingType homeBuilding = BuildingType(
    id: 'hogar', category: 'vivienda', cost: 0, level: 1, capacity: {'vivienda': 1}, art: 'home', base: 0xFFE8D7B0, accent: 0xFFB8473D);

/// Catálogo de construcciones, agrupado por categoría y ordenado por nivel.
const List<BuildingType> catalog = [
  // Vivienda
  BuildingType(id: 'casita', category: 'vivienda', cost: 100, level: 1, capacity: {'vivienda': 3},
      art: 'house', base: 0xFFD9A066, accent: 0xFFB8473D),
  BuildingType(id: 'casa', category: 'vivienda', cost: 150, level: 1, capacity: {'vivienda': 4},
      art: 'house', base: 0xFFD9C9A6, accent: 0xFF8C5A8F, extras: ['chimney']),
  BuildingType(id: 'cabana', category: 'vivienda', cost: 220, level: 2, capacity: {'vivienda': 5},
      art: 'cabin', base: 0xFF9A6A44, accent: 0xFF5A3A2A),
  BuildingType(id: 'casa_jardin', category: 'vivienda', cost: 300, level: 3, capacity: {'vivienda': 6},
      art: 'house', base: 0xFFE8D7B0, accent: 0xFF3E8C56, extras: ['garden']),
  BuildingType(id: 'casa2', category: 'vivienda', cost: 350, level: 3, capacity: {'vivienda': 8},
      art: 'house', base: 0xFFC7D3E0, accent: 0xFF4F6FA8, floors: 2),
  BuildingType(id: 'duplex', category: 'vivienda', cost: 600, level: 4, capacity: {'vivienda': 12},
      art: 'house', base: 0xFFF0C987, accent: 0xFFA8743A, floors: 2, extras: ['twin']),
  BuildingType(id: 'depas', category: 'vivienda', cost: 1200, level: 6, capacity: {'vivienda': 24},
      art: 'tower', base: 0xFFB9A28C, accent: 0xFF8F7A66, floors: 4),
  BuildingType(id: 'torre', category: 'vivienda', cost: 2500, level: 9, capacity: {'vivienda': 50},
      art: 'tower', base: 0xFF8FA3B8, accent: 0xFF5F7388, floors: 5, extras: ['antenna']),
  BuildingType(id: 'residencial', category: 'vivienda', cost: 4000, level: 12, capacity: {'vivienda': 80},
      art: 'tower', base: 0xFFD8CCB4, accent: 0xFF3E8C56, floors: 5, extras: ['roofgarden']),

  // Empleo
  BuildingType(id: 'tiendita', category: 'empleo', cost: 120, level: 1, capacity: {'empleo': 3},
      art: 'shop', base: 0xFFF0E0C0, accent: 0xFFD24C4C, extras: ['awning']),
  BuildingType(id: 'tortilleria', category: 'empleo', cost: 250, level: 2, capacity: {'empleo': 6},
      art: 'shop', base: 0xFFF2C94C, accent: 0xFFA8743A, extras: ['sign', 'steam']),
  BuildingType(id: 'panaderia', category: 'empleo', cost: 280, level: 2, capacity: {'empleo': 6},
      art: 'shop', base: 0xFFF2D7B5, accent: 0xFFC98A3C, extras: ['awning', 'bread']),
  BuildingType(id: 'taqueria', category: 'empleo', cost: 380, level: 3, capacity: {'empleo': 7},
      art: 'shop', base: 0xFFE07A3A, accent: 0xFF3E8C56, extras: ['awning', 'taco']),
  BuildingType(id: 'papeleria', category: 'empleo', cost: 300, level: 3, capacity: {'empleo': 6},
      art: 'shop', base: 0xFFC7E0F0, accent: 0xFF4F6FD8, extras: ['sign', 'book']),
  BuildingType(id: 'farmacia', category: 'empleo', cost: 400, level: 3, capacity: {'empleo': 8},
      art: 'shop', base: 0xFFEFF5EF, accent: 0xFF3E8C56, extras: ['sign', 'cross']),
  BuildingType(id: 'cafeteria', category: 'empleo', cost: 450, level: 4, capacity: {'empleo': 8},
      art: 'shop', base: 0xFF8A5A3A, accent: 0xFFF4B942, extras: ['awning', 'cup']),
  BuildingType(id: 'mercado', category: 'empleo', cost: 700, level: 4, capacity: {'empleo': 15},
      art: 'market', base: 0xFFE7D3B5),
  BuildingType(id: 'fabrica', category: 'empleo', cost: 1500, level: 7, capacity: {'empleo': 30}, art: 'factory', base: 0xFF8C8F9C),
  BuildingType(id: 'oficinas', category: 'empleo', cost: 1800, level: 7, capacity: {'empleo': 25},
      art: 'tower', base: 0xFF62A0C0, accent: 0xFF3D78A8, floors: 4, extras: ['glass']),
  BuildingType(id: 'plaza_comercial', category: 'empleo', cost: 3000, level: 10, capacity: {'empleo': 45},
      art: 'civic', base: 0xFFE8E0F0, accent: 0xFFD86BB0, floors: 2, extras: ['sign']),

  // Educación
  BuildingType(id: 'kinder', category: 'escuela', cost: 300, level: 2, capacity: {'escuela': 8},
      art: 'civic', base: 0xFFF4D35E, accent: 0xFFD24C4C, extras: ['playground']),
  BuildingType(id: 'escuela', category: 'escuela', cost: 450, level: 2, capacity: {'escuela': 15},
      art: 'civic', base: 0xFFD9805B, accent: 0xFF7A3F2A, extras: ['bell']),
  BuildingType(id: 'biblioteca', category: 'escuela', cost: 900, level: 4, capacity: {'escuela': 10, 'felicidad': 2},
      art: 'civic', base: 0xFF8C5A8F, accent: 0xFF5A3A5F, extras: ['columns', 'book']),
  BuildingType(id: 'secundaria', category: 'escuela', cost: 1100, level: 5, capacity: {'escuela': 30},
      art: 'civic', base: 0xFFCF6F6F, accent: 0xFF8A3F3F, floors: 2, extras: ['flag']),
  BuildingType(id: 'prepa', category: 'escuela', cost: 1800, level: 7, capacity: {'escuela': 40},
      art: 'civic', base: 0xFF6F8FCF, accent: 0xFF3F5F9F, floors: 2, extras: ['flag', 'bell']),
  BuildingType(id: 'universidad', category: 'escuela', cost: 3500, level: 11, capacity: {'escuela': 80},
      art: 'civic', base: 0xFFD8CCB4, accent: 0xFF7A3F2A, floors: 3, extras: ['columns', 'dome']),

  // Agua
  BuildingType(id: 'pozo', category: 'agua', cost: 180, level: 1, capacity: {'agua': 12}, art: 'tank', base: 0xFF5AA0D8),
  BuildingType(id: 'agua2', category: 'agua', cost: 900, level: 5, capacity: {'agua': 50}, art: 'waterplant', base: 0xFF5AA0D8),
  BuildingType(id: 'torre_agua', category: 'agua', cost: 2000, level: 9, capacity: {'agua': 120}, art: 'watertower', base: 0xFF5AA0D8),

  // Luz
  BuildingType(id: 'poste', category: 'luz', cost: 200, level: 1, capacity: {'luz': 12}, art: 'pole', base: 0xFF7A5A3A),
  BuildingType(id: 'solar', category: 'luz', cost: 600, level: 4, capacity: {'luz': 30}, art: 'solar', base: 0xFF5A5D6A),
  BuildingType(id: 'luz2', category: 'luz', cost: 1000, level: 5, capacity: {'luz': 50}, art: 'substation', base: 0xFF8C8F9C),
  BuildingType(id: 'eolica', category: 'luz', cost: 2200, level: 9, capacity: {'luz': 120}, art: 'wind', base: 0xFFF3EEE4),

  // Basura
  BuildingType(id: 'contenedores', category: 'basura', cost: 120, level: 1, capacity: {'basura': 6}, art: 'bins', base: 0xFF3E8C56),
  BuildingType(id: 'basura', category: 'basura', cost: 220, level: 2, capacity: {'basura': 15}, art: 'garage', base: 0xFF5F9C6A),
  BuildingType(id: 'reciclaje', category: 'basura', cost: 950, level: 6, capacity: {'basura': 50}, art: 'recycle', base: 0xFF5F9C6A),
  BuildingType(id: 'planta_basura', category: 'basura', cost: 2200, level: 9, capacity: {'basura': 120}, art: 'dump', base: 0xFF6B7A5A),

  // Recreación
  BuildingType(id: 'arbol', category: 'felicidad', cost: 40, level: 1, capacity: {'felicidad': 1}, art: 'tree', base: 0xFF3F7A37),
  BuildingType(id: 'fuente', category: 'felicidad', cost: 250, level: 2, capacity: {'felicidad': 3}, art: 'fountain', base: 0xFFB9B2A6),
  BuildingType(id: 'parque', category: 'felicidad', cost: 300, level: 3, capacity: {'felicidad': 5}, art: 'park', base: 0xFF5F9A4A),
  BuildingType(id: 'cancha', category: 'felicidad', cost: 450, level: 4, capacity: {'felicidad': 6}, art: 'court', base: 0xFFD9805B),
  BuildingType(id: 'kiosko', category: 'felicidad', cost: 600, level: 5, capacity: {'felicidad': 8}, art: 'kiosk', base: 0xFF3E8C56),

  // Transporte
  BuildingType(id: 'parada', category: 'transporte', cost: 150, level: 2, capacity: {'felicidad': 2},
      art: 'busstop', base: 0xFFF4B942),

  // Gobierno
  BuildingType(id: 'palacio', category: 'gobierno', cost: 3000, level: 10, capacity: {}, art: 'palace', base: 0xFFEFE6D6, unique: true),
];

BuildingType buildingById(String id) =>
    id == homeBuilding.id ? homeBuilding : catalog.firstWhere((b) => b.id == id, orElse: () => homeBuilding);

/// Requisitos extra del palacio municipal.
const int palaceHappiness = 80;
const int palacePopulation = 30;

/// Tamaños del terreno (cuadros por lado) y lo que cuesta llegar a cada uno.
class MapExpansion {
  final int size;
  final int cost;
  final int level;
  const MapExpansion(this.size, this.cost, this.level);
}

const List<MapExpansion> mapExpansions = [
  MapExpansion(8, 0, 1),
  MapExpansion(10, 400, 3),
  MapExpansion(12, 800, 5),
  MapExpansion(14, 1200, 7),
  MapExpansion(16, 1600, 9),
  MapExpansion(18, 2200, 12),
  MapExpansion(20, 3000, 15),
];

/// Lo que se devuelve al demoler.
const double demolishRefund = 0.5;

// ---------- Balance de recompensas ----------

/// Tareas por día que pagan completo; después pagan la mitad y luego el 10%.
const int fullRewardsPerDay = 8;
const int halfRewardsPerDay = 14;

/// Cuántas épicas y difíciles al día pagan como tales; las demás pagan como media.
const int epicPerDay = 1;
const int hardPerDay = 3;

/// Minutos que debe esperar una tarea recién creada para poder completarse.
const int freshInkMinutes = 10;

/// Bonus de oro por racha: +5% por día de racha, hasta +50%.
double streakBonus(int streak) => min(0.5, max(0, streak - 1) * 0.05);

/// Factor de recompensa según cuántas tareas ya se completaron hoy.
double rewardFactor(int doneToday) =>
    doneToday < fullRewardsPerDay ? 1.0 : (doneToday < halfRewardsPerDay ? 0.5 : 0.1);

/// Inflación: cada copia del mismo edificio cuesta 15% más que la anterior.
const double inflationRate = 1.15;
int inflatedCost(int base, int alreadyBuilt) => (base * pow(inflationRate, alreadyBuilt)).round();
