extends SmokeTestBase
## Shop screenshots: the Featured page, a few categories, search, the detail sheet, preview mode
## (several camera shots and its search), Seasonal and More, then a simulated paid shop (prices,
## Owned, Log in to buy). Run it at desktop size and again as a phone (--device=phone_portrait
## with --resolution 390x844). Also exports the catalog for the server when given --catalog=<path>.
## Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/ShopShots.tscn -- --out=<dir> [--audit] [--catalog=<file>]
## With --api-url=<site> the pictures not on disk come from <site>/play/thumbs (e.g. `php -S` on the
## web repo's public folder), as in the browser.

var _out := "user://shop"
var _catalog := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--catalog="):
			_catalog = arg.trim_prefix("--catalog=")
	DirAccess.make_dir_recursive_absolute(_out)
	if not Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--api-url=")):
		ApiManager.base_url = "http://127.0.0.1:9"  # Offline: every request fails fast.
	seed(11)
	await boot()
	if _catalog != "":
		_export_catalog()
	_check_themes()
	var ui: UIRoot = main.get_node("UI")
	var shop: Screen = ui.screen("shop")
	ApiManager.token = "offline-test"  # The shop is for players; requests still fail fast.
	ApiManager.user = {"username": "tester", "credits": 1200}
	ui.show_screen("shop")
	await _shot("shop_featured", 1.2)
	shop.call("_switch", "themes")
	await _shot("shop_themes", 1.0)
	check((shop.get("_content") as Control).get_child_count() > 3, "the Themes tab lists theme shelves")
	shop.call("_open_theme", "great_wave")
	await _shot("shop_theme_great_wave", 1.0)
	shop.call("_open_preview", "look", "fb_treasure_seas")
	await _shot("preview_look", 1.8)
	shop.call("_close_preview")
	shop.call("_switch", "featured")
	for category: String in ["shape", "kill", "ambience", "topper"]:
		shop.call("_switch", category)
		await _shot("shop_%s" % category, 1.0)
	var shop_search: LineEdit = shop.get("_shop_search")
	shop_search.text = "snow"
	shop_search.text_changed.emit("snow")
	await _shot("shop_search", 0.8)
	shop.call("_switch", "shape")
	shop.call("_open_sheet", "shape", "shape_wish_orb")
	await _shot("shop_sheet", 1.0)
	shop.call("_close_sheet")

	# Preview mode: one shot per kind of camera framing, then a search.
	for pair: Array in [["shape", "shape_dice", 1.4], ["kill", "kill_bazooka", 1.1], ["ambience", "ambience_aurora", 1.6],
			["arena", "lava_pit", 1.6], ["topper", "topper_dino", 1.4]]:
		shop.call("_open_preview", pair[0], pair[1])
		await _shot("preview_%s" % pair[1], pair[2])
	var search: LineEdit = shop.get("_search")
	search.text = "dragon"
	search.text_changed.emit("dragon")
	await _shot("preview_search", 0.6)
	search.text = ""
	shop.call("_close_preview")
	await frames(5)
	check(not ui.game.visible and (shop.get("_page") as Control).visible, "back to shop: the catalogue covers the screen again")

	shop.call("_switch", "seasonal")
	await _shot("shop_seasonal", 1.2)
	shop.call("_switch", "extras")
	await _shot("shop_extras", 0.6)

	# Paid shop, logged in with 1,200 credits and a couple of owned items.
	Loadout.set("_server_test_mode", false)
	Loadout.shop_items["shape/shape_wish_orb"] = {"category": "shape", "item": "shape_wish_orb", "price": 2500, "featured": true}
	Loadout.set("_owned", {"shape/shape_coin": true, "shape/shape_dice": true})
	Loadout.set("_shop_loaded", true)
	Loadout.shop_updated.emit()
	shop.call("_switch", "shape")
	await _shot("shop_paid", 0.8)
	shop.call("_open_sheet", "shape", "shape_coin")
	await _shot("shop_sheet_owned", 0.8)
	shop.call("_close_sheet")
	shop.call("_switch", FEATURED_KEY)
	await _shot("shop_featured_paid", 0.8)
	Loadout.set("_server_test_mode", null)
	Loadout.set("_owned", {})
	ApiManager.token = ""
	ui.show_screen("title")
	await frames(3)
	check(ui.game.visible, "leaving the shop brings the board back")
	finish()


const FEATURED_KEY := "featured"


## docs/cosmetics_catalog.json for the server: {category: {label, items: {slug: {name, rarity, desc,
## season?, collection?}}}}.
## Every item has a known theme, every theme a Featured Board, and every set only real items.
func _check_themes() -> void:
	var unknown: Array = []
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		for slug: String in CosmeticCatalog.slugs(entry["key"]):
			if not Collections.exists(CosmeticCatalog.collection_of(entry["key"], slug)):
				unknown.append("%s/%s" % [entry["key"], slug])
	check(unknown.is_empty(), "every item's theme is known %s" % [unknown])
	var bare: Array = Collections.listed().filter(func(t: String) -> bool: return FeaturedBoards.of_theme(t).is_empty())
	check(bare.is_empty(), "every theme has a Featured Board %s" % [bare])
	var broken: Array = []
	for set_slug: String in FeaturedBoards.all():
		for pair: Array in FeaturedBoards.items(set_slug):
			if CosmeticCatalog.info(pair[0], pair[1]).is_empty():
				broken.append("%s: %s/%s" % [set_slug, pair[0], pair[1]])
			elif FeaturedBoards.season_of(set_slug) == "" and CosmeticCatalog.season_of(pair[0], pair[1]) != "":
				broken.append("%s: seasonal %s" % [set_slug, pair[1]])
	check(broken.is_empty(), "Featured Boards only use real, all-year items (holiday sets excepted) %s" % [broken])


func _export_catalog() -> void:
	var out: Dictionary = {}
	for entry: Dictionary in CosmeticCatalog.CATEGORIES:
		var key: String = entry["key"]
		var items: Dictionary = {}
		var all := CosmeticCatalog.items(key)
		for slug: String in all:
			items[slug] = {"name": str(all[slug].get("name", slug)), "rarity": str(all[slug].get("rarity", "common")), "desc": str(all[slug].get("desc", ""))}
			if str(all[slug].get("season", "")) != "":
				items[slug]["season"] = str(all[slug]["season"])  # The server sells it during that occasion.
			items[slug]["collection"] = CosmeticCatalog.collection_of(key, slug)  # Its shelf on the Themes tab.
		out[key] = {"label": entry["label"], "items": items}
	# Featured Boards sell as bundles: the items' server slugs and a price about 20% off.
	var bundles: Dictionary = {}
	for slug: String in FeaturedBoards.all():
		var set_items: Array = FeaturedBoards.items(slug).map(func(pair: Array) -> String: return FeaturedBoards.server_slug(pair[0], pair[1]))
		bundles[slug] = {"name": FeaturedBoards.name_of(slug), "rarity": "legendary", "desc": "Featured Board: " + FeaturedBoards.blurb(slug),
			"collection": FeaturedBoards.theme_of(slug), "items": set_items, "price": FeaturedBoards.default_price(slug)}
		if FeaturedBoards.season_of(slug) != "":
			bundles[slug]["season"] = FeaturedBoards.season_of(slug)
	out["bundle"] = {"label": "Featured Boards", "items": bundles}
	var file := FileAccess.open(_catalog, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  ", true) + "\n")
	file.close()
	print("exported catalog: ", _catalog)


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
