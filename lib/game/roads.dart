import 'dart:collection';

import 'game_state.dart';

/// Red de calles generada a partir de las construcciones.
///
/// Cada construcción tiene una "entrada": el primer cuadro libre junto a ella
/// (de preferencia abajo, donde está su puerta). Todas las entradas se unen con
/// el camino libre más corto hacia la red ya trazada, así las calles crecen solas
/// conforme se construye.
class RoadNetwork {
  final int size;
  final Set<int> roads;
  final Map<int, int> entrances; // id de construcción -> cuadro de su entrada

  RoadNetwork._(this.size, this.roads, this.entrances);

  int key(int x, int y) => y * size + x;
  int xOf(int k) => k % size;
  int yOf(int k) => k ~/ size;
  bool isRoad(int x, int y) => x >= 0 && y >= 0 && x < size && y < size && roads.contains(key(x, y));

  static String signature(List<Placed> buildings, int size) =>
      '$size|${buildings.map((b) => '${b.id}:${b.x},${b.y}').join(';')}';

  factory RoadNetwork.build(List<Placed> buildings, int size) {
    final occupied = <int>{for (final b in buildings) b.y * size + b.x};
    bool free(int x, int y) => x >= 0 && y >= 0 && x < size && y < size && !occupied.contains(y * size + x);

    final entrances = <int, int>{};
    for (final b in buildings) {
      for (final d in const [[0, 1], [1, 0], [-1, 0], [0, -1]]) {
        final x = b.x + d[0], y = b.y + d[1];
        if (free(x, y)) {
          entrances[b.id] = y * size + x;
          break;
        }
      }
    }

    final roads = <int>{};
    final pending = entrances.values.toSet().toList();
    if (pending.isNotEmpty) {
      // Empieza por la entrada más cercana al centro para que la red crezca desde ahí.
      final c = size ~/ 2;
      pending.sort((a, b) {
        final da = (a % size - c).abs() + (a ~/ size - c).abs();
        final db = (b % size - c).abs() + (b ~/ size - c).abs();
        return da.compareTo(db);
      });
      roads.add(pending.removeAt(0));
      for (final start in pending) {
        if (roads.contains(start)) continue;
        // Búsqueda en anchura por cuadros libres hasta tocar la red.
        final prev = <int, int>{start: -1};
        final queue = Queue<int>()..add(start);
        int? hit;
        while (queue.isNotEmpty) {
          final k = queue.removeFirst();
          if (roads.contains(k)) {
            hit = k;
            break;
          }
          final x = k % size, y = k ~/ size;
          for (final d in const [[0, 1], [1, 0], [-1, 0], [0, -1]]) {
            final nx = x + d[0], ny = y + d[1];
            if (!free(nx, ny)) continue;
            final nk = ny * size + nx;
            if (prev.containsKey(nk)) continue;
            prev[nk] = k;
            queue.add(nk);
          }
        }
        if (hit == null) {
          roads.add(start); // aislada: al menos su entrada se pavimenta
          continue;
        }
        var k = hit;
        while (k != -1) {
          roads.add(k);
          k = prev[k]!;
        }
      }
    }
    return RoadNetwork._(size, roads, entrances);
  }

  /// Camino de cuadros por la calle entre dos cuadros de calle (incluye ambos), o null.
  List<int>? path(int from, int to) {
    if (!roads.contains(from) || !roads.contains(to)) return null;
    if (from == to) return [from];
    final prev = <int, int>{from: -1};
    final queue = Queue<int>()..add(from);
    while (queue.isNotEmpty) {
      final k = queue.removeFirst();
      if (k == to) break;
      final x = k % size, y = k ~/ size;
      for (final d in const [[0, 1], [1, 0], [-1, 0], [0, -1]]) {
        final nx = x + d[0], ny = y + d[1];
        if (!isRoad(nx, ny)) continue;
        final nk = ny * size + nx;
        if (prev.containsKey(nk)) continue;
        prev[nk] = k;
        queue.add(nk);
      }
    }
    if (!prev.containsKey(to)) return null;
    final out = <int>[];
    var k = to;
    while (k != -1) {
      out.add(k);
      k = prev[k]!;
    }
    return out.reversed.toList();
  }
}
