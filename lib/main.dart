import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/achievements.dart';
import 'game/game_state.dart';
import 'game/rules.dart';
import 'i18n/strings.dart';
import 'screens/achievements_screen.dart';
import 'screens/avatar_screen.dart';
import 'screens/city_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'services/home_widget_sync.dart';
import 'services/reminders.dart';
import 'services/store.dart';
import 'ui/pixel.dart';
import 'ui/sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final game = GameState();
  await game.load();
  await Reminders.init();
  await HomeWidgetSync.init();
  game.onChanged = (g) {
    Reminders.scheduleSoon(g);
    HomeWidgetSync.pushSoon(g);
  };
  Reminders.scheduleSoon(game);
  HomeWidgetSync.pushSoon(game);
  runApp(PixelTodoApp(game: game));
  // La tienda se prepara después de mostrar la app para no retrasar el arranque.
  Store.instance.init(game);
}

class PixelTodoApp extends StatelessWidget {
  final GameState game;
  const PixelTodoApp({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        // Idioma y tema se aplican aquí para que toda la app se redibuje al cambiarlos.
        L.lang = game.language ?? 'es';
        C.useLight(game.lightTheme);
        final iconBrightness = game.lightTheme ? Brightness.dark : Brightness.light;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: C.bg,
          statusBarIconBrightness: iconBrightness,
          systemNavigationBarColor: C.panel,
          systemNavigationBarIconBrightness: iconBrightness,
        ));
        return MaterialApp(
          title: 'Pixel To-Do',
          debugShowCheckedModeBanner: false,
          theme: pixelTheme(),
          home: game.language == null ? LanguageScreen(game: game) : HomeShell(game: game),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final GameState game;
  const HomeShell({super.key, required this.game});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app se recargan los datos, por si se completó algo desde el widget.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.game.load().then((_) => HomeWidgetSync.pushSoon(widget.game));
    }
  }

  int _tab = 0;
  static const _tabs = ['tab.missions', 'tab.city', 'tab.achievements', 'tab.progress', 'tab.avatar'];
  bool _showingAchievement = false;

  /// Muestra, uno por uno, los logros recién ganados.
  void _showPendingAchievements() {
    final g = widget.game;
    if (_showingAchievement || g.pendingAchievements.isEmpty) return;
    final id = g.pendingAchievements.removeAt(0);
    final a = achievements.firstWhere((x) => x.id == id);
    _showingAchievement = true;
    final lines = [
      achievementGoalText(a),
      L.f('ach.unlockedGold', {'n': fmt(a.gold)}),
      if (a.cosmetic != null) L.f('ach.unlockedCosmetic', {'name': L.t('acc.${a.cosmetic}')}),
    ];
    showPixelDialog(context, '${L.t('ach.unlockedTitle')}\n${L.t('ach.$id')}', lines.join('\n')).then((_) {
      _showingAchievement = false;
      if (mounted) _showPendingAchievements();
    });
  }

  void _openSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(game: widget.game)));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final pages = <Widget>[
      MissionsScreen(game: g),
      CityScreen(game: g),
      AchievementsScreen(game: g),
      ProgressScreen(game: g),
      AvatarScreen(game: g),
    ];
    if (g.pendingAchievements.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPendingAchievements();
      });
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(game: g, onSettings: _openSettings),
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
        decoration: BoxDecoration(
          color: C.panel,
          border: Border(top: BorderSide(color: C.ink, width: 3)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _TabButton(
                      label: L.t(_tabs[i]),
                      selected: i == _tab,
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _tab = i);
                      },
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
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
          decoration: BoxDecoration(
            color: selected ? C.bg : Colors.transparent,
            border: Border.all(color: selected ? C.ink : Colors.transparent, width: 3),
          ),
          // heightFactor: 1 hace que el botón mida lo que su texto, sin estirarse.
          child: Align(
            heightFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: T.display(11, selected ? C.gold : C.dim)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final GameState game;
  final VoidCallback onSettings;
  const _Header({required this.game, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final lvl = game.level;
    final start = levelStart(lvl);
    final next = levelNext(lvl);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
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
              PixelChip(L.f('hdr.level', {'n': lvl}), color: C.xp),
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
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Coin(),
            const SizedBox(width: 6),
            Text(fmt(game.gold), style: T.display(16, C.gold)),
          ]),
          const SizedBox(height: 4),
          Text(L.f('hdr.today', {'n': fmt(game.goldToday)}), style: T.body(12, C.dim)),
        ]),
        const SizedBox(width: 10),
        GearButton(onTap: onSettings),
      ]),
    );
  }
}
