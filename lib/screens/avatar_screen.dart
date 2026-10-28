import 'package:flutter/material.dart';

import '../game/game_state.dart';
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

    Widget swatches(List<Color> colors, int selected, void Function(Avatar, int) apply) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: 'Color ${i + 1}',
            child: GestureDetector(
              onTap: () => g.updateAvatar((av) => apply(av, i)),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors[i],
                  border: Border.all(color: i == selected ? C.gold : C.ink, width: i == selected ? 4 : 3),
                ),
              ),
            ),
          ),
      ]);
    }

    Widget texts(List<List<String>> options, String selected, void Function(Avatar, String) apply) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          PixelChoice(label: o[1], selected: o[0] == selected, onTap: () => g.updateAvatar((av) => apply(av, o[0]))),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        PixelBox(
          color: C.panel2,
          padding: const EdgeInsets.all(16),
          child: Center(child: AvatarView(avatar: a, size: 192)),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Nombre del alcalde'),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          maxLength: 20,
          style: T.body(16),
          onChanged: g.setName,
          decoration: const InputDecoration(
            counterText: '',
            filled: true,
            fillColor: C.bg,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.ink, width: 3)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.ink, width: 3)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.xp, width: 3)),
          ),
        ),
        option('Piel', swatches(skinColors, a.skin, (av, i) => av.skin = i)),
        option('Peinado', texts(hairStyles, a.hair, (av, v) => av.hair = v)),
        option('Color de cabello', swatches(hairColors, a.hairColor, (av, i) => av.hairColor = i)),
        option('Playera', swatches(clothColors, a.shirt, (av, i) => av.shirt = i)),
        option('Pantalón', swatches(clothColors, a.pants, (av, i) => av.pants = i)),
        option('Accesorio', texts(accessories, a.accessory, (av, v) => av.accessory = v)),
      ],
    );
  }
}
