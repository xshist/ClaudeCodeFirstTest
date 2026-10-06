#!/usr/bin/env python3
"""Собирает CREDITS.md по реально использованным спрайтам LPC.

Запускать после build_characters.py и build_environment.py (они пишут списки слоёв в .cache).
"""
from __future__ import annotations

import csv
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / ".cache"
ULPC_RAW = "https://raw.githubusercontent.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator/master/"
ELIZA_RAW = "https://raw.githubusercontent.com/ElizaWy/LPC/main/"


def fetch(url: str, dst: Path) -> Path:
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=60) as r:
            dst.write_bytes(r.read())
    return dst


def ulpc_section() -> list[str]:
    rows = list(csv.DictReader(fetch(ULPC_RAW + "CREDITS.csv", CACHE / "ulpc" / "CREDITS.csv").open(encoding="utf-8")))
    used: dict[str, set[str]] = {}
    for layers in sorted(CACHE.glob("*.layers.txt")):
        character = layers.name.split(".")[0]
        for line in layers.read_text().splitlines():
            path = line.removeprefix("spritesheets/")
            used.setdefault(path, set()).add(character)
    out = ["## Персонажи — Universal LPC Spritesheet Character Generator", "",
           "Источник: https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator  ",
           "Слои собраны скриптом `tools/assets/build_characters.py`.", "",
           "| Слой | Авторы | Лицензии | Персонажи |", "|---|---|---|---|"]
    for path in sorted(used):
        best = None
        for row in rows:
            name = row["filename"].strip()
            if name and row["authors"].strip() and path.startswith(name) and (best is None or len(name) > len(best["filename"])):
                best = row
        authors = best["authors"].replace(",", ", ") if best else "см. репозиторий"
        licenses = best["licenses"].replace(",", ", ") if best else "CC-BY-SA 3.0 / GPL 3.0"
        out.append(f"| `{path}` | {authors} | {licenses} | {', '.join(sorted(used[path]))} |")
    return out


def eliza_section() -> list[str]:
    used = [l for l in (CACHE / "eliza_used.txt").read_text().splitlines() if l]
    out = ["## Окружение — LPC Revised", "",
           "Источник: https://github.com/ElizaWy/LPC — лицензии CC-BY 3.0 / OGA-BY 3.0.  ",
           "Авторы проекта: Eliza Wyatt (DeathsDarling), Lanea Zimmerman (Sharm), Stephen Challener (Redshrike), "
           "Johannes Sjölund (Wulax), BlueCarrot16, BenCreating, Durrani, YuriNikolai, Craftpix.net.  ",
           "Нарезка и доработка (цветокоррекция, колодец, прилавки, заборы, кресты, крысы) — `tools/assets/build_environment.py`.", ""]
    folders: dict[str, list[str]] = {}
    for rel in used:
        folders.setdefault(str(Path(rel).parent), []).append(Path(rel).stem)
    for folder, stems in sorted(folders.items()):
        credits_path = fetch(ELIZA_RAW + urllib.request.quote(folder + "/Credits.txt"), CACHE / "eliza" / folder / "Credits.txt")
        text = credits_path.read_text(encoding="utf-8", errors="replace")
        blocks = re.split(r"\n(?=[^\n]+\n-{5,})", text)
        tokens = {re.split(r"[ ,_\-]", s.lower())[0] for s in stems}
        tokens |= {t.rstrip("s") for t in tokens}
        picked = []
        for block in blocks:
            title = block.strip().split("\n")[0].lower()
            if any(tok and tok in title for tok in tokens):
                picked.append(block.strip())
        out.append(f"### {folder}")
        out.append("")
        out.append("Файлы: " + ", ".join(f"`{s}`" for s in sorted(stems)))
        out.append("")
        out.append("```")
        out.extend(picked or ["(см. Credits.txt в папке источника)"])
        out.append("```")
        out.append("")
    return out


def main() -> None:
    lines = ["# Авторы и лицензии", "",
             "Игра «Пепел и кровь» использует свободные ресурсы. Спасибо их авторам!", "",
             "## Шрифты", "",
             "Alegreya, Alegreya Sans, Alegreya SC — Huerta Tipográfica, SIL Open Font License 1.1 "
             "(тексты лицензий — `assets/fonts/OFL_*.txt`).", "",
             "## Иллюстрации меню, глав и героя", "",
             "`assets/ui/art/*` — референсы, предоставленные автором проекта.", "",
             "## Музыка и звуки", "",
             "Сгенерированы процедурно скриптом `tools/assets/build_audio.py` (Karplus–Strong, шум, колокол).", ""]
    lines += ulpc_section() + [""] + eliza_section()
    (ROOT / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("CREDITS.md готов")


if __name__ == "__main__":
    main()
