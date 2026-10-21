extends SceneTree
## Dumps CosmeticCatalog (category -> slug -> {name, desc, season, collection}) to JSON, for
## build_audio.py --catalog. Errors about autoloads not compiling in --script mode are harmless.
##   godot --headless --path . --script tools/audio/dump_catalog.gd -- <out.json>

func _initialize() -> void:
	var out := {}
	for c: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = c["key"]
		var rows := {}
		var items := CosmeticCatalog.items(category)
		for slug: String in items:
			var it: Dictionary = items[slug]
			rows[slug] = {"name": str(it.get("name", slug)), "desc": str(it.get("desc", "")),
				"season": str(it.get("season", "")), "collection": str(it.get("collection", it.get("theme", "")))}
		out[category] = rows
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	quit()
