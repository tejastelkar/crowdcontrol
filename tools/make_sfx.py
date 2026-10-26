"""Generates the game's own sound effects and its background music loop.

Run from the project folder:  python3 tools/make_sfx.py
Needs numpy. Writes WAVs to assets/sfx and the music loop to assets/music/loop.wav.
"""
import os
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "assets", "sfx")
MUSIC = os.path.join(ROOT, "assets", "music")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def env(n, attack=0.004, decay=3.0):
    t = np.arange(n) / RATE
    a = np.minimum(1.0, t / max(attack, 1e-6))
    return a * (1.0 - np.arange(n) / n) ** decay


def osc(freq, dur, kind="sine"):
    f = np.asarray(freq, dtype=np.float64) if np.ndim(freq) else np.full(int(RATE * dur), freq)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "saw":
        return 2 * (ph / (2 * np.pi) % 1.0) - 1
    return np.tanh(3 * np.sin(ph))  # soft square


def sweep(f0, f1, dur, curve=1.0):
    x = np.linspace(0, 1, int(RATE * dur)) ** curve
    return f0 + (f1 - f0) * x


def noise(dur, smooth=0.5):
    n = rng.uniform(-1, 1, int(RATE * dur))
    out = np.empty_like(n)
    last = 0.0
    for i in range(len(n)):
        last = last * smooth + n[i] * (1 - smooth)
        out[i] = last
    return out * 2.0


def lowpass(x, a=0.2):
    out = np.empty_like(x)
    last = 0.0
    for i in range(len(x)):
        last += a * (x[i] - last)
        out[i] = last
    return out


def echo(x, delay=0.11, fb=0.32, mix=0.35, taps=4):
    d = int(RATE * delay)
    out = np.concatenate([x, np.zeros(d * taps)])
    wet = np.zeros_like(out)
    g = 1.0
    for k in range(1, taps + 1):
        g *= fb
        wet[d * k:d * k + len(x)] += x * g
    return out + wet * mix / max(fb, 1e-6)


def pad_to(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return sum(pad_to(t, n) for t in tracks)


def seq(*parts):
    return np.concatenate(parts)


def note(semi, base=523.25):  # 0 = C5
    return base * 2 ** (semi / 12)


def pluck(freq, dur, bright=0.5, decay=4.0):
    s = osc(freq, dur, "tri") * 0.7 + osc(freq * 2, dur, "sine") * 0.25 * bright + osc(freq * 3, dur) * 0.08 * bright
    return s * env(len(s), 0.003, decay)


def save_wav(path, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    x = x * np.minimum(1.0, np.linspace(1, 0, len(x)) * 400)  # no click at the end
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def sfx(name, x, peak=0.85):
    os.makedirs(SFX, exist_ok=True)
    save_wav(os.path.join(SFX, name + ".wav"), x, peak)


# ------------------------------------------------------------------ effects
shoot = mix(osc(sweep(380, 150, 0.09, 0.6), 0.09, "sine") * env(int(RATE * 0.09), 0.002, 3.5),
            lowpass(noise(0.05, 0.3), 0.35) * env(int(RATE * 0.05), 0.001, 4) * 0.35)
sfx("shoot", shoot, 0.7)

gate = mix(pluck(note(7), 0.16, 1.0, 3.0), pluck(note(14), 0.14, 0.6, 3.5) * 0.5,
           osc(sweep(note(19), note(24), 0.08), 0.08) * env(int(RATE * 0.08), 0.002, 2) * 0.15)
sfx("gate", echo(gate, 0.07, 0.25, 0.3, 2), 0.7)

coin = seq(pluck(note(16), 0.07, 1.0, 1.5), pluck(note(23), 0.22, 1.0, 3.0))
sfx("coin", echo(coin, 0.09, 0.3, 0.35, 3), 0.7)

star = mix(pluck(note(19), 0.4, 1.0, 2.5), pluck(note(26), 0.35, 0.8, 3.0) * 0.6, pluck(note(31), 0.3, 0.6, 3.5) * 0.3)
sfx("star", echo(star, 0.12, 0.35, 0.4, 4), 0.75)

boom = mix(osc(sweep(140, 35, 0.6, 0.5), 0.6) * env(int(RATE * 0.6), 0.003, 2.2),
           lowpass(noise(0.55, 0.6), 0.12) * env(int(RATE * 0.55), 0.002, 2.4) * 0.9)
sfx("boom", boom, 0.9)

champion = seq(*[pluck(note(s, 261.63), d, 1.0, 2.0) for s, d in [(0, 0.09), (4, 0.09), (7, 0.09), (12, 0.3)]])
buzz = osc(sweep(80, 160, len(champion) / RATE), 0, "saw")
champion = mix(champion, buzz * env(len(buzz), 0.02, 1.5) * 0.12)
sfx("champion", echo(champion, 0.1, 0.3, 0.3, 3), 0.8)

base_hit = mix(osc(sweep(150, 70, 0.14), 0.14) * env(int(RATE * 0.14), 0.002, 3), lowpass(noise(0.06, 0.6), 0.2) * env(int(RATE * 0.06)) * 0.4)
sfx("base_hit", base_hit, 0.8)


def chord_stab(semis, dur, base=261.63):
    return mix(*[pluck(note(s, base), dur, 0.8, 2.2) * 0.5 for s in semis])


# a little fanfare: rising arpeggio into a held major chord, with echo
win = seq(*[pluck(note(s, 392.0), 0.11, 1.0, 1.8) for s in [0, 4, 7, 12, 16]],
          mix(chord_stab([0, 4, 7, 12], 0.9, 392.0), osc(note(-12, 392.0), 0.9, "tri") * env(int(RATE * 0.9), 0.01, 1.5) * 0.4))
sfx("win", echo(win, 0.13, 0.35, 0.4, 4), 0.85)

# a sad slide down
lose = seq(pluck(note(7, 261.63), 0.22, 0.6, 1.2), pluck(note(6, 261.63), 0.22, 0.6, 1.2), pluck(note(5, 261.63), 0.22, 0.6, 1.2),
           mix(osc(sweep(note(4, 261.63), note(-1, 261.63), 0.7), 0.7, "tri") * env(int(RATE * 0.7), 0.01, 1.6),
               osc(sweep(note(-8, 261.63), note(-13, 261.63), 0.7), 0.7, "sine") * env(int(RATE * 0.7), 0.01, 1.6) * 0.5))
sfx("lose", echo(lose, 0.15, 0.3, 0.3, 3), 0.8)

# ------------------------------------------------------------------ music loop
BPM = 112
beat = 60.0 / BPM
bars = 8
total = int(RATE * beat * 4 * bars)
song = np.zeros(total)


def put(x, at_beats, gain=1.0):
    i = int(at_beats * beat * RATE)
    if i >= total:
        return
    n = min(len(x), total - i)
    song[i:i + n] += x[:n] * gain


# C - G - Am - F, two bars each
prog = [[0, 4, 7], [-5, -1, 2], [-3, 0, 4], [-7, -3, 0]]
for b in range(bars):
    ch = prog[(b // 2) % 4]
    root = ch[0]
    for k in range(4):  # bass on every beat
        put(pluck(note(root - 24, 261.63), beat * 0.9, 0.3, 2.0), b * 4 + k, 0.5)
    for k in range(8):  # arpeggio on eighths
        s = ch[[0, 1, 2, 1, 0, 2, 1, 2][k]] + (12 if k in (3, 7) else 0)
        put(pluck(note(s, 523.25), beat * 0.45, 0.7, 3.0), b * 4 + k * 0.5, 0.22)
    pad = mix(*[osc(note(s, 261.63), beat * 4, "tri") for s in ch]) * env(int(RATE * beat * 4), 0.4, 0.8) * 0.06
    put(pad, b * 4)
    for k in range(4):  # kick on 1 and 3, snare-ish on 2 and 4, hats on eighths
        if k % 2 == 0:
            put(osc(sweep(120, 45, 0.18), 0.18) * env(int(RATE * 0.18), 0.002, 3), b * 4 + k, 0.55)
        else:
            put(lowpass(noise(0.12, 0.2), 0.5) * env(int(RATE * 0.12), 0.001, 4), b * 4 + k, 0.2)
        put(noise(0.03, 0.0) * env(int(RATE * 0.03), 0.001, 5), b * 4 + k + 0.5, 0.06)
os.makedirs(MUSIC, exist_ok=True)
save_wav(os.path.join(MUSIC, "loop.wav"), song, 0.6)
print("sfx + music written")
