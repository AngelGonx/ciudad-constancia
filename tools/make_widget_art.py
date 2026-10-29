"""Genera los gráficos pixel del widget de pantalla de inicio.

Uso (desde la raíz del repo):  python tools/make_widget_art.py
- widget_check_off / widget_check_on: casillas pixel.
- widget_preview: imagen que muestra el selector de widgets del teléfono.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

INK = (15, 11, 20)
BG = (36, 28, 46)
PANEL = (63, 49, 80)
FG = (243, 233, 214)
DIM = (179, 165, 192)
GOLD = (244, 185, 66)
GOOD = (147, 207, 99)
CAT = (24, 18, 30)
EYE = (111, 227, 107)
PINK = (232, 138, 160)


def rects(size, items, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", size, bg)
    d = ImageDraw.Draw(im)
    for c, x, y, w, h in items:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c + (255,) if len(c) == 3 else c)
    return im


def checkbox(on):
    items = [(INK, 0, 0, 10, 10), (GOOD if on else BG, 2, 2, 6, 6)]
    if on:
        # Palomita pixel
        items += [(INK, 3, 5, 1, 1), (INK, 4, 6, 1, 1), (INK, 5, 5, 1, 1), (INK, 6, 4, 1, 1)]
    return rects((10, 10), items)


def preview():
    w, h = 64, 48
    items = [(INK, 0, 0, w, h), (BG, 1, 1, w - 2, h - 2)]
    # Gatito
    items += [(CAT, 3, 4, 7, 5), (CAT, 3, 3, 1, 1), (CAT, 9, 3, 1, 1), (EYE, 4, 5, 1, 1), (EYE, 7, 5, 1, 1),
              (PINK, 5, 7, 2, 1)]
    items += [(GOLD, 12, 4, 26, 2), (DIM, 12, 7, 16, 1), (INK, 2, 11, w - 4, 1)]
    for i, y in enumerate((14, 22, 30, 38)):
        items += [(INK, 2, y, w - 4, 7), (PANEL, 3, y + 1, w - 6, 5), (INK, 4, y + 1, 5, 5),
                  (GOOD if i == 0 else BG, 5, y + 2, 3, 3), (FG, 11, y + 3, 26 - i * 3, 1), (GOLD, 52, y + 3, 7, 1)]
    return rects((w, h), items)


def main():
    out = RES / "drawable-nodpi"
    out.mkdir(parents=True, exist_ok=True)
    checkbox(False).resize((60, 60), Image.NEAREST).save(out / "widget_check_off.png")
    checkbox(True).resize((60, 60), Image.NEAREST).save(out / "widget_check_on.png")
    preview().resize((64 * 8, 48 * 8), Image.NEAREST).save(out / "widget_preview.png")


if __name__ == "__main__":
    main()
