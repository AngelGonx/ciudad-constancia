import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';
import '../ui/city_view.dart';
import '../ui/pixel.dart';
import '../ui/sprites.dart';

class CityScreen extends StatelessWidget {
  final GameState game;
  const CityScreen({super.key, required this.game});

  void _build(BuildContext context, BuildingType b) {
    if (!game.build(b)) return;
    if (b.id == 'palacio') {
      showPixelDialog(context, L.t('c.palaceTitle'), L.t('c.palaceBody'));
    } else {
      showToast(context, L.f('c.built', {'name': b.name}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = game.city();
    final felColor = c.happiness >= 70 ? C.good : (c.happiness >= 60 ? C.gold : C.bad);

    final bonusText = c.bonus > 0
        ? L.f('c.bonusOn', {'n': (c.bonus * 100).round()})
        : L.t('c.bonusOff');
    final arrivalText = !c.acceptsNewcomers
        ? L.t('c.noArrivals')
        : (c.population < c.housing ? L.t('c.arrivals') : L.t('c.needHomes'));

    final shop = <Widget>[];
    String? lastCat;
    for (final b in catalog) {
      if (b.category != lastCat) {
        lastCat = b.category;
        shop.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(categoryName(b.category).toUpperCase(),
              style: T.display(11, C.gold).copyWith(letterSpacing: 1)),
        ));
      }
      shop.add(_ShopItem(
        type: b,
        reason: game.blockReason(b),
        locked: game.level < b.level,
        onBuild: () => _build(context, b),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: C.grass,
            border: Border.all(color: C.ink, width: 3),
            boxShadow: hardShadow(),
          ),
          child: CityView(game: game),
        ),
        const SizedBox(height: 16),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(L.t('c.happiness')),
                  Text('${c.happiness}%', style: T.display(22, felColor)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SectionTitle(L.t('c.population')),
                Text('${c.population} / ${c.housing}', style: T.display(22)),
              ]),
            ]),
            const SizedBox(height: 8),
            Text(bonusText + arrivalText, style: T.body(13, C.dim)),
            const SizedBox(height: 12),
            _NeedsGrid(stats: c),
          ]),
        ),
        const SizedBox(height: 16),
        _PalaceGoal(game: game, stats: c),
        const SizedBox(height: 20),
        SectionTitle(L.t('c.build')),
        ...shop,
      ],
    );
  }
}

class _NeedsGrid extends StatelessWidget {
  final CityStats stats;
  const _NeedsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget need(String k) {
      final cap = stats.capacity[k] ?? 0;
      final n = stats.need[k] ?? 0;
      final low = cap < n;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(categoryName(k), style: T.body(13))),
          Text('$cap / $n', style: T.body(13, low ? C.bad : C.fg)),
        ]),
        const SizedBox(height: 3),
        PixelBar(value: n == 0 ? 1.0 : cap / n, color: low ? C.bad : C.good, height: 10),
      ]);
    }

    final rows = <Widget>[];
    for (var i = 0; i < needKeys.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: need(needKeys[i])),
          const SizedBox(width: 14),
          Expanded(child: i + 1 < needKeys.length ? need(needKeys[i + 1]) : const SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

class _PalaceGoal extends StatelessWidget {
  final GameState game;
  final CityStats stats;
  const _PalaceGoal({required this.game, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (game.hasPalace) {
      return PixelBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('c.palaceDone'), style: T.display(16)),
          const SizedBox(height: 6),
          Text(L.t('c.palaceDoneBody'), style: T.body(14, C.dim)),
        ]),
      );
    }
    final palace = buildingById('palacio');
    Widget check(bool ok, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            SizedBox(width: 20, child: Text(ok ? '✓' : '·', style: T.display(14, ok ? C.good : C.bad))),
            Expanded(child: Text(text, style: T.body(14))),
          ]),
        );
    return PixelBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.t('c.goal'), style: T.display(16)),
        const SizedBox(height: 4),
        check(game.level >= palace.level, L.f('c.goalLevel', {'need': palace.level, 'have': game.level})),
        check(stats.happiness >= palaceHappiness, L.f('c.goalHappy', {'need': palaceHappiness, 'have': stats.happiness})),
        check(stats.population >= palacePopulation, L.f('c.goalPop', {'need': palacePopulation, 'have': stats.population})),
        check(game.gold >= palace.cost, L.f('c.goalGold', {'need': fmt(palace.cost), 'have': fmt(game.gold)})),
      ]),
    );
  }
}

class _ShopItem extends StatelessWidget {
  final BuildingType type;
  final String? reason;
  final bool locked;
  final VoidCallback onBuild;
  const _ShopItem({required this.type, required this.reason, required this.locked, required this.onBuild});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: PixelBox(
          color: C.panel2,
          shadow: false,
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            BuildingThumb(type.id),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type.name, style: T.display(12)),
                const SizedBox(height: 2),
                Text(type.effect, style: T.body(13, C.dim)),
                const SizedBox(height: 4),
                Row(children: [
                  const Coin(),
                  const SizedBox(width: 6),
                  Text(fmt(type.cost), style: T.display(12, C.gold)),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            PixelButton(
              label: reason ?? L.t('c.build'),
              onPressed: reason == null ? onBuild : null,
              fontSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ]),
        ),
      ),
    );
  }
}
