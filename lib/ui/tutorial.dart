import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import 'cat_buddy.dart';
import 'pixel.dart';

/// Llaves de las partes de la pantalla que el tutorial señala.
class TutorialKeys {
  final xp = GlobalKey();
  final gold = GlobalKey();
  final gear = GlobalKey();
  final today = GlobalKey();
  final form = GlobalKey();
  final habit = GlobalKey();
  final tabs = List.generate(5, (_) => GlobalKey());
}

class _Step {
  final String text;
  final GlobalKey? target;
  const _Step(this.text, [this.target]);
}

// Colores fijos para que el tutorial se vea igual en tema claro u oscuro.
const _ink = Color(0xFF0F0B14);
const _paper = Color(0xFFF3E9D6);
const _gold = Color(0xFFF4B942);

/// Abre el tutorial guiado por el gatito.
/// Regresa cuando el usuario termina o lo salta.
Future<void> showTutorial(BuildContext context, TutorialKeys keys, {required bool replay}) {
  final steps = <_Step>[
    if (!replay) const _Step('tut.welcome'),
    _Step('tut.xp', keys.xp),
    _Step('tut.gold', keys.gold),
    _Step('tut.today', keys.today),
    _Step('tut.form', keys.form),
    _Step('tut.habit', keys.habit),
    _Step('tut.city', keys.tabs[1]),
    _Step('tut.ach', keys.tabs[2]),
    _Step('tut.progress', keys.tabs[3]),
    _Step('tut.avatar', keys.tabs[4]),
    _Step('tut.gear', keys.gear),
    _Step(replay ? 'tut.endReplay' : 'tut.end'),
  ];
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => _TutorialOverlay(steps: steps, replay: replay),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _TutorialOverlay extends StatefulWidget {
  final List<_Step> steps;
  final bool replay;
  const _TutorialOverlay({required this.steps, required this.replay});

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int _i = 0;
  Rect? _hole;

  _Step get _step => widget.steps[_i];
  bool get _isFirst => _i == 0 && !widget.replay;
  bool get _isLast => _i == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Rect? _rectOf(GlobalKey key) {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  /// Lleva la parte señalada a la vista y mide dónde quedó.
  Future<void> _measure() async {
    final key = _step.target;
    if (key == null) {
      setState(() => _hole = null);
      return;
    }
    final ctx = key.currentContext;
    if (ctx == null) {
      _go(1); // esa parte no existe ahora (por ejemplo, no hay hábitos): se salta
      return;
    }
    await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.25);
    if (!mounted) return;
    setState(() => _hole = _rectOf(key));
  }

  void _go(int delta) {
    final next = _i + delta;
    if (next < 0 || next >= widget.steps.length) return;
    setState(() {
      _i = next;
      _hole = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _skip() {
    setState(() {
      _i = widget.steps.length - 1;
      _hole = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final hole = _hole;
    final centered = _step.target == null;
    // El globo va del lado contrario a lo que se señala.
    final bubbleOnTop = hole != null && hole.center.dy > size.height * 0.5;
    final counter = widget.steps.where((s) => s.target != null).toList();
    final pos = counter.indexOf(_step) + 1;

    final bubble = _Bubble(
      text: L.t(_step.text),
      counter: pos > 0 ? '$pos/${counter.length}' : null,
      actions: [
        if (_isFirst) ...[
          PixelButton(label: L.t('tut.skip'), color: const Color(0xFF3F3150), textColor: _paper, onPressed: _skip),
          PixelButton(label: L.t('tut.yes'), onPressed: () => _go(1)),
        ] else if (_isLast)
          PixelButton(
            label: L.t(widget.replay ? 'tut.ok' : 'tut.start'),
            onPressed: () => Navigator.of(context).pop(),
          )
        else ...[
          PixelButton(label: L.t('tut.skip'), color: const Color(0xFF3F3150), textColor: _paper, onPressed: _skip),
          PixelButton(label: L.t('tut.next'), onPressed: () => _go(1)),
        ],
      ],
    );

    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isFirst || _isLast ? null : () => _go(1),
              child: CustomPaint(painter: _ScrimPainter(hole)),
            ),
          ),
          if (centered)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const PixelCat(width: 120),
                    const SizedBox(height: 12),
                    bubble,
                  ]),
                ),
              ),
            )
          else if (hole != null)
            Positioned(
              left: 16,
              right: 16,
              top: bubbleOnTop ? pad.top + 16 : null,
              bottom: bubbleOnTop ? null : pad.bottom + 16,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const PixelCat(width: 64),
                const SizedBox(width: 8),
                Expanded(child: bubble),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final String? counter;
  final List<Widget> actions;
  const _Bubble({required this.text, required this.counter, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: _ink, width: 3),
        boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: T.body(15, _ink)),
        const SizedBox(height: 12),
        Row(children: [
          if (counter != null) Text(counter!, style: T.display(11, const Color(0xFF6B5A78))),
          const Spacer(),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
        ]),
      ]),
    );
  }
}

/// Oscurece la pantalla dejando un hueco con marco dorado sobre lo que se explica.
class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  _ScrimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = const Color(0xD90B0812);
    final h = hole?.inflate(6);
    if (h == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(h),
    );
    canvas.drawPath(path, scrim);
    canvas.drawRect(
      h,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Flechita pixel apuntando al hueco.
    final above = h.top > 60;
    const s = 4.0;
    final cx = h.center.dx;
    final paint = Paint()..color = _gold;
    for (var row = 0; row < 3; row++) {
      final w = (3 - row) * 2 - 1;
      final y = above ? h.top - 8 - (3 - row) * s : h.bottom + 8 + (2 - row) * s;
      canvas.drawRect(Rect.fromLTWH(cx - w * s / 2, y, w * s, s), paint);
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
