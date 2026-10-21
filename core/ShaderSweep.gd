class_name ShaderSweep
extends Node
## QA tool: dresses the menu board in every cosmetic, one item at a time, printing
## "SWEEP <category>/<slug>" before each, so a shader that fails to compile on a weak GPU (the
## browser console then shows "SceneShaderGLES3: ... compilation failed") can be traced to the item
## right above it. Kill effects and trails also play once.
## Enabled by `?sweep=1` in the page URL (web) or `--sweep` after `--` on the command line.

const SKIP := ["taunt"]  # Thrown at the opponent from the HUD, not worn on the board.
const SECONDS := 0.6

var game: Game3D


static func requested() -> bool:
	if "--sweep" in OS.get_cmdline_user_args():
		return true
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		return query is String and (query as String).contains("sweep=1")
	return false


func _ready() -> void:
	if not game.warmed:
		await game.warmed_up
	var total := 0
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var category: String = entry["key"]
		if category in SKIP:
			continue
		for slug: String in CosmeticCatalog.slugs(category):
			var look := Loadout.complete({})
			if category == "topper":
				look["toppers"] = {"slots": [{"kind": ToppersLibrary.kind_of(slug), "slug": slug}]}
			else:
				look[category] = slug
			print("SWEEP %s/%s" % [category, slug])
			game.set_showcase(look, look)
			if category in ["kill", "trail"]:
				game.preview_effect(category)
			await get_tree().create_timer(SECONDS).timeout
			total += 1
	game.set_showcase({})
	print("SWEEP done: %d items" % total)
