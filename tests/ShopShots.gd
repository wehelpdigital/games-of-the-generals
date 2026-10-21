extends SmokeTestBase
## Shop screenshots: the new categories in test mode, preview mode (several shots, search, phone),
## the toppers spots and flag editor, the extras tab, then a simulated paid shop (prices, featured
## and seasonal badges, Buy and Log in to buy).
## Also exports the catalog for the server when given --catalog=<path>. Real renderer:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/ShopShots.tscn -- --out=<dir> [--catalog=<file>]

var _out := "user://shop"
var _catalog := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--catalog="):
			_catalog = arg.trim_prefix("--catalog=")
	DirAccess.make_dir_recursive_absolute(_out)
	ApiManager.base_url = "http://127.0.0.1:9"  # Offline: every request fails fast.
	seed(11)
	await boot()
	if _catalog != "":
		_export_catalog()
	var ui: UIRoot = main.get_node("UI")
	var shop: Screen = ui.screen("shop")
	ApiManager.token = "offline-test"  # The shop is for players; requests still fail fast.
	ApiManager.user = {"username": "tester", "credits": 1200}
	ui.show_screen("shop")
	await frames(5)

	shop.call("_switch", "shape")
	Loadout.equip("shape", "shape_wish_orb")
	await _shot("shop_shapes", 1.2)
	shop.call("_switch", "ambience")
	await _shot("shop_ambience", 1.2)
	shop.call("_switch", "kill")
	await _shot("shop_kills", 1.2)
	var shop_search: LineEdit = shop.get("_shop_search")
	shop_search.text = "snow"
	shop_search.text_changed.emit("snow")
	await _shot("shop_search", 1.0)
	shop.call("_switch", "shape")

	# Preview mode: one shot per kind of camera framing, a search, then a phone-sized screen.
	for pair: Array in [["shape", "shape_dice", 1.4], ["kill", "kill_bazooka", 1.1], ["ambience", "ambience_aurora", 1.6],
			["arena", "lava_pit", 1.6], ["topper", "topper_dino", 1.4], ["aura", "aura_flame", 1.2]]:
		shop.call("_open_preview", pair[0], pair[1])
		await _shot("preview_%s" % pair[1], pair[2])
	var search: LineEdit = shop.get("_search")
	search.text = "dragon"
	search.text_changed.emit("dragon")
	await _shot("preview_search", 0.6)
	search.text = ""
	search.text_changed.emit("")
	DisplayServer.window_set_size(Vector2i(390, 844))
	await _shot("preview_phone_resized", 0.6)
	shop.call("_open_preview", "shape", "shape_wish_orb")
	await _shot("preview_phone", 1.4)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	shop.call("_close_preview")
	await frames(5)
	shop.call("_switch", "shape")
	ApiManager.token = ""
	ApiManager.token = "offline-test"

	Loadout.set_toppers({"slots": [{"kind": "object", "slug": "topper_rubber_duck"}, {"kind": "flag", "slug": "topper_flag_gold", "flag": {"shape": "swallowtail", "emblem": "crown"}}]})
	shop.call("_switch", "topper")
	await _shot("shop_toppers", 1.0)
	shop.call("_edit_flag", 1)
	await _shot("shop_flag_editor", 1.0)
	var editor: FlagEditor = shop.get("_editor")
	editor.call("_pick_shape", "burgee")
	editor.call("_pick_pattern", "sunburst")
	editor.call("_set_color", "#1b3f8f")
	editor.call("_pick_emblem", "dragon")
	await _shot("shop_flag_editor_edited", 0.8)
	editor.done.emit()
	shop.call("_switch", "extras")
	await _shot("shop_extras", 0.6)
	shop.call("_switch", "seasonal")
	await _shot("shop_seasonal", 1.4)
	shop.call("_open_preview", "topper", "topper_parol")
	await _shot("preview_seasonal_parol", 1.4)
	shop.call("_close_preview")
	await frames(3)

	# Paid shop, logged out: prices are hidden behind "Log in to buy".
	Loadout.set("_server_test_mode", false)
	var soon := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 3 * 86400 + 600)
	Loadout.shop_items["shape/shape_wish_orb"] = {"category": "shape", "item": "shape_wish_orb", "price": 2500, "featured": true}
	Loadout.shop_items["shape/shape_lantern"] = {"category": "shape", "item": "shape_lantern", "price": 1500, "season": "Halloween", "available_until": soon}
	Loadout.shop_updated.emit()
	shop.call("_switch", "shape")
	await _shot("shop_paid_logged_out", 0.8)
	# Logged in with 1,200 credits and a couple of owned items.
	ApiManager.token = "offline-test"
	ApiManager.user = {"username": "tester", "credits": 1200}
	Loadout.set("_owned", {"shape/shape_coin": true, "shape/shape_dice": true})
	Loadout.set("_shop_loaded", true)
	Loadout.shop_updated.emit()
	await _shot("shop_paid_logged_in", 0.8)
	shop.call("_switch", "seasonal")
	await _shot("shop_seasonal_paid", 1.2)
	var scroll: ScrollContainer = (shop.get("_content") as Control).get_parent()
	scroll.scroll_vertical = 2600
	await _shot("shop_seasonal_paid_scrolled", 0.8)
	ApiManager.token = ""
	Loadout.set("_server_test_mode", null)
	Loadout.reset()
	get_tree().quit()


## docs/cosmetics_catalog.json for the server: {category: {label, items: {slug: {name, rarity, desc}}}}.
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
		out[key] = {"label": entry["label"], "items": items}
	var file := FileAccess.open(_catalog, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  ", true) + "\n")
	file.close()
	print("exported catalog: ", _catalog)


func _shot(file: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	if "--audit" in OS.get_cmdline_user_args():
		LayoutAudit.report(get_tree().root, file)
	wait = 0.0
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, file])
	print("saved ", file)
