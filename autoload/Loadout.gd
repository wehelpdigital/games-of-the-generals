extends Node
## The player's equipped cosmetics: one slug per category (see CosmeticCatalog) plus up to three
## table toppers. Saved on this device in user://loadout.cfg and, when logged in, synced to the
## account so opponents see the visible ones online (auras, territory, chips, shapes, toppers...).
##
## Shop state lives here too: which items the player owns and what they cost, from the server
## (GET /api/shop/items, /api/shop/inventory). While the admin keeps the shop in test mode
## (ServerConfig "shop_test_mode") everything is free, owned and equippable without logging in.

signal changed(category: String, slug: String)
signal toppers_changed
signal shop_updated

const FILE := "user://loadout.cfg"
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
	"shape": "shape_classic",
	"ambience": "none",
}
const RARITY_PRICES := {"common": 300, "rare": 900, "epic": 1800, "legendary": 3000}
const FLAG_DIR := "user://flags"

var items: Dictionary = _fresh()
## Server shop data: "category/slug" -> {price, featured, season, available_until, ...}.
var shop_items: Dictionary = {}
var _owned: Dictionary = {}  # "category/slug" -> true
var _shop_loaded := false
var _server_test_mode: Variant = null  # The shop endpoints' own test_mode flag, once known.
var _push_pending := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for category: String in DEFAULTS:
			var slug: Variant = cfg.get_value("loadout", category, DEFAULTS[category])
			if slug is String and _known(category, slug):
				items[category] = slug
		items["toppers"] = ToppersLibrary.sanitize(cfg.get_value("loadout", "toppers", {}))
	ApiManager.auth_changed.connect(_on_auth_changed)
	ServerConfig.changed.connect(func() -> void: shop_updated.emit())


func _on_auth_changed(logged_in: bool) -> void:
	_owned.clear()
	_shop_loaded = false
	if logged_in:
		_push()
	refresh_shop()


func get_item(category: String) -> String:
	return items.get(category, DEFAULTS.get(category, ""))


func equip(category: String, slug: String) -> void:
	if not DEFAULTS.has(category) or not _known(category, slug) or not owns(category, slug):
		return
	items[category] = slug
	_save()
	changed.emit(category, slug)
	_push()


func reset() -> void:
	for category: String in DEFAULTS:
		equip(category, DEFAULTS[category])
	set_toppers({"slots": []})


func randomize_all() -> void:
	var picked := random_loadout(true)
	for category: String in DEFAULTS:
		equip(category, picked[category])
	set_toppers(picked["toppers"])


# --- Toppers -------------------------------------------------------------------------------------

func get_toppers() -> Dictionary:
	return items.get("toppers", {"slots": []})


## Replaces the toppers (at most three; unknown or unowned items are dropped).
func set_toppers(config: Variant) -> void:
	var clean := ToppersLibrary.sanitize(config)
	clean["slots"] = (clean["slots"] as Array).filter(func(s: Dictionary) -> bool: return owns("topper", s["slug"]))
	items["toppers"] = clean
	_save()
	toppers_changed.emit()
	changed.emit("toppers", "")
	_push()


## Keeps a flag picture on this device (logged out, or until the upload finishes). Returns its path.
func save_local_flag_image(image: Image) -> String:
	DirAccess.make_dir_recursive_absolute(FLAG_DIR)
	var path := "%s/flag_%d.png" % [FLAG_DIR, Time.get_ticks_msec()]
	image.save_png(path)
	return path


# --- Shop ----------------------------------------------------------------------------------------

func test_mode() -> bool:
	if _server_test_mode != null:
		return bool(_server_test_mode)
	return bool(ServerConfig.get_value("shop_test_mode", true))


func owns(category: String, slug: String) -> bool:
	if test_mode() or slug == DEFAULTS.get(category):
		return true
	var key := "%s/%s" % [category, slug]
	return _owned.has(key) or bool(shop_items.get(key, {}).get("is_default", false))


## Price in credits: the server's, else the rarity default.
func price(category: String, slug: String) -> int:
	var server: Dictionary = shop_items.get("%s/%s" % [category, slug], {})
	if server.has("price") and server["price"] != null:
		return int(server["price"])
	return RARITY_PRICES.get(str(CosmeticCatalog.info(category, slug).get("rarity", "common")), 300)


## Server info for an item ({featured, season, available_until, ...}) or {}.
func shop_info(category: String, slug: String) -> Dictionary:
	return shop_items.get("%s/%s" % [category, slug], {})


## The occasion a seasonal item belongs to ("halloween", ...), or "".
func season_of(category: String, slug: String) -> String:
	var server: Variant = shop_info(category, slug).get("season")
	if server != null and str(server) != "":
		return str(server)
	return str(CosmeticCatalog.info(category, slug).get("season", ""))


## Whether an item can be bought today. Seasonal items sell only during their occasion; the server
## decides (`available` in /api/shop/items), and offline the yearly window in Seasons does.
func available(category: String, slug: String) -> bool:
	var server: Dictionary = shop_info(category, slug)
	if server.has("available") and server["available"] != null:
		return bool(server["available"])
	var season := season_of(category, slug)
	return season == "" or Seasons.is_live(season)


## "Oct 15": when an off-season item is back on sale ("" when it is on sale).
func returns_text(category: String, slug: String) -> String:
	if available(category, slug):
		return ""
	var at: Variant = shop_info(category, slug).get("returns_at")
	if at != null and str(at).length() >= 10:
		var iso := str(at)
		return "%s %d" % [Seasons.MONTHS[clampi(int(iso.substr(5, 2)) - 1, 0, 11)], int(iso.substr(8, 2))]
	return Seasons.returns_text(season_of(category, slug))


## Server items of a type the client doesn't render as a cosmetic (guild charters, shoutouts...).
func server_items_of(type: String) -> Array:
	return shop_items.values().filter(func(i: Dictionary) -> bool: return str(i.get("type", "")) == type or str(i.get("category", "")) == type)


## Coroutine: loads prices (public) and, when logged in, what the player owns.
func refresh_shop() -> void:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/shop/items", null, false)
	if res.ok:
		shop_items.clear()
		for item: Variant in res.data.get("data", []):
			if item is Dictionary:
				var category := str(item.get("category", ""))
				var slug := str(item.get("item", item.get("slug", "")))
				shop_items["%s/%s" % [category, slug]] = item
		if res.data.has("test_mode"):
			_server_test_mode = bool(res.data["test_mode"])
	if ApiManager.is_logged_in():
		var inv: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/shop/inventory")
		if inv.ok:
			_owned.clear()
			var owned: Variant = inv.data.get("owned", {})
			if owned is Dictionary:
				for category: String in owned:
					for slug: Variant in owned[category]:
						_owned["%s/%s" % [category, str(slug)]] = true
			if inv.data.has("test_mode"):
				_server_test_mode = bool(inv.data["test_mode"])
			_shop_loaded = true
	_enforce_ownership()
	shop_updated.emit()


## Coroutine: buys an item. Returns the request result ({ok, status, error...}).
func buy(category: String, slug: String) -> Dictionary:
	if not ApiManager.is_logged_in():
		return {"ok": false, "status": 401, "data": {}, "error": "Log in to buy."}
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/shop/purchase", {"category": category, "slug": slug})
	if res.ok:
		_owned["%s/%s" % [category, slug]] = true
		var bundle: Variant = shop_info(category, slug).get("metadata", {})
		if bundle is Dictionary and bundle.get("items") is Array:
			await refresh_shop()  # Bundles grant several items.
		ApiManager.fetch_user()
		shop_updated.emit()
	return res


## Outside test mode, items equipped while everything was free fall back to defaults once the
## server says the player doesn't own them.
func _enforce_ownership() -> void:
	if test_mode() or (ApiManager.is_logged_in() and not _shop_loaded):
		return
	for category: String in DEFAULTS:
		if not owns(category, items[category]):
			items[category] = DEFAULTS[category]
			changed.emit(category, items[category])
	var slots: Array = get_toppers()["slots"]
	if slots.any(func(s: Dictionary) -> bool: return not owns("topper", s["slug"])):
		set_toppers(get_toppers())
	_save()


# --- Helpers -------------------------------------------------------------------------------------

## A random full loadout (the practice AI's look, and the Randomize button with `owned_only`).
static func random_loadout(owned_only := false) -> Dictionary:
	var picked := _fresh()
	for category: String in DEFAULTS:
		var options: Array = CosmeticCatalog.items(category).keys()
		if owned_only:
			options = options.filter(func(s: String) -> bool: return Loadout.owns(category, s))
		if not options.is_empty():
			picked[category] = options.pick_random()
	var toppers := ToppersLibrary.random_config()
	if owned_only:
		toppers["slots"] = (toppers["slots"] as Array).filter(func(s: Dictionary) -> bool: return Loadout.owns("topper", s["slug"]))
	picked["toppers"] = toppers
	return picked


## Fill gaps in a loadout from someone else (e.g. an opponent) with defaults.
static func complete(loadout: Variant) -> Dictionary:
	var full := _fresh()
	if loadout is Dictionary:
		for category: String in DEFAULTS:
			var slug: Variant = loadout.get(category)
			if slug is String and slug != "":
				full[category] = slug
		full["toppers"] = ToppersLibrary.sanitize(loadout.get("toppers"))
	return full


static func _fresh() -> Dictionary:
	var d := DEFAULTS.duplicate()
	d["toppers"] = {"slots": []}
	return d


func _known(category: String, slug: String) -> bool:
	var all := CosmeticCatalog.items(category)
	return all.is_empty() or all.has(slug) or slug == DEFAULTS.get(category)


func _save() -> void:
	var cfg := ConfigFile.new()
	for category: String in items:
		cfg.set_value("loadout", category, items[category])
	cfg.save(FILE)


## Debounced: several quick changes become one request. Pictures that only exist on this device
## stay out of the account copy.
func _push() -> void:
	if not ApiManager.is_logged_in() or _push_pending:
		return
	_push_pending = true
	await get_tree().create_timer(0.8).timeout
	_push_pending = false
	if ApiManager.is_logged_in():
		var payload: Dictionary = items.duplicate(true)
		for slot: Dictionary in payload["toppers"]["slots"]:
			if slot.get("flag") is Dictionary:
				(slot["flag"] as Dictionary).erase("local_image")
		ApiManager.save_loadout(payload)
