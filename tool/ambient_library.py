"""
Decant — the extended ambience library (50 extra beds) and the full catalog.

Imported by `tool/generate_ambient.py`, which renders every bed and writes the
Dart catalog (`lib/audio/ambient_catalog.g.dart`). Everything here is
synthesized from scratch (CC0) on the same loop-perfect primitives as the
original beds: circular noise, circular envelopes, wrapped events and circular
reverb, so every bed loops seamlessly.

Recipe conventions: a recipe takes `rng` and returns an un-mastered stereo
array of shape (2, N); the catalog row says how loud to master it.
"""
import math

import numpy as np

from generate_ambient import (
    DUR, N, SR, bp, brown, bump, circ_conv, clustered_times, filt, lp,
    make_fireplace, make_ocean, make_rain, make_stream, pan_gains, pink, place,
    poisson_times, reverb, slow_env, stereo_noise,
)

TAU = 2 * math.pi


# =========================================================================== #
# Primitives
# =========================================================================== #
def zeros():
    return np.zeros((2, N))


def periodic(period):
    """Snap a period so a whole number of repeats fits the loop."""
    return DUR / max(1, round(DUR / period))


def mono(x):
    return np.stack([x, x])


def grain_field(rng, rate, kernel_fn, rate_env=None, amp_sigma=0.5,
                pan_spread=1.0, kernels=4):
    """Dense granular texture (drops, grains, crackles, pebbles).

    Poisson impulses — optionally rate-modulated by `rate_env` (per-sample
    multiplier) — circularly convolved with a small bank of grain kernels.
    Cheap at any density and seamless by construction."""
    r = np.full(N, float(rate)) if rate_env is None else rate * rate_env
    hits = np.nonzero(rng.random(N) < r / SR)[0]
    out = zeros()
    if len(hits) == 0:
        return out
    amps = rng.lognormal(0, amp_sigma, len(hits))
    pans = rng.uniform(-pan_spread, pan_spread, len(hits))
    gl, gr = pan_gains(pans)
    group = rng.integers(kernels, size=len(hits))
    for k in range(kernels):
        ker = kernel_fn(rng)
        sel = group == k
        for ch, g in ((0, gl), (1, gr)):
            imp = np.zeros(N)
            imp[hits[sel]] = amps[sel] * g[sel]
            out[ch] += circ_conv(imp, ker)
    return out


def burst_kernel(lo, hi, dur, decay_frac=0.25):
    """Kernel factory: a band-passed noise burst with exponential decay."""
    def make(rng):
        L = max(8, int(rng.uniform(*dur) * SR))
        t = np.arange(L) / SR
        f1 = rng.uniform(lo, hi)
        band = [f1 * 0.6, min(f1 * 1.7, SR / 2 - 100)]
        return filt(rng.standard_normal(L), "bandpass", band) * np.exp(-t / (L / SR * decay_frac))
    return make


def ring_kernel(freqs, decay, click=0.4):
    """Kernel factory: a struck resonance (sum of damped sines) + click."""
    def make(rng):
        L = int(decay * 6 * SR)
        t = np.arange(L) / SR
        x = np.zeros(L)
        for f in freqs:
            fr = f * rng.uniform(0.85, 1.18)
            x += np.sin(TAU * fr * t + rng.uniform(0, TAU)) * np.exp(-t / (decay * rng.uniform(0.6, 1.4)))
        c = min(L, int(0.002 * SR))
        x[:c] += click * filt(rng.standard_normal(c), "highpass", 2000)
        return x / len(freqs)
    return make


def moving_band(rng, fc_env, width_oct=0.6, frame=3200):
    """Noise through a band-pass whose center follows `fc_env` (Hz, per
    sample). Circular STFT (hop divides N) so it loops seamlessly."""
    hop = frame // 2
    assert N % hop == 0
    x = rng.standard_normal(N)
    win = np.hanning(frame + 1)[:-1]
    lf = np.log2(np.maximum(np.fft.rfftfreq(frame, 1.0 / SR), 1.0))
    out = np.zeros(N)
    for s in range(0, N, hop):
        idx = (s + np.arange(frame)) % N
        fc = fc_env[(s + hop) % N]
        g = np.exp(-((lf - math.log2(max(fc, 20.0))) ** 2) / (2 * width_oct ** 2))
        out[idx] += np.fft.irfft(np.fft.rfft(x[idx] * win) * g, frame)
    return out / (np.std(out) + 1e-12)


def env_events(rng, rate, dur_range):
    """A circular envelope made of overlapping smooth swells."""
    env = np.zeros(N)
    for st in poisson_times(rng, rate):
        L = int(rng.uniform(*dur_range) * SR)
        u = np.linspace(0, 1, L)
        idx = (int(st * SR) + np.arange(L)) % N
        env[idx] += np.sin(math.pi * u) ** 2 * rng.uniform(0.6, 1.0)
    return np.minimum(env, 1.2)


def tone(f_traj, amp, harm=0.12):
    ph = TAU * np.cumsum(f_traj) / SR
    return amp * (np.sin(ph) + harm * np.sin(2 * ph))


def room_tone(rng, level=0.04):
    return level * stereo_noise(rng, lambda f: lp(f, 900) * brown(f) ** 0.6, corr=0.7)


# --------------------------------------------------------------------------- #
# Weather / water building blocks
# --------------------------------------------------------------------------- #
def rain_bed(rng, wash=0.55, center=4200, top=11000, drops=90, drop_amp=0.06,
             drips=1.6, body=0.18, var=(0.7, 1.0)):
    out = zeros()
    inten = slow_env(rng, 0.04, *var)
    shape = lambda f: bp(f, 300, top) * pink(f) * bump(f, center, 0.9, 2.0)
    out += wash * stereo_noise(rng, shape, corr=0.12) * inten
    if drops:
        out += drop_amp * grain_field(rng, drops, burst_kernel(2000, 8000, (0.002, 0.009)),
                                      rate_env=inten, amp_sigma=0.5, pan_spread=0.95)
    for st in poisson_times(rng, drips):
        L = int(0.12 * SR)
        t = np.arange(L) / SR
        f0 = rng.uniform(900, 2600)
        tau = rng.uniform(0.012, 0.035)
        tn = np.sin(TAU * np.cumsum(f0 * (1 + 0.9 * t / 0.12)) / SR) * np.exp(-t / tau)
        tick = filt(rng.standard_normal(L), "highpass", 2500) * np.exp(-t / 0.0015)
        place(out, st, (0.6 * tn + 0.4 * tick) * rng.uniform(0.04, 0.12), rng.uniform(-0.7, 0.7))
    out += body * stereo_noise(rng, lambda f: lp(f, 260) * brown(f), corr=0.6) * inten
    return out


def thunder(rng, out, st, amp):
    L = int(rng.uniform(6, 10) * SR)
    t = np.arange(L) / SR
    crack = np.exp(-t / 0.25) * (t < 1.5)
    roll = (1 - np.exp(-t / 0.4)) * np.exp(-t / rng.uniform(1.8, 3.0))
    mod = 0.5 + 0.5 * filt(np.abs(rng.standard_normal(L)), "lowpass", 3)
    mod /= mod.max()
    p = rng.uniform(-0.4, 0.4)
    idx = (int(st * SR) + np.arange(L)) % N
    for ch in range(2):
        low = filt(rng.standard_normal(L), "lowpass", rng.uniform(140, 260))
        mid = filt(rng.standard_normal(L), "bandpass", [200, 1600])
        out[ch, idx] += pan_gains(p)[ch] * (2.2 * low * roll * mod + 0.5 * mid * crack) * amp


def wind_bed(rng, lo=250, hi=900, gusts=0.08, body=1.0, rumble=0.5,
             whistle=0.0, rustle=0.0, sand=0.0, width=0.9):
    gust = slow_env(rng, gusts, 0.3, 1.0) ** 1.2      # always some wind, swelling gusts
    g = gust * slow_env(rng, 0.6, 0.8, 1.0)
    fc = lo * (hi / lo) ** g
    out = zeros()
    out[0] = moving_band(rng, fc, width)
    out[1] = moving_band(rng, fc * 1.06, width)
    out *= body * (0.2 + 0.8 * g)
    out += rumble * stereo_noise(rng, lambda f: lp(f, 170) * brown(f), corr=0.5) * (0.3 + 0.7 * g)
    if whistle:
        w = zeros()
        w[0] = moving_band(rng, fc * 2.3, 0.07)
        w[1] = moving_band(rng, fc * 2.45, 0.07)
        out += whistle * w * (0.25 + g ** 1.5)
    if rustle:
        flutter = slow_env(rng, 7.0, 0.3, 1.0)
        out += rustle * stereo_noise(rng, lambda f: bp(f, 1500, 9000) * pink(f), corr=0.15) \
            * (0.15 + g ** 1.3) * flutter
    if sand:
        out += sand * grain_field(rng, 900, burst_kernel(3500, 9000, (0.0008, 0.002)),
                                  rate_env=0.1 + g ** 1.5, amp_sigma=0.6)
    return out


def bubbles(rng, out, rate, f_lo, f_hi, amp=0.08, pan=0.8, clustered=None):
    def one(st, p):
        f0 = rng.uniform(f_lo, f_hi)
        tau = float(np.clip(rng.uniform(0.01, 0.04) * math.sqrt(1000.0 / f0), 0.006, 0.08))
        L = int(min(0.3, tau * 6) * SR)
        t = np.arange(L) / SR
        ev = np.sin(TAU * np.cumsum(f0 * (1 + rng.uniform(0.4, 1.4) * t / (tau * 6))) / SR)
        ev *= np.exp(-t / tau) * np.minimum(1, t / 0.0008)
        place(out, st, ev * amp * rng.lognormal(0, 0.4), p)
    for st in poisson_times(rng, rate):
        one(st, rng.uniform(-pan, pan))
    if clustered:
        for st in clustered_times(rng, *clustered):
            one(st, rng.uniform(-pan, pan))


def laps(rng, out, period=(2.0, 3.5), amp=0.5, lo=250, hi=1800, hollow=0.0):
    """Small waves lapping a shore / hull, spaced to fill the loop exactly."""
    gaps = []
    while sum(gaps) < DUR:
        gaps.append(rng.uniform(*period))
    gaps = np.array(gaps) * (DUR / sum(gaps))
    t0 = rng.uniform(0, 1)
    for st in t0 + np.concatenate([[0], np.cumsum(gaps[:-1])]):
        L = int(rng.uniform(1.0, 1.8) * SR)
        t = np.arange(L) / SR
        env = (1 - np.exp(-t / 0.18)) * np.exp(-t / 0.45)
        p = rng.uniform(-0.6, 0.6)
        a = amp * rng.uniform(0.7, 1.0)
        idx = (int(st * SR) + np.arange(L)) % N
        for ch in range(2):
            sig = filt(rng.standard_normal(L), "bandpass", [lo, hi]) * env
            if hollow:
                sig += hollow * filt(sig, "bandpass", [160, 260])
            out[ch, idx] += pan_gains(p)[ch] * sig * a
        for k in range(rng.integers(1, 4)):
            f0 = rng.uniform(350, 900)
            Lb = int(0.08 * SR)
            tb = np.arange(Lb) / SR
            ev = np.sin(TAU * np.cumsum(f0 * (1 + 0.8 * tb / 0.08)) / SR) * np.exp(-tb / 0.02)
            place(out, st + 0.25 + k * rng.uniform(0.05, 0.2), ev * a * 0.25, p)


# --------------------------------------------------------------------------- #
# Fauna
# --------------------------------------------------------------------------- #
def syl(f0, f1, dur, vib=0.0, vib_rate=30.0, harm=0.12, curve=1.0):
    L = max(8, int(dur * SR))
    u = np.linspace(0, 1, L)
    f = f0 + (f1 - f0) * u ** curve
    if vib:
        f = f * (1 + vib * np.sin(TAU * vib_rate * np.arange(L) / SR))
    return tone(f, np.sin(math.pi * u) ** 1.5, harm)


def concat(parts):
    return np.concatenate(parts) if parts else np.zeros(1)


def gap(s):
    return np.zeros(int(s * SR))


def song_warbler(rng, base):
    parts = []
    for _ in range(rng.integers(4, 9)):
        parts += [syl(base * rng.uniform(0.8, 1.3), base * rng.uniform(0.7, 1.45),
                      rng.uniform(0.06, 0.18), vib=rng.uniform(0, 0.07),
                      vib_rate=rng.uniform(18, 40)), gap(rng.uniform(0.02, 0.07))]
    return concat(parts)


def song_trill(rng, base):
    parts = []
    k = int(rng.integers(8, 20))
    for i in range(k):
        b = base * (1 - 0.12 * i / k)
        parts += [syl(b * 1.2, b * 0.9, rng.uniform(0.03, 0.05)), gap(rng.uniform(0.018, 0.032))]
    return concat(parts)


def song_whistle(rng, base):
    parts = []
    for _ in range(rng.integers(2, 4)):
        f0 = base * rng.uniform(0.85, 1.15)
        parts += [syl(f0, f0 * rng.uniform(0.9, 1.12), rng.uniform(0.25, 0.5), harm=0.03),
                  gap(rng.uniform(0.08, 0.2))]
    return concat(parts)


def song_chips(rng, base):
    parts = []
    for _ in range(rng.integers(1, 5)):
        parts += [syl(base * 1.25, base * 0.8, rng.uniform(0.02, 0.04), harm=0.3),
                  gap(rng.uniform(0.06, 0.25))]
    return concat(parts)


def song_coo(rng, base):
    parts = []
    for d in (0.28, 0.5, 0.36):
        parts += [syl(base, base * 0.93, d, harm=0.25, curve=0.5), gap(0.12)]
    return concat(parts)


def song_owl(rng, base):
    parts = [syl(base, base * 0.94, 0.42, harm=0.08), gap(0.55)]
    for d in (0.16, 0.16, 0.5):
        parts += [syl(base * 0.98, base * 0.93, d, harm=0.08), gap(0.12)]
    return concat(parts)


def song_exotic(rng, base):
    parts = []
    for _ in range(rng.integers(2, 6)):
        if rng.random() < 0.4:
            parts += [syl(base * 0.7, base * 1.6, rng.uniform(0.15, 0.3), curve=2.0)]
        else:
            parts += [syl(base, base, rng.uniform(0.1, 0.25), vib=rng.uniform(0.08, 0.18),
                          vib_rate=rng.uniform(8, 16))]
        parts += [gap(rng.uniform(0.05, 0.2))]
    return concat(parts)


def birds(rng, out, species, count=4, rate=(0.08, 0.2), dist=(0.2, 1.0)):
    """Scatter `count` individual birds across the stereo field."""
    for _ in range(count):
        song, lo, hi = species[rng.integers(len(species))]
        base = rng.uniform(lo, hi)
        pan = rng.uniform(-0.85, 0.85)
        d = rng.uniform(*dist)
        cutoff = 9000 - 5500 * d
        gain = 0.28 / (0.6 + 1.6 * d)
        for st in poisson_times(rng, rng.uniform(*rate)):
            ev = filt(song(rng, base * rng.uniform(0.97, 1.03)), "lowpass", cutoff)
            place(out, st, ev * gain, pan)


SONGBIRDS = [(song_warbler, 2200, 3800), (song_trill, 4000, 6000),
             (song_whistle, 2200, 3200), (song_chips, 3600, 5200)]


def crickets(rng, out, count=5, f=(3800, 5200), amp=0.05, period=(0.45, 1.2)):
    for _ in range(count):
        fc = rng.uniform(*f)
        per = periodic(rng.uniform(*period))
        pulses = int(rng.integers(2, 5))
        pp = rng.uniform(0.028, 0.045)
        pan = rng.uniform(-0.9, 0.9)
        a = amp * rng.uniform(0.4, 1.0)
        Lp = int(0.016 * SR)
        tp = np.arange(Lp) / SR
        pulse = np.sin(TAU * fc * tp) * np.sin(math.pi * tp / tp[-1]) ** 2
        chirp = np.zeros(int((pulses * pp + 0.02) * SR))
        for k in range(pulses):
            i0 = int(k * pp * SR)
            chirp[i0:i0 + Lp] += pulse
        t0 = rng.uniform(0, per)
        for i in range(int(round(DUR / per))):
            if rng.random() < 0.06:
                continue                                   # the odd skipped chirp
            place(out, t0 + i * per + rng.normal(0, 0.004), chirp * a, pan)


def katydids(rng, out, count=3, amp=0.05):
    for _ in range(count):
        per = periodic(rng.uniform(0.9, 1.4))
        n_p = int(rng.integers(2, 4))
        pan = rng.uniform(-0.8, 0.8)
        t0 = rng.uniform(0, per)
        L = int(0.03 * SR)
        t = np.arange(L) / SR
        for i in range(int(round(DUR / per))):
            for k in range(n_p):
                ev = filt(rng.standard_normal(L), "bandpass", [6000, 12000]) * np.sin(math.pi * t / t[-1])
                place(out, t0 + i * per + k * 0.085, ev * amp, pan)


def cicadas(rng, out, count=4, amp=0.12):
    t = np.arange(N) / SR
    for _ in range(count):
        fc = rng.uniform(4200, 7000)
        rate = round(rng.uniform(150, 240) * DUR) / DUR
        carrier = stereo_noise(rng, lambda f, fc=fc: bump(f, fc, 0.18, 30.0) - 1.0, corr=0.6)
        am = np.abs(np.sin(math.pi * rate * t)) ** 4
        env = env_events(rng, 0.07, (6, 15))
        gl, gr = pan_gains(rng.uniform(-0.8, 0.8))
        out[0] += amp * gl * carrier[0] * am * env
        out[1] += amp * gr * carrier[1] * am * env


def frogs(rng, out, croakers=3, peepers=4, amp=0.15):
    for _ in range(croakers):
        pr = rng.uniform(25, 60)
        f1, f2 = rng.uniform(250, 500), rng.uniform(900, 1500)
        pan = rng.uniform(-0.8, 0.8)
        kt = np.arange(int(0.02 * SR)) / SR
        ker = (np.sin(TAU * f1 * kt) + 0.5 * np.sin(TAU * f2 * kt)) * np.exp(-kt / 0.006)
        for st in poisson_times(rng, rng.uniform(0.25, 0.6)):
            L = int(rng.uniform(0.25, 0.6) * SR)
            imp = np.zeros(L)
            imp[(np.arange(0, L / SR, 1 / pr) * SR).astype(int)] = 1.0
            ev = np.convolve(imp, ker)[:L] * np.sin(math.pi * np.linspace(0, 1, L)) ** 0.7
            place(out, st, ev * amp * rng.uniform(0.6, 1.0), pan)
    for _ in range(peepers):
        f0 = rng.uniform(2500, 3100)
        pan = rng.uniform(-0.9, 0.9)
        per = periodic(rng.uniform(0.7, 1.6))
        t0 = rng.uniform(0, per)
        for i in range(int(round(DUR / per))):
            if rng.random() < 0.25:
                continue
            place(out, t0 + i * per, syl(f0 * 0.9, f0 * 1.08, 0.11, harm=0.05) * amp * 0.25, pan)


def bee_flyby(rng, out, st, amp=0.08):
    L = int(rng.uniform(2.0, 4.0) * SR)
    t = np.arange(L) / SR
    u = t / t[-1]
    f0 = rng.uniform(190, 250) * (1.03 - 0.06 * u) * (1 + 0.01 * np.sin(TAU * 7 * t))
    ph = TAU * np.cumsum(f0) / SR
    sig = sum(np.sin(k * ph) / k for k in range(1, 12))
    sig = filt(sig, "lowpass", 2500) * np.sin(math.pi * u) ** 2
    p0 = rng.choice([-1, 1]) * 0.8
    gl, gr = pan_gains(p0 - 2 * p0 * u)
    idx = (int(st * SR) + np.arange(L)) % N
    out[0, idx] += amp * gl * sig
    out[1, idx] += amp * gr * sig


# =========================================================================== #
# Recipes — Rain
# =========================================================================== #
def r_drizzle(rng):
    return rain_bed(rng, wash=0.35, center=5500, drops=35, drop_amp=0.05, drips=0.9,
                    body=0.06, var=(0.5, 1.0))


def r_downpour(rng):
    out = rain_bed(rng, wash=0.8, center=3200, drops=260, drop_amp=0.07, drips=3.0, body=0.4)
    return reverb(out, rng, rt60=0.8, wet=0.12)


def r_window(rng):
    out = zeros()
    inten = slow_env(rng, 0.05, 0.6, 1.0)
    out += 0.4 * stereo_noise(rng, lambda f: bp(f, 200, 2800) * pink(f), corr=0.3) * inten
    out += 0.12 * grain_field(rng, 28, ring_kernel([1800, 3100], 0.006, 0.8),
                              rate_env=inten, amp_sigma=0.6)
    for st in poisson_times(rng, 0.35):                     # rivulets running down
        for k in range(rng.integers(4, 10)):
            f0 = rng.uniform(600, 1400)
            L = int(0.06 * SR)
            t = np.arange(L) / SR
            ev = np.sin(TAU * np.cumsum(f0 * (1 + 0.5 * t / 0.06)) / SR) * np.exp(-t / 0.015)
            place(out, st + k * rng.uniform(0.06, 0.15), ev * 0.04, rng.uniform(-0.3, 0.3))
    out += room_tone(rng, 0.05)
    return reverb(out, rng, rt60=0.5, wet=0.15)


def r_tent(rng):
    out = zeros()
    inten = slow_env(rng, 0.05, 0.6, 1.0)
    out += 0.3 * stereo_noise(rng, lambda f: bp(f, 150, 2200) * pink(f), corr=0.4) * inten
    out += 0.22 * grain_field(rng, 70, burst_kernel(250, 1100, (0.006, 0.02)),
                              rate_env=inten, amp_sigma=0.55)
    out += 0.35 * grain_field(rng, 1.2, burst_kernel(150, 500, (0.03, 0.06)), amp_sigma=0.3)
    return out


def r_tin_roof(rng):
    out = zeros()
    inten = slow_env(rng, 0.05, 0.6, 1.0)
    out += 0.25 * stereo_noise(rng, lambda f: bp(f, 400, 9000) * pink(f), corr=0.3) * inten
    out += 0.16 * grain_field(rng, 80, ring_kernel([2300, 3700, 5100], 0.01, 0.5),
                              rate_env=inten, amp_sigma=0.6)
    out += 0.08 * grain_field(rng, 6, ring_kernel([900, 1500], 0.05, 0.3), amp_sigma=0.4)
    return reverb(out, rng, rt60=0.6, wet=0.15)


def r_thunderstorm(rng):
    out = rain_bed(rng, wash=0.7, center=3500, drops=200, drop_amp=0.07, drips=2.5, body=0.35)
    for st in np.sort(rng.uniform(0, DUR, 3)):
        thunder(rng, out, st, rng.uniform(0.6, 1.0))
    return reverb(out, rng, rt60=1.2, wet=0.15)


# =========================================================================== #
# Water
# =========================================================================== #
def r_waterfall(rng):
    out = 0.6 * stereo_noise(rng, lambda f: bp(f, 60, 12000) * pink(f) ** 0.7
                             * bump(f, 450, 1.2, 1.5) * bump(f, 3000, 1.0, 0.8), corr=0.2)
    out *= slow_env(rng, 0.3, 0.85, 1.0)
    out += 0.45 * stereo_noise(rng, lambda f: lp(f, 150) * brown(f), corr=0.5)
    out += 0.05 * grain_field(rng, 300, burst_kernel(800, 5000, (0.004, 0.015)), amp_sigma=0.5)
    return reverb(out, rng, rt60=1.0, wet=0.15)


def r_lake(rng):
    out = 0.08 * stereo_noise(rng, lambda f: lp(f, 400) * brown(f) ** 0.5, corr=0.5)
    laps(rng, out, period=(2.0, 3.5), amp=0.45)
    out += 0.03 * grain_field(rng, 25, burst_kernel(1500, 5000, (0.002, 0.006)), amp_sigma=0.5)
    return reverb(out, rng, rt60=0.9, wet=0.12)


def r_cave(rng):
    out = 0.05 * stereo_noise(rng, lambda f: lp(f, 200) * brown(f), corr=0.6)
    for _ in range(6):                                         # fixed drip spots
        per = rng.uniform(1.4, 5.0)
        f0 = rng.uniform(700, 2200)
        pan = rng.uniform(-0.85, 0.85)
        amp = rng.uniform(0.08, 0.2)
        t = rng.uniform(0, per)
        L = int(0.15 * SR)
        tt = np.arange(L) / SR
        while t < DUR:
            ev = np.sin(TAU * np.cumsum(f0 * (1 + 0.7 * tt / 0.15)) / SR) * np.exp(-tt / 0.03)
            tick = filt(rng.standard_normal(L), "highpass", 2000) * np.exp(-tt / 0.002)
            place(out, t, (ev + 0.3 * tick) * amp, pan)
            t += per * rng.uniform(0.85, 1.15)
    return reverb(out, rng, rt60=4.0, predelay=0.04, wet=0.5)


def r_fountain(rng):
    out = 0.35 * stereo_noise(rng, lambda f: bp(f, 300, 9000) * pink(f) * bump(f, 2500, 1.0, 1.0),
                              corr=0.25) * slow_env(rng, 0.5, 0.8, 1.0)
    out += 0.1 * grain_field(rng, 400, burst_kernel(1000, 6000, (0.005, 0.02)), amp_sigma=0.5)
    bubbles(rng, out, 10, 300, 1200, amp=0.05)
    out += 0.1 * stereo_noise(rng, lambda f: lp(f, 250) * brown(f), corr=0.5)
    return reverb(out, rng, rt60=1.3, wet=0.2)


def r_underwater(rng):
    out = 0.6 * stereo_noise(rng, lambda f: lp(f, 450) * brown(f) ** 0.8, corr=0.5)
    out *= slow_env(rng, 0.1, 0.6, 1.0)
    bubbles(rng, out, 3, 120, 500, amp=0.15, clustered=(0.25, 8, 0.15))
    env = env_events(rng, 0.08, (3, 6))
    out += 0.3 * stereo_noise(rng, lambda f: bp(f, 80, 700) * brown(f) ** 0.5, corr=0.3) * env
    return reverb(out, rng, rt60=2.0, wet=0.3, hf_ratio=0.3)


# =========================================================================== #
# Wind
# =========================================================================== #
def r_breeze(rng):
    return wind_bed(rng, lo=220, hi=700, gusts=0.06, body=0.6, rumble=0.25, rustle=0.08)


def r_trees(rng):
    return wind_bed(rng, lo=250, hi=900, gusts=0.09, body=0.6, rumble=0.3, rustle=0.45)


def r_howling(rng):
    out = wind_bed(rng, lo=300, hi=1200, gusts=0.12, body=0.8, rumble=0.5, whistle=0.7, width=0.7)
    return reverb(out, rng, rt60=1.5, wet=0.2)


def r_desert(rng):
    return wind_bed(rng, lo=300, hi=1000, gusts=0.08, body=0.7, rumble=0.35, sand=0.1, whistle=0.15)


def r_blizzard(rng):
    out = wind_bed(rng, lo=350, hi=1500, gusts=0.14, body=1.0, rumble=0.7, whistle=0.35,
                   sand=0.06, width=1.1)
    return reverb(out, rng, rt60=1.2, wet=0.2, hf_ratio=0.35)


# =========================================================================== #
# Fire
# =========================================================================== #
def fire_core(rng, roar=0.55, roar_lp=320, crackle_rate=9, flurries=0.22, pops=0.25, crackle_lp=None):
    out = zeros()
    env = slow_env(rng, 0.12, 0.55, 1.0) * slow_env(rng, 2.5, 0.85, 1.0)
    out += roar * stereo_noise(rng, lambda f: lp(f, roar_lp) * brown(f) ** 0.8, corr=0.65) * env
    cr = grain_field(rng, crackle_rate, burst_kernel(2000, 7000, (0.0015, 0.007), 0.22),
                     amp_sigma=0.8, pan_spread=0.6)
    for st in clustered_times(rng, flurries, 16, 0.18):
        L = int(rng.uniform(0.0015, 0.006) * SR)
        t = np.arange(L) / SR
        ev = filt(rng.standard_normal(L), "highpass", rng.uniform(1500, 6000)) * np.exp(-t / (L / SR * 0.22))
        place(cr, st, ev * rng.lognormal(-2.0, 0.6), float(np.clip(rng.normal(0, 0.3), -0.8, 0.8)))
    if crackle_lp:
        cr = np.stack([filt(c, "lowpass", crackle_lp) for c in cr])
    out += 0.12 * cr
    for st in poisson_times(rng, pops):
        L = int(0.09 * SR)
        t = np.arange(L) / SR
        thump = np.sin(TAU * rng.uniform(70, 150) * t) * np.exp(-t / 0.025)
        snap = filt(rng.standard_normal(L), "highpass", 800) * np.exp(-t / 0.006)
        place(out, st, (0.5 * thump + snap) * rng.uniform(0.2, 0.4), rng.uniform(-0.5, 0.5))
    return out


def r_campfire(rng):
    out = fire_core(rng, roar=0.45, crackle_rate=14, flurries=0.3, pops=0.45)
    out += 0.03 * stereo_noise(rng, lambda f: bp(f, 1500, 6000) * pink(f), corr=0.2)
    return reverb(out, rng, rt60=0.5, wet=0.08)


def r_candle(rng):
    out = zeros()
    flick = slow_env(rng, 1.5, 0.3, 1.0) * slow_env(rng, 7.0, 0.7, 1.0)
    out += 0.4 * stereo_noise(rng, lambda f: bp(f, 60, 400) * brown(f) ** 0.6, corr=0.8) * flick
    out += 0.08 * grain_field(rng, 0.4, burst_kernel(2000, 6000, (0.001, 0.004)), amp_sigma=0.5,
                              pan_spread=0.2)
    out += room_tone(rng, 0.25)
    return reverb(out, rng, rt60=0.5, wet=0.15)


def r_wood_stove(rng):
    out = fire_core(rng, roar=0.6, roar_lp=200, crackle_rate=6, flurries=0.15, pops=0.15,
                    crackle_lp=3000)
    out += 0.06 * grain_field(rng, 0.15, ring_kernel([3200, 4700, 6100], 0.03, 0.2), amp_sigma=0.3,
                              pan_spread=0.3)
    return reverb(out, rng, rt60=0.6, wet=0.18)


# =========================================================================== #
# Nature (day)
# =========================================================================== #
def r_forest_birds(rng):
    out = wind_bed(rng, lo=220, hi=600, gusts=0.05, body=0.25, rumble=0.1, rustle=0.12)
    birds(rng, out, SONGBIRDS, count=6, rate=(0.07, 0.18))
    birds(rng, out, [(song_coo, 450, 600)], count=1, rate=(0.04, 0.06), dist=(0.5, 0.9))
    return reverb(out, rng, rt60=1.6, wet=0.25)


def r_meadow(rng):
    out = wind_bed(rng, lo=250, hi=800, gusts=0.07, body=0.35, rumble=0.12, rustle=0.2)
    birds(rng, out, [(song_trill, 3500, 5500), (song_warbler, 2500, 4000)], count=4, rate=(0.1, 0.22))
    for st in poisson_times(rng, 0.08):
        bee_flyby(rng, out, st)
    crickets(rng, out, count=2, amp=0.015)
    return reverb(out, rng, rt60=0.8, wet=0.12)


def r_cicadas(rng):
    out = wind_bed(rng, lo=220, hi=600, gusts=0.05, body=0.2, rumble=0.1, rustle=0.08)
    cicadas(rng, out, count=5)
    birds(rng, out, [(song_chips, 3500, 5000)], count=2, rate=(0.03, 0.06), dist=(0.6, 1.0))
    return reverb(out, rng, rt60=1.0, wet=0.15)


def r_rainforest(rng):
    out = rain_bed(rng, wash=0.25, center=4500, drops=40, drop_amp=0.05, drips=2.5, body=0.08)
    birds(rng, out, [(song_exotic, 1500, 3000), (song_warbler, 2500, 4000),
                     (song_whistle, 1800, 2800)], count=6, rate=(0.08, 0.2))
    cicadas(rng, out, count=2, amp=0.05)
    frogs(rng, out, croakers=1, peepers=3, amp=0.08)
    return reverb(out, rng, rt60=1.8, wet=0.25)


# =========================================================================== #
# Night
# =========================================================================== #
def night_air(rng, level=0.12):
    return level * stereo_noise(rng, lambda f: bp(f, 80, 1200) * brown(f) ** 0.6, corr=0.5) \
        * slow_env(rng, 0.05, 0.6, 1.0)


def r_crickets(rng):
    out = night_air(rng)
    crickets(rng, out, count=7, amp=0.06)
    return reverb(out, rng, rt60=1.2, wet=0.2)


def r_frog_pond(rng):
    out = night_air(rng, 0.08)
    frogs(rng, out, croakers=4, peepers=6)
    laps(rng, out, period=(3.0, 5.0), amp=0.12)
    crickets(rng, out, count=3, amp=0.02)
    return reverb(out, rng, rt60=1.3, wet=0.22)


def r_night_forest(rng):
    out = night_air(rng, 0.06)
    out += wind_bed(rng, lo=200, hi=500, gusts=0.04, body=0.2, rumble=0.08, rustle=0.1)
    crickets(rng, out, count=5, amp=0.035)
    birds(rng, out, [(song_owl, 360, 420)], count=2, rate=(0.035, 0.05), dist=(0.4, 0.9))
    return reverb(out, rng, rt60=1.8, wet=0.28)


def r_summer_night(rng):
    out = night_air(rng, 0.1)
    out += wind_bed(rng, lo=220, hi=550, gusts=0.04, body=0.25, rumble=0.08, rustle=0.06)
    crickets(rng, out, count=5, amp=0.045)
    katydids(rng, out, count=3, amp=0.04)
    return reverb(out, rng, rt60=1.2, wet=0.2)


# =========================================================================== #
# Home
# =========================================================================== #
def r_clock(rng):
    out = room_tone(rng, 0.1)
    L = int(0.05 * SR)
    t = np.arange(L) / SR
    for i in range(int(DUR)):
        f = 3200 if i % 2 == 0 else 2700
        ev = (np.sin(TAU * f * t) * np.exp(-t / 0.006) + 0.6 * np.sin(TAU * 1150 * t) * np.exp(-t / 0.01)
              + 0.3 * filt(rng.standard_normal(L), "highpass", 3000) * np.exp(-t / 0.001))
        place(out, i + rng.normal(0, 0.002), ev * 0.12, 0.1)
    return reverb(out, rng, rt60=0.5, wet=0.2)


def r_fan(rng):
    t = np.arange(N) / SR
    blade = round(6.0 * DUR) / DUR
    whoosh = stereo_noise(rng, lambda f: bp(f, 150, 5000) * pink(f), corr=0.6)
    out = 0.5 * whoosh * (1 + 0.28 * np.sin(TAU * blade * t))
    out += mono(sum(np.sin(TAU * h * 60.0 * t) / h for h in (1, 2, 3)) * 0.025)
    rot = round(2.0 * DUR) / DUR
    L = int(0.01 * SR)
    tt = np.arange(L) / SR
    for i in range(int(round(rot * DUR))):
        place(out, i / rot, filt(rng.standard_normal(L), "bandpass", [1500, 4000]) * np.exp(-tt / 0.002) * 0.02, 0.0)
    return reverb(out, rng, rt60=0.5, wet=0.15)


def r_air_conditioner(rng):
    t = np.arange(N) / SR
    out = 0.5 * stereo_noise(rng, lambda f: bp(f, 60, 7000) * pink(f) ** 1.3, corr=0.7)
    out *= slow_env(rng, 0.1, 0.92, 1.0)
    hum = sum(np.sin(TAU * h * 120.0 * t + h) / h ** 1.5 for h in (1, 2, 3, 4)) * 0.03
    hum *= 1 + 0.2 * np.sin(TAU * (round(0.7 * DUR) / DUR) * t)
    out += mono(hum)
    return reverb(out, rng, rt60=0.4, wet=0.1)


def r_washer(rng):
    out = zeros()
    t = np.arange(N) / SR
    per = periodic(1.6)
    L = int(per * SR)
    u = np.linspace(0, 1, L)
    env = np.sin(math.pi * u) ** 2 * (0.6 + 0.4 * u)
    Lt = int(0.12 * SR)
    tt = np.arange(Lt) / SR
    for i in range(int(round(DUR / per))):
        p = 0.25 * math.sin(i)
        idx = (int(round(i * per * SR)) + np.arange(L)) % N
        for ch in range(2):
            out[ch, idx] += 0.35 * pan_gains(p)[ch] * filt(rng.standard_normal(L), "bandpass", [180, 1600]) * env
        place(out, i * per + per * 0.55, np.sin(TAU * 65 * tt) * np.exp(-tt / 0.04) * 0.25, 0.0)
    out += mono(0.03 * np.sin(TAU * np.cumsum(420 * (1 + 0.01 * np.sin(TAU * t / per))) / SR))
    out += room_tone(rng, 0.06)
    return reverb(out, rng, rt60=0.5, wet=0.15)


def r_simmer(rng):
    out = 0.04 * stereo_noise(rng, lambda f: bp(f, 2000, 8000) * pink(f), corr=0.5)
    bubbles(rng, out, 18, 150, 650, amp=0.12, pan=0.35, clustered=(1.5, 5, 0.06))
    L = int(0.03 * SR)
    tt = np.arange(L) / SR
    for st in poisson_times(rng, 0.15):                       # lid rattle
        for k in range(rng.integers(3, 8)):
            ev = np.sin(TAU * rng.uniform(2800, 3600) * tt) * np.exp(-tt / 0.006)
            place(out, st + k * 0.065, ev * 0.05, 0.1)
    out += room_tone(rng, 0.06)
    return reverb(out, rng, rt60=0.5, wet=0.15)


def r_purr(rng):
    out = room_tone(rng, 0.05)
    cyc = periodic(2.4)
    kl = int(0.03 * SR)
    for i in range(int(round(DUR / cyc))):
        for start, length, rate, amp in ((0.0, 1.35, 25.0, 1.0), (1.4, 0.95, 22.0, 0.6)):
            L = int(length * SR)
            times = np.arange(0, length, 1 / rate)
            times = times + rng.normal(0, 0.0015, len(times))
            imp = np.zeros(L)
            imp[np.clip((times * SR).astype(int), 0, L - 1)] = 1.0
            ker = filt(rng.standard_normal(kl), "lowpass", 400) * np.exp(-np.arange(kl) / (0.006 * SR))
            ev = filt(np.convolve(imp, ker)[:L], "bandpass", [60, 450])
            ev *= np.sin(math.pi * np.linspace(0, 1, L)) ** 0.8
            place(out, i * cyc + start, ev * amp * 0.5, 0.0)
    return reverb(out, rng, rt60=0.3, wet=0.08)


def r_keyboard(rng):
    out = room_tone(rng, 0.05)
    L = int(0.08 * SR)
    t = np.arange(L) / SR

    def key(st, space=False):
        click = filt(rng.standard_normal(L), "bandpass", [2000, 6000]) * np.exp(-t / 0.003)
        thock = filt(rng.standard_normal(L), "bandpass", [180, 700] if space else [300, 900]) \
            * np.exp(-t / (0.014 if space else 0.008))
        p = rng.uniform(-0.35, 0.35)
        place(out, st, (0.5 * click + (1.4 if space else 1.0) * thock) * rng.uniform(0.06, 0.1), p)
        place(out, st + rng.uniform(0.06, 0.11), click * 0.025, p)       # key release

    tm = rng.uniform(0, 1)
    while tm < DUR - 0.5:
        for _ in range(rng.integers(2, 9)):                # a burst of words
            for _ in range(rng.integers(2, 9)):
                key(tm)
                tm += rng.uniform(0.07, 0.16)
            key(tm, space=True)
            tm += rng.uniform(0.12, 0.25)
        tm += rng.uniform(0.8, 3.0)                        # thinking pause
    return reverb(out, rng, rt60=0.4, wet=0.12)


# =========================================================================== #
# Travel
# =========================================================================== #
def r_train(rng):
    out = 0.45 * stereo_noise(rng, lambda f: lp(f, 300) * brown(f) ** 0.8, corr=0.6) \
        * slow_env(rng, 0.1, 0.8, 1.0)
    out += 0.12 * stereo_noise(rng, lambda f: bp(f, 300, 3000) * pink(f), corr=0.4)
    per = periodic(2.0)
    L = int(0.1 * SR)
    t = np.arange(L) / SR
    for i in range(int(round(DUR / per))):
        for off in (0.0, 0.11, 0.9, 1.01):
            ev = np.sin(TAU * rng.uniform(60, 110) * t) * np.exp(-t / 0.035) \
                + 0.4 * filt(rng.standard_normal(L), "bandpass", [900, 3000]) * np.exp(-t / 0.012)
            place(out, i * per + off + rng.normal(0, 0.003), ev * rng.uniform(0.18, 0.26), rng.uniform(-0.2, 0.2))
    tt = np.arange(N) / SR
    out += mono(0.015 * (np.sin(TAU * 100 * tt) + 0.5 * np.sin(TAU * 200 * tt)))
    return reverb(out, rng, rt60=0.4, wet=0.12)


def r_airplane(rng):
    t = np.arange(N) / SR
    out = 0.6 * stereo_noise(rng, lambda f: bp(f, 40, 2500) * brown(f) ** 0.6 * bump(f, 300, 1.2, 0.8),
                             corr=0.75)
    out *= slow_env(rng, 0.05, 0.94, 1.0)
    out += mono(0.02 * (np.sin(TAU * (round(118 * DUR) / DUR) * t)
                        + np.sin(TAU * (round(118.6 * DUR) / DUR) * t)))
    return out


def r_night_drive(rng):
    out = 0.45 * stereo_noise(rng, lambda f: lp(f, 250) * brown(f) ** 0.8, corr=0.7)
    out += 0.15 * stereo_noise(rng, lambda f: bp(f, 300, 2500) * pink(f), corr=0.5) \
        * slow_env(rng, 0.15, 0.6, 1.0)
    L = int(4.0 * SR)
    u = np.linspace(0, 1, L)
    env = np.exp(-((u - 0.5) / 0.15) ** 2)
    for st in poisson_times(rng, 0.08):                       # passing cars
        d = rng.choice([-1, 1])
        gl, gr = pan_gains(d * (1.6 * u - 0.8))
        sig = filt(rng.standard_normal(L), "bandpass", [200, 3500]) * env * 0.4
        idx = (int(st * SR) + np.arange(L)) % N
        out[0, idx] += gl * sig
        out[1, idx] += gr * sig
    return out


def r_sailboat(rng):
    out = wind_bed(rng, lo=250, hi=700, gusts=0.06, body=0.3, rumble=0.12)
    laps(rng, out, period=(1.5, 2.8), amp=0.4, lo=150, hi=1400, hollow=1.5)
    kt = np.arange(int(0.04 * SR)) / SR
    ker = sum(np.sin(TAU * f * kt) * np.exp(-kt / 0.012) for f in (310, 720, 1150))
    for st in poisson_times(rng, 0.18):                       # wood creaks
        L = int(rng.uniform(0.5, 1.4) * SR)
        u = np.linspace(0, 1, L)
        rate = rng.uniform(15, 30) + rng.uniform(20, 50) * np.sin(math.pi * u)
        ph = np.cumsum(rate) / SR
        imp = np.zeros(L)
        imp[np.nonzero(np.diff(np.floor(ph)) > 0)[0]] = 1.0
        ev = np.convolve(imp, ker)[:L] * np.sin(math.pi * u)
        place(out, st, ev * 0.04, rng.uniform(-0.6, 0.6))
    out += 0.04 * grain_field(rng, 0.3, ring_kernel([2400, 3900], 0.05, 0.2), amp_sigma=0.3)
    return reverb(out, rng, rt60=0.7, wet=0.12)


# =========================================================================== #
# Noise colors
# =========================================================================== #
def r_white(rng):
    return stereo_noise(rng, lambda f: bp(f, 30, 15000), corr=0.0)


def r_pink(rng):
    return stereo_noise(rng, lambda f: bp(f, 25, 16000) * pink(f), corr=0.0)


def r_brown(rng):
    return stereo_noise(rng, lambda f: bp(f, 20, 12000) * brown(f), corr=0.0)


def r_green(rng):
    return stereo_noise(rng, lambda f: bp(f, 30, 12000) * pink(f) * bump(f, 500, 1.0, 4.0), corr=0.0)


# =========================================================================== #
# ASMR textures
# =========================================================================== #
def r_tapping(rng):
    out = room_tone(rng, 0.04)
    surfaces = [[900, 1700], [2200, 3100], [3500, 5200]]
    side = 1
    for st in poisson_times(rng, 0.55):
        surf = surfaces[rng.integers(len(surfaces))]
        side = -side
        pan = side * rng.uniform(0.5, 0.9)
        ker = ring_kernel(surf, rng.uniform(0.006, 0.03), 0.6)
        t = st
        for _ in range(rng.integers(5, 13)):
            place(out, t, ker(rng) * rng.uniform(0.15, 0.3), pan)
            t += rng.uniform(0.09, 0.16)
    return reverb(out, rng, rt60=0.3, wet=0.1)


def r_brushing(rng):
    out = room_tone(rng, 0.03)
    side = 1
    t = 0.0
    while t < DUR:
        L = int(rng.uniform(0.5, 1.2) * SR)
        u = np.linspace(0, 1, L)
        env = np.sin(math.pi * u) ** 1.5
        fc = rng.uniform(2000, 6000)
        bristle = filt(np.abs(rng.standard_normal(L)), "lowpass", 180)
        bristle /= bristle.max() + 1e-9
        sig = filt(rng.standard_normal(L), "bandpass", [fc * 0.5, min(fc * 1.8, 18000)]) * env * (0.5 + bristle)
        side = -side if rng.random() < 0.6 else side
        place(out, t, sig * 0.12, side * rng.uniform(0.4, 0.9))
        t += L / SR + rng.uniform(0.05, 0.4)
    return out


def r_paper(rng):
    out = room_tone(rng, 0.03)
    for st in poisson_times(rng, 0.4):
        L = int(rng.uniform(1.0, 2.8) * SR)
        u = np.linspace(0, 1, L)
        env = np.sin(math.pi * u) ** 0.8
        n_cr = int(rng.uniform(80, 220) * L / SR)
        ev = 0.05 * filt(rng.standard_normal(L), "bandpass", [1000, 6000]) * env
        for pos in rng.integers(0, L - 200, n_cr):
            m = int(rng.uniform(0.0005, 0.003) * SR)
            ev[pos:pos + m] += filt(rng.standard_normal(m), "highpass", 1500) * rng.lognormal(-2.2, 0.7) * env[pos]
        place(out, st, ev, rng.uniform(-0.7, 0.7))
    return reverb(out, rng, rt60=0.3, wet=0.08)


def r_hourglass(rng):
    out = 0.35 * grain_field(rng, 2500, burst_kernel(2500, 8000, (0.0005, 0.0015)),
                             rate_env=slow_env(rng, 0.2, 0.85, 1.0), amp_sigma=0.6, pan_spread=0.3)
    out += 0.06 * grain_field(rng, 20, burst_kernel(1500, 4000, (0.002, 0.005)), amp_sigma=0.4, pan_spread=0.3)
    out += room_tone(rng, 0.04)
    return reverb(out, rng, rt60=0.3, wet=0.1)


def r_heartbeat(rng):
    out = zeros()
    whoosh = stereo_noise(rng, lambda f: lp(f, 450) * brown(f) ** 0.7, corr=0.8)
    t = np.arange(N) / SR
    cdist = lambda c: ((t - c + 0.5) % 1.0) - 0.5       # circular distance → seamless
    swell = np.exp(-(cdist(0.15) / 0.18) ** 2) + 0.6 * np.exp(-(cdist(0.47) / 0.15) ** 2)
    out += 0.25 * whoosh * (0.4 + swell)
    L = int(0.2 * SR)
    tt = np.arange(L) / SR
    for i in range(int(DUR)):
        for off, f, a, d in ((0.0, 52, 1.0, 0.09), (0.32, 68, 0.7, 0.06)):
            ev = np.sin(TAU * np.cumsum(f * (1 - 0.3 * tt / 0.2)) / SR) * np.exp(-tt / d) * np.minimum(1, tt / 0.006)
            place(out, i + off, ev * a * 0.8, 0.0)
    return out


def r_wind_chimes(rng):
    out = wind_bed(rng, lo=220, hi=700, gusts=0.07, body=0.35, rumble=0.12, rustle=0.06)
    gust = slow_env(rng, 0.08, 0.0, 1.0) ** 2
    notes = [72, 74, 76, 79, 81, 84]                 # C major pentatonic
    pans = np.linspace(-0.7, 0.7, len(notes))
    L = int(3.0 * SR)
    t = np.arange(L) / SR
    for h in np.nonzero(rng.random(N) < gust * 2.5 / SR)[0]:
        k = rng.integers(len(notes))
        f0 = 440 * 2 ** ((notes[k] - 69) / 12)
        ev = sum(a * np.sin(TAU * f0 * rr * t + rng.uniform(0, TAU)) * np.exp(-t / dd)
                 for rr, a, dd in ((1, 1, 1.4), (2.756, 0.5, 0.6), (5.404, 0.25, 0.3), (8.933, 0.1, 0.15)))
        ev *= np.minimum(1, t / 0.001)
        place(out, h / SR, ev * rng.uniform(0.04, 0.09), pans[k])
    return reverb(out, rng, rt60=1.2, wet=0.2)


def r_singing_bowl(rng):
    out = room_tone(rng, 0.04)
    f0 = 220.0                                      # A3 — fits the music key
    L = int(16.0 * SR)
    t = np.arange(L) / SR
    for st in np.arange(0, DUR, 12.0) + rng.uniform(0, 1):
        ev = np.zeros(L)
        for ratio, a, tau in ((1.0, 1.0, 9.0), (2.71, 0.55, 6.0), (5.12, 0.25, 3.5), (8.0, 0.1, 2.0)):
            fr = f0 * ratio
            beat = rng.uniform(0.5, 1.6)
            ev += a * 0.5 * (np.sin(TAU * fr * t) + np.sin(TAU * (fr + beat) * t)) * np.exp(-t / tau)
        m = int(0.02 * SR)
        ev[:m] += 0.3 * filt(rng.standard_normal(m), "lowpass", 1200) * np.exp(-np.arange(m) / (0.004 * SR))
        place(out, st, ev * rng.uniform(0.18, 0.25), rng.uniform(-0.15, 0.15))
    return reverb(out, rng, rt60=3.0, wet=0.35)


def r_rain_stick(rng):
    out = room_tone(rng, 0.03)
    t = np.arange(N) / SR
    per = periodic(6.0)
    phase = (t % per) / per
    dens = np.where(phase < 0.75, np.clip(np.sin(math.pi * phase / 0.75), 0, None) ** 1.5, 0.0)
    direction = np.where((t // per) % 2 == 0, 1.0, -1.0)     # alternate L→R / R→L
    gl, gr = pan_gains(direction * (2 * np.minimum(phase / 0.75, 1) - 1) * 0.8)
    grains = grain_field(rng, 700, ring_kernel([3000, 4600, 6200], 0.004, 0.6), rate_env=dens + 1e-3,
                         amp_sigma=0.6, pan_spread=0.0)
    m = 0.5 * (grains[0] + grains[1])
    out[0] += 0.3 * gl * m
    out[1] += 0.3 * gr * m
    return reverb(out, rng, rt60=0.6, wet=0.15)


# =========================================================================== #
# The catalog: (id, label, category, icon, recipe, seed, rms_db).
# The four ORIGINAL_IDS recipes live in generate_ambient.py and master
# themselves; every other recipe is mastered to `rms_db` by the generator.
# =========================================================================== #
CATALOG = [
    ("rain", "Rain", "rain", "grain_rounded", make_rain, 22, None),
    ("drizzle", "Drizzle", "rain", "umbrella_rounded", r_drizzle, 101, -24.0),
    ("downpour", "Downpour", "rain", "water_rounded", r_downpour, 102, -21.0),
    ("window_rain", "Rain on Window", "rain", "window_rounded", r_window, 103, -23.0),
    ("tent_rain", "Rain on Tent", "rain", "holiday_village_rounded", r_tent, 104, -22.0),
    ("tin_roof", "Tin Roof Rain", "rain", "roofing_rounded", r_tin_roof, 105, -22.0),
    ("thunderstorm", "Thunderstorm", "rain", "thunderstorm_rounded", r_thunderstorm, 106, -21.0),

    ("ocean", "Ocean", "water", "waves_rounded", make_ocean, 33, None),
    ("stream", "Stream", "water", "water_drop_rounded", make_stream, 44, None),
    ("waterfall", "Waterfall", "water", "landscape_rounded", r_waterfall, 201, -22.0),
    ("lake", "Lake Shore", "water", "kayaking_rounded", r_lake, 202, -23.0),
    ("cave", "Cave Drips", "water", "terrain_rounded", r_cave, 203, -24.0),
    ("fountain", "Fountain", "water", "shower_rounded", r_fountain, 204, -22.0),
    ("underwater", "Underwater", "water", "scuba_diving_rounded", r_underwater, 205, -22.0),

    ("breeze", "Gentle Breeze", "wind", "air_rounded", r_breeze, 301, -24.0),
    ("trees", "Wind in Trees", "wind", "park_rounded", r_trees, 302, -23.0),
    ("howling", "Howling Wind", "wind", "storm_rounded", r_howling, 303, -22.0),
    ("desert", "Desert Wind", "wind", "wb_sunny_rounded", r_desert, 304, -23.0),
    ("blizzard", "Blizzard", "wind", "ac_unit_rounded", r_blizzard, 305, -22.0),

    ("fireplace", "Fireplace", "fire", "fireplace_rounded", make_fireplace, 55, None),
    ("campfire", "Campfire", "fire", "local_fire_department_rounded", r_campfire, 401, -22.0),
    ("candle", "Candle Flame", "fire", "light_rounded", r_candle, 402, -27.0),
    ("wood_stove", "Wood Stove", "fire", "whatshot_rounded", r_wood_stove, 403, -23.0),

    ("forest_birds", "Forest Birds", "nature", "forest_rounded", r_forest_birds, 501, -23.0),
    ("meadow", "Spring Meadow", "nature", "local_florist_rounded", r_meadow, 502, -23.0),
    ("cicadas", "Summer Cicadas", "nature", "wb_twilight_rounded", r_cicadas, 503, -24.0),
    ("rainforest", "Rainforest", "nature", "eco_rounded", r_rainforest, 504, -22.0),

    ("crickets", "Crickets", "night", "nightlight_round", r_crickets, 601, -25.0),
    ("frog_pond", "Frog Pond", "night", "pest_control_rounded", r_frog_pond, 602, -23.0),
    ("night_forest", "Night Forest", "night", "nights_stay_rounded", r_night_forest, 603, -24.0),
    ("summer_night", "Summer Night", "night", "bedtime_rounded", r_summer_night, 604, -24.0),

    ("clock", "Clock Ticking", "home", "schedule_rounded", r_clock, 701, -26.0),
    ("fan", "Ceiling Fan", "home", "wind_power_rounded", r_fan, 702, -24.0),
    ("air_conditioner", "Air Conditioner", "home", "mode_fan_off_rounded", r_air_conditioner, 703, -24.0),
    ("washer", "Washing Machine", "home", "local_laundry_service_rounded", r_washer, 704, -23.0),
    ("simmer", "Simmering Pot", "home", "soup_kitchen_rounded", r_simmer, 705, -23.0),
    ("purr", "Purring Cat", "home", "pets_rounded", r_purr, 706, -23.0),
    ("keyboard", "Keyboard Typing", "home", "keyboard_rounded", r_keyboard, 707, -24.0),

    ("train", "Train Journey", "travel", "train_rounded", r_train, 801, -22.0),
    ("airplane", "Airplane Cabin", "travel", "flight_rounded", r_airplane, 802, -23.0),
    ("night_drive", "Night Drive", "travel", "directions_car_rounded", r_night_drive, 803, -23.0),
    ("sailboat", "Sailboat", "travel", "sailing_rounded", r_sailboat, 804, -23.0),

    ("white_noise", "White Noise", "noise", "blur_on_rounded", r_white, 901, -27.0),
    ("pink_noise", "Pink Noise", "noise", "blur_circular_rounded", r_pink, 902, -25.0),
    ("brown_noise", "Brown Noise", "noise", "lens_blur_rounded", r_brown, 903, -23.0),
    ("green_noise", "Green Noise", "noise", "grass_rounded", r_green, 904, -24.0),

    ("tapping", "Gentle Tapping", "asmr", "touch_app_rounded", r_tapping, 1001, -25.0),
    ("brushing", "Soft Brushing", "asmr", "brush_rounded", r_brushing, 1002, -25.0),
    ("paper", "Paper Crinkle", "asmr", "description_rounded", r_paper, 1003, -26.0),
    ("hourglass", "Sand Hourglass", "asmr", "hourglass_bottom_rounded", r_hourglass, 1004, -25.0),
    ("heartbeat", "Heartbeat", "asmr", "favorite_rounded", r_heartbeat, 1005, -22.0),
    ("wind_chimes", "Wind Chimes", "asmr", "notifications_rounded", r_wind_chimes, 1006, -23.0),
    ("singing_bowl", "Singing Bowl", "asmr", "self_improvement_rounded", r_singing_bowl, 1007, -23.0),
    ("rain_stick", "Rain Stick", "asmr", "auto_awesome_rounded", r_rain_stick, 1008, -25.0),
]

CATEGORIES = [  # (id, label, icon) — display order
    ("rain", "Rain", "grain_rounded"),
    ("water", "Water", "water_rounded"),
    ("wind", "Wind", "air_rounded"),
    ("fire", "Fire", "local_fire_department_rounded"),
    ("nature", "Nature", "forest_rounded"),
    ("night", "Night", "nightlight_round"),
    ("home", "Home", "home_rounded"),
    ("travel", "Travel", "luggage_rounded"),
    ("noise", "Noise", "graphic_eq_rounded"),
    ("asmr", "ASMR", "spa_rounded"),
]
