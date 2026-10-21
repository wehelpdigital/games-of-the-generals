extends Screen
## My Board: your board as everyone sees it, filling the screen, with one slim locker to wear what
## you own. Pick a category, tap an item, and the board changes on the spot (and syncs to your
## account, so opponents see it). Effects that only show in play get a demo: a move for trails, a
## knockout for kill effects, a throw for taunts. Toppers have their three spots and the flag
## editor. Randomize, Reset and "Get more" sit at the bottom.
##
## The locker is a side panel in landscape and a foldable sheet at the bottom in portrait; the
## camera keeps the board centred in the room that's left and can be pinched and dragged.
## "Try on" (from the shop) shows an item you don't own yet, without equipping it, or a Featured
## Board's whole look ("try_look") with Buy the set and Wear what I own.

const ORDER := ["arena", "board", "territory", "chip", "shape", "icons", "aura", "glow", "trail", "kill", "ambience", "topper", "taunt"]
## Beside the side panel, close shots step back so more of the board shows (wide shots already fit).
const DESKTOP_ZOOM_OUT := {"close": 1.6, "half": 1.3, "toppers": 1.35}
const PANEL_WIDTH := 390.0
const SHEET_SHARE := 0.48  # Portrait: how much of the screen the open locker covers.
const FOLDED_HEIGHT := 132.0
const TOP_BAR := 74.0

var _frame: Control  # Scaled up on portrait phones (ProfileUi.fit).
var _top: HBoxContainer
var _panel: PanelContainer
var _heading: Label
var _fold_button: Button
var _chip_scroll: ScrollContainer
var _chip_row: HBoxContainer
var _chips: Dictionary = {}
var _hint: Label
var _items_scroll: ScrollContainer
var _items: VBoxContainer
var _footer: HBoxContainer
var _try_bar: PanelContainer
var _try_label: Label
var _try_actions: HBoxContainer
var _category := "arena"
var _portrait := false
var _folded := false
var _tile_width := 104.0
var _selected_slot := -1
var _editor: FlagEditor
var _editing_slot := -1
var _trying: Array = []  # [category, slug] while trying an item on; ["look", set] for a whole look.
var _buying := false


func _ready() -> void:
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_top = AppTheme.hbox(10)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.home(), 46))
	var title := AppTheme.pill("MY BOARD", AppTheme.PURPLE, Color.WHITE, 18)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(title)
	_top.add_child(AppTheme.spacer())
	_top.add_child(ProfileUi.colored_button("Shop", AppTheme.GOLD, AppTheme.INK, func() -> void: ui.show_screen("shop", {"category": _category}), 46))
	_frame.add_child(_top)

	_try_bar = AppTheme.card("Row")
	_try_bar.visible = false
	var try_row := AppTheme.hbox(10)
	_try_bar.add_child(try_row)
	_try_label = AppTheme.label("", "", 17)
	_try_label.add_theme_font_override("font", AppTheme.heading_font())
	_try_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_try_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_try_label.custom_minimum_size.x = 120
	try_row.add_child(_try_label)
	_try_actions = AppTheme.hbox(8)
	try_row.add_child(_try_actions)
	_frame.add_child(_try_bar)

	_panel = AppTheme.card()
	_frame.add_child(_panel)
	var box := AppTheme.vbox(10)
	_panel.add_child(box)
	var head := AppTheme.hbox(8)
	_heading = AppTheme.label("Locker", "HeadingLabel", 26)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.clip_text = true
	head.add_child(_heading)
	_fold_button = AppTheme.button("Hide", "Ghost", _toggle_fold, 40)
	_fold_button.add_theme_font_size_override("font_size", 16)
	head.add_child(_fold_button)
	box.add_child(head)

	_chip_scroll = ScrollContainer.new()
	_chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chip_row = AppTheme.hbox(6)
	_chip_scroll.add_child(_chip_row)
	for key: String in ORDER:
		var chip := AppTheme.button(CosmeticCatalog.label(key), "Ghost", _switch.bind(key), 40)
		chip.add_theme_font_size_override("font_size", 15)
		_chips[key] = chip
		_chip_row.add_child(chip)
	box.add_child(_chip_scroll)

	_hint = AppTheme.label("", "MutedLabel", 15)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)

	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items = AppTheme.vbox(10)
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items)
	_items_scroll.resized.connect(_fit_tiles)
	box.add_child(_items_scroll)

	_footer = AppTheme.hbox(8)
	for spec: Array in [["Randomize", "Secondary", _randomize], ["Reset", "Ghost", _reset], ["Get more", "Primary", _get_more]]:
		var b := AppTheme.button(spec[0], spec[1], spec[2], 44)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_footer.add_child(b)
	box.add_child(_footer)

	get_viewport().size_changed.connect(func() -> void:
		if visible:
			_layout()
			_refresh_items())
	Loadout.changed.connect(func(_c: String, _s: String) -> void:
		if visible and _editor == null:
			_refresh_items())
	Loadout.shop_updated.connect(func() -> void:
		if visible and _editor == null:
			_refresh_items()
			_show_try_actions())


func open(args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen.call_deferred("auth", {"next": "my_board"})
		return
	ui.game.visible = true
	ui.game.set_showcase({})
	ui.game.show_attract()  # Both armies on the board; your look on your side.
	_folded = false
	_close_editor()
	_category = str(args.get("category", _category)) if str(args.get("category", "")) in ORDER else _category
	_layout()
	_switch(_category)
	if str(args.get("place", "")) != "":
		_place_topper(str(args["place"]))
	if str(args.get("try_slug", "")) != "":
		_try_on(str(args.get("try_category", "")), str(args["try_slug"]))
	elif FeaturedBoards.exists(str(args.get("try_look", ""))):
		_try_look(str(args["try_look"]))
	AppTheme.pop_in(_panel)
	Loadout.refresh_shop()


func close() -> void:
	_close_editor()
	_end_try()
	ui.game.rig.screen_shift = Vector2.ZERO
	ui.game.show_attract()


# --- Layout --------------------------------------------------------------------------------------

## Landscape: the locker on the right and the board centred in the room left of it. Portrait: the
## locker is a sheet along the bottom (foldable), the board sits above it.
func _layout() -> void:
	_portrait = ProfileUi.fit(_frame, get_viewport().get_visible_rect().size)
	var view := _frame.size
	var narrow := view.x < ProfileUi.NARROW
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	AppTheme.set_card_padding(_panel, narrow or _portrait)
	_fold_button.visible = _portrait
	_fold_button.text = "Show" if _folded else "Hide"
	var shift := Vector2.ZERO
	if _portrait:
		var sheet := FOLDED_HEIGHT if _folded else roundf(view.y * SHEET_SHARE)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 8)
		_panel.offset_top = -sheet
		_panel.offset_bottom = -8
		shift = Vector2(0.0, -(sheet / view.y) * 0.5 + (TOP_BAR / view.y) * 0.5)
	else:
		var width := minf(PANEL_WIDTH, view.x * 0.42)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 14)
		_panel.offset_left = -width - 14.0
		_panel.offset_right = -14.0
		_panel.offset_top = TOP_BAR + 6.0
		_panel.offset_bottom = -14.0
		shift = Vector2(-((width + 14.0) / view.x) * 0.5, (TOP_BAR / view.y) * 0.5)
	_hint.visible = not (_portrait and _folded)
	_items_scroll.visible = not (_portrait and _folded)
	_footer.visible = not (_portrait and _folded)
	ui.game.rig.screen_shift = shift
	_place_try_bar()


## Tiles fill the locker's width: three across in the side panel, more on a wide phone sheet.
func _fit_tiles() -> void:
	var inner := _items_scroll.size.x - 14.0  # Room for the scroll bar.
	if inner <= 0.0:
		return
	var columns := clampi(int(inner / 104.0), 3, 6)
	var width := floorf((inner - (columns - 1) * 8.0) / columns)
	if absf(width - _tile_width) > 1.0:
		_tile_width = width
		_refresh_items.call_deferred()


func _place_try_bar() -> void:
	var view := _frame.size
	var width := minf(view.x - 28.0, 560.0)
	if not _portrait:
		width = minf(width, view.x - PANEL_WIDTH - 60.0)
	_try_bar.custom_minimum_size.x = width
	_try_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	var left := 14.0 if _portrait else maxf(14.0, (view.x - PANEL_WIDTH - 28.0 - width) / 2.0)
	_try_bar.position = Vector2(roundf(left if not _portrait else (view.x - width) / 2.0), TOP_BAR + 4.0)


## A camera shot for the category. Portrait shots come closer than the shop preview's: the board
## only has the room above the locker sheet, and nothing else needs to fit.
func _frame_shot(shot: String) -> void:
	ui.game.rig.frame(shot)
	ui.game.rig.zoom_by(0.8 if _portrait else float(DESKTOP_ZOOM_OUT.get(shot, 1.0)))


func _toggle_fold() -> void:
	_folded = not _folded
	_layout()


# --- Categories ----------------------------------------------------------------------------------

func _switch(category: String) -> void:
	_close_editor()
	_category = category
	_selected_slot = -1
	for key: String in _chips:
		(_chips[key] as Button).theme_type_variation = "AccentButton" if key == category else "GhostButton"
	_chip_scroll.ensure_control_visible.call_deferred(_chips[category])
	_heading.text = CosmeticCatalog.label(category)
	_set_hint()
	if _trying.is_empty():
		_frame_shot(Game3D.PREVIEW_SHOTS.get(category, "half"))
	_refresh_items()


func _set_hint() -> void:
	match _category:
		"taunt":
			_hint.text = "All your taunts are in the Taunt menu during matches. Tap one to throw it."
		"topper":
			_hint.text = "Up to three beside your half. Tap a spot, then a topper to put it there."
		_:
			_hint.text = "Tap to wear it." + (" Your opponent sees it too." if _category not in ["arena", "board"] else " Only you see it.")


func _refresh_items() -> void:
	if _editor != null:
		return  # The flag editor owns the locker until Done.
	ProfileUi.clear(_items)
	if _category == "topper":
		_items.add_child(_topper_spots())
		_items.add_child(AppTheme.label("Your toppers", "", 16, AppTheme.MUTED))
	var owned := _owned(_category)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for slug: String in owned:
		flow.add_child(_tile(_category, slug))
	_items.add_child(flow)
	var defaults := 1 if Loadout.DEFAULTS.has(_category) else 0
	if owned.size() <= defaults:
		var note := ProfileUi.note("Nothing else here yet. Find more in the Shop.", 16)
		_items.add_child(note)


## Owned items of a category, the default first.
func _owned(category: String) -> Array:
	var out: Array = []
	var fallback := str(Loadout.DEFAULTS.get(category, ""))
	if fallback != "":
		out.append(fallback)
	for slug: String in CosmeticCatalog.slugs(category):
		if slug != fallback and Loadout.owns(category, slug):
			out.append(slug)
	return out


## A small picture tile: tap to wear it (or throw it, for taunts; place it, for toppers). The one
## you wear has a check.
func _tile(category: String, slug: String) -> Button:
	var item := CosmeticCatalog.info(category, slug)
	var worn := category not in ["taunt", "topper"] and Loadout.get_item(category) == slug
	var b := AppTheme.button("", "Accent" if worn else "Ghost", _pick.bind(category, slug), 0)
	b.custom_minimum_size = Vector2(_tile_width, 0)
	var column := AppTheme.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 6
	column.offset_bottom = -9
	var picture := ThumbView.new(category, slug, roundf(_tile_width * 0.56), item.get("swatch", []))
	column.add_child(picture)
	var label_text := "Default" if slug == Loadout.DEFAULTS.get(category) and category in ["arena", "board", "chip", "icons", "shape", "territory", "kill"] \
		else ("None" if slug == "none" else str(item.get("name", slug.capitalize())))
	var name_label := AppTheme.label(label_text, "", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	column.add_child(name_label)
	b.add_child(column)
	b.custom_minimum_size.y = roundf(_tile_width * 0.56) + 46.0
	if worn:
		var check := TileIcon.new("check", Vector2(26, 26))
		check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		check.position = Vector2(_tile_width - 30.0, 2.0)
		b.add_child(check)
	b.tooltip_text = str(item.get("desc", ""))
	return b


func _pick(category: String, slug: String) -> void:
	match category:
		"taunt":
			ui.game.throw_taunt(ui.game.board.my_side, slug)
		"topper":
			_place_topper(slug)
		_:
			_end_try()
			Loadout.equip(category, slug)
			if category in ["trail", "kill"]:
				await get_tree().create_timer(0.35).timeout
				if visible:
					ui.game.preview_effect(category)


# --- Toppers -------------------------------------------------------------------------------------

## The three spots beside your half. Tap one to choose where the next topper goes.
func _topper_spots() -> Control:
	var row := AppTheme.hbox(8)
	var slots: Array = Loadout.get_toppers()["slots"]
	for i in ToppersLibrary.MAX_SLOTS:
		var spot := PanelContainer.new()
		var chosen := i == _selected_slot
		var style := ProfileUi.box(Color(AppTheme.BLUE, 0.22) if chosen else AppTheme.PAPER, 16, 3)
		style.set_content_margin_all(8)
		spot.add_theme_stylebox_override("panel", style)
		spot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spot.mouse_filter = Control.MOUSE_FILTER_STOP
		spot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_selected_slot = -1 if _selected_slot == i else i
				_refresh_items())
		var inner := AppTheme.vbox(4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spot.add_child(inner)
		var filled := i < slots.size()
		var title := AppTheme.label("%d. %s" % [i + 1, ToppersLibrary.STYLES[slots[i]["slug"]]["name"] if filled else "Empty"],
			"", 14, AppTheme.INK if filled else AppTheme.MUTED)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(title)
		if filled:
			if slots[i]["kind"] == "flag":
				var design := AppTheme.button("Design", "Accent", _edit_flag.bind(i), 34)
				design.add_theme_font_size_override("font_size", 14)
				inner.add_child(design)
			var remove := AppTheme.button("Remove", "Ghost", _remove_topper.bind(i), 34)
			remove.add_theme_font_size_override("font_size", 14)
			inner.add_child(remove)
		row.add_child(spot)
	return row


func _place_topper(slug: String) -> void:
	if not Loadout.owns("topper", slug):
		return
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	var slot := {"kind": ToppersLibrary.kind_of(slug), "slug": slug}
	if slot["kind"] == "flag":
		slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
	var index := _selected_slot
	if index < 0 or index >= slots.size():
		if slots.size() < ToppersLibrary.MAX_SLOTS:
			index = slots.size()
			slots.append(slot)
		else:
			index = slots.size() - 1
			slots[index] = slot
			ui.toast("All three spots were full, so the last one was swapped. Tap a spot to pick which.", AppTheme.PURPLE)
	else:
		slots[index] = slot
	_selected_slot = -1
	Loadout.set_toppers(config)
	_frame_shot("toppers")
	if slot["kind"] == "flag":
		_edit_flag(index)


func _remove_topper(index: int) -> void:
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	if index >= 0 and index < slots.size():
		slots.remove_at(index)
	_selected_slot = -1
	Loadout.set_toppers(config)


func _edit_flag(index: int) -> void:
	var slots: Array = Loadout.get_toppers()["slots"]
	if index >= slots.size() or slots[index]["kind"] != "flag":
		return
	_close_editor()
	ProfileUi.clear(_items)
	_editing_slot = index
	_editor = FlagEditor.new(slots[index].get("flag", {}))
	_editor.ui = ui
	_editor.changed.connect(_on_flag_changed)
	_editor.done.connect(func() -> void:
		_close_editor()
		_set_hint()
		_refresh_items())
	_items.add_child(_editor)
	_hint.text = "Your flag waves beside your half. Everyone sees it."
	if _portrait and _folded:
		_toggle_fold()


func _on_flag_changed(design: Dictionary) -> void:
	var config: Dictionary = Loadout.get_toppers().duplicate(true)
	var slots: Array = config["slots"]
	if _editing_slot >= 0 and _editing_slot < slots.size():
		slots[_editing_slot]["flag"] = design
		Loadout.set_toppers(config)


func _close_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null
	_editing_slot = -1


# --- Trying something on -------------------------------------------------------------------------

## Shows an item on your board without equipping it (from the shop's "Try on My Board").
func _try_on(category: String, slug: String) -> void:
	if CosmeticCatalog.info(category, slug).is_empty():
		return
	_trying = [category, slug]
	if category in ORDER and category != _category:
		_switch(category)
	ui.game.preview_item(category, slug)
	ui.game.rig.zoom_by(0.8 if _portrait else float(DESKTOP_ZOOM_OUT.get(Game3D.PREVIEW_SHOTS.get(category, "half"), 1.0)))
	_try_label.text = "Trying on: %s" % str(CosmeticCatalog.info(category, slug).get("name", slug))
	_try_bar.visible = true
	_show_try_actions()
	_place_try_bar()
	AppTheme.pop_in(_try_bar)
	if category in ["aura", "glow", "topper"]:
		Audio.play_item(category, slug)
	if category in ["trail", "kill"]:
		await get_tree().create_timer(0.5).timeout
		if visible and not _trying.is_empty():
			ui.game.preview_effect(category)
			if category == "trail":
				Audio.play_item("trail", slug)


## Shows a Featured Board's whole look on your side, seen whole, without equipping anything.
func _try_look(slug: String) -> void:
	_trying = ["look", slug]
	ui.game.preview_look(FeaturedBoards.look(slug))
	ui.game.rig.zoom_by(0.8 if _portrait else 1.15)
	_try_label.text = "Trying on: %s (the whole set)" % FeaturedBoards.name_of(slug)
	_try_bar.visible = true
	_show_try_actions()
	_place_try_bar()
	AppTheme.pop_in(_try_bar)


func _show_try_actions() -> void:
	if _trying.is_empty():
		return
	ProfileUi.clear(_try_actions)
	if _trying[0] == "look":
		_show_look_actions(_trying[1])
		return
	var category: String = _trying[0]
	var slug: String = _trying[1]
	var action: Button
	if Loadout.owns(category, slug):
		action = AppTheme.button("Wear it", "Success", _wear_tried, 42)
	elif not Loadout.available(category, slug):
		action = AppTheme.button("Back %s" % Loadout.returns_text(category, slug), "Ghost", Callable(), 42)
		action.disabled = true
	else:
		action = AppTheme.button("Buy · %s" % AppTheme.num(Loadout.price(category, slug)), "Primary", _buy_tried, 42)
		action.disabled = _buying
	action.add_theme_font_size_override("font_size", 16)
	_try_actions.add_child(action)
	var stop := AppTheme.button("Stop", "Ghost", func() -> void:
		_end_try()
		_frame_shot(Game3D.PREVIEW_SHOTS.get(_category, "half")), 42)
	stop.add_theme_font_size_override("font_size", 16)
	_try_actions.add_child(stop)


func _show_look_actions(slug: String) -> void:
	var buttons: Array = []
	if FeaturedBoards.owns_all(slug):
		buttons.append(AppTheme.button("Wear the set", "Success", _wear_tried, 42))
	else:
		var buy := AppTheme.button("Buy the set · %s" % AppTheme.num(FeaturedBoards.set_price(slug)), "Primary", _buy_tried, 42)
		buy.disabled = _buying or not FeaturedBoards.available(slug)
		buttons.append(buy)
		if FeaturedBoards.owned_count(slug) > 0:
			buttons.append(AppTheme.button("Wear what I own", "Ghost", _wear_tried, 42))
	buttons.append(AppTheme.button("Stop", "Ghost", func() -> void:
		_end_try()
		_frame_shot(Game3D.PREVIEW_SHOTS.get(_category, "half")), 42))
	for b: Button in buttons:
		b.add_theme_font_size_override("font_size", 16)
		_try_actions.add_child(b)


func _wear_tried() -> void:
	var pair := _trying.duplicate()
	_end_try()
	if pair[0] == "look":
		var worn := FeaturedBoards.wear_owned(pair[1])
		ui.toast("Wearing %d pieces of %s." % [worn, FeaturedBoards.name_of(pair[1])], AppTheme.MINT)
		_frame_shot("wide")
		return
	_pick(pair[0], pair[1])


func _buy_tried() -> void:
	if _buying or _trying.is_empty():
		return
	_buying = true
	_show_try_actions()
	var pair := _trying.duplicate()
	var look: bool = pair[0] == "look"
	var res: Dictionary = await Loadout.buy("bundle" if look else pair[0], pair[1])
	_buying = false
	if res.ok:
		var title: String = FeaturedBoards.name_of(pair[1]) + " set" if look else str(CosmeticCatalog.info(pair[0], pair[1]).get("name", pair[1]))
		ui.toast("Unlocked %s!" % title, AppTheme.MINT)
		if not _trying.is_empty() and _trying[1] == pair[1]:
			_wear_tried()
	else:
		ui.toast(str(res.get("error", "")) if str(res.get("error", "")) != "" else "Not enough credits.", AppTheme.RED)
		_show_try_actions()


func _end_try() -> void:
	if _trying.is_empty():
		return
	_trying = []
	_try_bar.visible = false
	ui.game.set_showcase({})


# --- Footer --------------------------------------------------------------------------------------

func _randomize() -> void:
	_end_try()
	_close_editor()
	Loadout.randomize_all()
	ui.toast("A random look from your locker!", AppTheme.PURPLE)


func _reset() -> void:
	_end_try()
	_close_editor()
	ui.confirm("Put every look back to the default?", "Reset", func() -> void: Loadout.reset(), false)


func _get_more() -> void:
	ui.show_screen("shop", {"category": _category})
