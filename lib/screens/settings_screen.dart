import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../i18n/strings.dart';
import '../services/reminders.dart';
import '../services/sounds.dart';
import '../ui/pixel.dart';
import '../ui/time_picker.dart';

/// Pantalla del engranaje: estudio, idioma, tema y datos.
class SettingsScreen extends StatefulWidget {
  final GameState game;
  const SettingsScreen({super.key, required this.game});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmReset = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.game,
      builder: (context, _) {
        final g = widget.game;
        return Scaffold(
          backgroundColor: C.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(children: [
                  PixelButton(
                    label: '< ${L.t('s.back')}',
                    color: C.panel2,
                    textColor: C.fg,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(L.t('s.title'), style: T.display(18))),
                ]),
                const SizedBox(height: 24),
                const _StudioBadge(),
                const SizedBox(height: 14),
                Text(L.t('s.madeBy'), textAlign: TextAlign.center, style: T.display(14)),
                const SizedBox(height: 4),
                Text('Pixel To-Do · ${L.t('s.version')}', textAlign: TextAlign.center, style: T.body(13, C.dim)),
                const SizedBox(height: 28),
                _Section(
                  title: L.t('s.language'),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    PixelChoice(label: 'Español', selected: L.lang == 'es', onTap: () => g.setLanguage('es')),
                    PixelChoice(label: 'English', selected: L.lang == 'en', onTap: () => g.setLanguage('en')),
                  ]),
                ),
                _Section(
                  title: L.t('s.theme'),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    PixelChoice(label: L.t('s.dark'), selected: !g.lightTheme, onTap: () => g.setLightTheme(false)),
                    PixelChoice(label: L.t('s.light'), selected: g.lightTheme, onTap: () => g.setLightTheme(true)),
                  ]),
                ),
                _Section(
                  title: L.t('s.sound'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L.t('s.sfx'), style: T.body(14)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      PixelChoice(label: L.t('s.on'), selected: g.soundOn, onTap: () {
                        g.setSound(true);
                        Sounds.sfxOn = true;
                        Sounds.task();
                      }),
                      PixelChoice(label: L.t('s.off'), selected: !g.soundOn, onTap: () => g.setSound(false)),
                    ]),
                    // La música solo aparece después de descubrir el minijuego secreto.
                    if (g.foundSecret) ...[
                      const SizedBox(height: 12),
                      Text(L.t('s.music'), style: T.body(14)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        PixelChoice(label: L.t('s.on'), selected: g.musicOn, onTap: () => g.setMusic(true)),
                        PixelChoice(label: L.t('s.off'), selected: !g.musicOn, onTap: () => g.setMusic(false)),
                      ]),
                    ],
                  ]),
                ),
                _Section(
                  title: L.t('s.reminders'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L.t('s.remindersText'), style: T.body(14, C.dim)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      PixelChoice(
                        label: L.t('s.on'),
                        selected: g.remindersOn,
                        onTap: () async {
                          final ok = await Reminders.requestPermission();
                          g.setReminders(true);
                          if (!ok && context.mounted) showToast(context, L.t('r.denied'));
                        },
                      ),
                      PixelChoice(label: L.t('s.off'), selected: !g.remindersOn, onTap: () => g.setReminders(false)),
                    ]),
                    if (g.remindersOn) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const PixelBell(size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(L.f('s.dailyAt', {'t': formatMinutes(g.reminderMinutes)}), style: T.body(15)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        PixelButton(
                          label: L.t('s.change'),
                          color: C.panel2,
                          textColor: C.fg,
                          onPressed: () async {
                            final choice = await pickTime(context, g.reminderMinutes);
                            if (choice?.minutes != null) g.setReminderMinutes(choice!.minutes!);
                          },
                        ),
                        PixelButton(label: L.t('s.test'), onPressed: Reminders.showTest),
                      ]),
                      const SizedBox(height: 12),
                      Text(L.t('s.xiaomiTip'), style: T.body(13, C.dim)),
                      FutureBuilder<bool>(
                        future: Reminders.canBeExact(),
                        builder: (context, snap) {
                          if (snap.data != false) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(L.t('s.exactText'), style: T.body(13, C.dim)),
                              const SizedBox(height: 8),
                              PixelButton(
                                label: L.t('s.exact'),
                                color: C.panel2,
                                textColor: C.fg,
                                onPressed: () => Reminders.askExact(g),
                              ),
                            ]),
                          );
                        },
                      ),
                    ],
                  ]),
                ),
                _Section(
                  title: L.t('s.beta'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L.t('s.testMode'), style: T.body(14)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      PixelChoice(label: L.t('s.on'), selected: g.testMode, onTap: () => g.setTestMode(true)),
                      PixelChoice(label: L.t('s.off'), selected: !g.testMode, onTap: () => g.setTestMode(false)),
                    ]),
                  ]),
                ),
                _Section(
                  title: L.t('s.data'),
                  child: _confirmReset
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(L.t('s.resetWarn'), style: T.body(14, C.dim)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            PixelButton(
                              label: L.t('s.resetYes'),
                              color: C.bad,
                              onPressed: () {
                                g.reset();
                                setState(() => _confirmReset = false);
                                showToast(context, L.t('s.resetDone'));
                              },
                            ),
                            PixelButton(
                              label: L.t('cancel'),
                              color: C.panel2,
                              textColor: C.fg,
                              onPressed: () => setState(() => _confirmReset = false),
                            ),
                          ]),
                        ])
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: PixelButton(
                            label: g.isSample ? L.t('s.resetSample') : L.t('s.reset'),
                            color: C.panel2,
                            textColor: C.fg,
                            onPressed: () => setState(() => _confirmReset = true),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PixelBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(title),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

/// Logo de Pancracio Studios en un círculo, pintado con el color del tema.
class _StudioBadge extends StatelessWidget {
  const _StudioBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 168,
        height: 168,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.panel,
          border: Border.all(color: C.ink, width: 3),
          boxShadow: hardShadow(),
        ),
        child: Image.asset(
          'assets/brand/pancracio_logo.png',
          color: C.fg,
          colorBlendMode: BlendMode.srcIn,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Pancracio Studios',
        ),
      ),
    );
  }
}

/// Primer inicio: elegir idioma.
class LanguageScreen extends StatelessWidget {
  final GameState game;
  const LanguageScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/brand/pancracio_logo.png', width: 96, color: C.fg, colorBlendMode: BlendMode.srcIn),
              const SizedBox(height: 20),
              Text('PIXEL TO-DO', style: T.display(26, C.gold)),
              const SizedBox(height: 24),
              Text('Elige tu idioma', style: T.display(14)),
              Text('Choose your language', style: T.body(14, C.dim)),
              const SizedBox(height: 20),
              SizedBox(
                width: 240,
                child: PixelButton(label: 'Español', onPressed: () => game.setLanguage('es')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 240,
                child: PixelButton(label: 'English', onPressed: () => game.setLanguage('en')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
