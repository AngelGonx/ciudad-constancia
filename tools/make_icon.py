"""Genera el ícono de Pixel To-Do: lista con checklist y gatito negro de ojos verdes asomándose.

Uso (desde la raíz del repo):  python tools/make_icon.py
Escribe los íconos de Android en android/app/src/main/res y el de la tienda en store/.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

BG = (63, 49, 80)          # fondo morado de la app
INK = (15, 11, 20)
PAPER = (243, 233, 214)
SHADE = (214, 197, 169)
GOLD = (244, 185, 66)
GOLD_DARK = (176, 122, 28)
GREEN = (147, 207, 99)
LINE = (138, 122, 150)
CAT = (24, 18, 30)
CAT_HI = (58, 47, 69)
EYE = (111, 227, 107)
EYE_HI = (220, 255, 210)
NOSE = (232, 138, 160)


def art() -> Image.Image:
    """Dibujo de 24 × 24 píxeles con fondo transparente."""
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def r(c, x, y, w=1, h=1):
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c + (255,))

    # Hoja
    r(INK, 2, 3, 15, 19)
    r(PAPER, 3, 4, 13, 17)
    r(SHADE, 3, 20, 13, 1)
    r(SHADE, 15, 4, 1, 17)
    # Clip
    r(INK, 6, 1, 7, 5)
    r(GOLD, 7, 2, 5, 3)
    r(GOLD_DARK, 7, 4, 5, 1)
    r(INK, 9, 2, 1, 1)
    # Renglones del checklist: dos hechos y uno pendiente
    for i, y in enumerate((6, 11, 16)):
        r(INK, 4, y, 4, 4)
        r(GREEN if i < 2 else PAPER, 5, y + 1, 2, 2)
        r(LINE, 9, y + 1, 5, 1)
        r(LINE, 9, y + 2, 3, 1)
    # Gatito negro asomándose abajo a la derecha
    for x, y in ((13, 15), (14, 14), (14, 15), (15, 15), (22, 15), (21, 14), (21, 15), (20, 15)):
        r(CAT, x, y)              # orejas
    r(NOSE, 14, 15)
    r(NOSE, 21, 15)
    r(CAT, 13, 16, 10, 8)         # cabeza
    r(CAT_HI, 14, 17, 2, 1)
    r(EYE, 15, 19, 2, 2)          # ojos verdes
    r(EYE, 19, 19, 2, 2)
    r(EYE_HI, 15, 19)
    r(EYE_HI, 19, 19)
    r(NOSE, 17, 21, 2, 1)
    r(CAT, 10, 20, 3, 2)          # patita sobre la orilla de la hoja
    r(CAT_HI, 10, 20)
    r(CAT_HI, 12, 20)
    return im


def compose(grid: int, offset: int, background: bool) -> Image.Image:
    canvas = Image.new("RGBA", (grid, grid), BG + (255,) if background else (0, 0, 0, 0))
    canvas.alpha_composite(art(), (offset, offset))
    return canvas


def save(img: Image.Image, size: int, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.NEAREST).save(path)


def main():
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    # Ícono adaptable (Android 8+): capa frontal de 108 dp; el dibujo ocupa la zona segura central.
    front = compose(36, 6, background=False)
    legacy = compose(28, 2, background=True)
    for name, k in densities.items():
        save(front, int(108 * k), RES / f"mipmap-{name}/ic_launcher_foreground.png")
        save(legacy, int(48 * k), RES / f"mipmap-{name}/ic_launcher.png")
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    (RES / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#3F3150</color>\n</resources>\n'
    )
    # Ícono para la Play Store (512 × 512)
    save(compose(32, 4, background=True), 512, ROOT / "store/icon-512.png")


if __name__ == "__main__":
    main()
