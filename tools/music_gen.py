"""Procedural soundtrack for Fallen Below, v2.

One leitmotif ("the Hungry Dark") runs through everything: the menu, the run (calm and
combat layers in sync), the boss (in Phrygian) and the story pages (Lia's lullaby).
Instruments are synthesised: string ensembles with vibrato, a formant choir, solo cello,
flute, harp (Karplus-Strong), celesta, bells, brass with an opening filter, taiko,
heartbeat. Everything goes through a stereo convolution reverb. Loops are seamless:
release tails and the reverb wrap around to the start.

  menu        64 bpm, 16 bars   strings, cello then solo strings, choir, bells, heartbeat
  story       72 bpm, 16 bars   celesta lullaby, harp, soft strings, choir
  run_calm    96 bpm, 32 bars   harp arpeggios, pad, heartbeat, flute theme   (base layer)
  run_combat  96 bpm, 32 bars   taiko, string ostinato, brass, bass, theme    (layered on top)
  boss       132 bpm, 32 bars   choir, brass theme in Phrygian, taiko, distorted bass, strings
  victory / defeat               short stingers

Run: python3 tools/music_gen.py [track ...]   (needs numpy, scipy, ffmpeg)
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")
rng = np.random.default_rng(11)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ================================================================ DSP basics

def adsr(n, a=0.01, d=0.1, s=0.8, r=0.3):
    a_n, d_n, r_n = max(int(a * SR), 1), max(int(d * SR), 1), max(int(r * SR), 1)
    sus = max(n - a_n - d_n - r_n, 0)
    e = np.concatenate([np.linspace(0, 1, a_n) ** 1.5, np.linspace(1, s, d_n), np.full(sus, s), np.linspace(s, 0, r_n) ** 1.3])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff / (SR / 2), 0.99), "low", output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff / (SR / 2), 0.99), "high", output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band", output="sos")
    return signal.sosfilt(sos, x)


def noise(n):
    return rng.uniform(-1, 1, n)


def vib_phase(f, n, rate=5.0, depth=0.005, delay=0.3, drift=0.0):
    """Phase of a note with delayed vibrato (and optional slow pitch drift)."""
    t = np.arange(n) / SR
    ramp = np.clip((t - delay) / 0.5, 0, 1)
    inst = f * (1 + depth * ramp * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28)) + drift * np.sin(2 * np.pi * 0.3 * t))
    return 2 * np.pi * np.cumsum(inst) / SR


def naive_saw(phase):
    return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0


def additive_saw(phase, f, max_h=40):
    out = np.zeros(len(phase))
    for k in range(1, max_h + 1):
        if f * k > SR / 2.3:
            break
        out += np.sin(k * phase) / k
    return out * 0.55


def n_of(sec):
    return int(sec * SR)


# ================================================================ instruments (mono)

def strings(notes, dur, attack=0.5, release=1.2, cutoff=2600, voices=3, gain=1.0, depth=0.006):
    n = n_of(dur + release)
    out = np.zeros(n)
    for m in notes:
        f = hz(m)
        for v in range(voices):
            det = 1 + (v - (voices - 1) / 2) * 0.004
            out += naive_saw(vib_phase(f * det, n, rate=4.8 + v * 0.4, depth=depth, delay=0.15))
    out = lowpass(lowpass(out, cutoff), cutoff * 1.5)
    out += lowpass(noise(n), 3000) * 0.015 * len(notes)  # bow hiss
    return out * adsr(n, attack, 0.3, 0.85, release) * gain / (voices * max(len(notes), 1)) * 1.4


def staccato(m, dur=0.18, gain=1.0, cutoff=2200):
    n = n_of(dur + 0.15)
    f = hz(m)
    x = naive_saw(vib_phase(f, n, depth=0.0)) + naive_saw(vib_phase(f * 1.004, n, depth=0.0))
    return lowpass(x, cutoff) * adsr(n, 0.005, 0.08, 0.5, 0.12) * gain * 0.5


FORMANTS = {"a": [(730, 1.0), (1090, 0.5), (2440, 0.25)], "o": [(450, 1.0), (800, 0.45), (2830, 0.12)],
            "u": [(325, 1.0), (700, 0.3), (2530, 0.08)], "e": [(530, 1.0), (1840, 0.4), (2480, 0.2)]}


def choir(notes, dur, vowel="a", attack=0.9, release=1.5, gain=1.0, voices=3):
    n = n_of(dur + release)
    src = np.zeros(n)
    for m in notes:
        for v in range(voices):
            f = hz(m) * (1 + (v - 1) * 0.005)
            src += naive_saw(vib_phase(f, n, rate=4.6 + v * 0.5, depth=0.012, delay=0.2))
    out = np.zeros(n)
    for freq, g in FORMANTS[vowel]:
        out += bandpass(src, freq * 0.85, freq * 1.15) * g
    out += lowpass(noise(n), 5000) * 0.01  # breath
    return out * adsr(n, attack, 0.4, 0.9, release) * gain / (voices * max(len(notes), 1)) * 3.0


def cello(m, dur, gain=1.0, cutoff=2400, attack=0.12):
    n = n_of(dur + 0.4)
    f = hz(m)
    x = additive_saw(vib_phase(f, n, rate=5.3, depth=0.007, delay=0.18), f)
    x = lowpass(x, cutoff) + bandpass(x, 200, 900) * 0.6
    x += bandpass(noise(n), 800, 3000) * 0.02
    return x * adsr(n, attack, 0.2, 0.9, 0.35) * gain


def flute(m, dur, gain=1.0):
    n = n_of(dur + 0.25)
    f = hz(m)
    ph = vib_phase(f, n, rate=5.0, depth=0.006, delay=0.25)
    x = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    x += bandpass(noise(n), f * 0.8, min(f * 3.0, 15000)) * 0.12
    return x * adsr(n, 0.07, 0.15, 0.8, 0.22) * gain * 0.6


def celesta(m, dur=2.0, gain=1.0):
    n = n_of(dur)
    t = np.arange(n) / SR
    f = hz(m)
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t * 1.6) + 0.35 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 4.0)
         + 0.12 * np.sin(2 * np.pi * f * 9.8 * t) * np.exp(-t * 9.0))
    x[: n_of(0.003)] *= np.linspace(0, 1, n_of(0.003))
    return x * gain * 0.6


def harp(m, dur=2.5, gain=1.0):
    """Karplus-Strong plucked string."""
    f = hz(m)
    n = n_of(dur)
    period = max(int(round(SR / f)), 2)
    exc = np.zeros(n)
    burst = lowpass(noise(period), min(f * 6, 8000))
    exc[:period] = burst
    a = np.zeros(period + 2)
    a[0] = 1.0
    a[period] = -0.497
    a[period + 1] = -0.497
    y = signal.lfilter([1.0], a, exc)
    y = lowpass(y, 5000)
    return y * gain * 0.8 * adsr(n, 0.002, 0.1, 1.0, 0.3)


def bell(m, dur=4.0, gain=1.0):
    n = n_of(dur)
    t = np.arange(n) / SR
    f = hz(m)
    out = np.zeros(n)
    for ratio, amp, dec in [(0.5, 0.6, 0.6), (1.0, 1.0, 0.9), (1.19, 0.5, 1.4), (1.56, 0.4, 1.8), (2.0, 0.35, 2.2),
                            (2.51, 0.25, 3.0), (2.66, 0.2, 3.2), (3.01, 0.15, 4.0)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t * dec)
    return out * gain * 0.3


def brass(notes, dur, gain=1.0, swell=0.12, dark=700, bright=3200):
    n = n_of(dur + 0.3)
    src = np.zeros(n)
    for m in notes:
        f = hz(m)
        src += naive_saw(vib_phase(f, n, rate=5.5, depth=0.004, delay=0.3)) + naive_saw(vib_phase(f * 1.003, n, depth=0.0))
    e = adsr(n, swell, 0.25, 0.75, 0.25)
    x = lowpass(src, dark) * (1 - e) + lowpass(src, bright) * e  # the filter opens with the note
    return np.tanh(x * 1.5) * e * gain / max(len(notes), 1) * 0.6


def bass(m, dur, gain=1.0, drive=2.5, cutoff=900):
    n = n_of(dur + 0.08)
    f = hz(m)
    ph = 2 * np.pi * f * np.arange(n) / SR
    x = naive_saw(ph) * 0.6 + np.sin(ph) * 0.8
    x = lowpass(np.tanh(x * drive), cutoff)
    return x * adsr(n, 0.005, 0.1, 0.8, 0.06) * gain * 0.5


def drone(m, dur, gain=1.0):
    n = n_of(dur)
    t = np.arange(n) / SR
    f = hz(m)
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t + 1.0) + 0.15 * naive_saw(2 * np.pi * f * 1.002 * t)
    x = lowpass(x, 600) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t))
    return x * adsr(n, 1.5, 0.5, 1.0, 1.5) * gain * 0.5


def taiko(gain=1.0, pitch=1.0):
    n = n_of(0.9)
    t = np.arange(n) / SR
    f = (55 + 45 * np.exp(-t * 18)) * pitch
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)
    skin = lowpass(noise(n), 1200) * np.exp(-t * 25) * 0.6
    return np.tanh((body + skin) * 1.6) * gain * 0.8


def low_boom(gain=1.0):
    n = n_of(2.2)
    t = np.arange(n) / SR
    f = 38 + 30 * np.exp(-t * 8)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2) + lowpass(noise(n), 300) * np.exp(-t * 6) * 0.4
    return x * gain


def kick(gain=1.0):
    n = n_of(0.35)
    t = np.arange(n) / SR
    f = 48 + 90 * np.exp(-t * 35)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * gain


def heartbeat(gain=1.0):
    """lub ... dub"""
    n = n_of(0.75)
    out = np.zeros(n)
    lub = lowpass(kick(1.0), 160)
    dub = lowpass(kick(0.65), 200)
    out[: len(lub)] += lub
    out[n_of(0.28): n_of(0.28) + len(dub)] += dub[: n - n_of(0.28)]
    return out * gain


def frame_drum(gain=1.0):
    n = n_of(0.4)
    t = np.arange(n) / SR
    f = 140 + 60 * np.exp(-t * 30)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12) + bandpass(noise(n), 400, 2500) * np.exp(-t * 30) * 0.4) * gain


def clap(gain=1.0):
    n = n_of(0.3)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        i = n_of(d)
        seg = bandpass(noise(n - i), 900, 5000) * np.exp(-t[: n - i] * (60 if k < 2 else 18))
        x[i:] += seg
    return x * gain * 0.6


def shaker(gain=1.0):
    n = n_of(0.09)
    t = np.arange(n) / SR
    return highpass(noise(n), 5000) * np.exp(-t * 50) * gain * 0.35


def cymbal_swell(dur, gain=1.0):
    n = n_of(dur)
    x = highpass(noise(n), 4000) * np.linspace(0, 1, n) ** 3
    return x * gain * 0.35


def crash(gain=1.0):
    n = n_of(3.0)
    t = np.arange(n) / SR
    return highpass(noise(n), 3000) * np.exp(-t * 1.6) * gain * 0.3


# ================================================================ harmony

QUAL = {"m": [0, 3, 7], "M": [0, 4, 7], "7": [0, 4, 7, 10], "sus": [0, 5, 7]}
CHORDS = {  # root (midi, octave 3) and quality
    "Dm": (50, "m"), "Bb": (46, "M"), "Gm": (43, "m"), "A": (45, "M"), "F": (41, "M"), "C": (48, "M"),
    "Eb": (51, "M"), "A7": (45, "7"), "D": (50, "M"), "Asus": (45, "sus"),
}


def root(name):
    return CHORDS[name][0]


def voicing(name, low=55, high=72):
    """Close triad between low and high."""
    r, q = CHORDS[name]
    notes = []
    for iv in QUAL[q]:
        m = r + iv
        while m < low:
            m += 12
        while m > high:
            m -= 12
        notes.append(m)
    return sorted(notes)


def tones(name, low=50):
    r, q = CHORDS[name]
    base = r
    while base < low:
        base += 12
    return [base + iv for iv in QUAL[q]]


# The leitmotif: 16 bars of (midi, beats) over PROG, one bar per chord.
PROG = ["Dm", "Bb", "Gm", "A", "Dm", "F", "C", "A", "Gm", "Dm", "Bb", "F", "Gm", "Bb", "A", "A"]
THEME = [
    [(69, 2), (65, 1), (64, 1)], [(62, 2), (65, 1), (70, 1)], [(69, 3), (67, 1)], [(64, 1.5), (65, 0.5), (64, 2)],
    [(69, 2), (74, 1), (72, 1)], [(69, 2), (65, 1), (69, 1)], [(67, 2), (64, 1), (72, 1)], [(69, 4)],
    [(70, 2), (69, 1), (67, 1)], [(65, 2), (64, 1), (62, 1)], [(65, 1), (67, 1), (69, 1), (70, 1)], [(72, 3), (69, 1)],
    [(74, 2), (72, 1), (70, 1)], [(69, 2), (67, 1), (65, 1)], [(64, 2), (67, 1), (73, 1)], [(69, 4)],
]
# Lia's lullaby (story): 8 bars
LULLABY_PROG = ["Dm", "F", "Bb", "A", "Gm", "Dm", "A", "Dm"]
LULLABY = [
    [(74, 1), (77, 1), (81, 2)], [(79, 1), (77, 1), (76, 2)], [(77, 1), (74, 1), (70, 2)], [(73, 2), (76, 2)],
    [(74, 1), (76, 1), (77, 2)], [(79, 1), (77, 1), (74, 2)], [(76, 1), (73, 1), (69, 2)], [(74, 4)],
]
# Boss: the theme bent into Phrygian, 8 chords of 2 bars
BOSS_PROG = ["Dm", "Eb", "Dm", "C", "Bb", "Eb", "Dm", "A"]
BOSS_THEME = [
    [(69, 3), (67, 1), (65, 2), (63, 2)], [(62, 4), (63, 2), (67, 2)], [(69, 2), (70, 2), (69, 2), (67, 2)],
    [(67, 4), (65, 2), (64, 2)], [(65, 4), (62, 2), (65, 2)], [(67, 4), (70, 2), (67, 2)], [(69, 6), (74, 2)],
    [(73, 4), (69, 4)],
]


# ================================================================ track & mixing

class Track:
    def __init__(self, bpm, bars, beats_per_bar=4, tail=7.0, loop=True):
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.loop = loop
        self.n = n_of(bars * beats_per_bar * 60.0 / bpm)
        self.tail = n_of(tail)
        self.dry = np.zeros((2, self.n + self.tail))
        self.send = np.zeros((2, self.n + self.tail))

    def sec(self, beat):
        return beat * 60.0 / self.bpm

    def beats(self, b):
        return b * 60.0 / self.bpm

    def add(self, x, beat, pan=0.0, gain=1.0, verb=0.3, humanize=0.006):
        t = self.sec(beat) + (rng.uniform(-humanize, humanize) if humanize else 0.0)
        i = max(int(round(t * SR)), 0)
        room = self.dry.shape[1] - i
        if room <= 0:
            return
        x = x[:room]
        ang = (pan + 1) * np.pi / 4
        l, r = np.cos(ang), np.sin(ang)
        self.dry[0, i: i + len(x)] += x * l * gain
        self.dry[1, i: i + len(x)] += x * r * gain
        self.send[0, i: i + len(x)] += x * l * gain * verb
        self.send[1, i: i + len(x)] += x * r * gain * verb

    def render(self, rt=3.0, wet=1.0, bright=5000, predelay=0.025):
        ir = make_ir(rt, bright, predelay)
        if self.loop:
            dry = self._wrap(self.dry)
            send = self._wrap(self.send)
            tiled = np.concatenate([send, send], axis=1)
            w = np.stack([signal.fftconvolve(tiled[c], ir[c])[self.n: 2 * self.n] for c in range(2)])
        else:
            dry, send = self.dry, self.send
            w = np.stack([signal.fftconvolve(send[c], ir[c])[: send.shape[1]] for c in range(2)])
        mix = dry + w * wet
        return master(mix)

    def _wrap(self, buf):
        out = buf[:, : self.n].copy()
        out[:, : self.tail] += buf[:, self.n:]
        return out


def make_ir(rt, bright, predelay):
    n = n_of(rt * 1.3)
    t = np.arange(n) / SR
    ir = np.zeros((2, n + n_of(predelay)))
    for c in range(2):
        tail = rng.normal(0, 1, n) * np.exp(-6.9 * t / rt)
        tail = lowpass(tail, bright) * 0.6 + lowpass(tail, bright * 0.3) * 0.4
        d = n_of(predelay)
        ir[c, d: d + n] = tail
        for k in range(6):  # a few early reflections
            j = d + n_of(rng.uniform(0.004, 0.06))
            ir[c, j] += rng.uniform(0.2, 0.5) * (1 if rng.random() > 0.5 else -1)
    ir /= np.sqrt(np.sum(ir ** 2) / 2) * 3.2
    return ir


def master(x, peak=0.89):
    x = np.stack([highpass(x[c], 28) for c in range(2)])
    x = x / (np.max(np.abs(x)) + 1e-9) * 1.25
    x = np.tanh(x) / np.tanh(1.25)  # gentle glue / saturation
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def theme_notes(theme, beats_per_bar, stretch=1.0):
    """Flattens a bar-wise theme into (start_beat, midi, length_beats)."""
    out = []
    for bar, notes in enumerate(theme):
        b = bar * beats_per_bar * stretch
        for m, d in notes:
            out.append((b, m, d * stretch))
            b += d * stretch
    return out


# ================================================================ tracks

def menu():
    tr = Track(64, 16)
    bar = 4
    for i, ch in enumerate(PROG):
        tr.add(strings(voicing(ch, 53, 69), tr.beats(bar) + 0.6, attack=1.0, release=1.6, cutoff=1800, gain=0.55), i * bar, pan=-0.2, verb=0.6)
        tr.add(strings([root(ch) - 12], tr.beats(bar) + 0.4, attack=0.8, cutoff=700, gain=0.35, voices=2), i * bar, pan=0.1, verb=0.4)
        if i >= 8:
            tr.add(choir(voicing(ch, 60, 76), tr.beats(bar) + 0.5, "o", gain=0.5), i * bar, pan=0.25, verb=0.8)
        for beat in range(4):  # the heart under everything
            tr.add(heartbeat(0.5 if beat == 0 else 0.3), i * bar + beat, verb=0.15, humanize=0)
    tr.add(drone(38, tr.sec(64) + 1, 0.5), 0, verb=0.3)
    for i in [0, 4, 8, 12]:
        tr.add(bell(50, 6.0, 0.55), i * bar, pan=0.4, verb=0.7)
    for b, m, d in theme_notes(THEME[:8], bar):
        tr.add(cello(m - 12, tr.beats(d) + 0.05, 0.55), b, pan=-0.1, verb=0.45)
    for b, m, d in theme_notes(THEME[8:], bar):
        tr.add(cello(m, tr.beats(d) + 0.05, 0.42, cutoff=4000), b + 32, pan=0.1, verb=0.55)
    for i in range(8, 16):  # harp ripples in the second half
        notes = tones(PROG[i], 62)
        for k, m in enumerate(notes + [notes[0] + 12]):
            tr.add(harp(m, 2.5, 0.35), i * bar + k * 0.5, pan=0.35, verb=0.5)
    return tr.render(rt=4.2, bright=4200)


def story():
    tr = Track(72, 16)
    bar = 4
    for rep in range(2):
        off = rep * 32
        for i, ch in enumerate(LULLABY_PROG):
            tr.add(strings(voicing(ch, 55, 70), tr.beats(bar) + 0.6, attack=1.2, cutoff=1500, gain=0.4), off + i * bar, verb=0.7)
            if rep == 1:
                tr.add(choir(voicing(ch, 62, 76), tr.beats(bar) + 0.4, "u", gain=0.35), off + i * bar, pan=-0.3, verb=0.8)
                for k, m in enumerate(tones(ch, 57)):
                    tr.add(harp(m, 2.5, 0.3), off + i * bar + 2 + k * 0.33, pan=0.4, verb=0.5)
        for b, m, d in theme_notes(LULLABY, bar):
            tr.add(celesta(m, 2.2, 0.55), off + b, pan=0.15, verb=0.6)
            if rep == 1:
                tr.add(celesta(m - 12, 2.0, 0.25), off + b, pan=-0.15, verb=0.6)
    tr.add(bell(62, 5.0, 0.3), 0, pan=-0.3, verb=0.8)
    tr.add(bell(62, 5.0, 0.3), 32, pan=-0.3, verb=0.8)
    return tr.render(rt=4.5, bright=3800)


RUN_BPM = 96
RUN_BARS = 32


def run_calm():
    tr = Track(RUN_BPM, RUN_BARS)
    for i, ch in enumerate(PROG):
        b0 = i * 8  # two bars per chord
        tr.add(strings(voicing(ch, 55, 69), tr.beats(8) + 0.5, attack=1.4, cutoff=1300, gain=0.4), b0, pan=-0.15, verb=0.55)
        tr.add(drone(root(ch) - 12, tr.beats(8) + 1.0, 0.45), b0, verb=0.2)
        t = tones(ch, 57)
        pattern = [t[0], t[1], t[2], t[0] + 12, t[1] + 12, t[0] + 12, t[2], t[1]]
        for k in range(16):  # harp eighths
            tr.add(harp(pattern[k % 8], 1.8, 0.32 if k % 4 == 0 else 0.22), b0 + k * 0.5, pan=0.3 if k % 2 else 0.1, verb=0.4)
        for bar in range(2):
            tr.add(heartbeat(0.55), b0 + bar * 4, verb=0.1, humanize=0)
            tr.add(heartbeat(0.3), b0 + bar * 4 + 2, verb=0.1, humanize=0)
            if i >= 4:
                for k in range(8):
                    tr.add(shaker(0.5 if k % 2 == 0 else 0.3), b0 + bar * 4 + k * 0.5, pan=0.5, verb=0.1)
    # the theme on flute, stretched over two bars per chord, in the second half
    for b, m, d in theme_notes(THEME[8:], 8):
        tr.add(flute(m + 12, tr.beats(d) * 0.95, 0.4), 64 + b, pan=-0.2, verb=0.5)
    for b, m, d in theme_notes(THEME[:8], 8):  # first half: a quiet cello answer, every other note
        if b % 8 == 0:
            tr.add(cello(m - 12, tr.beats(d) * 0.9, 0.3, cutoff=1500), b, pan=0.2, verb=0.5)
    return tr.render(rt=3.2, bright=4500)


def run_combat():
    tr = Track(RUN_BPM, RUN_BARS)
    for i, ch in enumerate(PROG):
        b0 = i * 8
        r = root(ch)
        tr.add(low_boom(0.7), b0, verb=0.3)
        tr.add(brass(voicing(ch, 50, 64), tr.beats(1.5), 0.7), b0, pan=-0.1, verb=0.35)
        tr.add(brass(voicing(ch, 50, 64), tr.beats(0.75), 0.55, swell=0.05), b0 + 6.5, pan=-0.1, verb=0.35)
        for bar in range(2):
            bb = b0 + bar * 4
            for beat, g in [(0, 1.0), (1.5, 0.6), (2, 0.8), (3, 0.55), (3.5, 0.5)]:
                tr.add(taiko(g, 1.0 if beat in (0, 2) else 1.3), bb + beat, pan=-0.2 if beat % 1 else 0.2, verb=0.25)
            if (i * 2 + bar) % 4 == 3:  # fill
                for k in range(4):
                    tr.add(frame_drum(0.5 + k * 0.12), bb + 3 + k * 0.25, pan=0.3, verb=0.2)
            if i >= 8:
                tr.add(clap(0.55), bb + 1, verb=0.25)
                tr.add(clap(0.55), bb + 3, verb=0.25)
            for k in range(16):  # string ostinato in sixteenths
                m = [r, r, r + 7, r + 12][k % 4] + 12
                tr.add(staccato(m, 0.14, 0.55 if k % 4 == 0 else 0.4), bb + k * 0.25, pan=0.35, verb=0.25)
            for k in range(8):
                tr.add(bass(r - 12 if k % 4 else r - 12, tr.beats(0.45), 0.55), bb + k * 0.5, verb=0.05)
        if i % 4 == 0:
            tr.add(crash(0.6), b0, pan=0.4, verb=0.3)
        if i % 4 == 3:
            tr.add(cymbal_swell(tr.beats(4), 0.6), b0 + 4, pan=-0.3, verb=0.2)
    # the theme on high strings in the second half, an octave over the flute
    for b, m, d in theme_notes(THEME[8:], 8):
        tr.add(strings([m + 12], tr.beats(d) * 0.98, attack=0.08, release=0.4, cutoff=4200, gain=0.55, voices=3, depth=0.008), 64 + b, pan=-0.25, verb=0.4)
    return tr.render(rt=2.4, bright=5200)


def boss():
    tr = Track(132, 32)
    for rep in range(2):
        off = rep * 64
        for i, ch in enumerate(BOSS_PROG):
            b0 = off + i * 8
            r = root(ch)
            tr.add(choir(voicing(ch, 55, 72), tr.beats(8) + 0.3, "a", attack=0.4, gain=0.7 + 0.2 * rep), b0, pan=0.0, verb=0.5)
            if rep == 1:
                tr.add(choir([n + 12 for n in voicing(ch, 60, 72)], tr.beats(8) + 0.3, "e", attack=0.4, gain=0.35), b0, pan=0.3, verb=0.6)
            tr.add(low_boom(0.9), b0, verb=0.3)
            for bar in range(2):
                bb = b0 + bar * 4
                for k in range(8):
                    g = 1.0 if k in (0, 3, 6) else 0.55
                    tr.add(taiko(g, 1.0 if k in (0, 3, 6) else 1.4), bb + k * 0.5, pan=0.2 if k % 2 else -0.2, verb=0.2)
                    tr.add(bass(r - 12, tr.beats(0.45), 0.7, drive=4.0, cutoff=1200), bb + k * 0.5, verb=0.05)
                tr.add(clap(0.7), bb + 1, verb=0.3)
                tr.add(clap(0.7), bb + 3, verb=0.3)
                if rep == 1 or i >= 4:
                    for k in range(16):
                        m = [r, r + 1 if ch == "Dm" else r, r + 7, r + 12][k % 4] + 24
                        tr.add(staccato(m, 0.12, 0.45), bb + k * 0.25, pan=-0.35, verb=0.25)
            if i % 4 == 0:
                tr.add(crash(0.7), b0, pan=0.4, verb=0.3)
            tr.add(bell(r + 24, 3.0, 0.35), b0, pan=0.45, verb=0.5)
        for b, m, d in theme_notes(BOSS_THEME, 8):
            if rep == 0:
                tr.add(brass([m - 12], tr.beats(d) * 0.95, 0.85, swell=0.08), off + b, pan=-0.1, verb=0.35)
            else:
                tr.add(brass([m - 12, m - 15 if m - 15 > 50 else m - 12], tr.beats(d) * 0.95, 0.85, swell=0.08), off + b, pan=-0.1, verb=0.35)
                tr.add(strings([m + 12], tr.beats(d) * 0.98, attack=0.05, release=0.3, cutoff=5000, gain=0.5, depth=0.01), off + b, pan=0.25, verb=0.4)
        tr.add(cymbal_swell(tr.beats(4), 0.7), off + 60, verb=0.2)
    return tr.render(rt=2.6, bright=5000)


def victory():
    tr = Track(80, 3, loop=False, tail=5.0)
    tr.add(low_boom(0.9), 0)
    for k in range(4):
        tr.add(taiko(0.8 - k * 0.12), k * 0.5, verb=0.3)
    tr.add(brass([62, 66, 69], tr.beats(10), 0.8, swell=0.3), 0, verb=0.5)
    tr.add(choir([62, 66, 69, 74], tr.beats(11), "a", attack=0.6, gain=0.8), 0, verb=0.7)
    tr.add(strings([50, 57], tr.beats(11), attack=0.5, gain=0.6), 0, verb=0.5)
    for k, m in enumerate([74, 78, 81, 86]):
        tr.add(bell(m, 4.0, 0.5), 2 + k * 0.5, pan=-0.3 + k * 0.2, verb=0.7)
    out = tr.render(rt=3.5)
    n = out.shape[1]
    fade = np.ones(n)
    fade[-n_of(2.0):] = np.linspace(1, 0, n_of(2.0))
    return out * fade


def defeat():
    tr = Track(56, 3, loop=False, tail=5.0)
    for k, m in enumerate([50, 48, 46, 45]):
        tr.add(strings([m - 12, m], tr.beats(2.2), attack=0.3, release=1.5, cutoff=1100, gain=0.8), k * 2, verb=0.6)
    tr.add(choir([62, 65, 69], tr.beats(8), "u", attack=1.0, gain=0.5), 0, verb=0.8)
    tr.add(bell(38, 7.0, 0.8), 0, verb=0.7)
    tr.add(bell(38, 6.0, 0.6), 6, verb=0.7)
    tr.add(heartbeat(0.6), 0, verb=0.1)
    tr.add(heartbeat(0.35), 2.2, verb=0.1)
    tr.add(heartbeat(0.15), 5.0, verb=0.1)
    out = tr.render(rt=4.0, bright=3000)
    n = out.shape[1]
    fade = np.ones(n)
    fade[-n_of(2.5):] = np.linspace(1, 0, n_of(2.5))
    return out * fade


# ================================================================ output

def write(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    ogg = os.path.join(OUT, name + ".ogg")
    from scipy.io import wavfile
    wavfile.write(wav, SR, (stereo.T * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
    os.remove(wav)
    print(f"{name}: {stereo.shape[1] / SR:.1f}s -> {os.path.getsize(ogg) // 1024} KB")


TRACKS = {"menu": menu, "story": story, "run_calm": run_calm, "run_combat": run_combat,
          "boss": boss, "victory": victory, "defeat": defeat}

if __name__ == "__main__":
    for name in (sys.argv[1:] or TRACKS.keys()):
        write(name, TRACKS[name]())
