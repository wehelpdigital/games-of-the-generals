class_name FlagEditor
extends VBoxContainer
## Designs a topper flag: shape, two colours, pattern and emblem, or a picture (uploaded, or the
## player's guild logo). Every change emits `changed` with the new design, so the flag on the board
## updates live. Pictures are kept on this device first and uploaded to the account
## (POST /api/media, purpose "flag") when logged in, so opponents can see them too.

signal changed(design: Dictionary)
signal done

const ICON_SCALE := 0.25

var design: Dictionary
var ui: UIRoot  ## For toasts; set by whoever shows the editor.

var _preview: TextureRect
var _shape_buttons: Dictionary = {}
var _pattern_buttons: Dictionary = {}
var _emblem_buttons: Dictionary = {}
var _palette_target := "color"
var _target_buttons: Dictionary = {}
var _custom_color: ColorPickerButton
var _guild_toggle: CheckButton
var _picture: Image  # The current picture (local, uploaded or guild logo), for the preview.
var _picture_mode := "photo"
var _picture_key := ""


func _init(start_design: Dictionary) -> void:
	design = FlagFactory.normalize(start_design)
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	var header := AppTheme.hbox(8)
	header.add_child(AppTheme.label("Design your flag", "HeadingLabel", 26))
	header.add_child(AppTheme.spacer())
	header.add_child(AppTheme.button("Done", "Success", func() -> void: done.emit(), 44))
	add_child(header)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 150)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_preview)

	_section("Shape")
	add_child(_choice_grid(FlagFactory.SHAPES.keys(), 4, _shape_buttons, _pick_shape))
	_section("Colours")
	var targets := AppTheme.hbox(6)
	for key: String in ["color", "color2"]:
		var b := AppTheme.button("Main" if key == "color" else "Accent", "Ghost", _set_target.bind(key), 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_target_buttons[key] = b
		targets.add_child(b)
	_custom_color = ColorPickerButton.new()
	_custom_color.custom_minimum_size = Vector2(76, 38)
	_custom_color.edit_alpha = false
	_custom_color.tooltip_text = "Any colour"
	_custom_color.color_changed.connect(func(c: Color) -> void: _set_color("#" + c.to_html(false)))
	targets.add_child(_custom_color)
	add_child(targets)
	var palette := GridContainer.new()
	palette.columns = 8
	palette.add_theme_constant_override("h_separation", 6)
	palette.add_theme_constant_override("v_separation", 6)
	for hex: String in FlagFactory.PALETTE:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(0, 34)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(hex)
		style.set_corner_radius_all(10)
		style.set_border_width_all(3)
		style.border_color = AppTheme.INK
		for state: String in ["normal", "hover", "pressed"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(_set_color.bind(hex))
		palette.add_child(swatch)
	add_child(palette)
	_section("Pattern")
	add_child(_choice_grid(FlagFactory.PATTERNS.keys(), 5, _pattern_buttons, _pick_pattern))
	_section("Emblem")
	add_child(_choice_grid(FlagFactory.EMBLEMS.keys(), 6, _emblem_buttons, _pick_emblem))

	_section("Picture")
	var pictures := AppTheme.hbox(6)
	var upload := AppTheme.button("Upload picture", "Secondary", _upload, 44)
	upload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pictures.add_child(upload)
	var clear := AppTheme.button("Remove", "Ghost", _clear_picture, 44)
	pictures.add_child(clear)
	add_child(pictures)
	_guild_toggle = CheckButton.new()
	_guild_toggle.text = "Use my guild logo"
	_guild_toggle.focus_mode = Control.FOCUS_NONE
	_guild_toggle.toggled.connect(_toggle_guild_logo)
	add_child(_guild_toggle)
	var credit := AppTheme.label("Some emblems by Lorc and Delapouite, game-icons.net, CC BY 3.0.", "MutedLabel", 13)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(credit)

	_set_target("color")
	_load_picture()
	_refresh()


func _section(title: String) -> void:
	add_child(AppTheme.label(title, "", 18, AppTheme.MUTED))


func _choice_grid(keys: Array, columns: int, store: Dictionary, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for key: String in keys:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.theme_type_variation = "GhostButton"
		b.pressed.connect(on_pick.bind(key))
		store[key] = b
		grid.add_child(b)
	return grid


# --- Edits ---------------------------------------------------------------------------------------

func _pick_shape(key: String) -> void:
	_update({"shape": key})


func _pick_pattern(key: String) -> void:
	_update({"pattern": key})


func _pick_emblem(key: String) -> void:
	_update({"emblem": key})


func _set_target(key: String) -> void:
	_palette_target = key
	for k: String in _target_buttons:
		_target_buttons[k].theme_type_variation = "AccentButton" if k == key else "GhostButton"
	_custom_color.color = Color(str(design[key]))


func _set_color(hex: String) -> void:
	_update({_palette_target: hex})


func _toggle_guild_logo(on: bool) -> void:
	_update({"use_guild_logo": on})
	_load_picture()
	_refresh()


func _clear_picture() -> void:
	design.erase("local_image")
	_update({"image_media_id": null, "use_guild_logo": false})
	_load_picture()
	_refresh()


func _update(fields: Dictionary) -> void:
	for key: String in fields:
		design[key] = fields[key]
	design = FlagFactory.normalize(design)
	changed.emit(design.duplicate())
	_refresh()


func _upload() -> void:
	FilePicker.pick_image(self, _on_picked)


## Keep a copy on this device right away, then upload it to the account when logged in.
func _on_picked(image: Image) -> void:
	if image == null:
		return
	var path := Loadout.save_local_flag_image(image)
	design["local_image"] = path
	_update({"image_media_id": null, "use_guild_logo": false})
	_load_picture()
	_refresh()
	if not ApiManager.is_logged_in():
		_toast("Saved on this device. Log in to show it to your opponents.")
		return
	var body := FilePicker.to_upload(image)
	body["purpose"] = "flag"
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_POST, "/api/media", body)
	if res.ok and res.data.get("id") != null:
		_update({"image_media_id": int(res.data["id"])})
		_toast("Picture uploaded!")
	else:
		_toast("Saved on this device only (upload failed).", AppTheme.RED)


func _toast(text: String, color := AppTheme.MINT) -> void:
	if ui != null:
		ui.toast(text, color)


# --- Display -------------------------------------------------------------------------------------

func _load_picture() -> void:
	_picture = null
	var logo := _guild_logo()
	if design["use_guild_logo"] and logo != "":
		_fetch(logo, "logo")
	elif str(design.get("local_image", "")) != "" and FileAccess.file_exists(str(design["local_image"])):
		_picture = Image.load_from_file(str(design["local_image"]))
		_picture_mode = "photo"
		_picture_key = str(design["local_image"])
	elif design["image_media_id"] != null:
		_fetch("/api/media/%d" % int(design["image_media_id"]), "photo")


func _fetch(url: String, mode: String) -> void:
	RemoteImage.fetch(url, func(texture: Texture2D) -> void:
		if texture and is_instance_valid(self):
			_picture = texture.get_image()
			_picture_mode = mode
			_picture_key = url
			_refresh())


func _guild_logo() -> String:
	var guild: Variant = ApiManager.user.get("guild")
	return str(guild.get("logo_url", "")) if guild is Dictionary and guild.get("logo_url") != null else ""


func _refresh() -> void:
	if _preview == null:
		return
	var has_picture: bool = _picture != null and (design["use_guild_logo"] or str(design.get("local_image", "")) != "" or design["image_media_id"] != null)
	_preview.texture = FlagFactory.texture(design, _picture if has_picture else null, _picture_mode, 1.0, _picture_key)
	var plain := {"color": design["color"], "color2": design["color2"]}
	for key: String in _shape_buttons:
		_shape_buttons[key].icon = FlagFactory.texture(_merge(plain, {"shape": key, "pattern": "solid", "emblem": "none"}), null, "photo", ICON_SCALE)
		_mark(_shape_buttons[key], key == design["shape"])
	for key: String in _pattern_buttons:
		_pattern_buttons[key].icon = FlagFactory.texture(_merge(plain, {"shape": "rectangle", "pattern": key, "emblem": "none"}), null, "photo", ICON_SCALE)
		_mark(_pattern_buttons[key], key == design["pattern"])
	for key: String in _emblem_buttons:
		_emblem_buttons[key].icon = FlagFactory.texture(_merge(plain, {"shape": "rectangle", "pattern": "solid", "emblem": key}), null, "photo", ICON_SCALE)
		_mark(_emblem_buttons[key], key == design["emblem"])
	var logo := _guild_logo()
	_guild_toggle.disabled = logo == ""
	_guild_toggle.set_pressed_no_signal(design["use_guild_logo"] and logo != "")
	_guild_toggle.tooltip_text = "" if logo != "" else "Join a guild with a logo to use it here."


func _mark(button: Button, selected: bool) -> void:
	button.theme_type_variation = "AccentButton" if selected else "GhostButton"


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := a.duplicate()
	d.merge(b, true)
	return d
