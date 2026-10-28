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

  testWidgets('la app abre en Misiones', (tester) async {
    final g = GameState();
    await g.load();
    await tester.pumpWidget(PixelTodoApp(game: g));
    await tester.pump();
    expect(find.text('Misiones'), findsWidgets);
    expect(find.text('Tender la cama'), findsOneWidget);
  });
}
