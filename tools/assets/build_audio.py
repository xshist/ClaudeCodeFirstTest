#!/usr/bin/env python3
"""Процедурный звук: эффекты, эмбиент и простая музыка (Karplus–Strong «лютня» + бурдон).

Запуск: python3 tools/assets/build_audio.py  ->  assets/audio/{sfx,ambience,music}/*.wav
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
SR = 22050
rng = np.random.default_rng(7)


def write(path: Path, data: np.ndarray, sr: int = SR) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * 0.89
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def t(sec: float) -> np.ndarray:
    return np.arange(int(sec * SR)) / SR


def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def noise(sec: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(sec * SR))


def pluck(freq: float, sec: float, damp: float = 0.996) -> np.ndarray:
    n = int(sec * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        j = i % period
        nxt = (j + 1) % period
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + buf[nxt])
    return out * env(n, 0.002, 0.05)


def bell(freq: float, sec: float) -> np.ndarray:
    tt = t(sec)
    partials = [(0.5, 1.0, 1.2), (1.0, 0.8, 1.6), (1.19, 0.5, 2.2), (1.56, 0.35, 2.8), (2.0, 0.3, 3.5), (2.74, 0.2, 4.4)]
    out = np.zeros_like(tt)
    for ratio, amp, decay in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * tt) * np.exp(-tt * decay)
    return out * env(len(tt), 0.003, 0.2)


# ------------------------------------------------------------------ SFX

def sfx() -> None:
    d = OUT / "sfx"
    # взмах палкой
    n = noise(0.22)
    sweep = np.sin(np.linspace(0, np.pi, len(n)))
    write(d / "swing.wav", lowpass(n, 0.25) * sweep)
    # удар
    tt = t(0.18)
    thump = np.sin(2 * np.pi * (110 - 300 * tt) * tt) * np.exp(-tt * 28) + lowpass(noise(0.18), 0.3) * np.exp(-tt * 40)
    write(d / "hit.wav", thump)
    # писк крысы
    tt = t(0.16)
    f = 2400 + 900 * np.sin(2 * np.pi * 18 * tt)
    write(d / "rat_squeak.wav", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.01, 0.06) * 0.6)
    tt = t(0.35)
    f = 2600 - 2000 * tt
    write(d / "rat_die.wav", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.01, 0.2) * 0.6)
    # получение предмета
    tt = t(0.32)
    tone = np.sin(2 * np.pi * 880 * tt) * (tt < 0.12) + np.sin(2 * np.pi * 1320 * tt) * (tt >= 0.1)
    write(d / "pickup.wav", tone * np.exp(-tt * 8) * env(len(tt), 0.005, 0.05))
    # монеты
    out = np.zeros(int(0.4 * SR))
    for k, start in enumerate((0.0, 0.07, 0.15)):
        s = int(start * SR)
        b = bell(2200 + k * 180, 0.25) * 0.5
        out[s:s + len(b)] += b[: len(out) - s]
    write(d / "coins.wav", out)
    # UI
    tt = t(0.05)
    write(d / "ui_click.wav", np.sin(2 * np.pi * 1200 * tt) * np.exp(-tt * 90))
    tt = t(0.12)
    write(d / "ui_open.wav", np.sin(2 * np.pi * (500 + 1500 * tt) * tt) * np.exp(-tt * 25))
    tt = t(0.03)
    write(d / "text_blip.wav", np.sin(2 * np.pi * 620 * tt) * np.exp(-tt * 120) * 0.4)
    # квест
    out = np.zeros(int(1.2 * SR))
    for k, (f0, st) in enumerate(((587.3, 0.0), (740.0, 0.12), (880.0, 0.24))):
        s = int(st * SR)
        b = pluck(f0, 0.9, 0.997)
        out[s:s + len(b)] += b[: len(out) - s]
    write(d / "quest_update.wav", out)
    out = np.zeros(int(2.0 * SR))
    for k, (f0, st) in enumerate(((440.0, 0.0), (554.4, 0.15), (659.3, 0.3), (880.0, 0.45))):
        s = int(st * SR)
        b = pluck(f0, 1.4, 0.998)
        out[s:s + len(b)] += b[: len(out) - s]
    write(d / "quest_done.wav", out)
    # колокол серых братьев
    write(d / "bell_toll.wav", bell(196.0, 5.0) + 0.3 * bell(98.0, 5.0))
    # получил урон
    tt = t(0.25)
    write(d / "hurt.wav", (np.sin(2 * np.pi * (220 - 200 * tt) * tt) + 0.4 * lowpass(noise(0.25), 0.2)) * np.exp(-tt * 14))
    # дверь
    tt = t(0.45)
    creak = np.sin(2 * np.pi * np.cumsum(180 + 60 * np.sin(2 * np.pi * 7 * tt)) / SR) * 0.3 * np.exp(-tt * 4)
    knock = lowpass(noise(0.45), 0.15) * np.exp(-tt * 20)
    write(d / "door.wav", creak + knock)
    # вода
    tt = t(0.6)
    bub = np.zeros_like(tt)
    for k in range(8):
        st = rng.uniform(0, 0.4)
        f0 = rng.uniform(500, 1100)
        m = tt > st
        bub += m * np.sin(2 * np.pi * (f0 + 900 * (tt - st)) * (tt - st)) * np.exp(-(tt - st) * 30)
    write(d / "water.wav", bub + 0.3 * lowpass(noise(0.6), 0.4) * np.exp(-tt * 6))
    # кашель (для Гордея) — шумовой «кхе»
    out = np.zeros(int(1.0 * SR))
    for st in (0.0, 0.3, 0.55):
        s = int(st * SR)
        seg = lowpass(noise(0.18), 0.35) * np.exp(-t(0.18) * 18)
        out[s:s + len(seg)] += seg
    write(d / "cough.wav", out)


# ------------------------------------------------------------------ эмбиент

def ambience() -> None:
    d = OUT / "ambience"
    sec = 24.0
    n = noise(sec)
    wind = lowpass(lowpass(n, 0.02), 0.05)
    tt = t(sec)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * tt / sec * 3) * np.sin(2 * np.pi * tt / sec * 5 + 1)
    high = lowpass(n, 0.3) - lowpass(n, 0.1)
    loop = wind * gust + 0.05 * high * gust
    # бесшовный цикл: кроссфейд хвоста
    fade = int(2 * SR)
    loop[:fade] = loop[:fade] * np.linspace(0, 1, fade) + loop[-fade:] * np.linspace(1, 0, fade)
    loop = loop[:-fade]
    write(d / "wind.wav", loop)
    # треск очага
    sec = 12.0
    out = 0.15 * lowpass(noise(sec), 0.05)
    for _ in range(140):
        st = int(rng.uniform(0, sec - 0.05) * SR)
        ln = int(rng.uniform(0.005, 0.03) * SR)
        out[st:st + ln] += rng.uniform(0.2, 1.0) * rng.uniform(-1, 1, ln) * np.linspace(1, 0, ln)
    write(d / "hearth.wav", out)


# ------------------------------------------------------------------ музыка

NOTE = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def freq(name: str) -> float:
    letter, octave = name[0], int(name[-1])
    semis = NOTE[letter] + (1 if "#" in name else 0) - (1 if name[1:-1] == "b" else 0)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


def drone(f0: float, sec: float) -> np.ndarray:
    tt = t(sec)
    saw = np.zeros_like(tt)
    for k in range(1, 8):
        saw += np.sin(2 * np.pi * f0 * k * tt * (1 + 0.0007 * k)) / k
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * tt)
    return lowpass(saw, 0.06) * lfo


def render_melody(melody: list[tuple[str, float]], bpm: float, damp: float = 0.9965) -> np.ndarray:
    beat = 60.0 / bpm
    total = sum(dur for _, dur in melody) * beat
    out = np.zeros(int((total + 2.5) * SR))
    pos = 0.0
    for name, dur in melody:
        if name != "-":
            s = int(pos * SR)
            note = pluck(freq(name), dur * beat + 1.5, damp)
            out[s:s + len(note)] += note[: len(out) - s]
        pos += dur * beat
    return out, total


def loopify(x: np.ndarray, total: float) -> np.ndarray:
    n = int(total * SR)
    body = x[:n].copy()
    tail = x[n:]
    body[: len(tail)] += tail  # хвост последней ноты переносим в начало цикла
    return body


def music() -> None:
    d = OUT / "music"
    # Деревня: ре-минор (эолийский), медленно, с паузами
    bpm = 72
    mel = [
        ("D4", 1), ("F4", 1), ("A4", 2), ("G4", 1), ("F4", 1), ("E4", 2),
        ("D4", 1), ("E4", 1), ("F4", 1), ("A4", 1), ("G4", 3), ("-", 1),
        ("A4", 1), ("C5", 1), ("D5", 2), ("C5", 1), ("A4", 1), ("G4", 2),
        ("F4", 1), ("E4", 1), ("D4", 1), ("E4", 1), ("D4", 3), ("-", 1),
        ("F4", 2), ("E4", 1), ("D4", 1), ("C4", 2), ("D4", 2),
        ("A3", 1), ("C4", 1), ("D4", 2), ("E4", 2), ("-", 2),
        ("D4", 1), ("F4", 1), ("A4", 1), ("G4", 1), ("F4", 2), ("E4", 2),
        ("D4", 4), ("-", 4),
    ]
    lead, total = render_melody(mel, bpm)
    bass_line = [("D3", 8), ("C3", 8), ("A2", 8), ("D3", 8), ("Bb2", 8), ("A2", 8), ("D3", 8), ("D3", 8)]
    bass, _ = render_melody(bass_line, bpm, 0.9985)
    n = max(len(lead), len(bass))
    mix = np.zeros(n)
    mix[: len(lead)] += 0.55 * lead
    mix[: len(bass)] += 0.45 * bass
    dr = drone(freq("D2"), n / SR) * 0.25 + drone(freq("A2"), n / SR) * 0.12
    mix += dr[:n]
    write(d / "village.wav", loopify(mix, total))

    # Дом: тише и теплее, ре-дорийский
    mel = [
        ("A4", 2), ("B4", 1), ("A4", 1), ("F4", 2), ("D4", 2),
        ("E4", 1), ("F4", 1), ("G4", 2), ("A4", 4),
        ("C5", 2), ("B4", 1), ("A4", 1), ("G4", 2), ("F4", 2),
        ("E4", 2), ("D4", 2), ("D4", 4),
    ]
    lead, total = render_melody(mel, 60, 0.997)
    bass, _ = render_melody([("D3", 8), ("G2", 8), ("C3", 8), ("D3", 8)], 60, 0.9985)
    n = max(len(lead), len(bass))
    mix = np.zeros(n)
    mix[: len(lead)] += 0.5 * lead
    mix[: len(bass)] += 0.5 * bass
    write(d / "home.wav", loopify(mix, total))

    # Титул: бурдон и далёкий колокол
    sec = 32.0
    n = int(sec * SR)
    mix = drone(freq("D2"), sec) * 0.5 + drone(freq("A2"), sec) * 0.25 + drone(freq("D3"), sec) * 0.08
    for st in (1.0, 9.0, 17.0, 25.0):
        b = bell(146.8, 7.0) * 0.35
        s = int(st * SR)
        mix[s:s + len(b)] += b[: n - s]
    mel = [("-", 4), ("D4", 2), ("F4", 2), ("E4", 4), ("-", 4), ("A3", 2), ("C4", 2), ("D4", 8)]
    lead, _ = render_melody(mel, 60, 0.997)
    mix[: min(n, len(lead))] += 0.35 * lead[: min(n, len(lead))]
    fade = int(1.5 * SR)
    mix[:fade] = mix[:fade] * np.linspace(0, 1, fade) + mix[-fade:] * np.linspace(1, 0, fade)
    write(d / "title.wav", mix[:-fade])


if __name__ == "__main__":
    sfx()
    ambience()
    music()
    print("ok")
