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
    await tester.pumpWidget(PixelTodoApp(game: g));
    await tester.pump();
    expect(find.text('Misiones'), findsWidgets);
    expect(find.text('Tender la cama'), findsOneWidget);
  });
}
