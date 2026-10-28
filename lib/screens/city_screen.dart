import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../i18n/strings.dart';
import '../services/store.dart';
import '../ui/building_art.dart';
import '../ui/city_view.dart';
import '../ui/color_picker.dart';
import '../ui/pixel.dart';
import '../ui/sprites.dart';

class CityScreen extends StatefulWidget {
  final GameState game;
  const CityScreen({super.key, required this.game});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final _mapKey = GlobalKey<CityMapState>();
  CityMode _mode = CityMode.view;
  BuildingType? _placing;
  Color? _placingColor;
  int? _selectedId;
  int? _movingId;
  bool _cityTab = false;
  bool _confirmDemolish = false;

  GameState get g => widget.game;

  void _cancel() => setState(() {
        _mode = CityMode.view;
        _placing = null;
        _movingId = null;
      });

  Future<void> _startPlacing(BuildingType type) async {
    final color = await chooseBuildingColor(context, type, Color(type.base), L.t('c.choosePlace'));
    if (color == null || !mounted) return;
    setState(() {
      _mode = CityMode.place;
      _placing = type;
      _placingColor = color;
      _selectedId = null;
    });
  }

  void _onTapTile(int x, int y) {
    switch (_mode) {
      case CityMode.place:
        final type = _placing;
        if (type == null) return;
        if (!g.canPlace(x, y)) {
          showToast(context, L.t('c.occupied'));
          return;
        }
        if (g.place(type, (_placingColor ?? Color(type.base)).toARGB32(), x, y)) {
          if (type.id == 'palacio') {
            showPixelDialog(context, L.t('c.palaceTitle'), L.t('c.palaceBody'));
          } else {
            showToast(context, L.f('c.built', {'name': type.name}));
          }
        }
        _cancel();
        break;
      case CityMode.move:
        final id = _movingId;
        if (id == null) return;
        if (!g.canPlace(x, y, ignoreId: id)) {
          showToast(context, L.t('c.occupied'));
          return;
        }
        final moving = g.placedById(id);
        if (g.moveBuilding(id, x, y) && moving != null) {
          showToast(context, L.f('c.moved', {'name': moving.kind.name}));
        }
        _cancel();
        break;
      case CityMode.view:
        final hit = g.buildingAt(x, y);
        setState(() {
          _selectedId = hit?.id == _selectedId ? null : hit?.id;
          _confirmDemolish = false;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!g.cityUnlocked) return _LockedCity(game: g);

    final selected = _selectedId == null ? null : g.placedById(_selectedId!);
    final hint = switch (_mode) {
      CityMode.place => L.f('c.placeHint', {'name': _placing?.name ?? ''}),
      CityMode.move => L.t('c.moveHint'),
      CityMode.view => null,
    };

    return Column(children: [
      Expanded(
        flex: 11,
        child: Container(
          color: C.grass,
          child: Stack(children: [
            Positioned.fill(
              child: CityMap(
                key: _mapKey,
                buildings: g.buildings,
                mapSize: g.mapSize,
                population: g.population,
                avatar: g.avatar,
                mode: _mode,
                selectedId: _mode == CityMode.view ? _selectedId : null,
                movingId: _movingId,
                ghostType: _placing,
                ghostColor: _placingColor,
                onTapTile: _onTapTile,
              ),
            ),
            const Positioned(left: 10, top: 10, child: _TimeChip()),
            Positioned(
              right: 10,
              top: 10,
              child: Column(children: [
                _MapButton(label: '+', semantic: L.t('c.zoomIn'), onTap: () => _mapKey.currentState?.zoomBy(1.4)),
                const SizedBox(height: 6),
                _MapButton(label: '-', semantic: L.t('c.zoomOut'), onTap: () => _mapKey.currentState?.zoomBy(1 / 1.4)),
                const SizedBox(height: 6),
                _MapButton(label: '[ ]', semantic: L.t('c.fit'), onTap: () => _mapKey.currentState?.refit()),
              ]),
            ),
            if (hint != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: PixelBox(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(hint, style: T.body(14))),
                    const SizedBox(width: 8),
                    PixelButton(
                      label: L.t('cancel'),
                      color: C.panel2,
                      textColor: C.fg,
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: _cancel,
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      Container(height: 3, color: C.ink),
      Expanded(
        flex: 10,
        child: selected != null && _mode == CityMode.view
            ? _SelectedPanel(
                game: g,
                building: selected,
                confirming: _confirmDemolish,
                onMove: () => setState(() {
                  _mode = CityMode.move;
                  _movingId = selected.id;
                  _selectedId = null;
                }),
                onPaint: () async {
                  final c = await chooseBuildingColor(context, selected.kind, Color(selected.color), L.t('a.use'));
                  if (c != null) g.recolor(selected.id, c.toARGB32());
                },
                onDemolish: () {
                  if (!_confirmDemolish) {
                    setState(() => _confirmDemolish = true);
                    return;
                  }
                  final name = selected.kind.name;
                  final refund = g.demolish(selected.id);
                  setState(() {
                    _selectedId = null;
                    _confirmDemolish = false;
                  });
                  if (refund >= 0) showToast(context, L.f('c.demolished', {'name': name, 'n': refund}));
                },
                onClose: () => setState(() {
                  _selectedId = null;
                  _confirmDemolish = false;
                }),
              )
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(children: [
                    PixelChoice(label: L.t('c.tabBuild'), selected: !_cityTab, onTap: () => setState(() => _cityTab = false)),
                    const SizedBox(width: 8),
                    PixelChoice(label: L.t('c.tabCity'), selected: _cityTab, onTap: () => setState(() => _cityTab = true)),
                  ]),
                ),
                Expanded(child: _cityTab ? _CityStatus(game: g) : _Shop(game: g, onBuild: _startPlacing)),
              ]),
      ),
    ]);
  }
}

// ---------------- Panel de construcción seleccionada ----------------

class _SelectedPanel extends StatelessWidget {
  final GameState game;
  final Placed building;
  final bool confirming;
  final VoidCallback onMove;
  final VoidCallback onPaint;
  final VoidCallback onDemolish;
  final VoidCallback onClose;
  const _SelectedPanel({
    required this.game,
    required this.building,
    required this.confirming,
    required this.onMove,
    required this.onPaint,
    required this.onDemolish,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final type = building.kind;
    final refund = (type.cost * demolishRefund).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuildingThumb(type, color: Color(building.color), width: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.name, style: T.display(14)),
              const SizedBox(height: 4),
              Text(type.effect, style: T.body(14, C.dim)),
              if (!type.demolishable) ...[
                const SizedBox(height: 4),
                Text(L.t('c.onlyMove'), style: T.body(13, C.dim)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PixelButton(label: L.t('c.move'), onPressed: onMove),
          PixelButton(label: L.t('c.paint'), color: C.xp, onPressed: onPaint),
          if (type.demolishable)
            PixelButton(
              label: confirming ? L.f('c.demolishConfirm', {'n': refund}) : L.t('c.demolish'),
              color: C.bad,
              onPressed: onDemolish,
            ),
          PixelButton(label: L.t('c.close'), color: C.panel2, textColor: C.fg, onPressed: onClose),
        ]),
        if (type.demolishable) ...[
          const SizedBox(height: 10),
          Text(L.t('c.refund'), style: T.body(13, C.dim)),
        ],
      ],
    );
  }
}

// ---------------- Tienda ----------------

class _Shop extends StatelessWidget {
  final GameState game;
  final void Function(BuildingType) onBuild;
  const _Shop({required this.game, required this.onBuild});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    String? lastCat;
    for (final b in catalog) {
      if (b.category != lastCat) {
        lastCat = b.category;
        items.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(categoryName(b.category).toUpperCase(), style: T.display(11, C.gold).copyWith(letterSpacing: 1)),
        ));
        if (b.category == 'transporte') {
          items.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(L.t('c.busHint'), style: T.body(13, C.dim)),
          ));
        }
      }
      final reason = game.blockReason(b);
      final locked = game.level < b.level;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: PixelBox(
            color: C.panel2,
            shadow: false,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              BuildingThumb(b),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: T.display(12)),
                  const SizedBox(height: 2),
                  Text(b.effect, style: T.body(13, C.dim)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Coin(),
                    const SizedBox(width: 6),
                    Text(fmt(b.cost), style: T.display(12, C.gold)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              PixelButton(
                label: reason ?? L.t('c.build'),
                onPressed: reason == null ? () => onBuild(b) : null,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ]),
          ),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: items);
  }
}

// ---------------- Estado de la ciudad ----------------

class _CityStatus extends StatelessWidget {
  final GameState game;
  const _CityStatus({required this.game});

  @override
  Widget build(BuildContext context) {
    final c = game.city();
    final felColor = c.happiness >= 70 ? C.good : (c.happiness >= 60 ? C.gold : C.bad);
    final bonusText = c.bonus > 0 ? L.f('c.bonusOn', {'n': (c.bonus * 100).round()}) : L.t('c.bonusOff');
    final arrivalText = !c.acceptsNewcomers
        ? L.t('c.noArrivals')
        : (c.population < c.housing ? L.t('c.arrivals') : L.t('c.needHomes'));
    final next = game.nextExpansion;
    final expBlock = next == null ? null : game.expansionBlock(next);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
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
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.t('c.expandTitle'), style: T.display(16)),
            const SizedBox(height: 6),
            if (next == null)
              Text(L.t('c.maxSize'), style: T.body(14, C.dim))
            else ...[
              Text(L.f('c.expandText', {'a': game.mapSize, 'b': next.size, 'lvl': next.level}), style: T.body(14, C.dim)),
              const SizedBox(height: 10),
              Row(children: [
                const Coin(),
                const SizedBox(width: 6),
                Text(fmt(next.cost), style: T.display(12, C.gold)),
                const Spacer(),
                PixelButton(
                  label: expBlock ?? L.t('c.expandBtn'),
                  onPressed: expBlock == null
                      ? () {
                          if (game.expand()) showToast(context, L.f('c.expanded', {'n': game.mapSize}));
                        }
                      : null,
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        _PalaceGoal(game: game, stats: c),
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
        check(stats.happiness >= palaceHappiness,
            L.f('c.goalHappy', {'need': palaceHappiness, 'have': stats.happiness})),
        check(stats.population >= palacePopulation,
            L.f('c.goalPop', {'need': palacePopulation, 'have': stats.population})),
        check(game.gold >= palace.cost, L.f('c.goalGold', {'need': fmt(palace.cost), 'have': fmt(game.gold)})),
      ]),
    );
  }
}

// ---------------- Controles del mapa ----------------

class _MapButton extends StatelessWidget {
  final String label;
  final String semantic;
  final VoidCallback onTap;
  const _MapButton({required this.label, required this.semantic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.panel,
            border: Border.all(color: C.ink, width: 3),
            boxShadow: hardShadow(3),
          ),
          child: Text(label, style: T.display(label.length > 1 ? 11 : 18)),
        ),
      ),
    );
  }
}

/// Muestra la hora y si es de día o de noche; se actualiza cada medio minuto.
class _TimeChip extends StatefulWidget {
  const _TimeChip();
  @override
  State<_TimeChip> createState() => _TimeChipState();
}

class _TimeChipState extends State<_TimeChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = now.hour;
    final label = h >= 7 && h < 18
        ? L.t('c.day')
        : h >= 18 && h < 21
            ? L.t('c.dusk')
            : h >= 5 && h < 7
                ? L.t('c.dawn')
                : L.t('c.night');
    final time = '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return PixelBox(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shadow: false,
      child: Text('$label $time', style: T.display(11)),
    );
  }
}

// ---------------- Selector de color de construcción ----------------

/// Pide el color de una construcción mostrando cómo se verá. Regresa null si se cancela.
Future<Color?> chooseBuildingColor(BuildContext context, BuildingType type, Color initial, String confirmLabel) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<Color>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 3)),
      child: _BuildingColorBody(type: type, initial: initial, confirmLabel: confirmLabel),
    ),
  );
}

class _BuildingColorBody extends StatefulWidget {
  final BuildingType type;
  final Color initial;
  final String confirmLabel;
  const _BuildingColorBody({required this.type, required this.initial, required this.confirmLabel});

  @override
  State<_BuildingColorBody> createState() => _BuildingColorBodyState();
}

class _BuildingColorBodyState extends State<_BuildingColorBody> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) {
    final presets = <Color>[Color(widget.type.base), ...clothColors, ...hairColors.take(6)];
    return Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L.f('c.chooseColor', {'name': widget.type.name}), textAlign: TextAlign.center, style: T.display(14)),
          const SizedBox(height: 14),
          BuildingThumb(widget.type, color: _color, width: 108),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final c in presets)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(
                      color: c.toARGB32() == _color.toARGB32() ? C.gold : C.ink,
                      width: c.toARGB32() == _color.toARGB32() ? 4 : 3,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () async {
                final picked = await pickColor(context, _color);
                if (picked != null && mounted) setState(() => _color = picked);
              },
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.panel2, border: Border.all(color: C.ink, width: 3)),
                child: Text('+', style: T.display(16)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            PixelButton(
              label: L.t('cancel'),
              color: C.panel2,
              textColor: C.fg,
              onPressed: () => Navigator.of(context).pop(),
            ),
            PixelButton(label: widget.confirmLabel, onPressed: () => Navigator.of(context).pop(_color)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------- Ciudad bloqueada (versión gratis) ----------------

class _LockedCity extends StatelessWidget {
  final GameState game;
  const _LockedCity({required this.game});

  static final List<Placed> _demo = [
    for (final d in const [
      ['hogar', 1, 1], ['casa', 2, 1], ['casa2', 3, 1], ['parque', 4, 1],
      ['tiendita', 1, 2], ['escuela', 2, 2], ['fuente', 3, 2], ['panaderia', 4, 2],
      ['pozo', 1, 3], ['solar', 2, 3], ['basura', 3, 3], ['palacio', 4, 3],
    ])
      Placed(
        id: (d[1] as int) * 10 + (d[2] as int),
        type: d[0] as String,
        x: d[1] as int,
        y: d[2] as int,
        color: buildingById(d[0] as String).base,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final benefits = ['lock.b1', 'lock.b2', 'lock.b3', 'lock.b4', 'lock.b5'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          height: 230,
          decoration: BoxDecoration(
            color: C.grass,
            border: Border.all(color: C.ink, width: 3),
            boxShadow: hardShadow(),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CityMap(
                  buildings: _demo,
                  mapSize: 6,
                  population: 12,
                  avatar: game.avatar,
                  interactive: false,
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: PixelChip('1 USD', color: C.gold),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Text(L.t('lock.title'), style: T.display(20, C.gold)),
        const SizedBox(height: 8),
        Text(L.t('lock.text'), style: T.body(15)),
        const SizedBox(height: 14),
        for (final b in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text('+', style: T.display(14, C.good))),
              Expanded(child: Text(L.t(b), style: T.body(14))),
            ]),
          ),
        const SizedBox(height: 14),
        PixelBox(
          child: Row(children: [
            const Coin(size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(L.f('lock.gold', {'n': fmt(game.gold)}), style: T.body(15))),
          ]),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: Store.instance,
          builder: (context, _) {
            final store = Store.instance;
            final price = store.product?.price;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PixelButton(
                label: store.busy
                    ? L.t('lock.busy')
                    : (price == null ? L.t('lock.buy') : L.f('lock.buyPrice', {'p': price})),
                onPressed: store.canBuy ? store.buy : null,
              ),
              const SizedBox(height: 10),
              if (store.available)
                PixelButton(
                  label: L.t('lock.restore'),
                  color: C.panel2,
                  textColor: C.fg,
                  onPressed: store.busy ? null : store.restore,
                ),
              if (store.error != null) ...[
                const SizedBox(height: 8),
                Text(L.f('lock.error', {'e': store.error!}), style: T.body(13, C.bad)),
              ],
              if (!store.canBuy && !store.busy) ...[
                const SizedBox(height: 8),
                Text(L.t('lock.soon'), style: T.body(13, C.dim)),
              ],
            ]);
          },
        ),
        const SizedBox(height: 8),
        Text(L.t('lock.beta'), style: T.body(13, C.dim)),
      ],
    );
  }
}
