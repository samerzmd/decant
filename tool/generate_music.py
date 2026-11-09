#!/usr/bin/env python3
"""
Decant — optional background music generator.

Composes and synthesizes calm, ASMR-style music loops that play *on top of*
the ambient bed. Like every other Decant sound they are original and CC0.

    python3 -m pip install numpy scipy      # once
    python3 tool/generate_music.py           # needs `ffmpeg` with libvorbis

Output: assets/sounds/music_*.ogg  (44.1 kHz, stereo, Ogg Vorbis)
        lib/audio/music_catalog.g.dart  (the app's music catalog)

The 3 original 96 s tracks are composed below; the other 50 (64 s loops), the
instruments, the composition engine and the catalog live in
`tool/music_library.py`. Twilight Pad comes from `generate_ambient.make_pad`.

* Every track is diatonic to C major / A minor and melodies use the C major
  pentatonic scale. The ambient beds are unpitched nature sounds, so any music
  track sits cleanly over any bed.
* Tempo and bar count are chosen so the loop is a whole number of bars and
  notes/reverb wrap around the loop end: it repeats seamlessly.
* Melodies are generated (seeded, so reproducible) with stepwise motion,
  chord-tone landings on downbeats and breathing rests at phrase ends, so the
  96 s loop doesn't sound like one short phrase on repeat.
"""
import math

import numpy as np

from generate_ambient import PACKS, SR, filt, master, place, reverb, save

DUR = 96.0
N = int(SR * DUR)

PENTA = {0, 2, 4, 7, 9}          # C major pentatonic pitch classes

# Chords as [bass, voicing...] (MIDI). All diatonic to C major.
AM7 = [45, 57, 60, 64, 67]       # A  | A C E G
FMAJ7 = [41, 57, 60, 64, 65]     # F  | A C E F
CMAJ7 = [48, 55, 59, 60, 64]     # C  | G B C E
G6 = [43, 55, 59, 62, 64]        # G  | G B D E


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# --------------------------------------------------------------------------- #
# Instruments
# --------------------------------------------------------------------------- #
def music_box_note(m, vel, rng):
    """Plucked metal comb tine: inharmonic partials, fast decay, tiny click."""
    f = hz(m)
    L = int(2.8 * SR)
    t = np.arange(L) / SR
    k = (f / 523.0) ** 0.5                      # higher tines die faster
    x = np.zeros(L)
    for ratio, amp, dec in ((1.0, 1.0, 1.4), (2.0, 0.30, 3.2), (3.0, 0.10, 4.5),
                            (4.16, 0.18, 6.5), (5.43, 0.08, 9.0), (6.79, 0.04, 12.0)):
        if f * ratio > 15000:
            continue
        x += amp * np.sin(2 * math.pi * f * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t * dec * k)
    x *= np.minimum(1.0, t / 0.0015)
    cl = int(0.004 * SR)
    x[:cl] += 0.12 * filt(rng.standard_normal(cl), "highpass", 3000) * np.exp(-np.arange(cl) / (0.0008 * SR))
    return vel * x


def felt_piano_note(m, vel, dur, rng):
    """Soft 'felt' piano: two slightly detuned strings with inharmonic
    partials, per-partial decay, felt hammer thump, damper on release, and a
    velocity-dependent low-pass (the felt muting)."""
    f = hz(m)
    tail = 1.4
    L = int((dur + tail) * SR)
    t = np.arange(L) / SR
    x = np.zeros(L)
    bright = 0.5 + 0.9 * vel
    tau0 = 4.0 * (261.6 / f) ** 0.5
    for k in range(1, 15):
        fk = k * f * math.sqrt(1 + 0.00032 * k * k)
        if fk > 9000:
            break
        amp = k ** -1.3 * math.exp(-(k - 1) / (3.0 * bright))
        tau = tau0 / (1 + 0.28 * (k - 1))
        for cents in (-0.7, 0.7):
            fs = fk * 2 ** (cents / 1200)
            x += 0.5 * amp * np.sin(2 * math.pi * fs * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    env = np.minimum(1.0, t / 0.004)
    env *= np.where(t < dur, 1.0, np.clip(1 - (t - dur) / 0.45, 0, 1) ** 2)
    x *= env
    hl = int(0.03 * SR)
    x[:hl] += 0.06 * filt(rng.standard_normal(hl), "lowpass", 900) * np.exp(-np.arange(hl) / (0.006 * SR))
    x = filt(x, "lowpass", 1400 + 2600 * vel)
    return vel * x


def keys_note(m, vel, dur, rng):
    """Warm electric-piano tone: 1:1 FM with decaying index + a short tine."""
    f = hz(m)
    tail = 1.1
    L = int((dur + tail) * SR)
    t = np.arange(L) / SR
    idx = (0.8 + 1.8 * vel) * np.exp(-t / 0.4) + 0.15
    ph = rng.uniform(0, 6.28)
    car = np.sin(2 * math.pi * f * t + idx * np.sin(2 * math.pi * f * t + ph))
    tine = 0.12 * vel * np.sin(2 * math.pi * f * 7.02 * t) * np.exp(-t / 0.025)
    env = np.exp(-t / (3.0 * (261.6 / f) ** 0.4)) * np.minimum(1.0, t / 0.003)
    env *= np.where(t < dur, 1.0, np.clip(1 - (t - dur) / 0.35, 0, 1) ** 2)
    return vel * filt((car + tine) * env, "lowpass", 3800)


def soft_bass(m, vel, dur):
    f = hz(m)
    L = int((dur + 0.6) * SR)
    t = np.arange(L) / SR
    env = np.minimum(1.0, t / 0.12) * np.where(t < dur, 1.0, np.clip(1 - (t - dur) / 0.5, 0, 1))
    x = np.sin(2 * math.pi * f * t) + 0.15 * np.sin(4 * math.pi * f * t)
    return vel * x * env * np.exp(-t / 6.0)


# --------------------------------------------------------------------------- #
# Composition helpers
# --------------------------------------------------------------------------- #
def melody(rng, prog, bars, bpb, lo, hi, durs, dur_p, rest_p):
    """Generate (beat, midi, dur_beats, vel) events over `bars` bars."""
    pool = [m for m in range(lo, hi + 1) if m % 12 in PENTA]
    cur = pool[len(pool) // 2]
    events = []
    beat = 0.0
    total = bars * bpb
    while beat < total - 1e-6:
        bar = int(beat // bpb)
        pos = beat - bar * bpb
        if bar % 2 == 1 and pos >= bpb - 1.5 and rng.random() < 0.75:
            beat = (bar + 1) * bpb                     # breathe at phrase ends
            continue
        d = float(rng.choice(durs, p=dur_p))
        d = min(d, total - beat)
        if rng.random() < rest_p:
            beat += d
            continue
        i = pool.index(cur)
        step = int(rng.choice([-3, -2, -1, 0, 1, 2, 3], p=[.05, .17, .26, .04, .26, .17, .05]))
        cur = pool[int(np.clip(i + step, 0, len(pool) - 1))]
        if pos < 1e-6:                                 # land on a chord tone
            pcs = {n % 12 for n in prog[bar % len(prog)][1:]}
            cands = [p for p in pool if p % 12 in pcs]
            if cands:
                cur = min(cands, key=lambda p: abs(p - cur))
        vel = 0.5 + 0.25 * rng.random() + (0.1 if pos < 1e-6 else 0.0)
        events.append((beat, cur, d, vel))
        beat += d
    return events


def jitter(rng, s=0.008):
    return float(rng.normal(0, s))


# --------------------------------------------------------------------------- #
# Tracks
# --------------------------------------------------------------------------- #
def make_music_box(rng):
    bpm, bpb = 80, 4
    beat_s = 60.0 / bpm
    bars = int(round(DUR / (bpb * beat_s)))            # 32 bars
    prog = [AM7, FMAJ7, CMAJ7, G6, FMAJ7, G6, AM7, AM7]
    out = np.zeros((2, N))

    for bar in range(bars):                            # gentle arpeggio
        ch = prog[bar % len(prog)]
        voic = [n + 12 for n in ch[1:]]
        for b, vi in enumerate((0, 1, 2, 1)):
            st = (bar * bpb + b) * beat_s + jitter(rng)
            place(out, st, music_box_note(voic[vi], 0.30 + 0.08 * rng.random(), rng), -0.25)
        place(out, bar * bpb * beat_s, music_box_note(ch[0] + 24, 0.38, rng), -0.1)

    for beat, m, d, vel in melody(rng, prog, bars, bpb, 72, 91,
                                  [0.5, 1.0, 1.5, 2.0], [0.45, 0.35, 0.1, 0.1], 0.15):
        place(out, beat * beat_s + jitter(rng), music_box_note(m, vel * 0.8, rng), 0.2)

    out = reverb(out, rng, rt60=2.8, predelay=0.025, wet=0.4)
    return master(out, rms_db=-22.0)


def make_felt_piano(rng):
    bpm, bpb = 60, 4
    beat_s = 60.0 / bpm
    bars = int(round(DUR / (bpb * beat_s)))            # 24 bars
    prog = [AM7, FMAJ7, CMAJ7, G6, FMAJ7, G6, CMAJ7, AM7]
    out = np.zeros((2, N))
    pan = lambda m: float(np.clip((m - 64) / 36.0, -0.7, 0.7))

    for bar in range(bars):                            # pedalled broken chords
        ch = prog[bar % len(prog)]
        t0 = bar * bpb * beat_s
        bass = ch[0] + 12 if ch[0] < 45 else ch[0]
        place(out, t0 + jitter(rng), felt_piano_note(bass, 0.5, 3.9, rng), pan(bass))
        for b, n in zip((1, 2, 3), (ch[1], ch[3], ch[2])):
            st = t0 + b * beat_s + jitter(rng, 0.012)
            place(out, st, felt_piano_note(n, 0.32 + 0.08 * rng.random(), (4 - b) * beat_s, rng), pan(n))

    for beat, m, d, vel in melody(rng, prog, bars, bpb, 67, 84,
                                  [0.5, 1.0, 1.5, 2.0, 3.0], [0.1, 0.35, 0.2, 0.25, 0.1], 0.2):
        place(out, beat * beat_s + jitter(rng, 0.012),
              felt_piano_note(m, vel * 0.85, d * beat_s + 0.3, rng), pan(m))

    out = reverb(out, rng, rt60=3.2, predelay=0.02, wet=0.38)
    return master(out, rms_db=-22.0)


def make_warm_keys(rng):
    bpm, bpb = 70, 4
    beat_s = 60.0 / bpm
    bars = int(round(DUR / (bpb * beat_s)))            # 28 bars
    prog = [AM7, FMAJ7, CMAJ7, G6]
    keys = np.zeros((2, N))
    out = np.zeros((2, N))

    for bar in range(bars):
        ch = prog[bar % len(prog)]
        t0 = bar * bpb * beat_s
        for n in ch[1:]:
            place(keys, t0 + jitter(rng, 0.01), keys_note(n, 0.42, bpb * beat_s - 0.1, rng), 0.0)
        if rng.random() < 0.5:                         # soft restrike on beat 3
            for n in ch[2:]:
                place(keys, t0 + 2.5 * beat_s + jitter(rng, 0.01),
                      keys_note(n, 0.25, 1.4 * beat_s, rng), 0.0)
        place(out, t0, soft_bass(ch[0], 0.55, bpb * beat_s), 0.0)

    for beat, m, d, vel in melody(rng, prog, bars, bpb, 64, 81,
                                  [0.5, 1.0, 1.5, 2.0], [0.25, 0.4, 0.15, 0.2], 0.4):
        place(keys, beat * beat_s + jitter(rng, 0.01), keys_note(m, vel * 0.75, d * beat_s, rng), 0.0)

    # stereo tremolo (whole cycles per loop → seamless)
    t = np.arange(N) / SR
    rate = round(3.0 * DUR) / DUR
    trem = 0.22 * np.sin(2 * math.pi * rate * t)
    keys[0] *= 1 + trem
    keys[1] *= 1 - trem
    out += keys

    out = reverb(out, rng, rt60=2.2, predelay=0.02, wet=0.3)
    return master(out, rms_db=-22.0)


# --------------------------------------------------------------------------- #
import os  # noqa: E402

DART_CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib", "audio",
                            "music_catalog.g.dart")


def write_dart_catalog(catalog, categories):
    """Emit the app's music catalog so Dart and the generator never drift."""
    def const_name(tid):
        return "music" + tid[0].upper() + tid[1:]
    lines = [
        "// GENERATED by tool/generate_music.py — do not edit by hand.",
        "// ignore_for_file: lines_longer_than_80_chars",
        "import 'package:flutter/material.dart';",
        "",
        "import 'music_track.dart';",
        "import 'sound_catalog.dart';",
        "",
        "const List<SoundCategory> kMusicCategories = [",
    ]
    for cid, label, icon in categories:
        lines.append(f"  SoundCategory('{cid}', '{label}', Icons.{icon}),")
    lines += ["];", ""]
    for tid, label, cat, icon, asset, _fn, _seed, rms, _q in catalog:
        esc = label.replace("'", "\\'")
        pack = ", pack: 'music'" if rms is not None else ""
        lines.append(f"const {const_name(tid)} = MusicTrack('{tid}', '{esc}', '{cat}', Icons.{icon}, "
                     f"'{asset}'{pack});")
    lines += ["", "const List<MusicTrack> kMusicCatalog = ["]
    lines += [f"  {const_name(r[0])}," for r in catalog]
    lines += ["];", ""]
    with open(DART_CATALOG, "w") as fh:
        fh.write("\n".join(lines))
    print(f"  wrote {os.path.relpath(DART_CATALOG)} ({len(catalog)} tracks)")


def _render(index):
    from music_library import CATALOG
    tid, _label, _cat, _icon, asset, fn, seed, rms, quality = CATALOG[index]
    rng = np.random.default_rng(seed)
    x = fn(rng)
    if rms is not None:
        x = master(x, rms_db=rms)
    # Originals ship inside the app; library tracks go to the "music" store pack.
    save(asset, x, rng, quality=quality, out_dir=None if rms is None else os.path.join(PACKS, "music"))


def main():
    """python3 tool/generate_music.py [ids...]   (no ids → every track;
    --catalog-only → just rewrite the Dart catalog)."""
    import sys
    from multiprocessing import Pool

    from music_library import CATALOG, CATEGORIES

    args = sys.argv[1:]
    print("Generating Decant background music (CC0):")
    write_dart_catalog(CATALOG, CATEGORIES)
    if "--catalog-only" in args:
        return
    wanted = set(args)
    unknown = wanted - {r[0] for r in CATALOG}
    if unknown:
        raise SystemExit(f"unknown music ids: {sorted(unknown)}")
    idx = [i for i, r in enumerate(CATALOG) if not wanted or r[0] in wanted]
    with Pool() as pool:
        pool.map(_render, idx, chunksize=1)


if __name__ == "__main__":
    main()
