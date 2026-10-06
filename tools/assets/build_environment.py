#!/usr/bin/env python3
"""Нарезает окружение (тайлы, пропсы, интерьер, иконки) из LPC Revised (ElizaWy/LPC)
и дорисовывает недостающее процедурно (колодец, прилавки, крысы, забор, кресты...).

Запуск: python3 tools/assets/build_environment.py
Исходники кэшируются в tools/assets/.cache/eliza/.
Также генерирует сцены пропсов scenes/props/*.tscn (StaticBody2D + Sprite2D + коллизия).
"""
from __future__ import annotations

import math
import random
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / ".cache" / "eliza"
RAW = "https://raw.githubusercontent.com/ElizaWy/LPC/main/"
PROPS_DIR = ROOT / "assets" / "sprites" / "props"
INTERIOR_DIR = ROOT / "assets" / "sprites" / "interior"
TILES_DIR = ROOT / "assets" / "tiles"
ICONS_DIR = ROOT / "assets" / "ui" / "icons"
FX_DIR = ROOT / "assets" / "sprites" / "fx"
ENEMY_DIR = ROOT / "assets" / "sprites" / "enemies"
SCENES_DIR = ROOT / "scenes" / "props"

rng = random.Random(1337)
USED: set[str] = set()  # какие исходники LPC Revised пошли в игру (для CREDITS.md)


def src(rel: str) -> Image.Image:
    USED.add(rel)
    p = CACHE / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + urllib.request.quote(rel), timeout=60) as r:
            p.write_bytes(r.read())
    return Image.open(p).convert("RGBA")


def trim(img: Image.Image) -> Image.Image:
    box = img.getbbox()
    return img.crop(box) if box else img


def crop(rel: str, x: int, y: int, w: int, h: int, do_trim: bool = True) -> Image.Image:
    img = src(rel).crop((x, y, x + w, y + h))
    return trim(img) if do_trim else img


def grade(img: Image.Image, sat: float = 1.0, bright: float = 1.0, tint: tuple[int, int, int] | None = None,
          tint_amount: float = 0.0) -> Image.Image:
    a = img.getchannel("A")
    rgb = img.convert("RGB")
    if sat != 1.0:
        rgb = ImageEnhance.Color(rgb).enhance(sat)
    if bright != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    if tint and tint_amount > 0:
        overlay = Image.new("RGB", rgb.size, tint)
        rgb = Image.blend(rgb, overlay, tint_amount)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def save(img: Image.Image, path: Path) -> Image.Image:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    return img


def outline_rect(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: tuple, edge: tuple) -> None:
    d.rectangle(box, fill=fill, outline=edge)


# ---------------------------------------------------------------- процедурные спрайты

WOOD_D = (58, 36, 26, 255)
WOOD_M = (110, 70, 44, 255)
WOOD_L = (146, 98, 62, 255)
OUTLINE = (34, 24, 22, 255)


def draw_post(d: ImageDraw.ImageDraw, x: int, top: int, bottom: int, w: int = 6) -> None:
    d.rectangle((x, top, x + w - 1, bottom), fill=WOOD_M, outline=OUTLINE)
    d.line((x + 1, top + 1, x + 1, bottom - 1), fill=WOOD_L)
    d.line((x + w - 2, top + 2, x + w - 2, bottom - 1), fill=WOOD_D)
    d.rectangle((x, top, x + w - 1, top + 2), fill=WOOD_L, outline=OUTLINE)


def fence_h() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    for ry in (13, 21):
        d.rectangle((0, ry, 31, ry + 3), fill=WOOD_M, outline=OUTLINE)
        d.line((1, ry + 1, 30, ry + 1), fill=WOOD_L)
    draw_post(d, 13, 6, 30)
    return img


def fence_v() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    d.rectangle((14, 0, 17, 31), fill=WOOD_M, outline=OUTLINE)
    d.line((15, 0, 15, 31), fill=WOOD_L)
    draw_post(d, 13, 10, 30)
    return img


def grave_cross() -> Image.Image:
    img = Image.new("RGBA", (20, 30))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 24, 17, 29), fill=(40, 34, 30, 140))
    d.rectangle((8, 2, 11, 27), fill=WOOD_M, outline=OUTLINE)
    d.rectangle((3, 8, 16, 11), fill=WOOD_M, outline=OUTLINE)
    d.line((9, 3, 9, 26), fill=WOOD_L)
    d.line((4, 9, 15, 9), fill=WOOD_L)
    # серая тряпица — знак немощи
    d.polygon([(11, 11), (15, 12), (14, 18), (12, 16)], fill=(150, 150, 152, 255), outline=(70, 70, 74, 255))
    return img


def stone_texture(w: int, h: int) -> Image.Image:
    walls = src("Structure/Walls/Jagged Stone Walls.png")
    tex = walls.crop((96, 0, 192, 96)).crop((0, 16, 96, 80))  # серо-лиловый камень
    out = Image.new("RGBA", (w, h))
    for yy in range(0, h, tex.height):
        for xx in range(0, w, tex.width):
            out.alpha_composite(tex, (xx, yy))
    return grade(out, sat=0.55, bright=0.85)


def well() -> Image.Image:
    W, H = 64, 84
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    # тень
    d.ellipse((4, 70, 60, 83), fill=(20, 16, 18, 110))
    # каменный цилиндр
    body = Image.new("RGBA", (W, H))
    bd = ImageDraw.Draw(body)
    bd.rectangle((6, 50, 57, 74), fill=(255, 255, 255, 255))
    bd.ellipse((6, 66, 57, 82), fill=(255, 255, 255, 255))
    stone = stone_texture(W, H)
    mask = body.getchannel("A")
    cyl = Image.new("RGBA", (W, H))
    cyl.paste(stone, (0, 0), mask)
    # затемнение по краям цилиндра
    shade = Image.new("RGBA", (W, H))
    sd = ImageDraw.Draw(shade)
    for i in range(10):
        a = int(110 * (1 - i / 10))
        sd.line((6 + i, 50, 6 + i, 82), fill=(10, 8, 12, a))
        sd.line((57 - i, 50, 57 - i, 82), fill=(10, 8, 12, a))
    cyl.alpha_composite(Image.composite(shade, Image.new("RGBA", (W, H)), mask))
    img.alpha_composite(cyl)
    d = ImageDraw.Draw(img)
    d.arc((6, 66, 57, 82), 0, 180, fill=OUTLINE)
    d.line((6, 50, 6, 74), fill=OUTLINE)
    d.line((57, 50, 57, 74), fill=OUTLINE)
    # верхний край и вода
    d.ellipse((6, 42, 57, 58), fill=(126, 118, 128, 255), outline=OUTLINE)
    d.ellipse((12, 45, 51, 55), fill=(20, 26, 34, 255), outline=(60, 56, 66, 255))
    d.ellipse((18, 47, 34, 51), fill=(44, 58, 70, 255))
    # стойки и ворот
    draw_post(d, 6, 12, 50, 5)
    draw_post(d, 53, 12, 50, 5)
    d.rectangle((8, 20, 56, 23), fill=WOOD_M, outline=OUTLINE)
    d.line((9, 21, 55, 21), fill=WOOD_L)
    d.line((32, 23, 32, 40), fill=(170, 150, 110, 255))
    # ведро на верёвке
    d.polygon([(27, 38), (37, 38), (36, 46), (28, 46)], fill=(96, 62, 40, 255), outline=OUTLINE)
    d.line((28, 41, 36, 41), fill=(60, 60, 64, 255))
    # крыша из драни
    roof = [(2, 16), (32, 2), (62, 16), (58, 19), (32, 7), (6, 19)]
    d.polygon(roof, fill=(66, 58, 64, 255), outline=OUTLINE)
    for i in range(6, 58, 6):
        d.line((i, 17 - int((32 - abs(32 - i)) * 14 / 30), i + 2, 18 - int((32 - abs(32 - i)) * 14 / 30)), fill=(92, 84, 92, 255))
    return img


def awning(width: int, colors: tuple[tuple, tuple]) -> Image.Image:
    img = Image.new("RGBA", (width, 22))
    d = ImageDraw.Draw(img)
    stripe = 8
    for i, x in enumerate(range(0, width, stripe)):
        c = colors[i % 2]
        d.rectangle((x, 2, x + stripe - 1, 15), fill=c)
        # фестоны
        d.pieslice((x, 10, x + stripe - 1, 21), 0, 180, fill=c)
    d.rectangle((0, 0, width - 1, 3), fill=WOOD_M, outline=OUTLINE)
    d.line((0, 15, width - 1, 15), fill=(0, 0, 0, 60))
    return img


def stall(kind: str) -> Image.Image:
    W, H = 96, 96
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 84, 90, 95), fill=(20, 16, 18, 100))
    draw_post(d, 8, 16, 90, 5)
    draw_post(d, 83, 16, 90, 5)
    table = crop("Objects/Furniture/Table, Rough Wood.png", 0, 16, 96, 48)
    img.alpha_composite(table, ((W - table.width) // 2, H - table.height - 6))
    if kind == "bread":
        sheet = "Objects/Small Items/Food/Bread A.png"
        goods = [crop(sheet, 32, 0, 32, 32), crop(sheet, 64, 0, 32, 32), crop(sheet, 96, 0, 32, 32),
                 crop(sheet, 0, 32, 32, 32)]
        aw = awning(W - 4, ((150, 128, 70, 255), (86, 80, 70, 255)))
    else:
        rolls = "Objects/Small Items/Fabric/Fabric Rolls.png"
        goods = [crop("Objects/Small Items/Baskets A.png", 0, 0, 32, 32), crop(rolls, 0, 0, 32, 48),
                 crop(rolls, 96, 0, 32, 48), crop("Objects/Small Items/Buckets.png", 0, 0, 32, 32)]
        aw = awning(W - 4, ((112, 52, 46, 255), (80, 74, 70, 255)))
    x = 14
    for g in goods:
        img.alpha_composite(g, (x, H - 40 - g.height + 10))
        x += g.width + 2
        if x > W - 24:
            break
    img.alpha_composite(aw, (2, 8))
    return img


def pyre() -> Image.Image:
    W, H = 96, 56
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    # пепельный курган
    for i in range(400):
        x = rng.gauss(48, 18)
        y = rng.gauss(40, 6)
        r = rng.randint(2, 5)
        g = rng.randint(70, 130)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(g, g - 4, g - 2, 255))
    logs = grade(crop("Objects/Small Items/Lumber.png", 0, 64, 128, 32), sat=0.2, bright=0.35)
    img.alpha_composite(logs, ((W - logs.width) // 2, 14))
    logs2 = grade(crop("Objects/Small Items/Lumber.png", 128, 64, 128, 32), sat=0.2, bright=0.3)
    img.alpha_composite(logs2, ((W - logs2.width) // 2 + 6, 22))
    # тлеющие угли
    for i in range(30):
        x = rng.randint(28, 68)
        y = rng.randint(24, 44)
        d.point((x, y), fill=(220, rng.randint(60, 120), 30, 255))
    return trim(img)


def herb() -> Image.Image:
    base = crop("Terrain/plants_autumn.png", 352, 0, 32, 64)
    g = grade(base, sat=0.1, bright=1.35, tint=(170, 190, 210), tint_amount=0.35)
    return g


def coin() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    for i, (x, y) in enumerate(((8, 14), (14, 10), (12, 18))):
        d.ellipse((x, y, x + 12, y + 8), fill=(168, 128, 52, 255), outline=(74, 50, 20, 255))
        d.ellipse((x + 3, y + 2, x + 8, y + 5), fill=(214, 178, 90, 255))
    return img


def medicine() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    d.rectangle((13, 4, 18, 9), fill=(120, 84, 52, 255), outline=OUTLINE)
    d.polygon([(12, 10), (19, 10), (24, 18), (24, 27), (7, 27), (7, 18)], fill=(80, 110, 96, 230), outline=OUTLINE)
    d.rectangle((9, 19, 22, 26), fill=(110, 150, 120, 255))
    d.line((10, 13, 9, 20), fill=(200, 230, 210, 255))
    return img


def stick_icon() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    d.line((6, 27, 26, 5), fill=OUTLINE, width=5)
    d.line((6, 27, 26, 5), fill=WOOD_M, width=3)
    d.line((7, 25, 25, 6), fill=WOOD_L, width=1)
    return img


def rat_sheet(grey: bool) -> Image.Image:
    """Крыса: 4 направления (вверх, влево, вниз, вправо) x 4 кадра; кадр 32x32."""
    F = 32
    out = Image.new("RGBA", (F * 4, F * 4))
    if grey:
        body, dark, light, eye = (132, 134, 140, 255), (78, 80, 88, 255), (176, 178, 184, 255), (200, 230, 240, 255)
    else:
        body, dark, light, eye = (104, 84, 70, 255), (62, 48, 42, 255), (140, 118, 98, 255), (20, 10, 10, 255)
    pink = (196, 140, 140, 255)
    for frame in range(4):
        step = [0, 1, 0, -1][frame]
        # вправо (side view)
        side = Image.new("RGBA", (F, F))
        d = ImageDraw.Draw(side)
        d.ellipse((6, 24, 26, 30), fill=(10, 8, 10, 90))
        # хвост
        pts = [(9, 21), (5, 20 - step), (2, 22), (1, 25 + step)]
        d.line(pts, fill=pink, width=2)
        # лапы
        for lx, ph in ((11, step), (20, -step)):
            d.line((lx, 23, lx + ph, 27), fill=dark, width=2)
        d.ellipse((7, 14, 23, 26), fill=body, outline=OUTLINE)
        d.ellipse((10, 15, 19, 19), fill=light)
        d.ellipse((18, 15, 28, 24), fill=body, outline=OUTLINE)  # голова
        d.polygon([(26, 19), (30, 21), (26, 23)], fill=pink)
        d.ellipse((18, 12, 22, 16), fill=pink, outline=OUTLINE)  # ухо
        d.point((24, 18), fill=eye)
        d.point((25, 18), fill=eye)
        left = side.transpose(Image.FLIP_LEFT_RIGHT)
        # вниз (к зрителю)
        down = Image.new("RGBA", (F, F))
        d = ImageDraw.Draw(down)
        d.ellipse((9, 25, 23, 30), fill=(10, 8, 10, 90))
        d.line((16, 10, 16 + step, 5), fill=pink, width=2)
        for lx, ph in ((11, step), (20, -step)):
            d.line((lx, 22, lx, 26 + ph), fill=dark, width=2)
        d.ellipse((9, 8, 23, 24), fill=body, outline=OUTLINE)
        d.ellipse((10, 16, 22, 28), fill=body, outline=OUTLINE)
        d.ellipse((8, 14, 12, 18), fill=pink, outline=OUTLINE)
        d.ellipse((20, 14, 24, 18), fill=pink, outline=OUTLINE)
        d.point((13, 21), fill=eye)
        d.point((19, 21), fill=eye)
        d.ellipse((15, 25, 17, 27), fill=pink)
        # вверх (от зрителя)
        up = Image.new("RGBA", (F, F))
        d = ImageDraw.Draw(up)
        d.ellipse((9, 25, 23, 30), fill=(10, 8, 10, 90))
        for lx, ph in ((11, step), (20, -step)):
            d.line((lx, 14, lx, 10 + ph), fill=dark, width=2)
        d.ellipse((10, 4, 22, 16), fill=body, outline=OUTLINE)
        d.ellipse((8, 4, 12, 8), fill=pink, outline=OUTLINE)
        d.ellipse((20, 4, 24, 8), fill=pink, outline=OUTLINE)
        d.ellipse((9, 10, 23, 26), fill=body, outline=OUTLINE)
        d.ellipse((12, 13, 20, 20), fill=light)
        d.line([(16, 25), (16 + step, 28), (18 - step, 31)], fill=pink, width=2)
        for row, im in enumerate((up, left, down, side)):
            out.alpha_composite(im, (frame * F, row * F))
    return out


def heart(full: bool) -> Image.Image:
    rows = [
        "..XX...XX..",
        ".XRRX.XRRX.",
        "XRHRRXRRRRX",
        "XRHRRRRRRRX",
        "XRRRRRRRRRX",
        ".XRRRRRRRX.",
        "..XRRRRRX..",
        "...XRRRX...",
        "....XRX....",
        ".....X.....",
    ]
    if full:
        pal = {"X": (30, 10, 12, 255), "R": (150, 28, 30, 255), "H": (220, 110, 100, 255)}
    else:
        pal = {"X": (30, 22, 24, 255), "R": (58, 46, 48, 255), "H": (80, 66, 68, 255)}
    img = Image.new("RGBA", (11, 10))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                img.putpixel((x, y), pal[ch])
    return img


def shadow() -> Image.Image:
    img = Image.new("RGBA", (26, 10))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 25, 9), fill=(12, 8, 12, 90))
    d.ellipse((4, 2, 21, 7), fill=(12, 8, 12, 60))
    return img


def rain_drop() -> Image.Image:
    img = Image.new("RGBA", (2, 14))
    for y in range(14):
        a = int(40 + 160 * y / 13)
        img.putpixel((0, y), (190, 205, 225, a))
        img.putpixel((1, y), (160, 175, 200, a // 2))
    return img


def campfire_strip() -> Image.Image:
    sheet = src("Objects/Small Items/Fire, Camp.png")
    return sheet.crop((0, 32, 128, 64))


def ash_flake() -> Image.Image:
    img = Image.new("RGBA", (4, 4))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 1, 2, 2), fill=(200, 196, 192, 255))
    d.point((0, 1), fill=(170, 166, 164, 160))
    d.point((3, 2), fill=(170, 166, 164, 160))
    return img


def soft_light(size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c + 0.5, y - c + 0.5) / c
            a = max(0.0, 1 - r) ** 1.8
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def smoke_puff() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    px = img.load()
    for y in range(32):
        for x in range(32):
            r = math.hypot(x - 15.5, y - 15.5) / 16
            a = max(0.0, 1 - r) ** 1.5
            px[x, y] = (220, 220, 220, int(200 * a))
    return img


def slash_arc() -> Image.Image:
    """Дуга удара палкой (смотрит вправо), 3 кадра по 48x48."""
    F = 48
    out = Image.new("RGBA", (F * 3, F))
    for i in range(3):
        fr = Image.new("RGBA", (F, F))
        d = ImageDraw.Draw(fr)
        start = -70 + i * 45
        d.arc((4, 4, 44, 44), start, start + 80, fill=(235, 230, 220, 230 - i * 60), width=4)
        d.arc((8, 8, 40, 40), start + 10, start + 70, fill=(255, 255, 255, 160 - i * 50), width=2)
        out.alpha_composite(fr, (i * F, 0))
    return out


# ---------------------------------------------------------------- таблица пропсов
# name: (картинка, коллизия (w, h) или None, смещение коллизии по y от основания)

def build_props() -> dict[str, tuple[Image.Image, tuple[int, int] | None]]:
    T = "Terrain/trees_autumn.png"
    R = "Terrain/Rocks, Grasslands.png"
    P = "Terrain/plants_autumn.png"
    props: dict[str, tuple[Image.Image, tuple[int, int] | None]] = {}
    trees = {
        "tree_orange_a": (128, 0, 96, 128), "tree_orange_b": (224, 0, 96, 128),
        "tree_orange_tall": (320, 0, 96, 144), "tree_red_a": (128, 144, 96, 112),
        "tree_red_b": (224, 144, 96, 112), "tree_red_tall": (416, 112, 96, 128),
        "tree_yellow_a": (128, 272, 96, 128), "tree_yellow_b": (224, 272, 96, 128),
        "tree_bare": (0, 272, 96, 128), "pine_a": (128, 384, 96, 112), "pine_b": (224, 384, 96, 128),
        "pine_small": (320, 416, 96, 96), "pine_tall": (416, 352, 96, 160),
    }
    for name, (x, y, w, h) in trees.items():
        img = crop(T, x, y, w, h)
        # приглушаем «открыточную» осень
        img = grade(img, sat=0.62, bright=0.9)
        props[name] = (img, (18, 10))
    props["stump"] = (grade(crop(T, 16, 432, 64, 40), sat=0.7), (22, 10))
    props["dead_pole"] = (grade(crop(T, 32, 480, 32, 80), sat=0.7), (10, 8))
    # камни (серо-голубой набор)
    props["rock_big"] = (crop(R, 0, 256, 64, 72), (48, 22))
    props["rock_flat"] = (crop(R, 0, 330, 64, 54), (52, 18))
    props["rock_mid"] = (crop(R, 64, 256, 64, 64), (40, 16))
    props["rock_small"] = (crop(R, 128, 320, 32, 32), (18, 8))
    props["pebble"] = (crop(R, 160, 352, 32, 32), None)
    # растения (декор без коллизий)
    props["bush_dry"] = (grade(crop(P, 0, 0, 32, 32), sat=0.6), None)
    props["bush_rust"] = (grade(crop(P, 0, 32, 32, 32), sat=0.6), None)
    props["grass_tall_a"] = (grade(crop(P, 352, 0, 32, 64), sat=0.55), None)
    props["grass_tall_b"] = (grade(crop(P, 384, 0, 32, 64), sat=0.55), None)
    props["grass_dry_a"] = (grade(crop(P, 256, 64, 32, 48), sat=0.55), None)
    props["grass_dry_b"] = (grade(crop(P, 288, 64, 32, 48), sat=0.55), None)
    props["shrub_green"] = (grade(crop(P, 0, 64, 96, 64), sat=0.5, bright=0.85), (60, 14))
    props["fern"] = (grade(crop(P, 160, 64, 96, 64), sat=0.5, bright=0.85), None)
    props["mushrooms"] = (crop("Terrain/mushrooms.png", 0, 128, 96, 32), None)
    props["herb_ashwort"] = (herb(), None)
    # быт
    props["barrel"] = (crop("Objects/Furniture/Barrel.png", 0, 0, 32, 64), (22, 10))
    props["barrel_water"] = (crop("Objects/Furniture/Barrel.png", 32, 0, 32, 64), (22, 10))
    props["barrels_stack"] = (crop("Objects/Furniture/Barrel.png", 96, 0, 64, 64), (50, 14))
    props["crate"] = (crop("Objects/Furniture/Crate.png", 0, 32, 32, 32), (26, 12))
    props["crate_big"] = (crop("Objects/Furniture/Crate.png", 0, 96, 64, 32), (56, 14))
    props["crate_small"] = (crop("Objects/Furniture/Crate.png", 64, 96, 32, 32), (18, 10))
    props["bucket"] = (crop("Objects/Small Items/Buckets.png", 0, 0, 32, 32), None)
    props["basket"] = (crop("Objects/Small Items/Baskets A.png", 64, 0, 32, 32), (20, 8))
    props["hay"] = (grade(crop("Objects/Small Items/Hay & Straw.png", 64, 16, 64, 80), sat=0.6, bright=0.9), (56, 30))
    props["woodpile"] = (crop("Objects/Small Items/Lumber.png", 0, 64, 128, 32), (110, 14))
    props["logs"] = (crop("Objects/Small Items/Lumber.png", 128, 64, 64, 32), (52, 12))
    props["firewood"] = (crop("Objects/Small Items/Lumber.png", 64, 32, 64, 32), (40, 10))
    props["sawhorse"] = (crop("Objects/Furniture/Sawhorse.png", 0, 0, 32, 48), (24, 8))
    props["trough"] = (crop("Objects/Furniture/Trough.png", 0, 64, 64, 64), (54, 18))
    props["lamp_post"] = (crop("Objects/Furniture/Lighting, Outdoors.png", 0, 0, 32, 96), (10, 8))
    props["table_rough"] = (crop("Objects/Furniture/Table, Rough Wood.png", 0, 16, 96, 48), (80, 20))
    props["campfire_logs"] = (crop("Objects/Small Items/Fire, Camp.png", 0, 0, 32, 32), (20, 8))
    props["bones"] = (grade(crop("Objects/Small Items/Skeletons A.png", 32, 32, 64, 32), sat=0.5, bright=0.8), None)
    # процедурные
    props["fence_h"] = (fence_h(), (32, 6))
    props["fence_v"] = (fence_v(), (8, 32))
    props["grave_cross"] = (grave_cross(), (10, 6))
    props["well"] = (well(), (52, 22))
    props["stall_bread"] = (stall("bread"), (84, 22))
    props["stall_goods"] = (stall("goods"), (84, 22))
    props["pyre"] = (pyre(), (70, 22))
    # дома
    gable = src("Structure/Structures/Brick House B.png")
    stone = src("Structure/Structures/Brick House A.png")
    props["house_gable"] = (grade(trim(gable), sat=0.75, bright=0.92), (124, 120))
    props["house_gable_grey"] = (grade(trim(gable), sat=0.25, bright=0.78, tint=(70, 80, 90), tint_amount=0.12), (124, 120))
    props["house_gable_moss"] = (grade(trim(gable), sat=0.45, bright=0.82, tint=(60, 80, 50), tint_amount=0.15), (124, 120))
    props["house_stone"] = (grade(trim(stone), sat=0.6, bright=0.9), (196, 130))
    silent = grade(trim(stone), sat=0.1, bright=0.62, tint=(90, 90, 100), tint_amount=0.2)
    props["house_silent"] = (board_windows(silent), (196, 130))
    return props


def board_windows(img: Image.Image) -> Image.Image:
    """Заколачиваем окна «Тихого дома» досками."""
    d = ImageDraw.Draw(img)
    for (x, y) in ((110, 128), (176, 96)):
        for k in range(3):
            yy = y + 6 + k * 9
            d.polygon([(x - 2, yy), (x + 30, yy - 3 + k), (x + 30, yy + 2 + k), (x - 2, yy + 5)],
                      fill=WOOD_D, outline=OUTLINE)
    return img


def interior() -> dict[str, tuple[Image.Image, tuple[int, int] | None]]:
    out: dict[str, tuple[Image.Image, tuple[int, int] | None]] = {}
    out["bed"] = (compose_bed("Objects/Furniture/Beds/Beds, Single  A.png", 0, 64, 64, 64), (42, 40))
    out["bed_child"] = (grade(compose_bed("Objects/Furniture/Beds/Beds, Single  A.png", 128, 64, 64, 64), sat=0.6, bright=0.85), (42, 40))
    out["fireplace"] = (crop("Objects/Furniture/Fireplace.png", 0, 96, 96, 96), (90, 24))
    out["shelf"] = (crop("Objects/Furniture/Shelf.png", 0, 0, 96, 32), None)
    out["chest"] = (crop("Objects/Furniture/Chest.png", 0, 0, 32, 32), (28, 14))
    out["loom"] = (crop("Objects/Furniture/Sewing & Weaving/Loom.png", 0, 0, 64, 64), (50, 16))
    out["spinning_wheel"] = (crop("Objects/Furniture/Sewing & Weaving/Spinning Wheel.png", 64, 0, 64, 64), (30, 12))
    out["workbench"] = (crop("Objects/Furniture/Workbench, Carpentry.png", 0, 0, 96, 64), (84, 20))
    out["cauldron"] = (crop("Objects/Furniture/Cauldron.png", 0, 0, 32, 32), (22, 10))
    out["stool"] = (crop("Objects/Furniture/Table, Rough Wood.png", 96, 32, 32, 32), (18, 8))
    out["window"] = (crop("Structure/Windows/Stone Windows A.png", 0, 0, 32, 128), None)
    return out


def compose_bed(rel: str, x: int, y: int, w: int, h: int) -> Image.Image:
    return crop(rel, x, y, w, h)


def tileables() -> None:
    TILES_DIR.mkdir(parents=True, exist_ok=True)
    src("Terrain/terrain_autumn.png").save(TILES_DIR / "terrain_autumn.png", optimize=True)
    src("Terrain/tilled_soil.png").save(TILES_DIR / "tilled_soil.png", optimize=True)
    floor = src("Structure/Floor/Wood Floor A.png").crop((32, 32, 64, 96))
    save(grade(floor, sat=0.7, bright=0.85), INTERIOR_DIR / "floor_wood.png")
    wall = src("Structure/Walls/Jagged Stone Walls.png").crop((0, 96, 96, 192))
    save(grade(wall, sat=0.6, bright=0.9), INTERIOR_DIR / "wall_stone.png")


def icons() -> None:
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    def fit(img: Image.Image) -> Image.Image:
        img = trim(img)
        canvas = Image.new("RGBA", (32, 32))
        if img.width > 32 or img.height > 32:
            img.thumbnail((32, 32), Image.NEAREST)
        canvas.alpha_composite(img, ((32 - img.width) // 2, (32 - img.height) // 2))
        return canvas
    save(fit(crop("Objects/Small Items/Buckets.png", 64, 16, 32, 32)), ICONS_DIR / "water_bucket.png")
    save(fit(crop("Objects/Small Items/Buckets.png", 0, 0, 32, 32)), ICONS_DIR / "bucket.png")
    save(fit(crop("Objects/Small Items/Food/Bread A.png", 64, 0, 32, 32)), ICONS_DIR / "bread.png")
    save(fit(crop("Objects/Small Items/Fabric/Fabric Rolls.png", 32, 0, 32, 48)), ICONS_DIR / "cloth.png")
    save(fit(crop("Objects/Small Items/Lumber.png", 64, 32, 64, 32)), ICONS_DIR / "firewood.png")
    save(fit(herb()), ICONS_DIR / "ashwort.png")
    save(coin(), ICONS_DIR / "coin.png")
    save(medicine(), ICONS_DIR / "medicine.png")
    save(stick_icon(), ICONS_DIR / "stick.png")
    save(heart(True), ICONS_DIR / "heart_full.png")
    save(heart(False), ICONS_DIR / "heart_empty.png")


def write_prop_scene(name: str, img: Image.Image, collision: tuple[int, int] | None, folder: str) -> None:
    SCENES_DIR.mkdir(parents=True, exist_ok=True)
    tex_path = f"res://assets/sprites/{folder}/{name}.png"
    node_name = "".join(part.capitalize() for part in name.split("_"))
    lines = []
    steps = 2 if collision else 1
    lines.append(f"[gd_scene load_steps={steps + 1} format=3]\n")
    lines.append(f'[ext_resource type="Texture2D" path="{tex_path}" id="1_tex"]\n')
    if collision:
        lines.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_base"]')
        lines.append(f"size = Vector2({collision[0]}, {collision[1]})\n")
        lines.append(f'[node name="{node_name}" type="StaticBody2D"]')
        lines.append("collision_mask = 0\n")
    else:
        lines.append(f'[node name="{node_name}" type="Node2D"]\n')
    lines.append('[node name="Sprite2D" type="Sprite2D" parent="."]')
    lines.append('texture = ExtResource("1_tex")')
    lines.append(f"offset = Vector2(0, {-img.height / 2:g})\n")
    if collision:
        lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="."]')
        lines.append(f"position = Vector2(0, {-collision[1] / 2:g})")
        lines.append('shape = SubResource("RectangleShape2D_base")\n')
    (SCENES_DIR / f"{name}.tscn").write_text("\n".join(lines))


def main() -> None:
    tileables()
    props = build_props()
    for name, (img, coll) in props.items():
        save(img, PROPS_DIR / f"{name}.png")
        write_prop_scene(name, img, coll, "props")
    for name, (img, coll) in interior().items():
        save(img, INTERIOR_DIR / f"{name}.png")
        write_prop_scene(name, img, coll, "interior")
    icons()
    FX_DIR.mkdir(parents=True, exist_ok=True)
    save(campfire_strip(), FX_DIR / "campfire.png")
    save(ash_flake(), FX_DIR / "ash_flake.png")
    save(soft_light(), FX_DIR / "soft_light.png")
    save(smoke_puff(), FX_DIR / "smoke_puff.png")
    save(slash_arc(), FX_DIR / "slash_arc.png")
    save(shadow(), FX_DIR / "shadow.png")
    save(rain_drop(), FX_DIR / "rain_drop.png")
    ENEMY_DIR.mkdir(parents=True, exist_ok=True)
    save(rat_sheet(False), ENEMY_DIR / "rat.png")
    save(rat_sheet(True), ENEMY_DIR / "rat_grey.png")
    (CACHE.parent / "eliza_used.txt").write_text("\n".join(sorted(USED)) + "\n")
    print(f"пропсов: {len(props)}, интерьер: {len(interior())}")


if __name__ == "__main__":
    main()
