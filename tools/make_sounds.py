"""Genera los sonidos 8-bit de Pixel To-Do (efectos y música en loop).

Uso (desde la raíz del repo):  python tools/make_sounds.py
Requiere numpy y ffmpeg (para la música en .ogg). Todo es síntesis propia, sin muestras externas.
"""
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sounds"
SR = 22050


def note(name):
    """'C5' -> frecuencia en Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((n + (octave - 4) * 12) / 12)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def square(freq, dur, duty=0.5):
    ph = np.cumsum(np.broadcast_to(freq, int(dur * SR)) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(freq, dur):
    ph = np.cumsum(np.broadcast_to(freq, int(dur * SR)) / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def env(n, attack=0.005, release=0.05, decay=None):
    """Envolvente sin clics: subida corta, caída exponencial opcional y salida suave."""
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e *= np.exp(-np.arange(n) / (decay * SR))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def soften(x, k=3):
    """Pasa-bajas sencillo para que lo cuadrado no suene áspero."""
    return np.convolve(x, np.ones(k) / k, mode="same")


def seq(parts):
    return np.concatenate(parts)


def save_wav(name, x, vol):
    x = np.clip(x / (np.max(np.abs(x)) + 1e-9) * vol, -1, 1)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def tone(freq, dur, kind="square", duty=0.5, decay=None, release=0.03):
    wave_ = square(freq, dur, duty) if kind == "square" else triangle(freq, dur)
    return wave_ * env(len(wave_), release=release, decay=decay)


# ---------------- Efectos ----------------

def sfx_flap():
    d = 0.09
    f = np.linspace(480, 760, int(d * SR))
    return soften(square(f, d, 0.25) * env(int(d * SR), decay=0.04, release=0.02), 4)


def sfx_coin():
    return soften(seq([tone(note("B5"), 0.06), tone(note("E6"), 0.22, decay=0.08)]), 3)


def sfx_crash():
    d = 0.55
    n = int(d * SR)
    sweep = triangle(np.linspace(420, 70, n), d)
    rng = np.random.default_rng(7)
    noise = np.repeat(rng.uniform(-1, 1, n // 8 + 1), 8)[:n]  # ruido "de 8 bits"
    return soften((sweep * 0.8 + noise * 0.35) * env(n, decay=0.18, release=0.08), 5)


def sfx_task():
    notes = ["C5", "E5", "G5"]
    parts = [tone(note(x), 0.06, duty=0.25) * 0.8 + tone(note(x), 0.06, "tri") * 0.4 for x in notes]
    parts.append(tone(note("C6"), 0.22, duty=0.25, decay=0.09) * 0.8 + tone(note("C6"), 0.22, "tri", decay=0.09) * 0.4)
    return soften(seq(parts), 3)


def sfx_levelup():
    melody = [("G4", 0.09), ("C5", 0.09), ("E5", 0.09), ("G5", 0.09), ("E5", 0.07), ("G5", 0.07)]
    parts = [tone(note(n), d, duty=0.25) for n, d in melody]
    d = 0.6
    vib = note("C6") * (1 + 0.006 * np.sin(2 * np.pi * 6 * t(d)))
    final = square(vib, d, 0.25) * env(int(d * SR), decay=0.3, release=0.12)
    harmony = triangle(note("E5"), d) * env(int(d * SR), decay=0.3, release=0.12) * 0.6
    parts.append(final + harmony)
    return soften(seq(parts), 3)


def sfx_build():
    thunk = triangle(np.linspace(180, 90, int(0.08 * SR)), 0.08) * env(int(0.08 * SR), decay=0.04)
    gap = np.zeros(int(0.03 * SR))
    return soften(seq([thunk, gap, thunk * 0.8, gap, tone(note("A5"), 0.18, duty=0.25, decay=0.07)]), 3)


# ---------------- Música ----------------

def music():
    """Loop tranquilo a 80 BPM: C – Am – F – G, melodía pentatónica suave."""
    bpm = 80
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR)

    def put(x, start_beat, gain):
        s = int(start_beat * beat * SR)
        mix[s:s + len(x)] += x * gain

    chords = [["C3", "E3", "G3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"]]
    melody = [
        # (beat dentro de 4 compases, nota, duración en beats)
        [(0, "E5", 1), (1, "G5", 1), (2, "A5", 1.5), (3.5, "G5", .5), (4, "E5", 2), (6, "D5", 2),
         (8, "C5", 1), (9, "D5", 1), (10, "E5", 2), (12, "D5", 1.5), (13.5, "C5", .5), (14, "D5", 2)],
        [(0, "G5", 1.5), (1.5, "A5", .5), (2, "G5", 1), (3, "E5", 1), (4, "C5", 2), (6, "E5", 2),
         (8, "F5", 1), (9, "E5", 1), (10, "C5", 2), (12, "D5", 3), (15, "G4", 1)],
        [(0, "C6", 1), (1, "A5", 1), (2, "G5", 2), (4, "A5", 1), (5, "G5", 1), (6, "E5", 2),
         (8, "F5", 1.5), (9.5, "G5", .5), (10, "A5", 2), (12, "G5", 2), (14, "E5", 1), (15, "D5", 1)],
        [(0, "E5", 2), (2, "D5", 1), (3, "C5", 1), (4, "A4", 2), (6, "C5", 2),
         (8, "D5", 1), (9, "E5", 1), (10, "G5", 2), (12, "E5", 1), (13, "D5", 1), (14, "C5", 2)],
    ]
    for bar in range(bars):
        root = chords[bar % 4]
        b0 = bar * 4
        # Bajo: triangular en tiempos 1 y 3
        for k in (0, 2):
            put(tone(note(root[0]), beat * 1.8, "tri", release=0.12), b0 + k, 0.30)
        # Arpegio suave en octavos
        for k in range(8):
            n = root[[0, 1, 2, 1][k % 4]].replace("2", "4").replace("3", "4")
            put(tone(note(n), beat * 0.45, duty=0.125, decay=0.12, release=0.04), b0 + k * 0.5, 0.07)
    for phrase in range(4):
        for st, n, dur in melody[phrase]:
            put(tone(note(n), beat * dur * 0.95, "tri", release=0.08) * 0.9
                + tone(note(n), beat * dur * 0.95, duty=0.25, decay=0.35, release=0.08) * 0.15,
                phrase * 16 + st, 0.32)
    # Lo que sobresale del final se suma al inicio, así el loop no tiene corte.
    tail = mix[total:]
    mix = mix[:total]
    mix[:len(tail)] += tail
    return soften(mix, 3)


def main():
    save_wav("flap", sfx_flap(), 0.35)
    save_wav("coin", sfx_coin(), 0.40)
    save_wav("crash", sfx_crash(), 0.45)
    save_wav("task", sfx_task(), 0.40)
    save_wav("levelup", sfx_levelup(), 0.45)
    save_wav("build", sfx_build(), 0.40)
    save_wav("_music", music(), 0.55)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(OUT / "_music.wav"),
         "-c:a", "libvorbis", "-q:a", "2", str(OUT / "music.ogg")],
        check=True,
    )
    (OUT / "_music.wav").unlink()


if __name__ == "__main__":
    main()
