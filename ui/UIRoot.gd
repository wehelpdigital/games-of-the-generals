class_name UIRoot
extends CanvasLayer
## Owns every UI screen and the transitions between them, plus toasts and confirm dialogs.
## Flow: title → (Play vs AI → difficulty) | (Play Online → login → lobby) | leaderboard | shop.
## Whenever GameSession loads a match the in-game HUD takes over; leaving returns to the title.

const SCREENS := {
	"title": preload("res://ui/screens/TitleScreen.gd"),
	"ai_setup": preload("res://ui/screens/AiSetupScreen.gd"),
	"auth": preload("res://ui/screens/AuthScreen.gd"),
	"lobby": preload("res://ui/screens/LobbyScreen.gd"),
	"leaderboard": preload("res://ui/screens/LeaderboardScreen.gd"),
	"shop": preload("res://ui/screens/ShopScreen.gd"),
	"hud": preload("res://ui/screens/GameHUD.gd"),
}

const SETTINGS_FILE := "user://settings.cfg"

var game: Game3D
var current_name := ""

var _root: Control
var _screens: Dictionary = {}
var _overlay: Control
var _toast_box: VBoxContainer
var _cut_in: ClashCutIn
var _settings := ConfigFile.new()


func _ready() -> void:
	UiScale.apply(get_tree())  # Before building screens, so they lay out at the final UI size.
	get_tree().root.size_changed.connect(func() -> void: UiScale.apply(get_tree()))
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = AppTheme.get_theme()
	get_tree().root.theme = _root.theme  # Popups such as tooltips live in their own window.
	add_child(_root)
	var all_screens: Dictionary = SCREENS.duplicate()
	all_screens.merge(ScreenRegistry.screens)  # Screens contributed by feature modules.
	for screen_name: String in all_screens:
		var screen: Screen = all_screens[screen_name].new()
		screen.name = screen_name.capitalize().replace(" ", "")
		screen.ui = self
		screen.visible = false
		_root.add_child(screen)
		_screens[screen_name] = screen

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_toast_box = AppTheme.vbox(8)
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 96)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_toast_box)
	_cut_in = ClashCutIn.new()
	_root.add_child(_cut_in)  # Last, so battle clips draw over dialogs too.

	_settings.load(SETTINGS_FILE)
	GameSession.match_loaded.connect(_on_match_loaded)


func show_screen(screen_name: String, args := {}) -> void:
	close_dialog()
	if current_name != "" and _screens.has(current_name):
		var old: Screen = _screens[current_name]
		old.close()
		old.visible = false
	current_name = screen_name
	var screen: Screen = _screens[screen_name]
	screen.visible = true
	screen.open(args)


func screen(screen_name: String) -> Screen:
	return _screens[screen_name]


func has_screen(screen_name: String) -> bool:
	return _screens.has(screen_name)


## The player's home: the dashboard when logged in (once that screen exists), else the title.
func home() -> void:
	show_screen("dashboard" if ApiManager.is_logged_in() and has_screen("dashboard") else "title")


## Leave whatever is going on and return home with the orbiting board.
func back_to_menu() -> void:
	GameSession.leave()
	game.show_attract()
	home()


## Screens that need an account send the player through login first.
func require_login(next: String) -> void:
	if ApiManager.is_logged_in():
		show_screen(next)
	else:
		show_screen("auth", {"next": next})


## Coroutine: plays a battle clip (see ClashCutIn.play) and returns when it ends or is skipped.
func play_clash(data: Dictionary) -> void:
	await _cut_in.play(data)


## Player preferences stored in user://settings.cfg.
func setting(key: String, default: Variant) -> Variant:
	return _settings.get_value("ui", key, default)


func set_setting(key: String, value: Variant) -> void:
	_settings.set_value("ui", key, value)
	_settings.save(SETTINGS_FILE)


func toast(text: String, color := AppTheme.INK) -> void:
	if text == "":
		return
	var chip := AppTheme.pill(text, color, Color.WHITE, 20)
	_toast_box.add_child(chip)
	AppTheme.pop_in(chip)
	var t := chip.create_tween()
	t.tween_interval(2.6)
	t.tween_property(chip, "modulate:a", 0.0, 0.3)
	t.tween_callback(chip.queue_free)


## Modal card with a message and Yes/No. `on_yes` runs when confirmed.
func confirm(message: String, yes_label: String, on_yes: Callable, danger := true) -> void:
	close_dialog()
	var shade := ColorRect.new()
	shade.color = Color(AppTheme.INK, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	var card := AppTheme.card()
	var box := AppTheme.vbox(18)
	card.add_child(box)
	var text := AppTheme.label(message, "", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var row := AppTheme.hbox(12)
	var no := AppTheme.button("Cancel", "Ghost", close_dialog)
	var yes := AppTheme.button(yes_label, "Danger" if danger else "Primary", _confirmed.bind(on_yes))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	row.add_child(yes)
	box.add_child(row)
	shade.add_child(AppTheme.centered(card, 440))
	AppTheme.pop_in(card)


## Any modal or overlay card (confirm, game over) lives on the overlay layer.
func show_overlay(content: Control, dim := true) -> void:
	close_dialog()
	var shade := ColorRect.new()
	shade.color = Color(AppTheme.INK, 0.45 if dim else 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	shade.add_child(content)


func _confirmed(on_yes: Callable) -> void:
	close_dialog()
	on_yes.call()


func close_dialog() -> void:
	for child in _overlay.get_children():
		child.queue_free()


func _on_match_loaded(_view: Dictionary) -> void:
	if current_name != "hud":
		show_screen("hud")
