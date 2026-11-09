#!/usr/bin/env python3
"""
Decant — ambient bed generator (v2, high quality).

Synthesizes every ambient background loop from scratch, so the beds stay
original and CC0 (public domain) like the rest of Decant's audio. No samples.

    python3 -m pip install numpy scipy      # once
    python3 tool/generate_ambient.py         # needs `ffmpeg` with libvorbis

Output: assets/sounds/ambient_*.ogg  (44.1 kHz, stereo, Ogg Vorbis, 48 s loops)
        lib/audio/ambient_catalog.g.dart  (the app's ambience catalog)

    python3 tool/generate_ambient.py rain cave   # re-render only some beds

The 4 original beds live in this file; the other 50 (and the catalog: ids,
labels, categories, icons) are in `tool/ambient_library.py`.

What makes these sound better than the old 10 s mono WAV beds:

* **Long stereo loops.** 48 s with decorrelated left/right channels, so the
  repetition is hard to notice and the bed has width instead of sitting in
  the middle of your head.
* **Mathematically seamless.** Every noise layer, envelope and reverb tail is
  generated *circularly* (FFT-domain shaping / circular convolution) and every
  event wraps around the loop end, so the last sample flows into the first with
  no crossfade smear and no click.
* **Physically-inspired sources.** Bubbles use the Minnaert model (pitch rises
  as the bubble collapses), rain is thousands of individual drops plus near
  drips, waves have rise / crash / foam-wash phases and drift along the shore,
  fire crackles arrive in clustered flurries with occasional wood pops.
* **A shared acoustic space.** A synthetic stereo reverb with frequency-dependent
  decay glues each bed together.
* **Mastered to a common loudness** (RMS target + soft limiter, TPDF dither),
  so switching beds never jumps in volume.
"""
import math
import os
import shutil
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
DUR = 48.0
N = int(SR * DUR)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
# Store-delivered packs (Play Asset Delivery / iOS On-Demand Resources).
PACKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sound_packs")


# --------------------------------------------------------------------------- #
# Spectral shapes (magnitude responses evaluated on an array of frequencies)
# --------------------------------------------------------------------------- #
def _f(f):
    return np.maximum(f, 1e-3)


def lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (_f(f) / fc) ** (2 * order))


def hp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (fc / _f(f)) ** (2 * order))


def bp(f, lo, hi, order=2):
    return hp(f, lo, order) * lp(f, hi, order)


def pink(f):
    return 1.0 / np.sqrt(_f(f) / 1000.0)


def brown(f):
    return 1.0 / (_f(f) / 1000.0)


def bump(f, center, width_oct, gain):
    """A smooth log-frequency resonance: 1 + gain at `center`."""
    return 1.0 + gain * np.exp(-(np.log2(_f(f) / center) ** 2) / (2 * width_oct ** 2))


# --------------------------------------------------------------------------- #
# Circular (loop-perfect) building blocks
# --------------------------------------------------------------------------- #
def shaped_noise(rng, mag_fn, n=N):
    """Unit-RMS noise with an arbitrary magnitude spectrum, periodic over n."""
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f))) * mag_fn(f)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def stereo_noise(rng, mag_fn, corr=0.3, n=N):
    """Two channels of shaped noise with inter-channel correlation `corr`."""
    a = shaped_noise(rng, mag_fn, n)
    b = shaped_noise(rng, mag_fn, n)
    return np.stack([a, corr * a + math.sqrt(1.0 - corr ** 2) * b])


def slow_env(rng, cutoff_hz, lo, hi, n=N):
    """Smooth random envelope in [lo, hi] that is periodic over the loop."""
    x = shaped_noise(rng, lambda f: np.exp(-((f / cutoff_hz) ** 2)), n)
    x = (x - x.min()) / (x.max() - x.min() + 1e-12)
    return lo + (hi - lo) * x


def pan_gains(pan):
    """Equal-power pan; pan in [-1, 1]."""
    th = (np.clip(pan, -1, 1) + 1.0) * math.pi / 4.0
    return np.cos(th), np.sin(th)


def place(buf, start_s, ev, pan=0.0):
    """Add a mono event into stereo `buf`, wrapping around the loop end."""
    n = buf.shape[1]
    i0 = int(round(start_s * SR)) % n
    idx = (i0 + np.arange(len(ev))) % n
    gl, gr = pan_gains(pan)
    buf[0, idx] += gl * ev
    buf[1, idx] += gr * ev


def place_stereo(buf, start_s, ev2):
    n = buf.shape[1]
    i0 = int(round(start_s * SR)) % n
    idx = (i0 + np.arange(ev2.shape[1])) % n
    buf[0, idx] += ev2[0]
    buf[1, idx] += ev2[1]


def circ_conv(x, ir):
    n = len(x)
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)


def reverb(x, rng, rt60=1.5, predelay=0.015, wet=0.25, hf_ratio=0.45):
    """Synthetic stereo reverb, applied circularly so tails wrap seamlessly.

    The IR is decaying noise whose high band dies `hf_ratio` times faster than
    the low band (air absorption), giving a natural, non-metallic tail. Left
    and right use independent IRs for a wide, enveloping space."""
    length = int(rt60 * 1.1 * SR)
    t = np.arange(length) / SR
    sos_lo = signal.butter(2, 2500, "low", fs=SR, output="sos")
    sos_hi = signal.butter(2, 2500, "high", fs=SR, output="sos")
    pre = np.zeros(int(predelay * SR))
    out = np.empty_like(x)
    for ch in range(2):
        lo = signal.sosfilt(sos_lo, rng.standard_normal(length)) * np.exp(-6.91 * t / rt60)
        hi = signal.sosfilt(sos_hi, rng.standard_normal(length)) * np.exp(
            -6.91 * t / (rt60 * hf_ratio))
        body = (lo + 0.7 * hi) * np.minimum(1.0, t / 0.008)   # soft onset
        ir = np.concatenate([pre, body])
        ir /= np.sqrt(np.sum(ir ** 2))
        out[ch] = math.sqrt(1 - wet) * x[ch] + math.sqrt(wet) * circ_conv(x[ch], ir)
    return out


def filt(x, kind, freq, order=2):
    sos = signal.butter(order, freq, kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def poisson_times(rng, rate, dur=DUR):
    """Event start times from a Poisson process over the loop."""
    count = rng.poisson(rate * dur)
    return np.sort(rng.uniform(0, dur, count))


def clustered_times(rng, cluster_rate, per_cluster, spread, dur=DUR):
    """Bursty event times: clusters of events (fire flurries, bubble runs)."""
    times = []
    for c in poisson_times(rng, cluster_rate, dur):
        k = rng.poisson(per_cluster)
        times.extend((c + np.abs(rng.normal(0, spread, k))) % dur)
    return np.array(sorted(times))


# --------------------------------------------------------------------------- #
# Mastering + output
# --------------------------------------------------------------------------- #
def master(x, rms_db=-22.0, peak_db=-1.0):
    x = x - x.mean(axis=1, keepdims=True)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    x = x * (10 ** (rms_db / 20.0) / rms)
    peak = 10 ** (peak_db / 20.0)
    return peak * np.tanh(x / peak)  # transparent at bed levels, catches spikes


def save(name, x, rng, quality=5, out_dir=None):
    """Dither to 16-bit, then encode to Ogg Vorbis with ffmpeg."""
    tpdf = (rng.uniform(-0.5, 0.5, x.shape) + rng.uniform(-0.5, 0.5, x.shape)) / 32767.0
    pcm = np.clip((x + tpdf) * 32767.0, -32768, 32767).astype(np.int16)
    path = os.path.join(out_dir or OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "bed.wav")
        with wave.open(wav, "w") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.T.copy().tobytes())
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
             "-c:a", "libvorbis", "-q:a", str(quality), path],
            check=True)
    rms = 20 * math.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    print(f"  {name:24s} {x.shape[1] / SR:5.1f}s stereo  "
          f"{os.path.getsize(path) // 1024:5d} KB  RMS {rms:6.1f} dBFS")


# --------------------------------------------------------------------------- #
# Beds
# --------------------------------------------------------------------------- #
def midi_hz(m):
    """MIDI note → Hz, quantized to a whole number of cycles per loop."""
    f = 440.0 * 2 ** ((m - 69) / 12.0)
    return round(f * DUR) / DUR


def make_pad(rng):
    """Twilight Pad: a slowly evolving four-chord pad in a large soft space.

    Shipped as a *music* track (tool/generate_music.py imports it); it lives
    here because it is built on the same 48 s circular helpers as the beds."""
    t = np.arange(N) / SR
    chords = [
        [45, 52, 55, 59, 64],      # Am9   (A E G B E)
        [41, 48, 55, 57, 64],      # Fmaj9 (F C G A E)
        [48, 55, 59, 62, 64],      # Cmaj9 (C G B D E)
        [43, 50, 54, 57, 62],      # G6/9  (G D F# A D)
    ]
    seg = DUR / len(chords)
    fade = 5.0
    out = np.zeros((2, N))
    bright = slow_env(rng, 0.05, 0.22, 0.55)          # filter "opening" over time
    for ci, notes in enumerate(chords):
        center = (ci + 0.5) * seg
        d = np.abs(((t - center + DUR / 2) % DUR) - DUR / 2)
        x = np.clip((seg / 2 + fade / 2 - d) / fade, 0, 1)
        env = np.sin(0.5 * math.pi * x)               # equal-power chord crossfades
        for m in notes:
            f0 = midi_hz(m)
            note_gain = 1.0 if m < 50 else 0.75
            for k in range(1, 9):
                if f0 * k > 6000:
                    break
                amp = note_gain * k ** -1.5 * np.exp(-(k - 1) / (bright * 6))
                for side, cents in ((0, -6.0), (1, +6.0)):   # stereo detune chorus
                    fk = round(f0 * k * 2 ** (cents / 1200) * DUR) / DUR
                    ph = rng.uniform(0, 2 * math.pi)
                    out[side] += env * amp * np.sin(2 * math.pi * fk * t + ph)
        root = midi_hz(notes[0] - 12)                 # soft sub, centered
        out += env * 0.35 * np.sin(2 * math.pi * root * t)
    out /= np.max(np.abs(out)) + 1e-9
    out *= slow_env(rng, 0.08, 0.75, 1.0)

    # shimmer: sparse soft bell tones two octaves up, scattered across the field
    tones = sorted({m + 24 for c in chords for m in c[1:]})
    for st in poisson_times(rng, 0.45):
        m = tones[rng.integers(len(tones))]
        f0 = 440.0 * 2 ** ((m - 69) / 12.0)
        L = int(4.0 * SR)
        tt = np.arange(L) / SR
        ev = np.sin(2 * math.pi * f0 * tt) + 0.25 * np.sin(2 * math.pi * 2.01 * f0 * tt)
        ev *= np.minimum(1, tt / 0.08) * np.exp(-tt / 1.2) * rng.uniform(0.04, 0.09)
        place(out, st, ev, rng.uniform(-0.8, 0.8))

    air = stereo_noise(rng, lambda f: bp(f, 2500, 9000) * pink(f), corr=0.1)
    out += 0.025 * air * slow_env(rng, 0.1, 0.4, 1.0)

    out = reverb(out, rng, rt60=4.5, predelay=0.03, wet=0.45, hf_ratio=0.5)
    return master(out, rms_db=-21.0)


def make_rain(rng):
    """Rain: distant wash + thousands of mid-field drops + near puddle drips."""
    out = np.zeros((2, N))
    intensity = slow_env(rng, 0.04, 0.7, 1.0)

    # 1) the wash — countless far-away drops blur into shaped stereo noise
    wash_shape = lambda f: bp(f, 300, 11000) * pink(f) * bump(f, 4200, 0.9, 2.0)
    out += 0.55 * stereo_noise(rng, wash_shape, corr=0.12) * intensity

    # 2) mid-field drops — individual short noise ticks with varied color
    for st in poisson_times(rng, 90):
        L = int(rng.uniform(0.002, 0.009) * SR)
        tt = np.arange(L) / SR
        fc = rng.uniform(2000, 8000)
        ev = filt(rng.standard_normal(L), "bandpass", [fc * 0.6, min(fc * 1.6, 20000)])
        ev *= np.exp(-tt / (L / SR * 0.25)) * rng.lognormal(-2.7, 0.5)
        place(out, st, ev, rng.uniform(-0.95, 0.95))

    # 3) near drips on puddles / leaves — impact tick + rising bubble tone
    for st in poisson_times(rng, 1.6):
        L = int(0.12 * SR)
        tt = np.arange(L) / SR
        f0 = rng.uniform(900, 2600)
        tau = rng.uniform(0.012, 0.035)
        f = f0 * (1 + 0.9 * tt / 0.12)                # Minnaert: pitch rises
        tone = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-tt / tau)
        tick = filt(rng.standard_normal(L), "highpass", 2500) * np.exp(-tt / 0.0015)
        ev = (0.6 * tone + 0.4 * tick) * rng.uniform(0.04, 0.12)
        place(out, st, ev, rng.uniform(-0.7, 0.7))

    # 4) gentle low body — rain on the roof / ground
    out += 0.18 * stereo_noise(rng, lambda f: lp(f, 260) * brown(f), corr=0.6) * intensity

    out = reverb(out, rng, rt60=1.1, predelay=0.01, wet=0.18)
    return master(out, rms_db=-22.0)


def make_ocean(rng):
    """Ocean: irregular waves (rise → crash → foam wash) drifting along a shore."""
    out = np.zeros((2, N))

    # distant surf bed that never fully goes away
    out += 0.22 * stereo_noise(rng, lambda f: lp(f, 450) * brown(f) ** 0.6,
                               corr=0.5) * slow_env(rng, 0.06, 0.6, 1.0)

    # wave schedule: random gaps scaled to fill the loop exactly
    gaps = rng.uniform(7.0, 11.0, 6)
    gaps *= DUR / gaps.sum()
    starts = np.cumsum(np.concatenate([[rng.uniform(0, 3)], gaps[:-1]]))

    dark_sos = signal.butter(2, 600, "low", fs=SR, output="sos")
    bright_sos = signal.butter(2, [700, 7000], "bandpass", fs=SR, output="sos")
    foam_sos = signal.butter(2, [2500, 14000], "bandpass", fs=SR, output="sos")

    for st in starts:
        rise = rng.uniform(2.0, 3.6)
        wash = rng.uniform(4.5, 7.5)
        L = int((rise + wash) * SR)
        tt = np.arange(L) / SR
        build = np.clip(tt / rise, 0, 1) ** 2.2
        decay = np.where(tt < rise, 1.0, np.exp(-(tt - rise) / (wash / 3.2)))
        env = build * decay
        crash = np.exp(-((tt - rise) / 0.55) ** 2)    # the break itself
        foam_env = np.where(tt < rise, 0.0, 1 - np.exp(-(tt - rise) / 0.3)) * decay ** 0.7
        # granular fizz: sparse spikes smoothed → bubbling foam texture
        grains = filt(np.abs(rng.standard_normal(L)) ** 3, "low", 40)
        grains /= grains.max() + 1e-9

        p0, p1 = rng.uniform(-0.6, 0.6, 2)            # wave travels along the shore
        gl, gr = pan_gains(p0 + (p1 - p0) * tt / tt[-1])
        size = rng.uniform(0.7, 1.0)
        ev2 = np.zeros((2, L))
        for ch, g in ((0, gl), (1, gr)):
            dark = signal.sosfilt(dark_sos, rng.standard_normal(L))
            brt = signal.sosfilt(bright_sos, rng.standard_normal(L))
            foam = signal.sosfilt(foam_sos, rng.standard_normal(L))
            ev2[ch] = g * size * (1.6 * dark * env
                                  + 0.55 * brt * (0.35 * env + 1.2 * crash)
                                  + 0.30 * foam * foam_env * (0.4 + 0.9 * grains))
        place_stereo(out, st, ev2)

    out = reverb(out, rng, rt60=1.4, predelay=0.02, wet=0.15)
    return master(out, rms_db=-21.5)


def make_stream(rng):
    """Stream: layered water flow + clustered Minnaert bubbles + small splashes."""
    out = np.zeros((2, N))
    out += 0.30 * stereo_noise(rng, lambda f: bp(f, 120, 650) * brown(f) ** 0.5,
                               corr=0.5) * slow_env(rng, 0.3, 0.55, 1.0)
    mid = stereo_noise(rng, lambda f: bp(f, 450, 2600) * pink(f), corr=0.25)
    mid_env = np.stack([slow_env(rng, 1.8, 0.35, 1.0), slow_env(rng, 1.8, 0.35, 1.0)])
    out += 0.28 * mid * mid_env
    out += 0.07 * stereo_noise(rng, lambda f: bp(f, 2500, 10000) * pink(f),
                               corr=0.1) * slow_env(rng, 0.8, 0.5, 1.0)

    def bubble(st, pan):
        radius_mm = rng.lognormal(math.log(2.2), 0.45)
        f0 = float(np.clip(3260.0 / radius_mm, 350, 3200))   # Minnaert frequency
        tau = float(np.clip(rng.uniform(0.012, 0.045) * math.sqrt(1000.0 / f0), 0.006, 0.07))
        L = int(min(0.25, tau * 6) * SR)
        tt = np.arange(L) / SR
        f = f0 * (1 + rng.uniform(0.4, 1.4) * tt / (tau * 6))
        ev = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-tt / tau)
        ev *= np.minimum(1, tt / 0.0008)
        place(out, st, ev * rng.lognormal(-2.6, 0.45) * (radius_mm / 2.2) ** 0.5, pan)

    for st in poisson_times(rng, 16):
        bubble(st, rng.uniform(-0.9, 0.9))
    for st in clustered_times(rng, 1.2, 6, 0.08):
        bubble(st, float(np.clip(rng.normal(0, 0.45), -0.9, 0.9)))

    for st in poisson_times(rng, 2.5):                   # little splashes
        L = int(rng.uniform(0.02, 0.07) * SR)
        tt = np.arange(L) / SR
        ev = filt(rng.standard_normal(L), "bandpass", [900, 6000])
        ev *= np.minimum(1, tt / 0.002) * np.exp(-tt / (L / SR * 0.3)) * rng.uniform(0.04, 0.1)
        place(out, st, ev, rng.uniform(-0.8, 0.8))

    out = reverb(out, rng, rt60=0.9, predelay=0.008, wet=0.16)
    return master(out, rms_db=-22.0)


def make_fireplace(rng):
    """Fireplace: breathing roar + flame hiss + clustered crackles + wood pops."""
    out = np.zeros((2, N))
    roar_env = slow_env(rng, 0.12, 0.55, 1.0) * slow_env(rng, 2.5, 0.85, 1.0)
    out += 0.55 * stereo_noise(rng, lambda f: lp(f, 320) * brown(f) ** 0.8,
                               corr=0.65) * roar_env
    out += 0.05 * stereo_noise(rng, lambda f: bp(f, 1200, 6000) * pink(f),
                               corr=0.4) * slow_env(rng, 0.2, 0.3, 1.0)

    def crackle(st, amp, pan):
        L = int(rng.uniform(0.0015, 0.007) * SR)
        tt = np.arange(L) / SR
        ev = filt(rng.standard_normal(L), "highpass", rng.uniform(1200, 6000))
        ev *= np.exp(-tt / (L / SR * 0.22))
        if rng.random() < 0.35:                         # woody resonance
            fr = rng.uniform(1800, 5000)
            ev = ev + 0.6 * np.sin(2 * math.pi * fr * tt) * np.exp(-tt / 0.0025)
        place(out, st, ev * amp, pan)

    for st in poisson_times(rng, 9):
        crackle(st, rng.lognormal(-2.8, 0.7), float(np.clip(rng.normal(0, 0.35), -0.8, 0.8)))
    for st in clustered_times(rng, 0.22, 16, 0.18):      # flurries as a log settles
        crackle(st, rng.lognormal(-2.4, 0.6), float(np.clip(rng.normal(0, 0.3), -0.8, 0.8)))

    for st in poisson_times(rng, 0.25):                  # deeper wood pops
        L = int(0.09 * SR)
        tt = np.arange(L) / SR
        thump = np.sin(2 * math.pi * rng.uniform(70, 150) * tt) * np.exp(-tt / 0.025)
        snap = filt(rng.standard_normal(L), "highpass", 800) * np.exp(-tt / 0.006)
        place(out, st, (0.5 * thump + snap) * rng.uniform(0.2, 0.4),
              float(rng.uniform(-0.5, 0.5)))

    for st in poisson_times(rng, 0.07):                  # sap hiss
        L = int(rng.uniform(0.5, 1.6) * SR)
        tt = np.arange(L) / SR
        ev = filt(rng.standard_normal(L), "bandpass", [4000, 11000])
        ev *= np.sin(math.pi * tt / tt[-1]) ** 2 * rng.uniform(0.02, 0.05)
        place(out, st, ev, float(rng.uniform(-0.4, 0.4)))

    out = reverb(out, rng, rt60=0.7, predelay=0.006, wet=0.2)
    return master(out, rms_db=-22.0)


# --------------------------------------------------------------------------- #
DART_CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib", "audio",
                            "ambient_catalog.g.dart")


def _camel(s):
    head, *rest = s.split("_")
    return head + "".join(w.capitalize() for w in rest)


def write_dart_catalog(catalog, categories):
    """Emit the app's ambience catalog so Dart and the generator never drift."""
    lines = [
        "// GENERATED by tool/generate_ambient.py — do not edit by hand.",
        "// ignore_for_file: lines_longer_than_80_chars",
        "import 'package:flutter/material.dart';",
        "",
        "import 'ambient_track.dart';",
        "import 'sound_catalog.dart';",
        "",
        "const List<SoundCategory> kAmbientCategories = [",
    ]
    for cid, label, icon in categories:
        lines.append(f"  SoundCategory('{cid}', '{label}', Icons.{icon}),")
    lines += ["];", ""]
    for row in catalog:
        tid, label, cat, icon = row[:4]
        pack = ", pack: 'ambient'" if row[6] is not None else ""
        lines.append(f"const ambient{_camel(tid)[0].upper() + _camel(tid)[1:]} = "
                     f"AmbientTrack('{tid}', '{label}', '{cat}', Icons.{icon}{pack});")
    lines += ["", "const List<AmbientTrack> kAmbientCatalog = ["]
    for row in catalog:
        c = _camel(row[0])
        lines.append(f"  ambient{c[0].upper() + c[1:]},")
    lines += ["];", ""]
    with open(DART_CATALOG, "w") as fh:
        fh.write("\n".join(lines))
    print(f"  wrote {os.path.relpath(DART_CATALOG)} ({len(catalog)} tracks)")


def _render(row):
    from ambient_library import CATALOG  # noqa: F401  (ensures import in workers)
    tid, _label, _cat, _icon, fn, seed, rms = row
    rng = np.random.default_rng(seed)
    x = fn(rng)
    if rms is not None:              # library recipes: master here, smaller files
        x = master(x, rms_db=rms)
    # Originals ship inside the app; library beds go to the "ambient" store pack.
    save(f"ambient_{tid}.ogg", x, rng, quality=5 if rms is None else 3,
         out_dir=None if rms is None else os.path.join(PACKS, "ambient"))


def main():
    import sys
    from multiprocessing import Pool

    from ambient_library import CATALOG, CATEGORIES

    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg (with libvorbis) is required: brew install ffmpeg")
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    if "--catalog-only" in args:
        write_dart_catalog(CATALOG, CATEGORIES)
        return
    wanted = set(args)
    unknown = wanted - {r[0] for r in CATALOG}
    if unknown:
        raise SystemExit(f"unknown ambience ids: {sorted(unknown)}")
    print("Generating Decant ambient beds (CC0):")
    write_dart_catalog(CATALOG, CATEGORIES)
    rows = [r for r in CATALOG if not wanted or r[0] in wanted]
    with Pool() as pool:
        pool.map(_render, rows, chunksize=1)
    print("Done ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
