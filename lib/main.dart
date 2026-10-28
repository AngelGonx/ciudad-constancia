import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_state.dart';
import 'game/rules.dart';
import 'screens/avatar_screen.dart';
import 'screens/city_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/progress_screen.dart';
import 'ui/pixel.dart';
import 'ui/sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: C.bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.panel,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final game = GameState();
  await game.load();
  runApp(PixelTodoApp(game: game));
}

class PixelTodoApp extends StatelessWidget {
  final GameState game;
  const PixelTodoApp({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel To-Do',
      debugShowCheckedModeBanner: false,
      theme: pixelTheme(),
      home: HomeShell(game: game),
    );
  }
}

class HomeShell extends StatefulWidget {
  final GameState game;
  const HomeShell({super.key, required this.game});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  static const _tabs = ['Misiones', 'Ciudad', 'Avance', 'Avatar'];

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final pages = <Widget>[
          MissionsScreen(game: g),
          CityScreen(game: g),
          ProgressScreen(game: g),
          AvatarScreen(game: g),
        ];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              _Header(game: g),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == _tab, child: pages[i]),
                  ],
                ),
              ),
            ]),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: C.panel,
              border: Border(top: BorderSide(color: C.ink, width: 3)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _TabButton(
                          label: _tabs[i],
                          selected: i == _tab,
                          onTap: () => setState(() => _tab = i),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.bg : Colors.transparent,
            border: Border.all(color: selected ? C.ink : Colors.transparent, width: 3),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: T.display(11, selected ? C.gold : C.dim)),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final GameState game;
  const _Header({required this.game});

  @override
  Widget build(BuildContext context) {
    final lvl = game.level;
    final start = levelStart(lvl);
    final next = levelNext(lvl);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.ink, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: C.panel2, border: Border.all(color: C.ink, width: 3)),
          child: AvatarView(avatar: game.avatar, size: 50),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PixelChip('NV $lvl', color: C.xp),
              const SizedBox(width: 6),
              Expanded(
                child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.display(13)),
              ),
            ]),
            const SizedBox(height: 6),
            PixelBar(value: (game.xp - start) / (next - start)),
            const SizedBox(height: 3),
            Text('${fmt(game.xp)} / ${fmt(next)} XP', style: T.body(12, C.dim)),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Coin(),
            const SizedBox(width: 6),
            Text(fmt(game.gold), style: T.display(16, C.gold)),
          ]),
          const SizedBox(height: 4),
          Text('hoy +${fmt(game.goldToday)}', style: T.body(12, C.dim)),
        ]),
      ]),
    );
  }
}
