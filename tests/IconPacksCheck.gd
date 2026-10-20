extends SceneTree
## Rasterises every rank icon of every pack through PieceIcons; checks size, mipmaps and
## fallbacks, and reports rasterise time and per-match texture memory.
##   godot --headless --path . -s res://tests/IconPacksCheck.gd

const RANKS := ["G5", "G4", "G3", "G2", "G1", "COL", "LTC", "MAJ", "CPT", "1LT", "2LT", "SGT", "PVT", "SPY", "FLG", "UNKNOWN"]


func _init() -> void:
	var failures := 0
	var started := Time.get_ticks_msec()
	var bytes := 0
	for pack: String in PieceIcons.PACKS:
		for rank: String in RANKS:
			var tex := PieceIcons.icon_texture(rank, pack)
			if tex == null:
				print("  FAIL  %s/%s missing" % [pack, rank])
				failures += 1
				continue
			var img := tex.get_image()
			if img.get_width() != PieceIcons.BASE or not img.has_mipmaps():
				print("  FAIL  %s/%s is %s, mipmaps=%s" % [pack, rank, img.get_size(), img.has_mipmaps()])
				failures += 1
			elif img.get_pixel(PieceIcons.BASE / 2, PieceIcons.BASE / 2).a < 0.5:
				print("  FAIL  %s/%s centre is transparent (did the SVG render?)" % [pack, rank])
				failures += 1
			if pack == "classic":
				bytes += img.get_data().size()
		if PieceIcons.face_material("G5", pack).albedo_texture != PieceIcons.icon_texture("G5", pack):
			print("  FAIL  %s face material texture" % pack)
			failures += 1
	var elapsed := Time.get_ticks_msec() - started
	if PieceIcons.icon_texture("G5", "nope") != PieceIcons.icon_texture("G5", "classic"):
		print("  FAIL  unknown pack does not fall back to classic")
		failures += 1
	if PieceIcons.badge_or_mystery("", "samurai") != PieceIcons.icon_texture("UNKNOWN", "samurai"):
		print("  FAIL  badge_or_mystery hidden rank")
		failures += 1
	var icons := PieceIcons.PACKS.size() * RANKS.size()
	print("rasterised %d icons in %d ms (%.1f ms each); one pack = %.1f MB, a match (2 packs) = %.1f MB" % [
		icons, elapsed, float(elapsed) / icons, bytes / 1048576.0, 2.0 * bytes / 1048576.0])
	print("%s: %d packs x %d icons, %d failures" % ["PASS" if failures == 0 else "FAIL", PieceIcons.PACKS.size(), RANKS.size(), failures])
	quit(0 if failures == 0 else 1)
