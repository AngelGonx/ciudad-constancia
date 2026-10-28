import 'package:flutter/material.dart';

import '../game/achievements.dart';
import '../game/game_state.dart';
import '../i18n/strings.dart';
import '../ui/pixel.dart';
import '../ui/sprites.dart';

/// Texto de la meta de un logro, por ejemplo "Completa 50 misiones".
String achievementGoalText(Achievement a) => L.f('am.${a.metric.name}', {'n': fmt(a.goal)});

class AchievementsScreen extends StatelessWidget {
  final GameState game;
  const AchievementsScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    if (!game.cityUnlocked) return _Locked(game: game);
    final done = achievements.where((a) => game.unlockedAchievements.contains(a.id)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(L.t('ach.title')),
            const SizedBox(height: 4),
            Text('$done / ${achievements.length}', style: T.display(24, C.gold)),
            const SizedBox(height: 8),
            PixelBar(value: done / achievements.length, color: C.gold),
            const SizedBox(height: 6),
            Text(L.t('ach.intro'), style: T.body(13, C.dim)),
          ]),
        ),
        const SizedBox(height: 16),
        for (final a in achievements) _AchievementCard(game: game, a: a),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final GameState game;
  final Achievement a;
  const _AchievementCard({required this.game, required this.a});

  @override
  Widget build(BuildContext context) {
    final unlocked = game.unlockedAchievements.contains(a.id);
    final value = metricValue(game, a.metric);
    final cosmetic = a.cosmetic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.panel2,
          border: Border.all(color: unlocked ? C.gold : C.ink, width: 3),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Medal(unlocked: unlocked),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.t('ach.${a.id}'), style: T.display(12, unlocked ? C.gold : C.fg)),
              const SizedBox(height: 2),
              Text(achievementGoalText(a), style: T.body(13, C.dim)),
              const SizedBox(height: 6),
              if (!unlocked) ...[
                PixelBar(value: value / a.goal, height: 10),
                const SizedBox(height: 3),
                Text('${fmt(value.clamp(0, a.goal).toInt())} / ${fmt(a.goal)}', style: T.body(12, C.dim)),
                const SizedBox(height: 6),
              ],
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Coin(size: 10),
                  const SizedBox(width: 4),
                  Text('+${fmt(a.gold)}', style: T.display(11, C.gold)),
                ]),
                if (cosmetic != null) PixelChip(L.f('ach.cosmetic', {'name': L.t('acc.$cosmetic')}), color: C.epic),
              ]),
            ]),
          ),
          if (cosmetic != null) ...[
            const SizedBox(width: 8),
            Opacity(
              opacity: unlocked ? 1 : 0.5,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: C.bg, border: Border.all(color: C.ink, width: 2)),
                child: AvatarView(avatar: _preview(cosmetic), size: 40),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  /// El avatar del jugador con el accesorio puesto, para ver cómo se vería.
  Avatar _preview(String cosmetic) {
    final a = game.avatar;
    return Avatar(
      skin: a.skin,
      hair: a.hair,
      hairColor: a.hairColor,
      shirt: a.shirt,
      pants: a.pants,
      accessory: cosmetic,
    );
  }
}

/// Medalla pixel: dorada si el logro ya se ganó.
class _Medal extends StatelessWidget {
  final bool unlocked;
  const _Medal({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _MedalPainter(unlocked ? C.gold : C.dim, C.ink, unlocked)),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final Color color;
  final Color ink;
  final bool shine;
  _MedalPainter(this.color, this.ink, this.shine);

  static const _rows = [
    'RR..BB..',
    '.RR.BB..',
    '..RRB...',
    '..XXXX..',
    '.XXXXXX.',
    '.XXSXXX.',
    '.XXXXXX.',
    '..XXXX..',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 8;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final ch = _rows[y][x];
        if (ch == '.') continue;
        paint.color = switch (ch) {
          'R' => const Color(0xFFD24C4C),
          'B' => const Color(0xFF4F6FD8),
          'S' => shine ? const Color(0xFFFFF4C2) : color,
          _ => color,
        };
        canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.color != color || old.shine != shine;
}

class _Locked extends StatelessWidget {
  final GameState game;
  const _Locked({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        const Center(child: SizedBox(width: 96, height: 96, child: _Medal(unlocked: true))),
        const SizedBox(height: 16),
        Text(L.t('ach.lockedTitle'), textAlign: TextAlign.center, style: T.display(18, C.gold)),
        const SizedBox(height: 10),
        Text(L.t('ach.lockedText'), textAlign: TextAlign.center, style: T.body(15)),
        const SizedBox(height: 16),
        PixelBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final a in achievements.where((a) => a.cosmetic != null).take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 22, child: Text('+', style: T.display(14, C.good))),
                  Expanded(child: Text('${L.t('ach.${a.id}')}: ${L.t('acc.${a.cosmetic}')}', style: T.body(14))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(L.t('ach.lockedHint'), textAlign: TextAlign.center, style: T.body(13, C.dim)),
      ],
    );
  }
}
