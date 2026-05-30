#!/usr/bin/env python3
"""
Decant — procedural ASMR sound generator.

Every sound shipped with Decant is synthesized from scratch by this script,
so the entire audio set is original and released as CC0 (public domain).
No third-party samples are used. Re-run this script to regenerate the assets:

    python3 tool/generate_sounds.py

Output: assets/sounds/*.wav  (44.1 kHz, 16-bit PCM, mono)
"""
import math
import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
RNG = np.random.default_rng(7)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def t_axis(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2, sr=SR):
    """Simple attack/decay/sustain/release envelope of length n samples."""
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False) if a_n else np.array([]),
        np.linspace(1, s, d_n, endpoint=False) if d_n else np.array([]),
        np.full(s_n, s),
        np.linspace(s, 0, r_n) if r_n else np.array([]),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def sine(freq, t, phase=0.0):
    return np.sin(2 * math.pi * freq * t + phase)


def bell(freq, dur, partials, sr=SR):
    """Additive bell/chime. partials = list of (ratio, amp, decay)."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp, decay in partials:
        out += amp * np.sin(2 * math.pi * freq * ratio * t) * np.exp(-decay * t)
    return out


def one_pole_lp(x, cutoff, sr=SR):
    """Cheap one-pole low-pass filter."""
    dt = 1.0 / sr
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def one_pole_hp(x, cutoff, sr=SR):
    """Cheap one-pole high-pass filter."""
    dt = 1.0 / sr
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = rc / (rc + dt)
    y = np.empty_like(x)
    prev_x = 0.0
    prev_y = 0.0
    for i in range(len(x)):
        y[i] = alpha * (prev_y + x[i] - prev_x)
        prev_x = x[i]
        prev_y = y[i]
    return y


def bandpass(x, lo, hi):
    return one_pole_hp(one_pole_lp(x, hi), lo)


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def seamless_loop(x, fade=0.12, sr=SR):
    """Crossfade the tail of x into its head so the buffer loops without a click."""
    f = int(fade * sr)
    f = min(f, len(x) // 3)
    head = x[:f].copy()
    tail = x[-f:].copy()
    ramp = np.linspace(0, 1, f)
    blended = tail * (1 - ramp) + head * ramp
    out = x[:-f].copy()
    out[:f] = blended
    return out


def add_click(buf, center, freq, amp, decay=0.0025, width=0.02, sr=SR):
    """Add a short decaying sine burst (a tick/pop/droplet) into buf in place."""
    i0 = int(center * sr)
    if i0 >= len(buf):
        return
    n = int(width * sr)
    end = min(len(buf), i0 + n)
    tt = np.arange(end - i0) / sr
    buf[i0:end] += amp * np.sin(2 * math.pi * freq * tt) * np.exp(-tt / decay)


def add_noise_burst(buf, center, amp, width=0.012, hp=1800, decay_frac=0.18,
                    sr=SR):
    """Inject a short broadband (high-passed) noise transient — a click/crackle.

    Unlike a sine burst this is *noisy*, which is what a real fire crackle or a
    water splash actually is. Very fast decay → snappy."""
    i0 = int(center * sr)
    if i0 >= len(buf):
        return
    m = min(len(buf) - i0, int(width * sr))
    if m <= 2:
        return
    seg = one_pole_hp(RNG.standard_normal(m), hp)
    tt = np.arange(m) / sr
    env = np.exp(-tt / (width * decay_frac))
    buf[i0:i0 + m] += amp * seg * env


def slow_env(n, cutoff=0.6, lo=0.35, hi=1.0):
    """A slow, smooth random amplitude envelope (low-passed noise, normalized).

    Used so beds breathe/fluctuate naturally instead of via rigid sine LFOs."""
    env = one_pole_lp(RNG.standard_normal(n), cutoff)
    env -= env.min()
    mx = env.max()
    if mx > 1e-9:
        env /= mx
    return lo + (hi - lo) * env


def save(name, x, sr=SR):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    dur = len(x) / sr
    print(f"  {name:24s} {dur:5.2f}s  {os.path.getsize(path)//1024:4d} KB")


# --------------------------------------------------------------------------- #
# Individual sounds
# --------------------------------------------------------------------------- #
def make_pour_loop():
    """Looping water trickle: filtered noise + gentle amplitude wobble + tiny bubbles."""
    dur = 1.6
    t = t_axis(dur)
    noise = RNG.standard_normal(len(t))
    stream = bandpass(noise, 600, 4500)
    # slow flutter so it sounds like flowing water, not static hiss
    wobble = 0.55 + 0.45 * (0.6 * np.sin(2 * math.pi * 3.1 * t)
                            + 0.4 * np.sin(2 * math.pi * 7.7 * t + 1.0))
    stream *= wobble
    # sprinkle a few quiet bubbles
    for _ in range(14):
        c = RNG.uniform(0, dur)
        f = RNG.uniform(700, 1600)
        env = np.exp(-((t - c) ** 2) / (2 * 0.012 ** 2))
        stream += 0.18 * np.sin(2 * math.pi * f * t) * env
    stream = normalize(stream, 0.7)
    return seamless_loop(stream)


def make_droplet():
    """A single droplet 'plink' with a quick downward pitch chirp."""
    dur = 0.30
    t = t_axis(dur)
    f = 1750 * np.exp(-9 * t) + 480           # falling pitch
    phase = 2 * math.pi * np.cumsum(f) / SR
    tone = np.sin(phase)
    env = np.exp(-22 * t)
    drop = tone * env
    # little resonant ring underneath
    drop += 0.25 * np.sin(2 * math.pi * 900 * t) * np.exp(-30 * t)
    return normalize(drop, 0.8)


def make_glass_clink():
    """Bright glass tap for tube select."""
    dur = 0.35
    clink = bell(2100, dur, [
        (1.00, 1.00, 26),
        (2.76, 0.55, 34),
        (5.40, 0.30, 42),
        (8.93, 0.16, 55),
    ])
    # tiny noise transient on the attack
    t = t_axis(dur)
    clink += 0.3 * bandpass(RNG.standard_normal(len(t)), 3000, 9000) * np.exp(-120 * t)
    return normalize(clink, 0.78)


def make_glug():
    """Low 'glug' as liquid settles into a tube."""
    dur = 0.42
    t = t_axis(dur)
    f = 150 + 70 * np.sin(2 * math.pi * 11 * t) * np.exp(-6 * t)
    phase = 2 * math.pi * np.cumsum(f) / SR
    body = np.sin(phase) * adsr(len(t), a=0.005, d=0.1, s=0.5, r=0.25)
    # a bubble pop near the end
    bub = 0.4 * np.sin(2 * math.pi * 420 * t) * np.exp(-((t - 0.30) ** 2) / (2 * 0.02 ** 2))
    return normalize(body + bub, 0.8)


def make_tube_complete():
    """Soft two-note bell when a tube is solved (C6 -> E6)."""
    seg = 0.42
    n1 = bell(1046.50, seg, [(1, 1, 6.5), (2, 0.4, 9), (3, 0.18, 12)])
    n2 = bell(1318.51, seg, [(1, 1, 6.5), (2, 0.4, 9), (3, 0.18, 12)])
    gap = int(0.12 * SR)
    out = np.zeros(len(n1) + gap + len(n2))
    out[:len(n1)] += n1
    out[gap:gap + len(n2)] += n2 * 0.95
    return normalize(out, 0.8)


def make_combo():
    """Ascending arpeggio for cascading tube completions."""
    notes = [1046.50, 1318.51, 1567.98, 2093.00]  # C6 E6 G6 C7
    step = int(0.11 * SR)
    seg = 0.5
    total = step * (len(notes) - 1) + int(seg * SR)
    out = np.zeros(total)
    for i, fr in enumerate(notes):
        b = bell(fr, seg, [(1, 1, 7), (2, 0.35, 10), (3, 0.15, 13)])
        s = i * step
        out[s:s + len(b)] += b * (0.7 + 0.1 * i)
    return normalize(out, 0.82)


def make_win_jingle():
    """Calming win melody: gentle bells over a soft pad."""
    melody = [  # (freq, start, dur)
        (1046.50, 0.00, 0.55),  # C6
        (1318.51, 0.28, 0.55),  # E6
        (1567.98, 0.56, 0.55),  # G6
        (2093.00, 0.90, 1.30),  # C7 (held)
    ]
    dur = 2.6
    out = np.zeros(int(SR * dur))
    for fr, st, ln in melody:
        b = bell(fr, ln, [(1, 1, 4.5), (2, 0.4, 7), (3, 0.2, 10), (5, 0.08, 14)])
        s = int(st * SR)
        out[s:s + len(b)] += b
    # warm pad underneath (C major triad), quiet
    t = t_axis(dur)
    pad = (sine(523.25, t) + sine(659.25, t) + sine(783.99, t)) / 3.0
    pad *= adsr(len(t), a=0.25, d=0.4, s=0.6, r=0.9)
    out += 0.22 * pad
    return normalize(out, 0.84)


def make_ambient_loop():
    """Subtle, slow ambient pad + faint water shimmer for the background bed."""
    dur = 10.0
    t = t_axis(dur)
    # slow detuned drone (A2/E3/A3) with breathing volume
    drone = (sine(110.0, t) + sine(164.81, t) * 0.7 + sine(220.0, t) * 0.5
             + sine(110.5, t) * 0.4)
    drone *= 0.5 + 0.5 * np.sin(2 * math.pi * (1 / dur) * t)  # one slow swell per loop
    # airy filtered noise shimmer
    shimmer = bandpass(RNG.standard_normal(len(t)), 1200, 5000)
    shimmer *= 0.12 * (0.6 + 0.4 * np.sin(2 * math.pi * 0.05 * t))
    bed = one_pole_lp(drone, 900) * 0.5 + shimmer
    bed = normalize(bed, 0.45)
    return seamless_loop(bed, fade=0.6)


def make_ambient_rain():
    """Gentle rain: airy high-passed hiss + many soft droplet ticks + low rumble."""
    dur = 10.0
    t = t_axis(dur)
    hiss = one_pole_hp(one_pole_lp(RNG.standard_normal(len(t)), 6500), 1400)
    hiss *= 0.16 * (0.85 + 0.15 * np.sin(2 * math.pi * 0.08 * t))
    out = hiss
    # scattered droplet ticks
    for _ in range(420):
        add_click(out, RNG.uniform(0, dur), RNG.uniform(1800, 4800),
                  RNG.uniform(0.02, 0.06), decay=0.0012, width=0.01)
    out += 0.12 * one_pole_lp(RNG.standard_normal(len(t)), 220)
    out = normalize(out, 0.5)
    return seamless_loop(out, fade=0.7)


def make_ambient_ocean():
    """Ocean waves: low-passed surf swelling in and out, over a deep rumble."""
    dur = 12.0
    t = t_axis(dur)
    surf = one_pole_lp(RNG.standard_normal(len(t)), 1100)
    # whole number of swell cycles across the loop → seamless
    n_waves = 3
    swell = np.zeros(len(t))
    period = dur / n_waves
    for k in range(n_waves):
        env = 0.5 - 0.5 * np.cos(2 * math.pi * (t / period + k * 0.0))
        swell += env ** 2
    swell /= n_waves
    out = surf * (0.18 + 0.82 * swell)
    out += 0.20 * one_pole_lp(RNG.standard_normal(len(t)), 150)
    out = normalize(out, 0.5)
    return seamless_loop(out, fade=0.8)


def make_ambient_stream():
    """A babbling brook: gentle water 'rush' + lots of irregular gurgle bloops.

    Realism comes from (a) two separately-breathing noise bands rather than one
    flat hiss, and (b) dense pitched 'blup/gurgle' events with downward pitch —
    the bubbling that actually defines the sound of a stream."""
    dur = 9.0
    t = t_axis(dur)
    n = len(t)

    # Splashy 'rush' over rocks — darker and lower than before so it reads as
    # water, not hiss; it also breathes (occasional dips) instead of being flat.
    rush = one_pole_hp(one_pole_lp(RNG.standard_normal(n), 3800), 900)
    rush *= 0.12 * slow_env(n, cutoff=3.0, lo=0.30, hi=1.0)
    # Warm body of the flowing water — mid band carries most of the level.
    body = bandpass(RNG.standard_normal(n), 280, 1200)
    body *= 0.18 * slow_env(n, cutoff=1.6, lo=0.45, hi=1.0)
    out = rush + body
    # Deep burble underneath.
    out += 0.12 * one_pole_lp(RNG.standard_normal(n), 170)

    # Gurgles define the brook — make them frequent and clearly audible, with a
    # falling pitch (a real water 'blup'). A few cluster into quick runs.
    def gurgle(c, amp, f0):
        i0 = int(c * SR)
        w = RNG.uniform(0.035, 0.10)
        m = min(n - i0, int(w * SR))
        if m <= 4:
            return
        tt = np.arange(m) / SR
        f = f0 * (1.0 - 0.45 * tt / w)
        phase = 2 * math.pi * np.cumsum(f) / SR
        env = np.exp(-tt / (w * 0.32))
        out[i0:i0 + m] += amp * np.sin(phase) * env

    for _ in range(190):
        gurgle(RNG.uniform(0, dur), RNG.uniform(0.09, 0.22), RNG.uniform(220, 820))
    # quick bubbling runs
    for _ in range(10):
        c = RNG.uniform(0, dur)
        for k in range(RNG.integers(3, 6)):
            gurgle((c + k * 0.05 + RNG.normal(0, 0.01)) % dur,
                   RNG.uniform(0.08, 0.16), RNG.uniform(300, 760))

    out = normalize(out, 0.5)
    return seamless_loop(out, fade=0.7)


def make_ambient_fireplace():
    """Cozy fireplace: a breathing low roar + sharp broadband crackles in flurries.

    The key fix vs. a naive version: crackles are short *noise* bursts (real
    snaps), not tonal sine blips, and they arrive in irregular flurries the way
    a real fire pops — with the occasional louder pop."""
    dur = 10.0
    t = t_axis(dur)
    n = len(t)

    # Roaring bed: low brown-ish rumble that slowly breathes, plus faint air.
    rumble = one_pole_lp(RNG.standard_normal(n), 160) * 0.55
    rumble *= slow_env(n, cutoff=1.2, lo=0.55, hi=1.0)
    air = one_pole_hp(one_pole_lp(RNG.standard_normal(n), 3800), 1800) * 0.05
    out = rumble + air

    # Scattered fine crackles across the whole loop (kept calm — this is an
    # "unwind" app, so the fire simmers rather than roars).
    for _ in range(150):
        add_noise_burst(out, RNG.uniform(0, dur), RNG.uniform(0.04, 0.16),
                        width=RNG.uniform(0.004, 0.012),
                        hp=RNG.uniform(2500, 7000), decay_frac=0.16)

    # Flurries: clusters of rapid pops, like a log settling.
    for _ in range(7):
        center = RNG.uniform(0, dur)
        for _ in range(RNG.integers(5, 12)):
            jitter = RNG.normal(0, 0.06)
            add_noise_burst(out, (center + jitter) % dur,
                            RNG.uniform(0.06, 0.22),
                            width=RNG.uniform(0.004, 0.010),
                            hp=RNG.uniform(2000, 6000), decay_frac=0.14)

    # A few louder, lower 'pops'.
    for _ in range(10):
        add_noise_burst(out, RNG.uniform(0, dur), RNG.uniform(0.25, 0.5),
                        width=RNG.uniform(0.010, 0.018),
                        hp=RNG.uniform(900, 1800), decay_frac=0.22)

    out = normalize(out, 0.55)
    return seamless_loop(out, fade=0.6)


# --------------------------------------------------------------------------- #
def main():
    os.makedirs(OUT, exist_ok=True)
    print("Generating Decant ASMR sound set (CC0):")
    save("water_pour_loop.wav", make_pour_loop())
    save("droplet.wav", make_droplet())
    save("glass_clink.wav", make_glass_clink())
    save("glug.wav", make_glug())
    save("tube_complete.wav", make_tube_complete())
    save("combo.wav", make_combo())
    save("win_jingle.wav", make_win_jingle())
    # Ambient bed options (pad keeps the original filename for compatibility).
    save("ambient_loop.wav", make_ambient_loop())       # Twilight Pad (default)
    save("ambient_rain.wav", make_ambient_rain())        # Rain
    save("ambient_ocean.wav", make_ambient_ocean())      # Ocean
    save("ambient_stream.wav", make_ambient_stream())    # Stream
    save("ambient_fireplace.wav", make_ambient_fireplace())  # Fireplace
    print("Done ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
