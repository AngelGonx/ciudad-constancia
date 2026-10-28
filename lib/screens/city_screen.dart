import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../ui/city_view.dart';
import '../ui/pixel.dart';
import '../ui/sprites.dart';

class CityScreen extends StatelessWidget {
  final GameState game;
  const CityScreen({super.key, required this.game});

  void _build(BuildContext context, BuildingType b) {
    if (!game.build(b)) return;
    if (b.id == 'palacio') {
      showPixelDialog(context, '¡Palacio municipal!',
          'Tu ciudad ya tiene gobierno. Desde aquí gobiernas Ciudad Constancia.');
    } else {
      showToast(context, '${b.name}: construido');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = game.city();
    final felColor = c.happiness >= 70 ? C.good : (c.happiness >= 60 ? C.gold : C.bad);

    final bonusText = c.bonus > 0
        ? 'Ciudad equilibrada: +${(c.bonus * 100).round()}% de oro por misión. '
        : 'Con 70% de felicidad ganas +10% de oro, con 90% ganas +20%. ';
    final arrivalText = !c.acceptsNewcomers
        ? 'Nadie se muda mientras la felicidad esté bajo 60%.'
        : (c.population < c.housing
            ? 'Llega gente nueva al completar misiones.'
            : 'Construye casas para que llegue más gente.');

    final shop = <Widget>[];
    String? lastCat;
    for (final b in catalog) {
      if (b.category != lastCat) {
        lastCat = b.category;
        shop.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(categoryNames[b.category]!.toUpperCase(),
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
            boxShadow: const [BoxShadow(color: C.ink, offset: Offset(0, 4))],
          ),
          child: CityView(game: game),
        ),
        const SizedBox(height: 16),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('Felicidad'),
                  Text('${c.happiness}%', style: T.display(22, felColor)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const SectionTitle('Habitantes'),
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
        const SectionTitle('Construir'),
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
          Expanded(child: Text(categoryNames[k]!, style: T.body(13))),
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
          Text('Palacio municipal construido', style: T.display(16)),
          const SizedBox(height: 6),
          Text('Ya gobiernas tu ciudad. Sigue creciendo hasta llenar cada lote.', style: T.body(14, C.dim)),
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
        Text('Meta: Palacio municipal', style: T.display(16)),
        const SizedBox(height: 4),
        check(game.level >= palace.level, 'Nivel ${palace.level} (tienes ${game.level})'),
        check(stats.happiness >= palaceHappiness, 'Felicidad $palaceHappiness% (tienes ${stats.happiness}%)'),
        check(stats.population >= palacePopulation, '$palacePopulation habitantes (tienes ${stats.population})'),
        check(game.gold >= palace.cost, '${fmt(palace.cost)} de oro (tienes ${fmt(game.gold)})'),
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
              label: reason ?? 'Construir',
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
