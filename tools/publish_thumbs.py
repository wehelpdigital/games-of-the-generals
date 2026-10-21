"""Publishes the baked shop pictures to the website and writes the game's picture manifest.

The pictures (tests/ThumbnailBaker.tscn writes them to assets/shop_thumbs/<category>/<slug>.webp)
are too big to ship inside the game download, so the website serves them next to the web build:
<web repo>/public/play/thumbs/<category>/<slug>.webp. The game finds them through
assets/shop_thumbs/manifest.json ({"files": {"category/slug": hash}}); the hash goes on the URL so
browsers fetch a picture again only when it changed.

    python tools/publish_thumbs.py [--web=../games-of-the-generals-web]

Copies new and changed pictures, removes ones that no longer exist, and rewrites the manifest.
Commit the manifest here and public/play/thumbs in the web repo.
"""
import hashlib
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "shop_thumbs")
web = os.path.join(os.path.dirname(ROOT), "games-of-the-generals-web")
for arg in sys.argv[1:]:
    if arg.startswith("--web="):
        web = os.path.abspath(arg[len("--web="):])
TARGET = os.path.join(web, "public", "play", "thumbs")

files = {}
copied = 0
for category in sorted(os.listdir(SOURCE)):
    folder = os.path.join(SOURCE, category)
    if not os.path.isdir(folder):
        continue
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".webp"):
            continue
        data = open(os.path.join(folder, name), "rb").read()
        files[f"{category}/{name[:-5]}"] = hashlib.md5(data).hexdigest()[:8]
        out = os.path.join(TARGET, category, name)
        if not os.path.exists(out) or open(out, "rb").read() != data:
            os.makedirs(os.path.dirname(out), exist_ok=True)
            shutil.copyfile(os.path.join(folder, name), out)
            copied += 1

removed = 0
if os.path.isdir(TARGET):
    for category in os.listdir(TARGET):
        for name in os.listdir(os.path.join(TARGET, category)):
            if f"{category}/{name[:-5]}" not in files:
                os.remove(os.path.join(TARGET, category, name))
                removed += 1

with open(os.path.join(SOURCE, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump({"files": files}, f, indent=0, sort_keys=True)
    f.write("\n")
size = sum(os.path.getsize(os.path.join(TARGET, k + ".webp")) for k in files)
print(f"{len(files)} pictures ({size / 1048576:.1f} MB): {copied} copied, {removed} removed -> {TARGET}")
