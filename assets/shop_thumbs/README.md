# Shop thumbnails

One picture per shop item, rendered from the real game by `tests/ThumbnailBaker.tscn` and read by
`core/cosmetics/ShopThumbs.gd` (cards use `ui/widgets/ThumbView.gd`).

- `<category>/<slug>.webp`: a 240×120 still, or for animated categories (aura, glow, trail, kill,
  taunt, ambience) a strip of 8 frames of 192×96 that plays as a little clip.
- Files are WebP (lossy) and imported with the **keep** importer, so they ship as-is and are
  decoded on demand; they are not texture resources.

Re-bake after adding or changing items (a real renderer is needed, not `--headless`):

```sh
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake
# Only the holiday collections, one category or one item:
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --seasonal
godot --path . --rendering-driver opengl3 --resolution 480x240 res://tests/ThumbnailBaker.tscn -- --bake --only=kill --slug=kill_kraken
godot --headless --path . --import
```

Items without a picture fall back to their colour swatch.

The whole folder ships with the web build, so keep it under ~6 MB. After a bake, the pictures were
re-encoded with Pillow (`method=6`; quality 62 for clip strips, 74 for stills), which kept them
looking the same at about 30% fewer bytes.
