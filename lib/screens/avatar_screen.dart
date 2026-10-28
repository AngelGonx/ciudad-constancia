import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../i18n/strings.dart';
import '../ui/color_picker.dart';
import '../ui/pixel.dart';
import '../ui/sprites.dart';

class AvatarScreen extends StatefulWidget {
  final GameState game;
  const AvatarScreen({super.key, required this.game});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.game.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final a = g.avatar;

    Widget colors(List<Color> presets, int selected, void Function(Avatar, int) apply) {
      final isPreset = presets.any((c) => c.toARGB32() == selected);
      Widget swatch(Color c, bool active, VoidCallback onTap, {String? label, Widget? child}) {
        return Semantics(
          button: true,
          selected: active,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                border: Border.all(color: active ? C.gold : C.ink, width: active ? 4 : 3),
              ),
              child: child,
            ),
          ),
        );
      }

      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in presets)
          swatch(c, c.toARGB32() == selected, () => g.updateAvatar((av) => apply(av, c.toARGB32()))),
        // Color libre: muestra el color actual si no es uno de los sugeridos.
        swatch(
          isPreset ? C.panel2 : Color(selected),
          !isPreset,
          () async {
            final picked = await pickColor(context, Color(selected));
            if (picked != null) g.updateAvatar((av) => apply(av, picked.toARGB32()));
          },
          label: L.t('a.custom'),
          child: isPreset ? const CustomPaint(painter: _RainbowPainter()) : null,
        ),
      ]);
    }

    Widget texts(List<String> ids, String prefix, String selected, void Function(Avatar, String) apply) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final id in ids)
          PixelChoice(
            label: L.t('$prefix.$id'),
            selected: id == selected,
            onTap: () => g.updateAvatar((av) => apply(av, id)),
          ),
      ]);
    }

    Widget option(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title),
            const SizedBox(height: 8),
            child,
          ]),
        );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          PixelBox(
            color: C.panel2,
            padding: const EdgeInsets.all(16),
            child: Center(child: AvatarView(avatar: a, size: 192)),
          ),
          const SizedBox(height: 16),
          SectionTitle(L.t('a.name')),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 20,
            style: T.body(16),
            onChanged: g.setName,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: pixelInput(),
          ),
          option(L.t('a.skin'), colors(skinColors, a.skin, (av, c) => av.skin = c)),
          option(L.t('a.hair'), texts(hairStyles, 'hair', a.hair, (av, v) => av.hair = v)),
          option(L.t('a.hairColor'), colors(hairColors, a.hairColor, (av, c) => av.hairColor = c)),
          option(L.t('a.shirt'), colors(clothColors, a.shirt, (av, c) => av.shirt = c)),
          option(L.t('a.pants'), colors(clothColors, a.pants, (av, c) => av.pants = c)),
          option(L.t('a.accessory'), texts(accessories, 'acc', a.accessory, (av, v) => av.accessory = v)),
        ],
      ),
    );
  }
}

/// Arcoíris pixel para el botón de color libre.
class _RainbowPainter extends CustomPainter {
  const _RainbowPainter();

  static const _colors = [
    Color(0xFFE3655B), Color(0xFFF4B942), Color(0xFF93CF63), Color(0xFF62CFC0), Color(0xFF4F6FD8), Color(0xFFC27CE0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / _colors.length;
    for (var i = 0; i < _colors.length; i++) {
      canvas.drawRect(Rect.fromLTWH(0, i * h, size.width, h + 0.5), Paint()..color = _colors[i]);
    }
  }

  @override
  bool shouldRepaint(_RainbowPainter old) => false;
}
