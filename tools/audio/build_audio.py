"""Builds every game sound from recipes.py into assets/audio, plus the generated index and docs.

    python tools/audio/build_audio.py --src <unpacked sources> [--catalog <catalog.json>] [--only name,...]

--src is a folder holding the downloaded CC0 packs, unpacked as x/k_interface, x/k_impact,
x/k_rpg, x/k_scifi, x/k_casino, x/k_digital, x/k_jingles, x/junkala and x/musicbox, plus the
loose music files (see assets/audio/CREDITS.md for every URL). Treat it as untrusted data: this
script only decodes audio from it with ffmpeg.

--catalog is a JSON dump of CosmeticCatalog (category -> slug -> {name}) used to document which
sound every shop item plays (assets/audio/SOUNDS.md). tests/AudioTest checks the same thing live.

Outputs (all OGG Vorbis):
- assets/audio/sfx/<name>.ogg  one-shots, mono
- assets/audio/amb/<name>.ogg  seamless ambience loops, mono
- assets/audio/music/<name>.ogg  music loops, stereo
- core/audio/SoundIndex.gd  paths, item mapping, keywords, defaults, groups (generated)
- assets/audio/CREDITS.md, assets/audio/SOUNDS.md (generated)
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import recipes  # noqa: E402
import sfxlib as S  # noqa: E402

OUT = ROOT / "assets" / "audio"

# Loudness targets: the loudest 50 ms window of a one-shot, in dBFS RMS, per group.
TARGET_RMS = {"ui": -20.0, "game": -16.0, "kill": -12.0, "taunt": -14.0, "trail": -19.0, "aura": -19.0,
              "topper": -17.0, "equip": -17.0, "other": -16.0}
BITRATE = {"ui": 48, "game": 56, "kill": 64, "taunt": 64, "trail": 48, "aura": 48, "topper": 48, "equip": 48, "other": 56}
LOOP_RMS = -26.0  # Ambience beds sit quietly under everything.
MUSIC_LUFS = -16.0


def group_of(name):
    for prefix, g in (("ui_", "ui"), ("kill_", "kill"), ("taunt_", "taunt"), ("trail_", "trail"), ("aura_", "aura"),
                      ("topper_", "topper"), ("equip_", "equip")):
        if name.startswith(prefix):
            return g
    return "ui" if name in ("coins", "daily_reward", "rank_up", "achievement") else "game"


def db(x):
    return 20 * np.log10(max(1e-9, x))


def max_window_rms(x, win=0.05):
    n = int(win * S.SR)
    if len(x) <= n:
        return float(np.sqrt(np.mean(x ** 2)))
    sq = np.convolve(x ** 2, np.ones(n) / n, mode="valid")
    return float(np.sqrt(np.max(sq)))


def trim(x, lead_db=-60.0, tail_db=-55.0):
    a = np.abs(x)
    above = np.where(a > 10 ** (lead_db / 20))[0]
    if len(above) == 0:
        return x
    start = max(0, above[0] - int(0.002 * S.SR))
    tail = np.where(a > 10 ** (tail_db / 20))[0]
    end = min(len(x), tail[-1] + int(0.03 * S.SR))
    return x[start:end]


def limit(x, ceiling=0.89):
    peak = np.max(np.abs(x))
    return x * (ceiling / peak) if peak > ceiling else x


def write_wav(path, x, channels=1):
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(S.SR)
        w.writeframes(pcm.tobytes())


def encode(x, path, kbps, channels=1):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        write_wav(wav, x, channels)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-b:a", f"{kbps}k",
                        "-ac", str(channels), str(path)], check=True)


def seam(x, channels=1):
    """How well a loop joins: the sample jump at the seam and the level change across it."""
    mono = x.reshape(-1, channels).mean(axis=1) if channels > 1 else x
    n = int(0.05 * S.SR)
    head = float(np.sqrt(np.mean(mono[:n] ** 2)))
    tail = float(np.sqrt(np.mean(mono[-n:] ** 2)))
    jump = float(abs(mono[0] - mono[-1]))
    return jump, db(head) - db(tail)


def build_sfx(name, builder):
    g = group_of(name)
    x = trim(np.asarray(builder(), dtype=np.float32))
    x = S.fade(x, 0.0, 0.02)
    gain = 10 ** ((TARGET_RMS.get(g, -16) - db(max_window_rms(x))) / 20)
    x = limit(x * gain)
    path = OUT / "sfx" / f"{name}.ogg"
    encode(x, path, BITRATE.get(g, 56))
    return {"name": name, "kind": "sfx", "group": g, "dur": len(x) / S.SR, "peak": db(np.max(np.abs(x))),
            "rms": db(max_window_rms(x)), "kb": path.stat().st_size / 1024, "seam": ""}


def build_loop(name, builder):
    x = np.asarray(builder(), dtype=np.float32)
    rms = float(np.sqrt(np.mean(x ** 2)))
    x = limit(x * 10 ** ((LOOP_RMS - db(rms)) / 20), 0.7)
    path = OUT / "amb" / f"{name}.ogg"
    encode(x, path, 48)
    jump, step = seam(x)
    return {"name": name, "kind": "loop", "group": "ambience", "dur": len(x) / S.SR, "peak": db(np.max(np.abs(x))),
            "rms": db(float(np.sqrt(np.mean(x ** 2)))), "kb": path.stat().st_size / 1024,
            "seam": f"jump {jump:.4f}, level {step:+.1f} dB"}


def loudness(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
    return float(m[-1]) if m else -20.0


def build_music(name, spec):
    rel, kbps, _ = spec
    src = recipes.SOURCES / rel
    cmd = ["ffmpeg", "-v", "error", "-i", str(src), "-f", "f32le", "-ac", "2", "-ar", str(S.SR), "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).copy()
    # Encoders pad the ends with silence, which leaves a gap when the track loops: trim near-silence
    # (up to 0.3 s each end), then a 5 ms fade at the seam so the join can't click.
    frames = x.reshape(-1, 2)
    level = np.abs(frames).max(axis=1)
    idx = np.where(level > 10 ** (-60 / 20))[0]
    limit_n = int(0.3 * S.SR)
    start = idx[0] if idx[0] <= limit_n else 0
    end = idx[-1] + 1 if len(frames) - idx[-1] <= limit_n else len(frames)
    frames = frames[start:end].copy()
    n = int(0.005 * S.SR)
    frames[:n] *= np.linspace(0, 1, n)[:, None]
    frames[-n:] *= np.linspace(1, 0, n)[:, None]
    x = frames.reshape(-1)
    gain_db = MUSIC_LUFS - loudness(src)
    x = x * 10 ** (gain_db / 20)
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x = x * (0.89 / peak)
    path = OUT / "music" / f"{name}.ogg"
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "m.wav"
        write_wav(wav, x, 2)
        path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-b:a", f"{kbps}k", str(path)], check=True)
    jump, step = seam(x, 2)
    return {"name": name, "kind": "music", "group": "music", "dur": len(x) / 2 / S.SR, "peak": db(np.max(np.abs(x))),
            "rms": loudness(path), "kb": path.stat().st_size / 1024, "seam": f"jump {jump:.4f}, level {step:+.1f} dB"}


# --- Generated GDScript and docs -------------------------------------------------------------------

def gd(value, indent=1):
    """A Python value as GDScript source."""
    pad = "\t" * indent
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = [f"{pad}{json.dumps(k)}: {gd(v, indent + 1)}," for k, v in value.items()]
        return "{\n" + "\n".join(items) + "\n" + "\t" * (indent - 1) + "}"
    if isinstance(value, (list, tuple)):
        if all(isinstance(v, str) for v in value) and len(json.dumps(value)) < 90:
            return json.dumps(list(value))
        items = [f"{pad}{gd(v, indent + 1)}," for v in value]
        return "[\n" + "\n".join(items) + "\n" + "\t" * (indent - 1) + "]"
    return json.dumps(value)


def label_of(name):
    words = name.replace("ui_", "").replace("amb_", "").replace("_", " ")
    return words[:1].upper() + words[1:]


def write_index():
    sfx = {n: f"res://assets/audio/sfx/{n}.ogg" for n in recipes.SFX}
    loops = {n: f"res://assets/audio/amb/{n}.ogg" for n in recipes.LOOPS}
    music = {n: f"res://assets/audio/music/{n}.ogg" for n in recipes.MUSIC}
    labels = {n: label_of(n) for n in list(recipes.SFX) + list(recipes.LOOPS)}
    labels.update({n: spec[2] for n, spec in recipes.MUSIC.items()})
    groups = {g: names for g, names in recipes.GROUPS}
    src = f'''class_name SoundIndex
extends RefCounted
## Every sound file in the game and which shop item plays which sound.
## GENERATED by tools/audio/build_audio.py from tools/audio/recipes.py: edit those and rebuild.

const SFX := {gd(sfx)}

const LOOPS := {gd(loops)}

const MUSIC := {gd(music)}

## category -> slug -> sound name ("" = silent). Items not listed fall back to KEYWORDS, then DEFAULTS.
const ITEMS := {gd(recipes.ITEMS)}

## category -> [[keyword, sound], ...], matched in order against "<slug> <item name>" in lower case.
const KEYWORDS := {gd(recipes.KEYWORDS)}

const DEFAULTS := {gd(recipes.DEFAULTS)}

## Sound test groups (shop categories are listed from CosmeticCatalog at runtime).
const GROUPS := {gd(groups)}

const LABELS := {gd(labels)}
'''
    (ROOT / "core" / "audio").mkdir(parents=True, exist_ok=True)
    (ROOT / "core" / "audio" / "SoundIndex.gd").write_text(src, encoding="utf-8", newline="\n")


def resolve(category, slug, name):
    table = recipes.ITEMS.get(category, {})
    if slug in table:
        return table[slug], "listed"
    text = f"{slug} {name}".lower()
    for keyword, sound in recipes.KEYWORDS.get(category, []):
        if keyword in text:
            return sound, f"keyword '{keyword}'"
    return recipes.DEFAULTS.get(category, ""), "category default"


def write_docs(rows, catalog):
    by_name = {r["name"]: r for r in rows}
    lines = ["# Sounds", "", "Generated by `tools/audio/build_audio.py`. Every file is OGG Vorbis.", "",
             "Measured after processing: duration, peak (dBFS), loudness (one-shots: loudest 50 ms window in dBFS RMS;",
             "loops: whole-file RMS; music: integrated LUFS), size, and for loops the seam (sample jump and the level",
             "difference between the first and last 50 ms).", "",
             "| Sound | Kind | Group | Seconds | Peak dB | Loudness | KB | Loop seam |", "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        lines.append(f"| {r['name']} | {r['kind']} | {r['group']} | {r['dur']:.2f} | {r['peak']:.1f} | {r['rms']:.1f} | {r['kb']:.1f} | {r['seam']} |")
    total = sum(r["kb"] for r in rows)
    lines += ["", f"Total: {len(rows)} files, {total / 1024:.2f} MB.", ""]
    if catalog:
        lines += ["## Shop items", "", "Which sound each item plays and why (listed, keyword or category default).", ""]
        for category, items in catalog.items():
            lines += [f"### {category}", "", "| Item | Name | Sound | Rule |", "|---|---|---|---|"]
            for slug, info in sorted(items.items()):
                sound, rule = resolve(category, slug, info.get("name", ""))
                ok = "" if (sound == "" or sound in by_name) else " (MISSING)"
                lines.append(f"| {slug} | {info.get('name', '')} | {sound or '(silent)'}{ok} | {rule} |")
            lines.append("")
    (OUT / "SOUNDS.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def write_credits(rows):
    pack_rows = []
    for key, (title, author, url) in recipes.PACK_SOURCES.items():
        pack_rows.append(f"| {title} | {author} | CC0 1.0 | {url} |")
    music_rows = [f"| music/{n}.ogg | {t} | {a} | CC0 1.0 | {u} |" for n, (t, a, u) in recipes.MUSIC_SOURCES.items()]
    used = {}
    for name, builder in list(recipes.SFX.items()) + list(recipes.LOOPS.items()):
        files = recipes.source_files_of(builder)
        rel = sorted({str(Path(f).relative_to(recipes.SOURCES)).replace("\\", "/") for f in files})
        used[name] = rel
    lines = ["# Audio credits and licences", "",
             "Every sound in the game is either CC0 1.0 (public domain: free for any use, no credit required) from the",
             "sources below, or synthesized by `tools/audio/sfxlib.py` (original, no licence needed). Many sounds mix both.",
             "Credit is given here anyway, with thanks.", "",
             "Licence text: https://creativecommons.org/publicdomain/zero/1.0/", "",
             "## Sound effect packs", "", "| Pack | Author | Licence | Source |", "|---|---|---|---|", *pack_rows, "",
             "## Music", "", "| File | Track | Author | Licence | Source |", "|---|---|---|---|---|", *music_rows, "",
             "## Per sound", "", "Source files mixed into each sound (none = fully synthesized).", "",
             "| Sound | Source files |", "|---|---|"]
    for name in sorted(used):
        lines.append(f"| {name} | {', '.join(used[name]) if used[name] else 'none (synthesized)'} |")
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--catalog")
    ap.add_argument("--only", default="")
    ap.add_argument("--docs-only", action="store_true")
    args = ap.parse_args()
    recipes.SOURCES = Path(args.src)
    only = {n for n in args.only.split(",") if n}
    rows = []
    if not args.docs_only:
        for name, builder in recipes.SFX.items():
            if not only or name in only:
                rows.append(build_sfx(name, builder))
                print("sfx", name, f"{rows[-1]['dur']:.2f}s {rows[-1]['kb']:.1f}KB", flush=True)
        for name, builder in recipes.LOOPS.items():
            if not only or name in only:
                rows.append(build_loop(name, builder))
                print("loop", name, rows[-1]["seam"], flush=True)
        for name, spec in recipes.MUSIC.items():
            if not only or name in only:
                rows.append(build_music(name, spec))
                print("music", name, f"{rows[-1]['rms']:.1f} LUFS {rows[-1]['kb']:.0f}KB", flush=True)
    saved = HERE / "measurements.json"  # Kept out of the game files.
    if only or args.docs_only:
        # Partial builds update their rows in the last full build's measurements.
        old = json.loads(saved.read_text(encoding="utf-8")) if saved.exists() else []
        fresh = {r["name"] for r in rows}
        rows = [r for r in old if r["name"] not in fresh] + rows
    saved.write_text(json.dumps(rows, indent=1), encoding="utf-8")
    catalog = json.loads(Path(args.catalog).read_text(encoding="utf-8")) if args.catalog else None
    write_index()
    write_docs(rows, catalog)
    write_credits(rows)
    print("done", len(rows), "files", f"{sum(r['kb'] for r in rows) / 1024:.2f} MB")


if __name__ == "__main__":
    main()
