"""Procedural sound effects for Fallen Below (placeholder until real foley).

Writes short one-shots into audio/sfx/*.ogg. Reuses the instruments from music_gen.py.
Run: python3 tools/sfx_gen.py
"""
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import music_gen as M  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
SR = M.SR


def fade(x, ms=15):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def norm(x, peak=0.8):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def hit():
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(180 * np.exp(-t * 30) + 60) / SR) * np.exp(-t * 28)
    crack = M.bandpass(M.noise(n), 900, 4000) * np.exp(-t * 60)
    return norm(body + 0.6 * crack, 0.7)


def warden_hit():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    crunch = M.lowpass(M.noise(n), 1500) * np.exp(-t * 18)
    thud = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t * 15) + 40) / SR) * np.exp(-t * 12)
    return norm(np.tanh((crunch + thud) * 2.5), 0.75)


def death():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 220 * np.exp(-t * 3) + 60
    growl = M.saw(1, n, harmonics=1) * 0  # placeholder silence for shape
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3
    tone = M.lowpass(tone, 1200) * np.exp(-t * 5)
    breath = M.bandpass(M.noise(n), 300, 1500) * np.exp(-t * 6) * 0.5
    return norm(tone + breath + growl, 0.7)


def devour():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    chomp = np.zeros(n)
    for k, start in enumerate([0.0, 0.14, 0.28]):
        i = int(start * SR)
        m = int(0.12 * SR)
        seg = M.lowpass(M.noise(m), 700) * np.exp(-np.arange(m) / (SR * 0.03))
        chomp[i:i + m] += seg * (1.0 - 0.2 * k)
    low = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 4) * 0.5
    return norm(chomp + low, 0.75)


def loot():
    x = np.zeros(int(0.7 * SR))
    for k, m in enumerate([81, 86, 93]):
        b = M.bell(m, 0.6, 1.0)
        i = int(k * 0.07 * SR)
        x[i:i + len(b)] += b[: len(x) - i]
    return norm(x, 0.6)


def place():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    stone = M.lowpass(M.noise(n), 600) * np.exp(-t * 20)
    thunk = np.sin(2 * np.pi * np.cumsum(120 * np.exp(-t * 20) + 50) / SR) * np.exp(-t * 14)
    grit = M.highpass(M.noise(n), 3000) * np.exp(-t * 40) * 0.3
    return norm(stone + thunk + grit, 0.7)


def level():
    tr = M.Track(1.6)
    tr.add(M.choir([62, 69, 74], 1.4, 1.0), 0)
    tr.add(M.bell(86, 1.2, 0.5), 0.05)
    out = tr.render(reverb=0.3, rt=1.5)
    return norm(out[0] * np.linspace(1, 0.3, out.shape[1]), 0.7)


def combo():
    x = np.zeros(int(1.0 * SR))
    for k, m in enumerate([74, 77, 81, 86]):
        b = M.bell(m, 0.8, 1.0)
        i = int(k * 0.09 * SR)
        x[i:i + len(b)] += b[: len(x) - i]
    x[: int(0.4 * SR)] += M.taiko(0.6)[: int(0.4 * SR)]
    return norm(x, 0.7)


def click():
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return norm(M.highpass(M.noise(n), 2000) * np.exp(-t * 120) + 0.4 * np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 90), 0.4)


def escape():
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    wind = M.bandpass(M.noise(n), 400, 2500) * np.sin(np.pi * t / t[-1]) ** 2
    f = 300 + 500 * t / t[-1]
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.15 * np.sin(np.pi * t / t[-1])
    return norm(wind + whistle, 0.55)


def ability():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    whoosh = M.bandpass(M.noise(n), 200, 3000) * np.exp(-t * 6)
    boom = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-t * 8) + 40) / SR) * np.exp(-t * 5)
    return norm(np.tanh((whoosh + boom) * 1.8), 0.8)


def boss():
    tr = M.Track(3.0)
    tr.add(M.taiko(1.0), 0)
    for m in [50, 57, 62]:
        tr.add(M.bell(m, 2.8, 0.6), 0)
    tr.add(M.choir([62, 65, 69], 2.5, 0.8), 0.1)
    out = tr.render(reverb=0.5, rt=2.5)
    return norm(out[0] * np.linspace(1, 0, out.shape[1]) ** 0.5, 0.85)


def blast():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-t * 6) + 30) / SR) * np.exp(-t * 4)
    debris = M.lowpass(M.noise(n), 2500) * np.exp(-t * 5) * 0.8
    crack = M.highpass(M.noise(n), 3000) * np.exp(-t * 30) * 0.6
    return norm(np.tanh((boom + debris + crack) * 2.0), 0.9)


def ignite():
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    roar = M.lowpass(M.noise(n), 1800) * np.minimum(t * 12, 1.0) * np.exp(-t * 3.5)
    crackle = (np.random.rand(n) > 0.995) * np.random.rand(n) * np.exp(-t * 4)
    return norm(roar + crackle * 0.8, 0.8)


def quench():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    hiss = M.highpass(M.noise(n), 3500) * np.exp(-t * 5)
    drop = np.sin(2 * np.pi * np.cumsum(500 * np.exp(-t * 8) + 120) / SR) * np.exp(-t * 14) * 0.5
    return norm(hiss + drop, 0.7)


def nightfall():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    drone = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(55, 1.0), (82.4, 0.6), (110, 0.4)])
    env = np.minimum(t * 3, 1.0) * np.exp(-t * 1.6)
    air = M.lowpass(M.noise(n), 600) * np.exp(-t * 2) * 0.6
    return norm((drone * 0.6 + air) * env, 0.85)


def sunburst():
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    chime = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in [(880, 3), (1320, 4), (1760, 5), (2640, 7)])
    swell = M.highpass(M.noise(n), 2500) * np.exp(-t * 6) * 0.4
    return norm(chime * 0.5 + swell, 0.75)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    from scipy.io import wavfile
    import subprocess
    wav = os.path.join(OUT, name + ".wav")
    ogg = os.path.join(OUT, name + ".ogg")
    wavfile.write(wav, SR, (fade(x) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print(f"{name}: {len(x) / SR:.2f}s")


if __name__ == "__main__":
    for name, fn in [("hit", hit), ("warden_hit", warden_hit), ("death", death), ("devour", devour),
                     ("loot", loot), ("place", place), ("level", level), ("combo", combo),
                     ("click", click), ("escape", escape), ("ability", ability), ("boss", boss), ("blast", blast), ("ignite", ignite), ("quench", quench), ("nightfall", nightfall), ("sunburst", sunburst)]:
        write(name, fn())
