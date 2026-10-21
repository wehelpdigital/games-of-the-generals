extends Screen
## Sound test: every sound in the game with a play button, so each one can be auditioned. Music,
## interface and gameplay sounds come first; then every shop item, category by category, playing
## exactly the sound it plays in the game. Opened from Settings.

const CATEGORY_ORDER := ["kill", "taunt", "trail", "ambience", "aura", "glow", "topper", "arena", "board",
	"territory", "chip", "shape", "icons"]

var _back := "settings"
var _page: Dictionary
var _list: VBoxContainer
var _tabs: Dictionary = {}
var _section := "Music"
var _playing_music := ""


func _ready() -> void:
	_page = ProfileUi.page(self, "Sound test", _go_back, 760)
	var body: VBoxContainer = _page["body"]
	body.add_child(ProfileUi.wrap("Tap Play to hear any sound. Shop items play exactly what they play in a match.", 16, AppTheme.MUTED))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	var sections: Array = []
	for group: String in SoundIndex.GROUPS:
		sections.append(group)
	for category: String in CATEGORY_ORDER:
		sections.append(category)
	for section: String in sections:
		var label := section if SoundIndex.GROUPS.has(section) else CosmeticCatalog.label(section)
		var b := AppTheme.button(label, "Ghost", _show.bind(section), 40)
		b.add_theme_font_size_override("font_size", 15)
		_tabs[section] = b
		tabs.add_child(b)
	body.add_child(tabs)
	_list = AppTheme.vbox(6)
	body.add_child(_list)
	get_viewport().size_changed.connect(_layout)
	_layout()


func open(args: Dictionary) -> void:
	_back = str(args.get("back", "settings"))
	_layout()
	_show(_section)
	AppTheme.pop_in(_page["card"])


func close() -> void:
	Audio.stop_preview()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _go_back() -> void:
	ui.show_screen(_back if ui.has_screen(_back) else "settings", {"back": "home"})


func _show(section: String) -> void:
	_section = section
	ProfileUi.select_tab(_tabs, section)
	for child in _list.get_children():
		child.queue_free()
	if SoundIndex.GROUPS.has(section):
		for sound: String in SoundIndex.GROUPS[section]:
			_list.add_child(_row(str(SoundIndex.LABELS.get(sound, sound)), sound, _play_named.bind(section, sound)))
		return
	for slug: String in CosmeticCatalog.slugs(section):
		var item_name := str(CosmeticCatalog.info(section, slug).get("name", slug))
		var sound := Audio.item_sound(section, slug)
		_list.add_child(_row(item_name, sound if sound != "" else "(silent)", Audio.play_item.bind(section, slug)))


func _play_named(section: String, sound: String) -> void:
	if section == "Music":
		Audio.music(sound)
		_playing_music = sound
	else:
		Audio.play(sound)


func _row(title: String, detail: String, on_play: Callable) -> PanelContainer:
	var panel := AppTheme.card("Row")
	var row := AppTheme.hbox(10)
	panel.add_child(row)
	var text := AppTheme.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := AppTheme.label(title, "", 17)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	text.add_child(AppTheme.label(detail, "", 13, AppTheme.MUTED))
	row.add_child(text)
	var play := ProfileUi.small_button("Play", "Primary", on_play, 40)
	play.custom_minimum_size.x = 84
	play.set_meta("no_click", true)  # So the sound is heard on its own.
	row.add_child(play)
	return panel
