// Reglas del juego: dificultades, niveles y catálogo de edificios.

class Difficulty {
  final String id;
  final String name;
  final int xp;
  final int gold;
  const Difficulty(this.id, this.name, this.xp, this.gold);
}

const Map<String, Difficulty> difficulties = {
  'facil': Difficulty('facil', 'Fácil', 50, 10),
  'media': Difficulty('media', 'Media', 150, 25),
  'dificil': Difficulty('dificil', 'Difícil', 300, 50),
  'epica': Difficulty('epica', 'Épica', 600, 100),
};

/// Nivel 1 desde 0 XP. El nivel n se alcanza con n × 1000 XP (nivel 2 = 2000).
int levelOf(int xp) => xp < 2000 ? 1 : xp ~/ 1000;
int levelStart(int level) => level == 1 ? 0 : level * 1000;
int levelNext(int level) => (level + 1) * 1000;

/// Servicios que necesita la ciudad, en el orden en que se muestran.
const List<String> needKeys = ['vivienda', 'empleo', 'escuela', 'agua', 'luz', 'basura'];

const Map<String, String> categoryNames = {
  'vivienda': 'Vivienda',
  'empleo': 'Empleo',
  'escuela': 'Escuela',
  'agua': 'Agua',
  'luz': 'Luz',
  'basura': 'Basura',
  'felicidad': 'Recreación',
  'gobierno': 'Gobierno',
};

class BuildingType {
  final String id;
  final String name;
  final String category;
  final int cost;
  final int level;
  final Map<String, int> capacity;
  final bool unique;
  const BuildingType({
    required this.id,
    required this.name,
    required this.category,
    required this.cost,
    required this.level,
    required this.capacity,
    this.unique = false,
  });

  String get effect {
    if (id == 'palacio') return 'Gobierna tu ciudad';
    return capacity.entries.map((e) {
      switch (e.key) {
        case 'vivienda':
          return '+${e.value} habitantes';
        case 'empleo':
          return '+${e.value} empleos';
        case 'escuela':
          return '+${e.value} alumnos';
        case 'felicidad':
          return '+${e.value}% felicidad';
        default:
          return '${categoryNames[e.key]} para ${e.value}';
      }
    }).join(', ');
  }
}

const BuildingType homeBuilding = BuildingType(
  id: 'hogar', name: 'Tu casa', category: 'vivienda', cost: 0, level: 1, capacity: {'vivienda': 1});

const List<BuildingType> catalog = [
  BuildingType(id: 'casa', name: 'Casa', category: 'vivienda', cost: 150, level: 1, capacity: {'vivienda': 4}),
  BuildingType(id: 'casa2', name: 'Casa de dos pisos', category: 'vivienda', cost: 350, level: 3, capacity: {'vivienda': 8}),
  BuildingType(id: 'depas', name: 'Edificio de departamentos', category: 'vivienda', cost: 1200, level: 6, capacity: {'vivienda': 24}),
  BuildingType(id: 'tiendita', name: 'Tiendita', category: 'empleo', cost: 120, level: 1, capacity: {'empleo': 3}),
  BuildingType(id: 'tortilleria', name: 'Tortillería', category: 'empleo', cost: 250, level: 2, capacity: {'empleo': 6}),
  BuildingType(id: 'mercado', name: 'Mercado', category: 'empleo', cost: 700, level: 4, capacity: {'empleo': 15}),
  BuildingType(id: 'fabrica', name: 'Fábrica', category: 'empleo', cost: 1500, level: 7, capacity: {'empleo': 30}),
  BuildingType(id: 'escuela', name: 'Escuela primaria', category: 'escuela', cost: 450, level: 2, capacity: {'escuela': 15}),
  BuildingType(id: 'secundaria', name: 'Secundaria', category: 'escuela', cost: 1100, level: 5, capacity: {'escuela': 30}),
  BuildingType(id: 'pozo', name: 'Tanque de agua', category: 'agua', cost: 180, level: 1, capacity: {'agua': 12}),
  BuildingType(id: 'agua2', name: 'Planta de agua', category: 'agua', cost: 900, level: 5, capacity: {'agua': 50}),
  BuildingType(id: 'poste', name: 'Transformador', category: 'luz', cost: 200, level: 1, capacity: {'luz': 12}),
  BuildingType(id: 'luz2', name: 'Subestación eléctrica', category: 'luz', cost: 1000, level: 5, capacity: {'luz': 50}),
  BuildingType(id: 'basura', name: 'Camión de basura', category: 'basura', cost: 220, level: 2, capacity: {'basura': 15}),
  BuildingType(id: 'reciclaje', name: 'Centro de reciclaje', category: 'basura', cost: 950, level: 6, capacity: {'basura': 50}),
  BuildingType(id: 'parque', name: 'Parque', category: 'felicidad', cost: 300, level: 3, capacity: {'felicidad': 5}),
  BuildingType(id: 'palacio', name: 'Palacio municipal', category: 'gobierno', cost: 3000, level: 10, capacity: {}, unique: true),
];

BuildingType buildingById(String id) =>
    id == homeBuilding.id ? homeBuilding : catalog.firstWhere((b) => b.id == id, orElse: () => homeBuilding);

/// Requisitos extra del palacio municipal.
const int palaceHappiness = 80;
const int palacePopulation = 30;
