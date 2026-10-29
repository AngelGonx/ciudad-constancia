import 'package:audioplayers/audioplayers.dart';

/// Sonidos 8-bit de la app (generados con tools/make_sounds.py).
///
/// Los efectos se mezclan con la música que el usuario esté escuchando en otra app
/// (no la pausan). Si falla el audio, la app sigue igual, solo sin sonido.
class Sounds {
  static bool sfxOn = true;
  static bool musicOn = true;

  static const _effects = ['flap', 'coin', 'crash', 'task', 'levelup', 'build'];
  static final Map<String, AudioPool> _pools = {};
  static AudioPlayer? _music;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (final e in _effects) {
        _pools[e] = await AudioPool.createFromAsset(
          path: 'sounds/$e.wav',
          maxPlayers: e == 'flap' ? 4 : 2,
          playerMode: PlayerMode.lowLatency,
        );
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> _play(String name, double volume) async {
    if (!sfxOn || !_ready) return;
    try {
      await _pools[name]?.start(volume: volume);
    } catch (_) {}
  }

  static void flap() => _play('flap', 0.6);
  static void coin() => _play('coin', 0.8);
  static void crash() => _play('crash', 0.8);
  static void task() => _play('task', 0.8);
  static void levelUp() => _play('levelup', 0.9);
  static void build() => _play('build', 0.8);

  /// Música tranquila en loop del minijuego.
  static Future<void> startMusic() async {
    if (!musicOn) return;
    try {
      final p = _music ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(0.45);
      await p.play(AssetSource('sounds/music.ogg'));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
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
    if (!musicOn) return;
    try {
      await _music?.resume();
    } catch (_) {}
  }
}
