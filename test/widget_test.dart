import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ciudad_constancia/game/game_state.dart';
import 'package:ciudad_constancia/game/rules.dart';
import 'package:ciudad_constancia/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('niveles: n × 1000 XP', () {
    expect(levelOf(0), 1);
    expect(levelOf(1999), 1);
    expect(levelOf(2000), 2);
    expect(levelOf(3000), 3);
    expect(levelOf(10000), 10);
  });

  test('balance: rendimiento decreciente, racha e inflación', () {
    expect(rewardFactor(0), 1.0);
    expect(rewardFactor(7), 1.0);
    expect(rewardFactor(8), 0.5);
    expect(rewardFactor(14), 0.1);
    expect(streakBonus(1), 0);
    expect(streakBonus(6), closeTo(0.25, 1e-9));
    expect(streakBonus(40), 0.5);
    expect(inflatedCost(100, 0), 100);
    expect(inflatedCost(100, 1), 115);
    expect(inflatedCost(100, 2), 132);
  });

  test('una tarea recién creada espera la tinta fresca', () async {
    final g = GameState();
    await g.load();
    g.addTask('Nueva', 'mision', 'media');
    expect(g.tasks.first.freshInkLeft, greaterThan(0));
  });

  test('completar y desmarcar una misión regresa todo', () async {
    final g = GameState();
    await g.load();
    final t = g.tasks.firstWhere((t) => !t.isHabit);
    final xp = g.xp, gold = g.gold;
    final r = g.complete(t);
    expect(g.xp, xp + r.xp);
    expect(g.gold, gold + r.gold);
    g.undo(t);
    expect(g.xp, xp);
    expect(g.gold, gold);
  });

  test('la checklist completa la tarea al marcar el último paso', () async {
    final g = GameState();
    await g.load();
    final t = g.tasks.firstWhere((t) => !t.isHabit);
    t.steps = [SubStep('a'), SubStep('b')];
    expect(g.toggleStep(t, 0).completed, isNull);
    expect(t.doneToday, isFalse);
    expect(g.toggleStep(t, 1).completed, isNotNull);
    expect(t.doneToday, isTrue);
    g.toggleStep(t, 0); // desmarcar un paso desmarca la tarea
    expect(t.doneToday, isFalse);
    expect(t.stepsDone, 1);
  });

  test('un día libre salva la racha si faltó un día', () async {
    SharedPreferences.setMockInitialValues({
      'pixel_todo_state_v1': jsonEncode({
        'language': 'es',
        'streakFreezes': 1,
        'tasks': [
          {'id': 'h1', 'title': 'Leer', 'kind': 'habito', 'diff': 'facil', 'streak': 5, 'last': dayOffset(-2)},
        ],
      }),
    });
    final g = GameState();
    await g.load();
    expect(g.streakFreezes, 0);
    expect(g.tasks.first.last, dayOffset(-1));
    expect(g.tasks.first.currentStreak, 5);
  });

  testWidgets('primer inicio pide idioma', (tester) async {
    final g = GameState();
    await g.load();
    await tester.pumpWidget(PixelTodoApp(game: g));
    await tester.pump();
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('la app abre en Misiones', (tester) async {
    final g = GameState();
    await g.load();
    g.setLanguage('es');
    g.tutorialSeen = true; // el tutorial se prueba aparte
    await tester.pumpWidget(PixelTodoApp(game: g));
    await tester.pump();
    expect(find.text('Misiones'), findsWidgets);
    expect(find.text('Tender la cama'), findsOneWidget);
  });
}
