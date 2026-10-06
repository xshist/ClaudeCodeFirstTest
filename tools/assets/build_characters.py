#!/usr/bin/env python3
"""Собирает спрайтшиты персонажей из слоёв Universal LPC Spritesheet Generator.

Слои качаются с GitHub (raw.githubusercontent.com) и кэшируются в tools/assets/.cache/.
Результат: assets/sprites/characters/<id>.png в компактной раскладке (кадр 64x64):

  ряды 0-3   walk   (9 кадров; кадр 0 — стойка)  вверх, влево, вниз, вправо
  ряды 4-7   slash  (6 кадров)
  ряд  8     hurt   (6 кадров)

(idle/sit у большинства слоёв одежды в ULPC не нарисованы, поэтому их не берём:
стойка = walk, кадр 0.)

Раскладку читает scripts/actors/lpc_sprite.gd — меняйте их вместе.
Запуск: python3 tools/assets/build_characters.py
"""
from __future__ import annotations

import concurrent.futures as cf
import json
import os
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / ".cache" / "ulpc"
OUT = ROOT / "assets" / "sprites" / "characters"
PORTRAITS = ROOT / "assets" / "portraits"
REPO_RAW = "https://raw.githubusercontent.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator/master/"

FRAME = 64
SRC_COLS, SRC_ROWS = 13, 46
# (исходный ряд, кол-во кадров) для каждого ряда компактного листа
COMPACT_ROWS: list[tuple[int, int]] = (
    [(8 + d, 9) for d in range(4)]      # walk
    + [(12 + d, 6) for d in range(4)]   # slash
    + [(20, 6)]                         # hurt
)
OUT_COLS = 9

# Рецепты персонажей. Слой: (имя sheet_definition, вариант цвета[, {"grey": True}]).
# "grey": True у рецепта — кожа «серой немощи»; у слоя — пепельно-серая ткань.
SKIN_DEFS = {"body", "heads_human_male", "heads_human_female", "heads_human_child",
             "heads_human_male_elderly", "heads_human_female_elderly", "heads_human_male_gaunt",
             "head_nose_large", "head_wrinkles"}

RECIPES: dict[str, dict] = {
    "kai": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male", "light"), ("eyes", "brown"), ("eyebrows_thick", "black"),
        ("hair_messy2", "black"), ("legs_pants", "walnut"), ("feet_boots", "brown"),
        ("torso_clothes_longsleeve_laced", "tan"), ("belt_sash", "maroon"), ("belt_leather", "brown")]},
    "tim": {"body": "child", "skin": "light", "layers": [
        ("heads_human_child", "light"), ("eyes", "blue"), ("hair_messed", "brown 2"),
        ("legs_childpants", "brown"), ("torso_clothes_child_shirt", "gray")]},
    "marta": {"body": "female", "skin": "light", "layers": [
        ("heads_human_female", "light"), ("eyes", "green"), ("hair_long_tied", "chestnut"),
        ("legs_skirts_plain", "charcoal"), ("feet_shoes", "brown"),
        ("torso_clothes_blouse_longsleeve", "maroon"), ("torso_aprons_apron_half", "white"),
        ("hat_headband_kerchief", "tan")]},
    "gordey": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male", "light"), ("eyes", "gray"), ("hair_balding", "dark gray"),
        ("beards_medium", "dark gray"), ("legs_pants", "charcoal"), ("feet_boots", "black"),
        ("torso_clothes_longsleeve", "slate"), ("torso_aprons_apron", "leather")]},
    "vedana": {"body": "female", "skin": "light", "layers": [
        ("heads_human_female_elderly", "light"), ("eyes", "gray"),
        ("torso_clothes_robe", "forest green"), ("hat_hood_cloth", "hood_brown"), ("neck_scarf", "brown")]},
    "grey_brother": {"body": "female", "skin": "light", "layers": [
        ("heads_human_male_gaunt", "light"), ("torso_clothes_robe", "white", {"grey": True}),
        ("hat_hood_sack_cloth", "gray"), ("facial_mask_plain", "white"), ("belt_leather", "charcoal"),
        ("feet_shoes", "charcoal")]},
    "lukash": {"body": "male", "skin": "light", "grey": True, "layers": [
        ("heads_human_male_gaunt", "light"), ("eyes", "gray"), ("hair_messy2", "dark gray"),
        ("legs_pants", "charcoal"), ("torso_clothes_shortsleeve", "walnut")]},
    "guard": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male", "light"), ("eyes", "brown"), ("beards_trimmed", "chestnut"),
        ("legs_pants", "charcoal"), ("feet_boots", "black"), ("torso_chainmail", "gray"),
        ("torso_jacket_tabard", "maroon"), ("belt_leather", "charcoal"),
        ("hat_helmet_kettle", "steel")]},
    "nyura": {"body": "female", "skin": "light", "layers": [
        ("heads_human_female", "light"), ("eyes", "brown"), ("hair_bangs_bun", "ginger"),
        ("legs_skirts_plain", "brown"), ("feet_shoes", "black"),
        ("torso_clothes_blouse_longsleeve", "tan"), ("torso_aprons_apron_half", "white"),
        ("hat_headband_kerchief", "red")]},
    "bogdan": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male", "light"), ("eyes", "brown"), ("hair_parted", "black"),
        ("beards_trimmed", "black"), ("legs_pants", "brown"), ("feet_shoes", "brown"),
        ("torso_clothes_longsleeve", "tan"), ("torso_clothes_vest", "leather")]},
    "efim": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male_elderly", "light"), ("eyes", "gray"), ("hair_balding", "white"),
        ("beards_medium", "white"), ("legs_pants", "brown"), ("feet_shoes", "black"),
        ("torso_clothes_longsleeve", "gray")]},
    "villager_man": {"body": "male", "skin": "light", "layers": [
        ("heads_human_male", "light"), ("eyes", "brown"), ("hair_messy1", "chestnut"),
        ("legs_pants", "slate"), ("feet_shoes", "black"), ("torso_clothes_shortsleeve", "bluegray")]},
    "villager_woman": {"body": "female", "skin": "light", "layers": [
        ("heads_human_female", "light"), ("eyes", "blue"), ("hair_ponytail", "light brown"),
        ("legs_skirts_plain", "walnut"), ("feet_shoes", "brown"),
        ("torso_clothes_blouse_longsleeve", "forest")]},
    "asya": {"body": "child", "skin": "light", "layers": [
        ("heads_human_child", "light"), ("eyes", "green"), ("hair_relm_ponytail", "ginger"),
        ("legs_childskirts", "maroon"), ("torso_clothes_child_shirt", "white")]},
}


def fetch(rel: str) -> Path | None:
    dst = CACHE / rel
    if dst.exists():
        return dst
    dst.parent.mkdir(parents=True, exist_ok=True)
    url = REPO_RAW + urllib.request.quote(rel)
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
    except Exception as e:  # noqa: BLE001
        print(f"  ! не удалось скачать {rel}: {e}", file=sys.stderr)
        return None
    dst.write_bytes(data)
    return dst


def definition(name: str) -> dict:
    p = fetch(f"sheet_definitions/{name}.json")
    if p is None:
        raise SystemExit(f"нет определения слоя {name}")
    return json.loads(p.read_text())


def layer_files(name: str, variant: str, body: str) -> list[tuple[int, str]]:
    """Файлы слоя для данного типа тела: [(zPos, путь в репозитории)]."""
    d = definition(name)
    out: list[tuple[int, str]] = []
    for key, val in d.items():
        if not key.startswith("layer_") or not isinstance(val, dict):
            continue
        if "custom_animation" in val:
            continue  # oversize-оружие не используем
        path = val.get(body)
        if not path:
            print(f"  ! слой {name} не поддерживает тело {body}", file=sys.stderr)
            continue
        if not path.endswith("/"):
            path += "/"
        out.append((int(val.get("zPos", 0)), f"spritesheets/{path}{variant.replace(' ', '_')}.png"))
    return out


def greyify(img: Image.Image) -> Image.Image:
    """Кожа «серой немощи»: обесцвечиваем и уводим в холодный пепельный тон."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            lum = lum * 0.82 + 10
            px[x, y] = (int(lum * 0.94), int(lum * 0.97), int(min(255, lum * 1.04)), a)
    return img


def build(cid: str, recipe: dict) -> None:
    body = recipe["body"]
    grey_skin = bool(recipe.get("grey"))
    entries: list[tuple[int, str, bool]] = []
    entries.append((10, f"spritesheets/body/bodies/{body}/{recipe['skin']}.png", grey_skin))
    for layer in recipe["layers"]:
        name, variant = layer[0], layer[1]
        opts = layer[2] if len(layer) > 2 else {}
        make_grey = (grey_skin and name in SKIN_DEFS) or bool(opts.get("grey"))
        for z, rel in layer_files(name, variant, body):
            entries.append((z, rel, make_grey))
    entries.sort(key=lambda e: e[0])
    with cf.ThreadPoolExecutor(8) as ex:
        paths = list(ex.map(lambda e: fetch(e[1]), entries))
    canvas = Image.new("RGBA", (SRC_COLS * FRAME, SRC_ROWS * FRAME))
    for (z, rel, make_grey), p in zip(entries, paths):
        if p is None:
            continue
        img = Image.open(p).convert("RGBA")
        if make_grey:
            img = greyify(img)
        layer = Image.new("RGBA", canvas.size)
        layer.paste(img.crop((0, 0, min(img.width, canvas.width), min(img.height, canvas.height))), (0, 0))
        canvas.alpha_composite(layer)
    out = Image.new("RGBA", (OUT_COLS * FRAME, len(COMPACT_ROWS) * FRAME))
    for row, (src_row, count) in enumerate(COMPACT_ROWS):
        for col in range(count):
            frame = canvas.crop((col * FRAME, src_row * FRAME, (col + 1) * FRAME, (src_row + 1) * FRAME))
            out.paste(frame, (col * FRAME, row * FRAME))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{cid}.png", optimize=True)
    # портрет для диалогов: голова из кадра «стоит лицом к нам», 36x36
    front = out.crop((0, 2 * FRAME, FRAME, 3 * FRAME))
    top = (front.getbbox() or (0, 4, 0, 0))[1]
    PORTRAITS.mkdir(parents=True, exist_ok=True)
    front.crop((14, max(0, top - 2), 50, max(0, top - 2) + 36)).save(PORTRAITS / f"{cid}.png", optimize=True)
    used = sorted({rel for _, rel, _ in entries})
    (CACHE.parent / f"{cid}.layers.txt").write_text("\n".join(used) + "\n")
    print(f"  {cid}: {len(entries)} слоёв -> {OUT / (cid + '.png')}")


def main() -> None:
    only = set(sys.argv[1:])
    for cid, recipe in RECIPES.items():
        if only and cid not in only:
            continue
        build(cid, recipe)


if __name__ == "__main__":
    main()
