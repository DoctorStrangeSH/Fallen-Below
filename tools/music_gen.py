"""Procedural soundtrack for Fallen Below (placeholder until a composer or licensed tracks).

Generates seamless loops in D minor into audio/music/*.ogg:
  menu        slow, dark, choir pad and distant bells
  story       sparse bells over a soft pad
  run_calm    100 bpm: drone, heartbeat, plucks   (base layer of a run)
  run_combat  100 bpm: taiko, string ostinato, stabs (layered on top while fighting)
  boss        140 bpm: driving drums, distorted bass, choir, bell motif
  victory / defeat  short stingers

Run: python3 tools/music_gen.py   (needs numpy, scipy, ffmpeg)
"""
import os
import subprocess
import numpy as np
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------- building blocks

def env(n, a=0.01, d=0.1, s=0.7, r=0.2):
    """ADSR envelope of n samples (times in seconds)."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    a = max(a, 1)
    sus = max(n - a - d - r, 0)
    e = np.concatenate([np.linspace(0, 1, a), np.linspace(1, s, max(d, 1)), np.full(sus, s), np.linspace(s, 0, max(r, 1))])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def saw(f, n, detune=0.0, harmonics=24):
    t = np.arange(n) / SR
    out = np.zeros(n)
    f = f * (1 + detune)
    for k in range(1, harmonics + 1):
        if f * k > SR / 2.2:
            break
        out += np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6.28)) / k
    return out * 0.6


def sine(f, n, phase=0.0):
    return np.sin(2 * np.pi * f * np.arange(n) / SR + phase)


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def noise(n):
    return rng.uniform(-1, 1, n)


class Track:
    """A stereo buffer with a fixed loop length; notes that run past the end wrap around."""

    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.buf = np.zeros((2, self.n + SR * 4))  # room for tails, folded back later

    def add(self, x, start_s, gain=1.0, pan=0.0):
        i = int(start_s * SR)
        l = gain * np.sqrt(0.5 * (1 - pan))
        r = gain * np.sqrt(0.5 * (1 + pan))
        end = min(i + len(x), self.buf.shape[1])
        self.buf[0, i:end] += x[: end - i] * l
        self.buf[1, i:end] += x[: end - i] * r

    def render(self, reverb=0.3, rt=2.5, peak=0.89):
        dry = self.buf.copy()
        if reverb > 0:
            m = int(rt * SR)
            decay = np.exp(-6.0 * np.arange(m) / m)
            wet = np.zeros_like(dry)
            for ch in range(2):
                ir = lowpass(noise(m) * decay, 5000) * 0.05
                wet[ch] = signal.fftconvolve(dry[ch], ir)[: dry.shape[1]]
            dry = dry + wet * reverb * 6
        # fold the tail onto the start: seamless loop
        out = dry[:, : self.n].copy()
        tail = dry[:, self.n:]
        k = min(tail.shape[1], self.n)
        out[:, :k] += tail[:, :k]
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.3)
        return out / np.max(np.abs(out)) * peak


# ---------------------------------------------------------------- instruments

def pad(chord, dur, cutoff=1200, attack=1.2, gain=1.0):
    n = int(dur * SR)
    x = np.zeros(n)
    for m in chord:
        for det in (-0.004, 0.0, 0.005):
            x += saw(hz(m), n, det, harmonics=16)
    x = lowpass(x, cutoff) * env(n, attack, 0.5, 0.8, min(1.5, dur * 0.4))
    return x * gain / len(chord)


def choir(chord, dur, gain=1.0):
    """Vowel-ish formants on saws: a dark 'ah' choir."""
    n = int(dur * SR)
    x = np.zeros(n)
    for m in chord:
        for det in (-0.006, 0.0, 0.006):
            x += saw(hz(m), n, det, harmonics=30)
    vowel = bandpass(x, 600, 1100) * 1.0 + bandpass(x, 250, 450) * 0.8 + bandpass(x, 2300, 2900) * 0.3
    vib = 1 + 0.004 * sine(5.0, n)
    return vowel * vib * env(n, 1.5, 0.5, 0.85, min(2.0, dur * 0.4)) * gain / len(chord)


def bell(m, dur=3.0, gain=1.0):
    n = int(dur * SR)
    f = hz(m)
    x = np.zeros(n)
    for ratio, amp, dec in [(1, 1, 1.0), (2.76, 0.5, 0.6), (5.4, 0.25, 0.35), (8.93, 0.12, 0.2)]:
        x += sine(f * ratio, n) * amp * np.exp(-np.arange(n) / (SR * dur * dec * 0.35))
    return x * gain * 0.4


def pluck(m, dur=0.6, gain=1.0, cutoff=2500):
    n = int(dur * SR)
    x = saw(hz(m), n, harmonics=20)
    x = lowpass(x, cutoff) * np.exp(-np.arange(n) / (SR * 0.15))
    return x * gain


def drone(m, dur, gain=1.0):
    n = int(dur * SR)
    lfo = 0.75 + 0.25 * sine(0.11, n)
    x = (sine(hz(m), n) + 0.5 * sine(hz(m + 12), n) + 0.25 * saw(hz(m), n, 0.003, 8)) * lfo
    return lowpass(x, 400) * gain


def kick(gain=1.0, length=0.45):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = 45 + 90 * np.exp(-t * 25)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    return x * gain


def taiko(gain=1.0):
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(70 + 40 * np.exp(-t * 18)) / SR) * np.exp(-t * 6)
    skin = lowpass(noise(n), 900) * np.exp(-t * 30) * 0.6
    return (body + skin) * gain


def snare(gain=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = bandpass(noise(n), 1200, 7000) * np.exp(-t * 18) + 0.4 * sine(190, n) * np.exp(-t * 30)
    return x * gain


def hat(gain=1.0, length=0.06):
    n = int(length * SR)
    return highpass(noise(n), 7000) * np.exp(-np.arange(n) / (SR * length * 0.3)) * gain


def swell(dur, gain=1.0):
    n = int(dur * SR)
    x = highpass(noise(n), 3000) * np.linspace(0, 1, n) ** 3
    return x * gain


def stab(chord, gain=1.0):
    n = int(0.5 * SR)
    x = np.zeros(n)
    for m in chord:
        x += saw(hz(m), n, 0.003) + saw(hz(m), n, -0.003)
    cut = np.exp(-np.arange(n) / (SR * 0.08))
    y = np.zeros(n)
    # filter envelope approximated by mixing a bright and a dark copy
    y = lowpass(x, 3500) * cut + lowpass(x, 600) * (1 - cut)
    return y * np.exp(-np.arange(n) / (SR * 0.25)) * gain / len(chord)


def dist_bass(m, dur, gain=1.0):
    n = int(dur * SR)
    x = saw(hz(m), n, harmonics=30) + 0.6 * sine(hz(m - 12), n)
    x = np.tanh(lowpass(x, 900) * 3.0) * env(n, 0.005, 0.1, 0.8, 0.05)
    return x * gain


# ---------------------------------------------------------------- tracks
# D minor. MIDI: D2=38, D3=50, D4=62, D5=74

CH = {
    "Dm": [50, 53, 57], "Bb": [46, 50, 53], "Gm": [43, 46, 50], "A": [45, 49, 52],
    "C": [48, 52, 55], "Eb": [51, 55, 58], "F": [41, 45, 48],
}


def menu():
    beat = 1.0  # 60 bpm
    tr = Track(64 * beat)
    prog = ["Dm", "Bb", "Gm", "A"] * 2
    for i, c in enumerate(prog):
        tr.add(choir([m + 12 for m in CH[c]], 8.5, 0.9), i * 8)
        tr.add(pad(CH[c], 8.5, 700, 2.0, 0.6), i * 8, pan=-0.2)
    tr.add(drone(26, 64, 0.5), 0)
    melody = [(74, 2), (72, 6), (69, 10), (70, 16), (67, 18), (69, 24), (77, 34), (76, 38), (74, 42), (69, 50), (70, 56), (69, 60)]
    for m, t in melody:
        tr.add(bell(m, 5.0, 0.35), t, pan=rng.uniform(-0.5, 0.5))
    tr.add(lowpass(noise(int(64 * SR)), 300) * 0.05, 0)  # wind
    return tr.render(reverb=0.5, rt=3.5)


def story():
    tr = Track(48)
    for i, c in enumerate(["Dm", "F", "Gm", "Dm", "Bb", "A"]):
        tr.add(pad(CH[c], 8.5, 900, 2.5, 0.5), i * 8)
    notes = [62, 65, 69, 67, 65, 64, 62, 57, 58, 62, 65, 64, 62, 61, 62]
    for i, m in enumerate(notes):
        tr.add(bell(m + 12, 4.0, 0.3), 1.0 + i * 3.0, pan=0.3 * np.sin(i))
    tr.add(drone(26, 48, 0.3), 0)
    return tr.render(reverb=0.55, rt=3.5)


BPM_RUN = 100.0
B_RUN = 60.0 / BPM_RUN
RUN_PROG = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"] * 2  # 16 bars


def run_calm():
    bar = 4 * B_RUN
    tr = Track(16 * bar)
    tr.add(drone(26, 16 * bar, 0.6), 0)
    for i, c in enumerate(RUN_PROG):
        if i % 2 == 0:
            tr.add(pad(CH[c], 2 * bar + 0.5, 800, 1.5, 0.45), i * bar, pan=0.2)
        t0 = i * bar
        # heartbeat: lub-dub on beat 1
        tr.add(kick(0.55, 0.35), t0)
        tr.add(kick(0.35, 0.3), t0 + 0.28)
        for b in range(4):
            tr.add(hat(0.06), t0 + b * B_RUN + B_RUN / 2, pan=0.4)
    scale = [62, 65, 67, 69, 72, 74]
    for i in range(16):
        if i % 2 == 1:
            for k in range(3):
                tr.add(pluck(scale[rng.integers(len(scale))], 0.8, 0.25, 1800), i * bar + (1 + k) * B_RUN * 1.0 + rng.choice([0, B_RUN / 2]), pan=rng.uniform(-0.6, 0.6))
    return tr.render(reverb=0.35, rt=2.5, peak=0.8)


def run_combat():
    bar = 4 * B_RUN
    tr = Track(16 * bar)
    e = B_RUN / 2
    for i, c in enumerate(RUN_PROG):
        t0 = i * bar
        root = CH[c][0] - 12
        # taiko pattern on eighths with accents
        for k, g in enumerate([1.0, 0, 0.5, 0.6, 0.9, 0, 0.5, 0.7]):
            if g:
                tr.add(taiko(g * 0.9), t0 + k * e, pan=-0.15 if k % 2 else 0.15)
        tr.add(snare(0.45), t0 + B_RUN)
        tr.add(snare(0.45), t0 + 3 * B_RUN)
        # string ostinato on sixteenths
        pattern = [0, 0, 12, 0, 3, 0, 7, 0, 0, 0, 12, 0, 5, 3, 7, 10]
        for k, iv in enumerate(pattern):
            tr.add(pluck(root + 12 + iv, 0.25, 0.32, 2200), t0 + k * e / 2, pan=0.35)
        if i % 2 == 0:
            tr.add(stab([m + 12 for m in CH[c]], 0.6), t0)
        if i % 4 == 3:
            tr.add(swell(bar, 0.25), t0)
        for k in range(8):
            tr.add(hat(0.09 if k % 2 else 0.05, 0.04), t0 + k * e, pan=0.5)
    return tr.render(reverb=0.25, rt=1.8, peak=0.85)


def boss():
    bpm = 140.0
    b = 60.0 / bpm
    bar = 4 * b
    prog = ["Dm", "Eb", "Dm", "C"] * 6  # 24 bars, phrygian menace
    tr = Track(24 * bar)
    s16 = b / 4
    for i, c in enumerate(prog):
        t0 = i * bar
        root = CH[c][0] - 24
        for k in range(4):
            tr.add(kick(0.9), t0 + k * b)
        tr.add(snare(0.6), t0 + b)
        tr.add(snare(0.6), t0 + 3 * b)
        if i % 4 == 3:
            for k in range(8):
                tr.add(taiko(0.4 + 0.07 * k), t0 + 2 * b + k * s16)
        for k in range(16):
            tr.add(hat(0.12 if k % 4 == 2 else 0.06, 0.035), t0 + k * s16, pan=0.45)
        # galloping distorted bass
        for k, iv in enumerate([0, 0, 0, 12, 0, 0, 1, 0]):
            tr.add(dist_bass(root + iv, s16 * 1.8, 0.45), t0 + k * 2 * s16)
        if i % 2 == 0:
            tr.add(choir([m + 12 for m in CH[c]], 2 * bar + 0.3, 0.8), t0)
    motif = [74, 75, 74, 72, 70, 69, 70, 72]
    for rep in range(3):
        for k, m in enumerate(motif):
            tr.add(bell(m + 12, 1.5, 0.3), (8 * rep + k) * bar + b * 2, pan=0.3)
    return tr.render(reverb=0.25, rt=2.0, peak=0.9)


def victory():
    tr = Track(7)
    tr.add(choir([62, 66, 69, 74], 6.5, 1.0), 0)
    for k, m in enumerate([74, 78, 81, 86]):
        tr.add(bell(m, 4.0, 0.4), k * 0.35)
    tr.add(taiko(0.8), 0)
    out = tr.render(reverb=0.5, rt=3.0)
    fade = np.ones(out.shape[1]); fade[-int(SR * 1.5):] = np.linspace(1, 0, int(SR * 1.5))
    return out * fade


def defeat():
    tr = Track(7)
    tr.add(pad([38, 41, 45], 6.5, 500, 0.3, 1.0), 0)
    for k, m in enumerate([62, 61, 58, 57]):
        tr.add(bell(m, 4.0, 0.4), k * 0.9)
    tr.add(taiko(1.0), 0)
    tr.add(taiko(0.6), 0.9)
    out = tr.render(reverb=0.6, rt=3.5)
    fade = np.ones(out.shape[1]); fade[-int(SR * 1.5):] = np.linspace(1, 0, int(SR * 1.5))
    return out * fade


def write(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    ogg = os.path.join(OUT, name + ".ogg")
    from scipy.io import wavfile
    wavfile.write(wav, SR, (stereo.T * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(wav)
    print(f"{name}: {stereo.shape[1] / SR:.1f}s -> {os.path.getsize(ogg) // 1024} KB")


if __name__ == "__main__":
    for name, fn in [("menu", menu), ("story", story), ("run_calm", run_calm), ("run_combat", run_combat),
                     ("boss", boss), ("victory", victory), ("defeat", defeat)]:
        write(name, fn())
