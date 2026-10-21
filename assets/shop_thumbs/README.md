# Shop thumbnails

One picture per shop item, rendered from the real game by `tests/ThumbnailBaker.tscn` and read by
`core/cosmetics/ShopThumbs.gd` (cards use `ui/widgets/ThumbView.gd`).

- `<category>/<slug>.webp`: a 512×256 still, or for animated categories (aura, glow, trail, kill,
  taunt, ambience) a strip of 8 frames of 320×160 that plays as a little clip.
  `featured/<set>.webp`: a 960×480 picture of each Featured Board.
- They are rendered at two to three times that size and scaled down, so they stay crisp on large
  and high-DPI screens (WebP quality 86 for stills, 80 for clips).

The pictures don't ship inside the game: the website serves them next to the web build
(`public/play/thumbs/` in the web repo), and the shop downloads only the ones on screen, with a
shimmer while they load. This folder keeps only `manifest.json` (every picture with a short hash
that busts browser caches) in git; the baked files here are local (git-ignored, and left out of the
export by `export_presets.cfg`). In the editor and in tests, pictures found here are read from disk.

Re-bake after adding or changing items (a real renderer is needed, not `--headless`), then publish:

```sh
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake
# Only new items, the holiday collections, one category or one item, or the Featured Boards:
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --missing
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --seasonal
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --only=kill --slug=kill_kraken
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --featured
python tools/publish_thumbs.py   # copies them to ../games-of-the-generals-web/public/play/thumbs and rewrites manifest.json
```

Commit `manifest.json` here and `public/play/thumbs` in the web repo together. Items without a
picture fall back to their colour swatch.
