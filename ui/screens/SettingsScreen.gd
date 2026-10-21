extends Screen
## Settings: graphics quality, text size, battle clips, opponent taunts, ambience and sound. Every
## choice is saved in user://settings.cfg and applies right away. Opened from the gear button on
## the title screen and the dashboard; Back returns to wherever it was opened from.

const GRAPHICS := [["auto", "Auto"], ["low", "Low"], ["high", "High"]]
const TEXT_SIZES := [["small", "Small"], ["normal", "Normal"], ["large", "Large"]]

var _back := "home"
var _page: Dictionary
var _graphics_note: Label


func _ready() -> void:
	_page = ProfileUi.page(self, "Settings", _go_back, 620)
	var body: VBoxContainer = _page["body"]

	body.add_child(ProfileUi.eyebrow("Graphics"))
	body.add_child(_choice_row(GRAPHICS, Graphics.get_choice(), _set_graphics))
	_graphics_note = ProfileUi.wrap("", 15, AppTheme.MUTED)
	body.add_child(_graphics_note)

	body.add_child(ProfileUi.eyebrow("Text size"))
	body.add_child(_choice_row(TEXT_SIZES, UiScale.text_size(), _set_text_size))
	body.add_child(ProfileUi.wrap("Bigger or smaller menus and text on this device.", 15, AppTheme.MUTED))

	body.add_child(ProfileUi.eyebrow("Battles"))
	body.add_child(_toggle("Battle clips when pieces clash", "clash_clips", true))
	body.add_child(_toggle("Show my opponent's taunts", "mute_taunts", false, true))
	body.add_child(_toggle("Reduce ambience effects (lighter on phones)", "reduce_ambience", false, false, _on_ambience))

	body.add_child(ProfileUi.eyebrow("Sound"))
	body.add_child(_toggle("Sound effects", "sound_off", false, true, _on_sound))

	get_viewport().size_changed.connect(_layout)
	_layout()


func open(args: Dictionary) -> void:
	_back = str(args.get("back", "home"))
	_layout()
	_update_graphics_note()
	AppTheme.pop_in(_page["card"])


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _go_back() -> void:
	if _back != "home" and ui.has_screen(_back):
		ui.show_screen(_back)
	else:
		ui.home()


## A row of candy buttons where exactly one is lit (like tabs).
func _choice_row(options: Array, current: String, on_pick: Callable) -> HBoxContainer:
	var row := AppTheme.hbox(8)
	var buttons: Dictionary = {}
	for option: Array in options:
		var key: String = option[0]
		var b := AppTheme.button(option[1], "Ghost", Callable(), 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			ProfileUi.select_tab(buttons, key)
			on_pick.call(key))
		buttons[key] = b
		row.add_child(b)
	ProfileUi.select_tab(buttons, current)
	return row


## A switch row. `inverted` flips the stored value (e.g. "Show taunts" stores mute_taunts).
func _toggle(text: String, key: String, default: bool, inverted := false, after := Callable()) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.custom_minimum_size.y = 48
	toggle.add_theme_font_size_override("font_size", 18)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(color, AppTheme.INK)
	var stored: bool = bool(ui.setting(key, default)) if ui else default
	toggle.button_pressed = not stored if inverted else stored
	toggle.toggled.connect(func(on: bool) -> void:
		ui.set_setting(key, not on if inverted else on)
		if after.is_valid():
			after.call(not on if inverted else on))
	return toggle


func _set_graphics(level: String) -> void:
	Graphics.set_choice(level)
	_update_graphics_note()


func _update_graphics_note() -> void:
	var now := Graphics.effective()
	var notes := {
		"high": "Everything on: shadows, glow and the full title-screen show.",
		"medium": "Balanced for browsers: everything on, with fewer new looks loading mid-game.",
		"low": "Smoothest on phones: no shadows or glow, lighter effects, sharper frame rate.",
	}
	var prefix := "Auto picked %s on this device. " % now.capitalize() if Graphics.get_choice() == "auto" else ""
	_graphics_note.text = prefix + str(notes.get(now, ""))


func _set_text_size(size: String) -> void:
	UiScale.set_text_size(get_tree(), size)


func _on_ambience(on: bool) -> void:
	AmbienceFX.reduced = on or Graphics.is_low()
	if ui.game:
		ui.game.board.rebuild_ambience()


func _on_sound(off: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), off)
