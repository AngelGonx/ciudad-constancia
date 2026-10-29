import 'package:audioplayers/audioplayers.dart';

/// Sonidos 8-bit de la app (generados con tools/make_sounds.py).
///
/// Cada efecto tiene un número fijo de reproductores precargados que se reutilizan
/// en rotación: nunca se crean reproductores nuevos al jugar, así no se acumulan.
/// Los sonidos se mezclan con la música de otras apps (no la pausan).
class Sounds {
  static bool sfxOn = true;
  static bool musicOn = true;

  static const Map<String, double> _volumes = {
    'flap': 0.6,
    'coin': 0.8,
    'crash': 0.8,
    'task': 0.8,
    'levelup': 0.9,
    'build': 0.8,
  };
  static final Map<String, List<AudioPlayer>> _players = {};
  static final Map<String, int> _next = {};
  static final Map<String, int> _lastPlay = {};
  static bool _ready = false;

  static AudioPlayer? _music;
  static bool _musicWanted = false;

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (final e in _volumes.entries) {
        final count = e.key == 'flap' ? 3 : 2;
        final list = <AudioPlayer>[];
        for (var i = 0; i < count; i++) {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setVolume(e.value);
          await p.setSource(AssetSource('sounds/${e.key}.wav'));
          list.add(p);
        }
        _players[e.key] = list;
        _next[e.key] = 0;
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static void _play(String name) {
    if (!sfxOn || !_ready) return;
    final list = _players[name];
    if (list == null || list.isEmpty) return;
    // Evita amontonar el mismo sonido si se toca muy rápido.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlay[name] ?? 0) < 60) return;
    _lastPlay[name] = now;
    final i = _next[name]!;
    _next[name] = (i + 1) % list.length;
    final p = list[i];
    () async {
      try {
        await p.stop();
        await p.resume();
      } catch (_) {}
    }();
  }

  static void flap() => _play('flap');
  static void coin() => _play('coin');
  static void crash() => _play('crash');
  static void task() => _play('task');
  static void levelUp() => _play('levelup');
  static void build() => _play('build');

  /// Música tranquila en loop del minijuego.
  static Future<void> startMusic() async {
    if (!musicOn) return;
    _musicWanted = true;
    try {
      final p = _music ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(0.45);
      await p.play(AssetSource('sounds/music.ogg'));
      // Si salieron del juego mientras cargaba, se detiene en cuanto empieza.
      if (!_musicWanted) await p.stop();
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    _musicWanted = false;
    try {
      await _music?.stop();
    } catch (_) {}
  }

  static Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  static Future<void> resumeMusic() async {
    if (!musicOn || !_musicWanted) return;
    try {
      await _music?.resume();
    } catch (_) {}
  }
}
