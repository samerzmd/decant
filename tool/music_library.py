"""
Decant — the extended music library: instruments, a small composition engine
and the catalog of all music tracks (the 4 originals + 50 more).

Imported by `tool/generate_music.py`, which renders the tracks and writes the
Dart catalog (`lib/audio/music_catalog.g.dart`). Everything is synthesized from
scratch (CC0).

Harmony: every track uses the C-major pitch set (moods come from different
modal centers — Aeolian, Dorian, Lydian, Mixolydian…) and melodies use a
pentatonic subset of it, so any track sits consonantly over any ambient bed,
including the tuned ones (wind chimes, singing bowl).

Loops are 64 s and always a whole number of bars (bpm = bars·beats·60/64), with
every note and reverb tail wrapping around the loop end → seamless.
"""
import math
import re

import numpy as np

from generate_ambient import SR, bp, filt, lp, make_pad, pink, place, reverb, stereo_noise
from generate_music import (
    felt_piano_note, keys_note, make_felt_piano, make_music_box, make_warm_keys,
    music_box_note, soft_bass,
)

DUR = 64.0
N = int(SR * DUR)
TAU = 2 * math.pi
SCALE = [0, 2, 4, 5, 7, 9, 11]                       # C major
ROMAN = {"i": 0, "ii": 1, "iii": 2, "iv": 3, "v": 4, "vi": 5, "vii": 6}


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# =========================================================================== #
# Instruments — each is note(m, vel, dur_s, rng) -> mono np.array
# =========================================================================== #
def _env(t, dur, attack, release):
    e = np.minimum(1.0, t / max(attack, 1e-4))
    return e * np.where(t < dur, 1.0, np.clip(1 - (t - dur) / max(release, 1e-4), 0, 1) ** 2)


def modal(f, L, modes, rng, attack=0.002):
    """Sum of decaying partials: modes = [(ratio, amp, tau_s)]."""
    t = np.arange(L) / SR
    x = np.zeros(L)
    for ratio, amp, tau in modes:
        if f * ratio > 16000:
            continue
        x += amp * np.sin(TAU * f * ratio * t + rng.uniform(0, TAU)) * np.exp(-t / tau)
    return x * np.minimum(1.0, t / attack)


def pluck(m, vel, dur, rng, pos=0.2, bright=0.5, decay=2.5, bend=0.0):
    """Plucked string (guitar / harp / koto) as a modal model: partial
    amplitudes follow the pluck position, upper partials die faster."""
    f = hz(m)
    L = int((min(dur, 4.0) + decay) * SR)
    t = np.arange(L) / SR
    fb = 1 + bend * np.exp(-t / 0.06)                 # koto-style pitch settle
    x = np.zeros(L)
    tau0 = decay * (261.6 / f) ** 0.3
    for k in range(1, 24):
        fk = k * f * math.sqrt(1 + 0.0001 * k * k)
        if fk > 10000:
            break
        amp = abs(math.sin(math.pi * k * pos)) / k * math.exp(-(k - 1) * (1 - bright) * 0.35)
        tau = tau0 / (1 + 0.16 * (k - 1) * (1.2 - bright))
        x += amp * np.sin(TAU * np.cumsum(fk * fb) / SR + rng.uniform(0, TAU)) * np.exp(-t / tau)
    n = int(0.004 * SR)
    x[:n] += 0.15 * filt(rng.standard_normal(n), "lowpass", 3000 + 4000 * bright)
    x *= np.minimum(1.0, t / 0.0015)
    return vel * x


def guitar(m, vel, dur, rng):
    return pluck(m, vel, dur, rng, pos=0.21, bright=0.45, decay=2.2)


def harp(m, vel, dur, rng):
    return pluck(m, vel, dur, rng, pos=0.5, bright=0.35, decay=3.5)


def koto(m, vel, dur, rng):
    return pluck(m, vel, dur, rng, pos=0.12, bright=0.8, decay=1.6, bend=0.012)


def pluck_bass(m, vel, dur, rng):
    return filt(pluck(m, vel, dur, rng, pos=0.25, bright=0.25, decay=1.4), "lowpass", 900)


def kalimba(m, vel, dur, rng):
    f = hz(m)
    L = int(2.2 * SR)
    x = modal(f, L, [(1, 1.0, 1.1 * (523 / f) ** 0.3), (6.27, 0.22, 0.12), (17.5, 0.06, 0.04)], rng)
    n = int(0.003 * SR)
    x[:n] += 0.2 * filt(rng.standard_normal(n), "bandpass", [1500, 6000])
    return vel * x


def marimba(m, vel, dur, rng):
    f = hz(m)
    L = int(1.6 * SR)
    x = modal(f, L, [(1, 1.0, 0.55 * (261 / f) ** 0.4), (3.93, 0.32, 0.12), (9.9, 0.08, 0.04)], rng, 0.003)
    n = int(0.01 * SR)
    x[:n] += 0.12 * filt(rng.standard_normal(n), "lowpass", 1500) * np.exp(-np.arange(n) / (0.002 * SR))
    return vel * x


def vibes(m, vel, dur, rng):
    f = hz(m)
    L = int((min(dur, 3.0) + 2.5) * SR)
    t = np.arange(L) / SR
    x = modal(f, L, [(1, 1.0, 2.6), (4.0, 0.25, 0.6), (10.0, 0.05, 0.15)], rng)
    trem = 1 + 0.28 * np.sin(TAU * 5.5 * t + rng.uniform(0, TAU))
    return vel * x * trem * _env(t, dur + 0.5, 0.002, 0.8)


def handpan(m, vel, dur, rng):
    f = hz(m)
    L = int(4.5 * SR)
    t = np.arange(L) / SR
    x = np.zeros(L)
    for ratio, amp, tau in ((1, 1.0, 3.0), (2.0, 0.42, 1.8), (3.0, 0.2, 1.1)):
        for det in (-0.6, 0.6):
            x += 0.5 * amp * np.sin(TAU * (f * ratio + det) * t + rng.uniform(0, TAU)) * np.exp(-t / tau)
    return vel * x * np.minimum(1.0, t / 0.008)


def celesta(m, vel, dur, rng):
    return vel * modal(hz(m), int(2.2 * SR), [(1, 1.0, 1.6), (4.0, 0.18, 0.35), (3.0, 0.08, 0.5)], rng)


def glock(m, vel, dur, rng):
    return vel * modal(hz(m), int(2.6 * SR), [(1, 1.0, 1.9), (2.76, 0.35, 0.7), (5.4, 0.15, 0.25)], rng)


def flute(m, vel, dur, rng):
    f = hz(m)
    L = int((dur + 0.25) * SR)
    t = np.arange(L) / SR
    vib = 1 + 0.006 * np.sin(TAU * 5.0 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    ph = TAU * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    env = _env(t, dur, 0.07, 0.18)
    breath = filt(rng.standard_normal(L), "bandpass", [min(f * 1.5, 8000), min(f * 4, 12000)]) * 0.07
    chiff = filt(rng.standard_normal(L), "bandpass", [1000, 5000]) * np.exp(-t / 0.03) * 0.15
    return vel * (tone + breath) * env + vel * chiff


def pad(m, vel, dur, rng):
    f = hz(m)
    L = int((dur + 1.6) * SR)
    t = np.arange(L) / SR
    x = np.zeros(L)
    for k in range(1, 9):
        if f * k > 5000:
            break
        for c in (-5, 5):
            x += k ** -1.6 * np.sin(TAU * f * k * 2 ** (c / 1200) * t + rng.uniform(0, TAU))
    return vel * 0.5 * x * _env(t, dur, 1.2, 1.5)


def strings(m, vel, dur, rng):
    f = hz(m)
    L = int((dur + 1.4) * SR)
    t = np.arange(L) / SR
    x = np.zeros(L)
    for c in (-8, 0, 8):
        vib = 1 + 0.003 * np.sin(TAU * rng.uniform(4.5, 5.5) * t + rng.uniform(0, TAU))
        ph = TAU * np.cumsum(f * 2 ** (c / 1200) * vib) / SR
        for k in range(1, 20):
            if f * k > 4500:
                break
            x += np.sin(k * ph) / k
    x = filt(x, "lowpass", 2800)
    return vel * 0.25 * x * _env(t, dur, 0.9, 1.2)


def sine_bass(m, vel, dur, rng):
    return soft_bass(m, vel, dur)


INSTR = {
    "piano": felt_piano_note, "keys": keys_note, "musicbox": lambda m, v, d, r: music_box_note(m, v, r),
    "guitar": guitar, "harp": harp, "koto": koto, "kalimba": kalimba, "marimba": marimba,
    "vibes": vibes, "handpan": handpan, "celesta": celesta, "glock": glock, "flute": flute,
    "pad": pad, "strings": strings, "sinebass": sine_bass, "pluckbass": pluck_bass,
}


# =========================================================================== #
# Harmony + melody
# =========================================================================== #
def chord(sym):
    """Roman numeral in C major → [bass, voicing...] (MIDI)."""
    mt = re.match(r"(vii|iii|ii|iv|vi|v|i)(.*)", sym, re.I)
    deg = ROMAN[mt.group(1).lower()]
    ext = mt.group(2)
    tones = [deg, deg + 2, deg + 4]
    if ext in ("7", "9"):
        tones.append(deg + 6)
    if ext in ("9", "add9"):
        tones.append(deg + 8)
    if ext == "sus2":
        tones[1] = deg + 1
    if ext == "sus4":
        tones[1] = deg + 3
    bass = 36 + SCALE[deg % 7]
    if bass < 40:
        bass += 12
    voicing = set()
    for tn in tones:
        n = 48 + SCALE[tn % 7]
        while n < 52:
            n += 12
        voicing.add(n)
    return [bass] + sorted(voicing)


def penta_set(root):
    return {(root + s) % 12 for s in (0, 2, 4, 7, 9)}


DENSITY = {
    "sparse": ([1.0, 1.5, 2.0, 3.0], [0.3, 0.2, 0.3, 0.2], 0.35),
    "medium": ([0.5, 1.0, 1.5, 2.0], [0.25, 0.4, 0.15, 0.2], 0.2),
    "busy": ([0.5, 1.0, 1.5], [0.55, 0.35, 0.1], 0.12),
}


def melody(rng, bar_chords, bpb, lo, hi, density, penta=0):
    durs, dur_p, rest_p = DENSITY[density]
    pcs_ok = penta_set(penta)
    pool = [m for m in range(lo, hi + 1) if m % 12 in pcs_ok]
    cur = pool[len(pool) // 2]
    bars = len(bar_chords)
    total = bars * bpb
    beat = 0.0
    events = []
    while beat < total - 1e-6:
        bar = int(beat // bpb)
        pos = beat - bar * bpb
        if bar % 2 == 1 and pos >= bpb - 1.5 and rng.random() < 0.75:
            beat = (bar + 1) * bpb
            continue
        d = min(float(rng.choice(durs, p=dur_p)), total - beat)
        if rng.random() < rest_p:
            beat += d
            continue
        i = pool.index(cur)
        step = int(rng.choice([-3, -2, -1, 0, 1, 2, 3], p=[.05, .17, .26, .04, .26, .17, .05]))
        cur = pool[int(np.clip(i + step, 0, len(pool) - 1))]
        if pos < 1e-6:
            pcs = {n % 12 for n in bar_chords[bar][1:]}
            cands = [p for p in pool if p % 12 in pcs]
            if cands:
                cur = min(cands, key=lambda p: abs(p - cur))
        events.append((beat, cur, d, 0.5 + 0.25 * rng.random() + (0.1 if pos < 1e-6 else 0)))
        beat += d
    return events


# =========================================================================== #
# Drums + texture
# =========================================================================== #
def kick(rng):
    L = int(0.35 * SR)
    t = np.arange(L) / SR
    f = 48 + 70 * np.exp(-t / 0.03)
    return np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.18) * np.minimum(1, t / 0.002)


def brush(rng):
    L = int(0.25 * SR)
    t = np.arange(L) / SR
    return filt(rng.standard_normal(L), "bandpass", [1500, 7000]) * np.minimum(1, t / 0.012) * np.exp(-t / 0.08)


def hat(rng):
    L = int(0.06 * SR)
    t = np.arange(L) / SR
    return filt(rng.standard_normal(L), "highpass", 7000) * np.exp(-t / 0.018)


def drums(rng, out, bars, bpb, beat_s, style):
    swing = 0.58 if style == "lofi" else 0.5
    for bar in range(bars):
        t0 = bar * bpb * beat_s
        hits = [(0.0, kick, 0.55), (2.0 + (0.5 if rng.random() < 0.5 else 0.0), kick, 0.4),
                (1.0, brush, 0.3), (3.0, brush, 0.3)]
        if rng.random() < 0.3:
            hits.append((3.5, brush, 0.12))
        for b, fn, a in hits:
            place(out, t0 + b * beat_s + rng.normal(0, 0.004), fn(rng) * a * rng.uniform(0.85, 1.0), 0.0)
        if style == "lofi":
            for e in range(8):
                off = (e // 2) + (swing if e % 2 else 0.0)
                place(out, t0 + off * beat_s + rng.normal(0, 0.003),
                      hat(rng) * (0.07 if e % 2 else 0.11) * rng.uniform(0.7, 1.0), 0.25)


def vinyl(rng, out, amount=1.0):
    out += 0.004 * amount * stereo_noise(rng, lambda f: bp(f, 200, 9000) * pink(f), corr=0.3, n=N)
    for st in np.sort(rng.uniform(0, DUR, int(rng.poisson(5 * DUR * amount)))):
        L = max(4, int(rng.uniform(0.0005, 0.002) * SR))
        ev = filt(rng.standard_normal(L), "highpass", 1500) * rng.lognormal(-4.0, 0.7)
        place(out, st, ev, rng.uniform(-0.6, 0.6))


# =========================================================================== #
# The composition engine
# =========================================================================== #
def compose(rng, spec):
    bpb = spec.get("meter", 4)
    bars = spec["bars"]
    beat_s = DUR / (bars * bpb)
    bar_s = bpb * beat_s
    prog = [chord(s) for s in spec["prog"]]
    cb = spec.get("chord_bars", 1)
    bar_chords = [prog[(b // cb) % len(prog)] for b in range(bars)]
    out = np.zeros((2, N))

    def jit(s=0.008):
        return float(rng.normal(0, s))

    # ---- chord layers ----------------------------------------------------- #
    for style, inst_name, gain in spec.get("chords", []):
        inst = INSTR[inst_name]
        b = 0
        while b < bars:
            ch = bar_chords[b]
            span = 1
            while style == "pad" and b + span < bars and bar_chords[b + span] is ch:
                span += 1
            t0 = b * bar_s
            voic = ch[1:]
            pans = np.linspace(-0.45, 0.45, len(voic))
            if style == "pad":
                for n, p in zip(voic, pans):
                    place(out, t0 + jit(0.02), inst(n, 0.35 * gain, span * bar_s - 0.2, rng), p)
            elif style == "block":
                for n, p in zip(voic, pans):
                    place(out, t0 + jit(0.01), inst(n, 0.36 * gain, bar_s * 0.9, rng), p)
                if rng.random() < 0.5:
                    for n, p in zip(voic[1:], pans[1:]):
                        place(out, t0 + (bpb - 1.5) * beat_s + jit(0.01),
                              inst(n, 0.22 * gain, beat_s * 1.4, rng), p)
            elif style == "broken":
                bn = ch[0] + 12 if ch[0] < 45 else ch[0]
                place(out, t0 + jit(), inst(bn, 0.45 * gain, bar_s - 0.1, rng), -0.3)
                order = [voic[0], voic[min(2, len(voic) - 1)], voic[1]]
                for k in range(1, bpb):
                    n = order[(k - 1) % len(order)]
                    place(out, t0 + k * beat_s + jit(0.012),
                          inst(n, (0.3 + 0.08 * rng.random()) * gain, (bpb - k) * beat_s, rng),
                          float(np.clip((n - 62) / 30, -0.6, 0.6)))
            elif style in ("arp8", "arp4"):
                step = 0.5 if style == "arp8" else 1.0
                seq = voic + voic[-2:0:-1]
                k = 0
                while k * step < bpb - 1e-6:
                    n = seq[k % len(seq)]
                    place(out, t0 + k * step * beat_s + jit(),
                          inst(n, (0.28 + 0.08 * rng.random()) * gain, step * beat_s * 1.6, rng),
                          float(np.clip((n - 60) / 20, -0.6, 0.6)))
                    k += 1
            elif style == "arp3":
                bn = ch[0] + 12 if ch[0] < 45 else ch[0]
                place(out, t0 + jit(), inst(bn, 0.4 * gain, bar_s, rng), -0.25)
                for k in (1, 2):
                    for n in voic[1:3]:
                        place(out, t0 + k * beat_s + jit(0.01), inst(n, 0.24 * gain, beat_s * 1.2, rng),
                              float(np.clip((n - 60) / 20, -0.5, 0.5)))
            elif style == "strum":
                notes = [ch[0] + 12] + voic
                for beat_pos, down, v in ((0, True, 0.34), (2, True, 0.28), (3.5, False, 0.18)):
                    if beat_pos >= bpb:
                        continue
                    seq = notes if down else notes[::-1][:3]
                    for i, n in enumerate(seq):
                        place(out, t0 + beat_pos * beat_s + i * 0.016 + jit(0.004),
                              inst(n, v * gain, beat_s * 1.8, rng), float(np.clip((n - 58) / 30, -0.5, 0.5)))
            b += span

    # ---- bass ------------------------------------------------------------- #
    bass = spec.get("bass")
    if bass:
        inst = INSTR[bass]
        for b in range(bars):
            ch = bar_chords[b]
            t0 = b * bar_s
            if bass == "sinebass":
                place(out, t0, inst(ch[0], 0.5, bar_s, rng), 0.0)
            else:
                place(out, t0 + jit(), inst(ch[0], 0.55, beat_s * 1.8, rng), 0.0)
                if bpb == 4:
                    n2 = ch[0] + 7 if rng.random() < 0.6 else ch[0]
                    place(out, t0 + 2 * beat_s + jit(), inst(n2, 0.42, beat_s * 1.6, rng), 0.0)

    # ---- melody + counter-melody ----------------------------------------- #
    mel = spec.get("melody")
    if mel:
        name, lo, hi, dens, gain = mel
        inst = INSTR[name]
        for beat, m, d, vel in melody(rng, bar_chords, bpb, lo, hi, dens, spec.get("penta", 0)):
            place(out, beat * beat_s + jit(0.01), inst(m, vel * 0.8 * gain, d * beat_s, rng), 0.15)
    ctr = spec.get("counter")
    if ctr:
        name, prob, gain = ctr
        inst = INSTR[name]
        for b in range(bars):
            if rng.random() > prob:
                continue
            ch = bar_chords[b]
            n = int(rng.choice(ch[1:])) + 12 * int(rng.integers(1, 3))
            pos = float(rng.choice(np.arange(0, bpb, 0.5)))
            place(out, b * bar_s + pos * beat_s, inst(n, 0.3 * gain, beat_s * 2, rng), rng.uniform(-0.6, 0.6))

    # ---- rhythm + texture ------------------------------------------------- #
    if spec.get("drums") and bpb == 4:
        drums(rng, out, bars, bpb, beat_s, spec["drums"])
    if spec.get("vinyl"):
        vinyl(rng, out, spec["vinyl"])

    rt60, wet = spec.get("reverb", (2.4, 0.32))
    out = reverb(out, rng, rt60=rt60, predelay=0.02, wet=wet)
    if spec.get("vinyl"):                    # tape warmth: circular low-pass → seamless
        g = lp(np.fft.rfftfreq(N, 1.0 / SR), 5200, 2)
        out = np.stack([np.fft.irfft(np.fft.rfft(c) * g, N) for c in out])
    return out


# =========================================================================== #
# The 50 new tracks: (id, label, category, spec)
# =========================================================================== #
P = "piano"
NEW = [
    # ---- Piano ----------------------------------------------------------- #
    ("quietHours", "Quiet Hours", "piano", dict(bars=16, prog=["vi7", "IV7", "I7", "V"],
        chords=[("broken", P, 1.0)], melody=(P, 67, 84, "sparse", 1.0), reverb=(3.2, 0.38))),
    ("paperMoon", "Paper Moon", "piano", dict(meter=3, bars=22, prog=["I7", "iii7", "vi7", "IV7"],
        chords=[("arp3", P, 1.0)], melody=(P, 67, 84, "medium", 1.0), reverb=(3.0, 0.36))),
    ("firstSnow", "First Snow", "piano", dict(bars=14, prog=["IV9", "I", "vi7", "V"],
        chords=[("broken", P, 1.0)], melody=(P, 69, 86, "sparse", 1.0), counter=("glock", 0.35, 0.6),
        reverb=(3.4, 0.4))),
    ("slowTide", "Slow Tide", "piano", dict(bars=16, prog=["ii7", "V", "I7", "vi7"],
        chords=[("pad", "strings", 0.8)], melody=(P, 64, 81, "sparse", 1.1), bass="sinebass",
        reverb=(3.0, 0.36))),
    ("lanternLight", "Lantern Light", "piano", dict(bars=18, prog=["I", "V", "vi7", "IV7"],
        chords=[("arp8", P, 0.8)], melody=(P, 72, 88, "medium", 1.0), reverb=(2.8, 0.34))),
    ("stillWater", "Still Water", "piano", dict(bars=12, prog=["vi9", "IV7"], chord_bars=2,
        chords=[("broken", P, 1.0)], counter=("celesta", 0.5, 0.6), melody=(P, 69, 84, "sparse", 0.9),
        reverb=(3.6, 0.42))),
    # ---- Keys ------------------------------------------------------------ #
    ("velvetEvening", "Velvet Evening", "keys", dict(bars=20, prog=["ii9", "V", "I7", "vi7"],
        chords=[("block", "keys", 1.0)], bass="sinebass", melody=("keys", 64, 81, "medium", 1.0),
        reverb=(2.2, 0.3))),
    ("softFocus", "Soft Focus", "keys", dict(bars=18, prog=["IV7", "iii7", "ii7", "I7"],
        chords=[("pad", "pad", 0.9)], melody=("keys", 64, 81, "sparse", 1.1), bass="sinebass",
        reverb=(2.6, 0.34))),
    ("lateBloom", "Late Bloom", "keys", dict(bars=16, prog=["vi7", "ii7", "V", "I7"],
        chords=[("arp8", "keys", 0.9)], melody=("vibes", 67, 84, "sparse", 0.9), bass="pluckbass",
        reverb=(2.4, 0.32))),
    ("amberGlow", "Amber Glow", "keys", dict(bars=20, prog=["I7", "vi7", "IV7", "V"],
        chords=[("block", "keys", 1.0)], bass="pluckbass", drums="soft",
        melody=("keys", 65, 82, "medium", 1.0), reverb=(2.0, 0.28))),
    ("nightBus", "Night Bus", "keys", dict(bars=22, prog=["vi7", "IV7", "I", "V"],
        chords=[("block", "keys", 1.0)], bass="sinebass", drums="lofi", vinyl=0.6,
        melody=("keys", 64, 79, "medium", 0.9), reverb=(1.8, 0.26))),
    ("blueHour", "Blue Hour", "keys", dict(bars=16, prog=["ii7", "iii7", "IV7", "V"],
        chords=[("pad", "strings", 0.8)], melody=("keys", 64, 81, "sparse", 1.1), bass="sinebass",
        reverb=(2.8, 0.34))),
    # ---- Bells ----------------------------------------------------------- #
    ("glassGarden", "Glass Garden", "bells", dict(bars=20, prog=["I", "IV7", "vi7", "V"],
        chords=[("arp8", "celesta", 0.7)], melody=("musicbox", 72, 91, "busy", 0.9), reverb=(2.8, 0.38))),
    ("starlitLullaby", "Starlit Lullaby", "bells", dict(meter=3, bars=24, prog=["I", "IV", "I", "V"],
        chords=[("arp3", "musicbox", 0.9)], melody=("glock", 72, 88, "sparse", 0.8), reverb=(3.0, 0.4))),
    ("celestaDreams", "Celesta Dreams", "bells", dict(bars=18, prog=["IV7", "I7", "V", "vi7"],
        chords=[("pad", "pad", 0.8)], melody=("celesta", 72, 89, "medium", 1.0),
        counter=("musicbox", 0.4, 0.6), reverb=(3.0, 0.4))),
    ("snowGlobe", "Snow Globe", "bells", dict(bars=22, prog=["I", "vi7", "IV", "V"],
        chords=[("arp8", "musicbox", 0.7)], melody=("celesta", 74, 91, "medium", 0.9), reverb=(2.8, 0.38))),
    ("tinyLights", "Tiny Lights", "bells", dict(bars=24, prog=["vi", "IV", "I", "V"],
        chords=[("arp4", "glock", 0.6)], melody=("musicbox", 72, 91, "busy", 0.9), reverb=(2.6, 0.36))),
    ("crystalSteps", "Crystal Steps", "bells", dict(bars=16, prog=["ii7", "V", "I7", "IV7"],
        chords=[("pad", "pad", 0.8)], melody=("glock", 76, 93, "sparse", 0.8),
        counter=("kalimba", 0.5, 0.7), reverb=(3.2, 0.42))),
    # ---- Strings --------------------------------------------------------- #
    ("nylonAfternoon", "Nylon Afternoon", "strings", dict(bars=20, prog=["I7", "vi7", "ii7", "V"],
        chords=[("arp8", "guitar", 0.9)], melody=("guitar", 64, 81, "medium", 1.0), bass="pluckbass",
        reverb=(1.8, 0.26))),
    ("harpOfDawn", "Harp of Dawn", "strings", dict(bars=18, prog=["IV9", "I", "V", "vi7"],
        chords=[("arp8", "harp", 0.9), ("pad", "pad", 0.5)], melody=("harp", 72, 88, "sparse", 1.0),
        reverb=(3.0, 0.38))),
    ("kotoGarden", "Koto Garden", "strings", dict(bars=16, prog=["vi", "iii", "IV", "vi"],
        chords=[("pad", "pad", 0.7)], melody=("koto", 64, 81, "medium", 1.1), reverb=(2.6, 0.34))),
    ("gentleStrum", "Gentle Strum", "strings", dict(bars=22, prog=["I", "V", "vi7", "IV"],
        chords=[("strum", "guitar", 0.9)], melody=("guitar", 67, 84, "sparse", 0.9), bass="pluckbass",
        reverb=(1.6, 0.24))),
    ("riversideGuitar", "Riverside Guitar", "strings", dict(meter=3, bars=22, prog=["vi7", "IV7", "I", "V"],
        chords=[("arp3", "guitar", 1.0)], melody=("guitar", 64, 81, "medium", 1.0), reverb=(2.0, 0.28))),
    ("harpLullaby", "Harp Lullaby", "strings", dict(meter=3, bars=20, prog=["I", "IV", "vi", "V"],
        chords=[("arp3", "harp", 1.0), ("pad", "pad", 0.4)], melody=("harp", 69, 86, "sparse", 1.0),
        reverb=(3.2, 0.4))),
    ("silkRoad", "Silk Road", "strings", dict(bars=18, prog=["V", "IV", "I", "V"], penta=7,
        chords=[("pad", "pad", 0.7)], melody=("koto", 67, 84, "busy", 1.0), counter=("kalimba", 0.4, 0.6),
        reverb=(2.4, 0.32))),
    # ---- Mallets --------------------------------------------------------- #
    ("kalimbaSunrise", "Kalimba Sunrise", "mallets", dict(bars=20, prog=["I", "vi7", "IV7", "V"],
        chords=[("arp8", "kalimba", 0.7)], melody=("kalimba", 72, 88, "medium", 1.0), bass="sinebass",
        reverb=(2.2, 0.3))),
    ("marimbaBreeze", "Marimba Breeze", "mallets", dict(bars=22, prog=["vi7", "ii7", "V", "I7"],
        chords=[("arp8", "marimba", 0.8)], melody=("marimba", 67, 84, "medium", 1.0), bass="pluckbass",
        drums="soft", reverb=(1.8, 0.26))),
    ("vibraphoneNight", "Vibraphone Night", "mallets", dict(bars=16, prog=["ii9", "V", "I7", "vi7"],
        chords=[("block", "vibes", 0.8)], melody=("vibes", 67, 84, "sparse", 1.0), bass="pluckbass",
        reverb=(2.4, 0.32))),
    ("handpanMeditation", "Handpan Meditation", "mallets", dict(bars=14, prog=["vi", "IV", "I", "V"],
        chords=[("arp4", "handpan", 0.7), ("pad", "pad", 0.4)], melody=("handpan", 62, 79, "sparse", 1.0),
        reverb=(3.0, 0.38))),
    ("woodenDreams", "Wooden Dreams", "mallets", dict(meter=3, bars=24, prog=["I", "iii", "IV", "V"],
        chords=[("arp3", "marimba", 0.9)], melody=("marimba", 72, 88, "sparse", 0.9), reverb=(2.2, 0.3))),
    ("handpanFlow", "Handpan Flow", "mallets", dict(bars=18, prog=["vi", "V", "IV", "V"],
        chords=[("arp8", "handpan", 0.6)], melody=("handpan", 64, 81, "medium", 0.9), drums="soft",
        reverb=(2.6, 0.34))),
    ("kalimbaLullaby", "Kalimba Lullaby", "mallets", dict(meter=3, bars=20, prog=["I", "vi", "IV", "V"],
        chords=[("arp3", "kalimba", 0.9)], melody=("musicbox", 74, 91, "sparse", 0.8), reverb=(2.8, 0.36))),
    # ---- Ambient --------------------------------------------------------- #
    ("deepSpace", "Deep Space", "ambient", dict(bars=12, prog=["vi9", "IV9"], chord_bars=3,
        chords=[("pad", "pad", 1.0)], counter=("glock", 0.25, 0.5), bass="sinebass", reverb=(4.5, 0.5))),
    ("aurora", "Aurora", "ambient", dict(bars=14, prog=["IV9", "I9", "V", "vi9"],
        chords=[("pad", "strings", 0.8), ("pad", "pad", 0.6)], melody=("vibes", 72, 88, "sparse", 0.6),
        reverb=(4.2, 0.48))),
    ("floating", "Floating", "ambient", dict(bars=12, prog=["I9", "IV9"], chord_bars=2,
        chords=[("pad", "pad", 1.0)], counter=("handpan", 0.4, 0.7), reverb=(4.5, 0.5))),
    ("morningMist", "Morning Mist", "ambient", dict(bars=16, prog=["ii9", "IV9", "I9", "V"],
        chords=[("pad", "strings", 0.9)], melody=(P, 76, 91, "sparse", 0.6), reverb=(4.0, 0.46))),
    ("northernLights", "Northern Lights", "ambient", dict(bars=14, prog=["vi9", "V", "IV9", "I9"],
        chords=[("pad", "pad", 0.9), ("arp4", "celesta", 0.35)], reverb=(4.2, 0.48))),
    ("weightless", "Weightless", "ambient", dict(bars=12, prog=["IV9", "vi9"], chord_bars=2,
        chords=[("pad", "strings", 0.9)], counter=("kalimba", 0.35, 0.6), reverb=(4.5, 0.5))),
    # ---- Lo-fi ----------------------------------------------------------- #
    ("studySession", "Study Session", "lofi", dict(bars=20, prog=["ii7", "V", "I7", "vi7"],
        chords=[("block", "keys", 1.0)], bass="sinebass", melody=("keys", 64, 79, "medium", 0.9),
        drums="lofi", vinyl=1.0, reverb=(1.6, 0.24))),
    ("coffeeBreak", "Coffee Break", "lofi", dict(bars=22, prog=["IV7", "iii7", "vi7", "V"],
        chords=[("block", P, 1.0)], bass="pluckbass", melody=("vibes", 67, 84, "sparse", 0.9),
        drums="lofi", vinyl=1.0, reverb=(1.6, 0.24))),
    ("cafeWindow", "Café Window", "lofi", dict(bars=20, prog=["vi7", "IV7", "I7", "V"],
        chords=[("arp8", "guitar", 0.8)], bass="pluckbass", melody=("keys", 65, 81, "sparse", 0.9),
        drums="lofi", vinyl=0.8, reverb=(1.6, 0.24))),
    ("sundayMorning", "Sunday Morning", "lofi", dict(bars=18, prog=["I7", "IV7", "ii7", "V"],
        chords=[("block", "keys", 1.0)], melody=("flute", 69, 84, "sparse", 0.8), bass="sinebass",
        drums="lofi", vinyl=0.8, reverb=(1.8, 0.26))),
    ("midnightTape", "Midnight Tape", "lofi", dict(bars=20, prog=["vi9", "ii7", "V", "I7"],
        chords=[("pad", "pad", 0.6), ("block", "keys", 0.8)], melody=("keys", 60, 76, "sparse", 0.9),
        bass="sinebass", drums="lofi", vinyl=1.4, reverb=(1.8, 0.26))),
    ("cozyCorner", "Cozy Corner", "lofi", dict(bars=22, prog=["I", "vi7", "ii7", "V"],
        chords=[("block", P, 1.0)], melody=("kalimba", 72, 86, "medium", 0.9), bass="pluckbass",
        drums="lofi", vinyl=1.0, reverb=(1.6, 0.24))),
    # ---- Flute ----------------------------------------------------------- #
    ("bambooFlute", "Bamboo Flute", "flute", dict(bars=14, prog=["vi", "IV", "I", "V"],
        chords=[("pad", "pad", 0.8)], melody=("flute", 69, 86, "medium", 1.0), reverb=(3.0, 0.38))),
    ("mountainAir", "Mountain Air", "flute", dict(bars=16, prog=["I", "IV9", "vi7", "V"],
        chords=[("arp8", "harp", 0.7)], melody=("flute", 69, 86, "sparse", 1.0), reverb=(2.8, 0.36))),
    ("forestSpirit", "Forest Spirit", "flute", dict(bars=18, prog=["vi7", "V", "IV7", "V"],
        chords=[("pad", "strings", 0.7)], melody=("flute", 67, 84, "medium", 1.0),
        counter=("kalimba", 0.4, 0.6), reverb=(3.0, 0.38))),
    ("eveningBreeze", "Evening Breeze", "flute", dict(meter=3, bars=20, prog=["I", "vi7", "IV", "V"],
        chords=[("arp3", "guitar", 0.9)], melody=("flute", 69, 86, "sparse", 1.0), reverb=(2.2, 0.3))),
    ("zenGarden", "Zen Garden", "flute", dict(bars=12, prog=["vi", "IV"], chord_bars=2,
        chords=[("arp4", "handpan", 0.5)], melody=("flute", 64, 81, "sparse", 1.0),
        counter=("koto", 0.4, 0.6), reverb=(3.4, 0.42))),
    ("shepherdsSong", "Shepherd's Song", "flute", dict(bars=18, prog=["I", "V", "IV", "I"], penta=7,
        chords=[("pad", "pad", 0.7)], bass="pluckbass", melody=("flute", 67, 86, "busy", 1.0),
        reverb=(2.6, 0.34))),
]

CATEGORIES = [  # (id, label, icon)
    ("piano", "Piano", "piano_rounded"),
    ("keys", "Keys", "graphic_eq_rounded"),
    ("bells", "Bells", "notifications_active_rounded"),
    ("strings", "Strings", "queue_music_rounded"),
    ("mallets", "Mallets", "album_rounded"),
    ("ambient", "Ambient", "nightlight_round"),
    ("lofi", "Lo-fi", "headphones_rounded"),
    ("flute", "Flute", "air_rounded"),
]
_CAT_ICON = {c: i for c, _l, i in CATEGORIES}


def _snake(camel):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", camel).lower()


def _make(spec):
    return lambda rng: compose(rng, spec)


# (id, label, category, icon, asset_file, recipe, seed, rms_db or None, quality)
CATALOG = [
    ("twilightPad", "Twilight Pad", "ambient", "nightlight_round", "music_twilight_pad.ogg", make_pad, 11, None, 5),
    ("musicBox", "Music Box", "bells", "toys_rounded", "music_box.ogg", make_music_box, 101, None, 5),
    ("feltPiano", "Felt Piano", "piano", "piano_rounded", "music_felt_piano.ogg", make_felt_piano, 202, None, 5),
    ("warmKeys", "Warm Keys", "keys", "graphic_eq_rounded", "music_warm_keys.ogg", make_warm_keys, 303, None, 5),
] + [
    (tid, label, cat, _CAT_ICON[cat], f"music_{_snake(tid)}.ogg", _make(spec), 2000 + i, -22.0, 3)
    for i, (tid, label, cat, spec) in enumerate(NEW)
]
