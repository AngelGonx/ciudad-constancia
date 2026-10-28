"""Genera los gráficos pixel de las notificaciones de Pixel To-Do.

Uso (desde la raíz del repo):  python tools/make_notification_art.py
- ic_stat_pixel: ícono pequeño de la barra de estado (silueta blanca del gatito).
- notif_cat: ícono grande a color (el gatito negro de ojos verdes).
- notif_banner: imagen grande de la notificación diaria (ciudad pixel al atardecer).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

INK = (15, 11, 20)
CAT = (24, 18, 30)
CAT_HI = (58, 47, 69)
EYE = (111, 227, 107)
EYE_HI = (220, 255, 210)
NOSE = (232, 138, 160)
GOLD = (244, 185, 66)
PAPER = (243, 233, 214)
GREEN = (147, 207, 99)
LINE = (138, 122, 150)


def canvas(w, h, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(im)

    def r(c, x, y, ww=1, hh=1):
        d.rectangle([x, y, x + ww - 1, y + hh - 1], fill=c + (255,) if len(c) == 3 else c)

    return im, r


def cat_head(r, ox, oy, silhouette=False):
    """Cabeza de gatito de 12 × 10 píxeles."""
    body = (255, 255, 255) if silhouette else CAT
    for x, y in ((0, 1), (1, 0), (1, 1), (2, 1), (11, 1), (10, 0), (10, 1), (9, 1)):
        r(body, ox + x, oy + y)
    r(body, ox, oy + 2, 12, 8)
    if silhouette:
        # Ojos y nariz como huecos para que la silueta se reconozca
        for x, y, w, h in ((2, 4, 2, 2), (8, 4, 2, 2), (5, 7, 2, 1)):
            r((0, 0, 0, 0), ox + x, oy + y, w, h)
        return
    r(NOSE, ox + 1, oy + 1)
    r(NOSE, ox + 10, oy + 1)
    r(CAT_HI, ox + 1, oy + 3, 2, 1)
    r(EYE, ox + 2, oy + 4, 2, 2)
    r(EYE, ox + 8, oy + 4, 2, 2)
    r(EYE_HI, ox + 2, oy + 4)
    r(EYE_HI, ox + 8, oy + 4)
    r(NOSE, ox + 5, oy + 7, 2, 1)


def save(im, size, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.resize(size, Image.NEAREST).save(path)


def status_icon():
    im, r = canvas(12, 12)
    cat_head(r, 0, 1, silhouette=True)
    for name, k in {"mdpi": 2, "hdpi": 3, "xhdpi": 4, "xxhdpi": 6, "xxxhdpi": 8}.items():
        save(im, (12 * k, 12 * k), RES / f"drawable-{name}/ic_stat_pixel.png")


def large_icon():
    im, r = canvas(16, 16, (63, 49, 80, 255))
    cat_head(r, 2, 4)
    r(GOLD, 6, 1, 4, 2)  # estrellita de recompensa
    r(GOLD, 7, 0, 2, 4)
    save(im, (128, 128), RES / "drawable-nodpi/notif_cat.png")


def banner():
    w, h = 64, 32
    im, r = canvas(w, h)
    sky = [(52, 38, 82), (78, 52, 104), (122, 72, 120), (186, 98, 108), (232, 146, 92)]
    for i, c in enumerate(sky):
        r(c, 0, i * 4, w, 4)
    r((255, 214, 120), 46, 10, 6, 6)  # sol poniente
    r((255, 236, 170), 47, 11, 4, 4)
    # Siluetas de edificios con ventanas encendidas
    city = [(0, 14, 7), (7, 10, 6), (13, 16, 8), (21, 8, 7), (28, 13, 6), (34, 6, 6), (40, 12, 9), (49, 9, 7), (56, 15, 8)]
    for x, top, bw in city:
        r((36, 28, 46), x, top + 6, bw, h - top - 6)
        for wy in range(top + 8, 27, 3):
            for wx in range(x + 1, x + bw - 1, 2):
                if (wx * 7 + wy * 3) % 5 != 0:
                    r((255, 226, 138), wx, wy)
    r((63, 106, 53), 0, 27, w, 5)  # pasto
    r((74, 69, 82), 0, 29, w, 3)  # calle
    for x in range(2, w, 8):
        r((232, 210, 122), x, 30, 4, 1)
    # Lista con checklist y el gatito asomándose
    r(INK, 4, 9, 14, 18)
    r(PAPER, 5, 10, 12, 16)
    r(INK, 8, 7, 6, 4)
    r(GOLD, 9, 8, 4, 2)
    for i, y in enumerate((13, 18, 23)):
        r(INK, 6, y - 1, 4, 4)
        r(GREEN if i < 2 else PAPER, 7, y, 2, 2)
        r(LINE, 11, y, 5, 1)
    cat_head(r, 13, 19)
    save(im, (w * 8, h * 8), RES / "drawable-nodpi/notif_banner.png")


def keep_file():
    raw = RES / "raw"
    raw.mkdir(exist_ok=True)
    # Evita que la compilación release borre estos gráficos (se usan por nombre desde Dart).
    (raw / "keep.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools"\n'
        '    tools:keep="@drawable/ic_stat_pixel,@drawable/notif_cat,@drawable/notif_banner" />\n'
    )


if __name__ == "__main__":
    status_icon()
    large_icon()
    banner()
    keep_file()
