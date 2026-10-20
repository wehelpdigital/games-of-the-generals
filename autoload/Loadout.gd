extends Node
## The player's equipped cosmetics: one slug per category (see CosmeticCatalog). Saved on this
## device in user://loadout.cfg and, when logged in, synced to the account so opponents see the
## visible ones online (auras, territory, chips, trails, kill effects, icons at the reveal).
##
## TEST MODE: every item can be equipped for free and without logging in.

signal changed(category: String, slug: String)

const FILE := "user://loadout.cfg"
const TEST_MODE := true
const DEFAULTS := {
	"arena": "classic",
	"board": "board_mahogany",
	"territory": "default",
	"chip": "pieces_classic_wood",
	"icons": "classic",
	"aura": "none",
	"glow": "none",
	"trail": "none",
	"kill": "classic",
}

var items: Dictionary = DEFAULTS.duplicate()
var _push_pending := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for category: String in DEFAULTS:
			var slug: Variant = cfg.get_value("loadout", category, DEFAULTS[category])
			if slug is String and _known(category, slug):
				items[category] = slug
	ApiManager.auth_changed.connect(_on_auth_changed)


func _on_auth_changed(logged_in: bool) -> void:
	if logged_in:
		_push()


func get_item(category: String) -> String:
	return items.get(category, DEFAULTS.get(category, ""))


func equip(category: String, slug: String) -> void:
	if not DEFAULTS.has(category) or not _known(category, slug):
		return
	items[category] = slug
	_save()
	changed.emit(category, slug)
	_push()


func reset() -> void:
	for category: String in DEFAULTS:
		equip(category, DEFAULTS[category])


func randomize_all() -> void:
	var picked := random_loadout()
	for category: String in picked:
		equip(category, picked[category])


## A random full loadout (used for the practice AI and the "Randomize" button).
static func random_loadout() -> Dictionary:
	var picked := DEFAULTS.duplicate()
	for category: String in DEFAULTS:
		var options: Array = CosmeticCatalog.items(category).keys()
		if not options.is_empty():
			picked[category] = options.pick_random()
	return picked


## Fill gaps in a loadout from someone else (e.g. an opponent) with defaults.
static func complete(loadout: Variant) -> Dictionary:
	var full := DEFAULTS.duplicate()
	if loadout is Dictionary:
		for category: String in DEFAULTS:
			var slug: Variant = loadout.get(category)
			if slug is String and slug != "":
				full[category] = slug
	return full


func _known(category: String, slug: String) -> bool:
	var all := CosmeticCatalog.items(category)
	return all.is_empty() or all.has(slug) or slug == DEFAULTS.get(category)


func _save() -> void:
	var cfg := ConfigFile.new()
	for category: String in items:
		cfg.set_value("loadout", category, items[category])
	cfg.save(FILE)


## Debounced: several quick equips become one request.
func _push() -> void:
	if not ApiManager.is_logged_in() or _push_pending:
		return
	_push_pending = true
	await get_tree().create_timer(0.8).timeout
	_push_pending = false
	if ApiManager.is_logged_in():
		ApiManager.save_loadout(items)
