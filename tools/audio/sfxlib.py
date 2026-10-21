"""Sound building blocks for tools/audio/build_audio.py.

Two kinds of ingredients:
- `load(path)`: a CC0 source file (Kenney, Juhani Junkala), decoded to mono float32 at 44.1 kHz.
- Synthesized sounds (whooshes, splats, boings, bells, wind, rain...): original, generated here
  with numpy, so they carry no licence at all.
Everything is mono float32 in [-1, 1] at SR.
"""

import subprocess

import numpy as np
from scipy import signal

SR = 44100
_rng = np.random.default_rng(20261022)


# --- Basics ----------------------------------------------------------------------------------

def seconds(n):
    return np.arange(int(SR * n)) / SR


def silence(d):
    return np.zeros(int(SR * d), dtype=np.float32)


def load(path, start=0.0, length=None):
    """Decode any audio file to mono float32 at SR (ffmpeg)."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).copy()
    a = int(start * SR)
    b = len(x) if length is None else a + int(length * SR)
    return x[a:b]


def noise(d, color="white"):
    n = int(SR * d)
    x = _rng.standard_normal(n)
    if color == "pink":
        b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
        x = signal.lfilter(b, a, x)
    elif color == "brown":
        x = np.cumsum(x)
        x = signal.lfilter([1, -1], [1, -0.995], x)  # Remove the drift.
    x = x / (np.max(np.abs(x)) + 1e-9)
    return x.astype(np.float32)


def _sos(kind, f, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = max(20, f[0]), min(nyq - 100, f[1])
        return signal.butter(order, [lo / nyq, hi / nyq], btype="band", output="sos")
    f = min(max(20, f), nyq - 100)
    return signal.butter(order, f / nyq, btype=kind, output="sos")


def lowpass(x, f, order=2):
    return signal.sosfilt(_sos("low", f, order), x).astype(np.float32)


def highpass(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x).astype(np.float32)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x).astype(np.float32)


def sweep_band(x, f0, f1, width=0.6, chunk=512):
    """A band-pass whose centre glides from f0 to f1 (log), applied in short chunks."""
    out = np.zeros_like(x)
    n = len(x)
    steps = max(1, n // chunk)
    for i in range(steps + 1):
        a, b = i * chunk, min(n, (i + 1) * chunk + chunk // 2)
        if a >= n:
            break
        frac = i / max(1, steps)
        fc = f0 * (f1 / f0) ** frac
        seg = bandpass(x[a:b], fc * (1 - width / 2), fc * (1 + width / 2))
        w = np.ones(b - a)
        out[a:b] += (seg * w)[: b - a] if i == 0 else seg * w
    return out / (np.max(np.abs(out)) + 1e-9)


def env_exp(n_or_d, decay, attack=0.004):
    n = n_or_d if isinstance(n_or_d, int) else int(SR * n_or_d)
    tt = np.arange(n) / SR
    e = np.exp(-tt / max(1e-4, decay))
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e.astype(np.float32)


def env_swell(d, peak=0.5, attack_pow=1.5, release_pow=1.2):
    """Rises to its peak at fraction `peak` of the length, then falls."""
    n = int(SR * d)
    u = np.linspace(0, 1, n)
    e = np.where(u < peak, (u / peak) ** attack_pow, ((1 - u) / (1 - peak)) ** release_pow)
    return e.astype(np.float32)


def tone(f, d, shape="sine"):
    """f: a number, or (f0, f1) for a glide (exponential)."""
    n = int(SR * d)
    if isinstance(f, (tuple, list)):
        freq = f[0] * (f[1] / f[0]) ** np.linspace(0, 1, n)
    else:
        freq = np.full(n, float(f))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    if shape == "sine":
        w = np.sin(phase)
    elif shape == "square":
        w = np.sign(np.sin(phase)) * 0.6
    elif shape == "saw":
        w = 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    elif shape == "tri":
        w = 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1.0) - 1) - 1
    else:
        raise ValueError(shape)
    return w.astype(np.float32)


def vibrato_tone(f, d, rate=6.0, depth=0.03, shape="sine"):
    n = int(SR * d)
    tt = np.arange(n) / SR
    base = f[0] * (f[1] / f[0]) ** np.linspace(0, 1, n) if isinstance(f, (tuple, list)) else np.full(n, float(f))
    freq = base * (1 + depth * np.sin(2 * np.pi * rate * tt))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    if shape == "saw":
        return (2 * ((phase / (2 * np.pi)) % 1.0) - 1).astype(np.float32)
    if shape == "square":
        return (np.sign(np.sin(phase)) * 0.6).astype(np.float32)
    return np.sin(phase).astype(np.float32)


def mix(*layers, length=None):
    """layers: (x, delay_seconds, gain_db) tuples, or plain arrays."""
    parts = []
    for layer in layers:
        if isinstance(layer, tuple):
            x, delay, gain = (layer + (0.0, 0.0))[:3]
        else:
            x, delay, gain = layer, 0.0, 0.0
        parts.append((np.asarray(x, dtype=np.float32), max(0, int(delay * SR)), 10 ** (gain / 20)))
    n = max(off + len(x) for x, off, _ in parts) if length is None else int(length * SR)
    out = np.zeros(n, dtype=np.float32)
    for x, off, g in parts:
        end = min(n, off + len(x))
        if end > off:
            out[off:end] += x[: end - off] * g
    return out


def repeat_at(x, times, gains=None):
    layers = [(x, t, (gains[i] if gains else 0.0)) for i, t in enumerate(times)]
    return mix(*layers)


def pitch(x, factor):
    """Resample to shift pitch (and length) by `factor` (>1 is higher and shorter)."""
    n = max(1, int(len(x) / factor))
    return signal.resample(x, n).astype(np.float32)


def fade(x, fade_in=0.0, fade_out=0.02):
    x = x.copy()
    a, b = min(int(fade_in * SR), len(x) // 2), min(int(fade_out * SR), len(x) // 2)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return (x / m * peak).astype(np.float32)


# --- Synthesized sounds ------------------------------------------------------------------------

def whoosh(d=0.35, f0=350, f1=2200, color="pink"):
    x = sweep_band(noise(d, color), f0, f1, 0.8)
    return x * env_swell(d, 0.45)


def swirl(d=1.2, f0=300, f1=1400, rate=5.0):
    x = whoosh(d, f0, f1)
    tt = seconds(d)
    return x * (0.55 + 0.45 * np.sin(2 * np.pi * rate * tt)).astype(np.float32)


def pop(f=700, d=0.09):
    body = tone((f * 1.6, f * 0.7), d) * env_exp(d, d / 4, 0.001)
    click = highpass(noise(0.01), 2000) * env_exp(0.01, 0.002, 0.0)
    return mix(body, (click, 0, -8))


def boing(f=170, d=0.55):
    tt = seconds(d)
    freq = f * (1 + 0.35 * np.exp(-tt * 6) * np.sin(2 * np.pi * 14 * tt)) * (1 + 0.6 * np.exp(-tt * 10))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return (np.sin(phase) * env_exp(d, d / 2.5)).astype(np.float32)


def splat(d=0.32, wet=1.0, low=220):
    thump = tone((180, 60), 0.12) * env_exp(0.12, 0.04)
    squish = sweep_band(noise(d, "pink"), 1800, low, 0.9) * env_exp(d, d / 3)
    drops = mix(*[(pop(_rng.uniform(500, 1100), 0.05), _rng.uniform(0.05, d), -14) for _ in range(int(5 * wet))])
    return mix((thump, 0, -2), (squish, 0, 0), (drops, 0, 0))


def splash(d=0.7, size=1.0):
    burst = highpass(noise(d, "white"), 900) * env_exp(d, 0.12 * size, 0.002)
    body = lowpass(noise(d, "pink"), 1400) * env_exp(d, 0.22 * size, 0.003)
    return mix((burst, 0, -3), (body, 0, 0), (bubbles(0.6, 7), 0.08, -10))


def bubbles(d=0.8, count=8, lo=350, hi=1300):
    layers = []
    for _ in range(count):
        f = _rng.uniform(lo, hi)
        b = tone((f, f * 1.9), 0.045) * env_exp(0.045, 0.015, 0.002)
        layers.append((b, _rng.uniform(0, max(0.01, d - 0.05)), _rng.uniform(-10, -2)))
    return mix(*layers, length=d)


def crackle(d=0.8, density=60):
    out = np.zeros(int(SR * d), dtype=np.float32)
    for _ in range(int(density * d)):
        p = int(_rng.uniform(0, len(out) - 300))
        click = highpass(noise(0.006), 1500) * env_exp(0.006, 0.0015, 0.0) * _rng.uniform(0.3, 1.0)
        out[p:p + len(click)] += click
    rumble = lowpass(noise(d, "brown"), 400) * 0.35
    return out + rumble


def fire_whoosh(d=0.9):
    return mix((whoosh(d, 200, 1200, "brown"), 0, 0), (crackle(d, 50), 0, -4))


def rumble(d=1.2, f=120):
    x = lowpass(noise(d, "brown"), f, 3)
    tt = seconds(d)
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * 7 * tt + 1.3)
    return (x * trem * env_swell(d, 0.25)).astype(np.float32)


def thunder(d=2.0):
    crack = highpass(noise(0.25, "white"), 1200) * env_exp(0.25, 0.05, 0.001)
    roll = lowpass(noise(d, "brown"), 300, 3) * env_exp(d, d / 2.5, 0.05)
    return mix((crack, 0, -2), (roll, 0.03, 0), (rumble(d, 90), 0.1, -4))


def beam_hum(d=1.2, f=95):
    tt = seconds(d)
    w = tone(f, d, "saw") * 0.5 + tone(f * 2.01, d, "saw") * 0.3 + tone(f * 3.98, d) * 0.15
    w = lowpass(w, 1800)
    return (w * (0.75 + 0.25 * np.sin(2 * np.pi * 9 * tt)) * env_swell(d, 0.2)).astype(np.float32)


def zwoop(d=0.6, f0=300, f1=1600, shape="sine"):
    return tone((f0, f1), d, shape) * env_swell(d, 0.3)


def bell(f, d=0.6, bright=0.35):
    e = env_exp(d, d / 3.5, 0.002)
    return ((tone(f, d) * 0.7 + tone(f * 2.0, d) * bright + tone(f * 3.01, d) * bright * 0.4) * e).astype(np.float32)


PENTA = [523.25, 587.33, 659.26, 783.99, 880.0, 1046.5, 1174.66, 1318.51, 1567.98, 1760.0, 2093.0]


def twinkle(d=0.9, count=7, lo=4, octave=1.0):
    layers = []
    for _ in range(count):
        f = PENTA[int(_rng.integers(lo, len(PENTA)))] * octave
        layers.append((bell(f, 0.35, 0.2), _rng.uniform(0, max(0.01, d - 0.3)), _rng.uniform(-12, -4)))
    return mix(*layers, length=d)


def arpeggio(notes, step=0.07, d=0.45, shape="bell"):
    layers = []
    for i, f in enumerate(notes):
        s = bell(f, d) if shape == "bell" else tone(f, step * 1.6, shape) * env_exp(step * 1.6, step)
        layers.append((s, i * step, 0))
    return mix(*layers)


def shimmer(d=1.2):
    return mix((twinkle(d, 9, 5), 0, 0), (highpass(noise(d, "pink"), 4000) * env_swell(d, 0.5) * 0.25, 0, -8))


def ghost_boo(d=0.9, f=210):
    voice = vibrato_tone((f * 1.15, f * 0.85), d, 5.5, 0.05) * env_swell(d, 0.35)
    breath = bandpass(noise(d, "pink"), 300, 1500) * env_swell(d, 0.4) * 0.35
    return mix(lowpass(voice, 900), (breath, 0, -6))


def squeak(f=3800, d=0.08):
    return tone((f, f * 1.25), d) * env_exp(d, d / 2.5, 0.002)


def honk(f=330, d=0.26):
    w = tone(f, d, "square") * 0.6 + tone(f * 1.5, d, "saw") * 0.3
    w = bandpass(w, 400, 2500)
    return (w * env_swell(d, 0.08, 0.5, 0.6)).astype(np.float32)


def party_horn(d=0.75, f=520):
    tt = seconds(d)
    freq = f * (1 + 0.02 * np.sin(2 * np.pi * 23 * tt)) * (1 + 0.04 * np.sin(2 * np.pi * 3 * tt))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    w = (2 * ((phase / (2 * np.pi)) % 1.0) - 1)
    rattle = bandpass(noise(d), 2500, 6000) * 0.15
    w = bandpass(w + rattle, 350, 4000)
    return (w * env_swell(d, 0.1, 0.4, 0.4)).astype(np.float32)


def squawk(d=0.55):
    tt = seconds(d)
    freq = 650 + 450 * np.sin(np.pi * tt / d) + 60 * np.sin(2 * np.pi * 31 * tt)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    w = 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    w = bandpass(w, 700, 3200)
    return (w * env_swell(d, 0.2, 0.5, 0.7)).astype(np.float32)


def mwah(d=0.38):
    smack = highpass(noise(0.02), 1500) * env_exp(0.02, 0.004, 0.0)
    voice = lowpass(vibrato_tone((700, 430), d, 7, 0.02), 1500) * env_swell(d, 0.3)
    return mix((smack, 0, -3), (voice, 0.02, -2))


def poof(d=0.4):
    return lowpass(noise(d, "pink"), 1800) * env_exp(d, d / 3.5, 0.004)


def plop(f=260):
    return mix(pop(f, 0.12), (lowpass(noise(0.15, "pink"), 700) * env_exp(0.15, 0.04), 0, -8))


def slide_whistle(f0=500, f1=1800, d=0.5):
    return lowpass(vibrato_tone((f0, f1), d, 6, 0.01), 3500) * env_swell(d, 0.15, 0.5, 0.5)


def thud(f=70, d=0.35):
    return mix(tone((f * 1.6, f), d) * env_exp(d, d / 4), (lowpass(noise(d, "brown"), 300) * env_exp(d, 0.06), 0, -6))


def crunch(d=0.3, count=6):
    out = mix(*[(highpass(noise(0.03), 800) * env_exp(0.03, 0.008), _rng.uniform(0, d - 0.04), _rng.uniform(-8, 0)) for _ in range(count)], length=d)
    return out


def buzz(d=0.8, f=190):
    tt = seconds(d)
    w = vibrato_tone(f, d, 11, 0.06, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * tt))
    return (bandpass(w, 250, 3000) * env_swell(d, 0.2)).astype(np.float32)


def hiss(d=0.5, lo=3000):
    return highpass(noise(d), lo) * env_swell(d, 0.15)


def applause(d=1.4, density=180):
    out = np.zeros(int(SR * d), dtype=np.float32)
    e = env_swell(d, 0.3)
    for _ in range(int(density * d)):
        p = int(_rng.uniform(0, len(out) - 900))
        clap = bandpass(noise(0.018), 900, 5000) * env_exp(0.018, 0.004, 0.0)
        out[p:p + len(clap)] += clap * e[p] * _rng.uniform(0.3, 1.0)
    return out


def drum(f=120, d=0.35, snap=0.0):
    body = tone((f * 1.8, f), d) * env_exp(d, d / 4, 0.001)
    sn = bandpass(noise(d), 1500, 7000) * env_exp(d, 0.05, 0.001) * snap
    return mix(body, (sn, 0, 0))


def cymbal(d=0.8):
    return highpass(noise(d), 5000) * env_exp(d, d / 3, 0.002)


def chip8(notes, step=0.07, shape="square"):
    layers = []
    for i, f in enumerate(notes):
        layers.append((tone(f, step * 1.1, shape) * env_exp(step * 1.1, step * 0.9, 0.002), i * step, 0))
    return lowpass(mix(*layers), 6000)


def metal_ring(f=2600, d=0.6):
    return mix(bell(f, d, 0.5), (bell(f * 1.47, d, 0.3), 0, -6))


def whistle_fall(d=0.9, f0=2400, f1=700):
    return lowpass(vibrato_tone((f0, f1), d, 7, 0.006), 4000) * env_swell(d, 0.2, 0.6, 0.3)


def ricochet(d=0.35):
    return tone((2600, 900), d) * env_exp(d, d / 2.5, 0.001)


def wind(d=6.0, lo=200, hi=900, gust=0.12):
    x = bandpass(noise(d, "pink"), lo, hi)
    tt = seconds(d)
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * gust * tt + _rng.uniform(0, 6)) * np.sin(2 * np.pi * gust * 0.37 * tt + 1)
    return (x * lfo).astype(np.float32)


def rain_bed(d=6.0, heavy=False):
    hissy = bandpass(noise(d, "pink"), 1200 if heavy else 2000, 9000) * (0.9 if heavy else 0.6)
    drops = mix(*[(pop(_rng.uniform(1800, 4200), 0.02), _rng.uniform(0, d - 0.03), _rng.uniform(-26, -14)) for _ in range(int(d * (90 if heavy else 50)))], length=d)
    return mix(hissy, (drops, 0, 0))


def crickets(d=6.0):
    layers = []
    t0 = 0.0
    while t0 < d - 0.4:
        f = _rng.uniform(4200, 5200)
        chirp = repeat_at(tone(f, 0.018) * env_exp(0.018, 0.006, 0.002), [i * 0.045 for i in range(3)])
        layers.append((chirp, t0, _rng.uniform(-18, -8)))
        t0 += _rng.uniform(0.35, 0.9)
    return mix(*layers, length=d)


def bird_chirp():
    f = _rng.uniform(2400, 3800)
    a = tone((f, f * _rng.uniform(1.3, 1.8)), 0.07) * env_exp(0.07, 0.03, 0.003)
    b = tone((f * 1.2, f * 0.9), 0.06) * env_exp(0.06, 0.025, 0.003)
    return mix(a, (b, 0.08, -2), (a * 0.7, 0.16, -4))


def birds_bed(d=6.0):
    layers = [(bird_chirp(), _rng.uniform(0, d - 0.4), _rng.uniform(-14, -6)) for _ in range(int(d * 1.3))]
    return mix((wind(d, 300, 900) * 0.3, 0, 0), *layers, length=d)


def gull_call():
    return lowpass(mix(vibrato_tone((1300, 900), 0.3, 18, 0.03, "saw") * env_swell(0.3, 0.2), (vibrato_tone((1400, 1000), 0.25, 18, 0.03, "saw") * env_swell(0.25, 0.2), 0.36, -3)), 3000)


def waves_bed(d=8.0):
    x = lowpass(noise(d, "pink"), 1600)
    tt = seconds(d)
    swell = 0.25 + 0.75 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 4.0 - 1.4)) ** 2
    return (x * swell).astype(np.float32)


def sleigh_bells(d=4.0, rate=4.0, tail=0.0):
    layers = []
    n = int(round(d * rate))
    for i in range(n):
        jingle = mix(*[(bell(_rng.uniform(3500, 6500), 0.18, 0.4), _rng.uniform(0, 0.03), _rng.uniform(-10, -4)) for _ in range(4)])
        layers.append((jingle, i / rate + _rng.uniform(0.0, 0.015), -2 if i % 2 == 0 else -6))
    return mix(*layers, length=d + tail)


def chimes(d=6.0, count=10):
    layers = [(bell(PENTA[int(_rng.integers(3, 9))], 1.2, 0.25), _rng.uniform(0, d - 0.6), _rng.uniform(-14, -6)) for _ in range(count)]
    return mix(*layers, length=d)


def pad(d=6.0, notes=(261.63, 329.63, 392.0, 523.25)):
    tt = seconds(d)
    w = sum(tone(f * (1 + 0.002 * k), d) for k, f in enumerate(notes))
    lfo = 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * tt)
    return lowpass(w * lfo, 2400).astype(np.float32)


def march_bed(d=4.0, bpm=120, tail=0.0):
    beat = 60.0 / bpm
    layers = []
    for i in range(int(round(d / beat))):
        layers.append((drum(110, 0.3, 0.25 if i % 2 else 0.0), i * beat, -2 if i % 4 == 0 else -6))
        layers.append((highpass(noise(0.05), 700) * env_exp(0.05, 0.015), i * beat + beat / 2, -14))  # Footsteps.
    return mix(*layers, length=d + tail)


def loop(x, crossfade=0.35):
    """Seamless loop: the tail fades into the head."""
    c = int(crossfade * SR)
    body = x[:-c].copy()
    tail = x[-c:]
    ramp = np.linspace(0, 1, c)
    body[:c] = body[:c] * ramp + tail * (1 - ramp)
    return body.astype(np.float32)


def exactly(x, d):
    """Pad or cut to exactly `d` seconds, so loop layers line up sample for sample."""
    n = int(round(d * SR))
    return np.pad(x, (0, max(0, n - len(x))))[:n].astype(np.float32)


def bed(d, *layers):
    """A looping ambience bed: mix, then make it seamless."""
    return exactly(loop(mix(*layers, length=d + 0.35), 0.35), d)


def periodic(d, build, tail=1.0):
    """A rhythmic layer that loops on the beat. `build(d, tail)` places its events in [0, d) on a
    grid that divides `d` and returns d + tail seconds; whatever rings past the end is wrapped
    onto the start, exactly as it will sound when the loop repeats."""
    y = exactly(build(d, tail), d + tail)
    n = int(round(d * SR))
    out = y[:n].copy()
    out[:len(y) - n] += y[n:]
    return out
