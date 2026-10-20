extends Screen
## Pick an AI difficulty and start an offline practice game.

const LEVELS := [
	{"level": SalpakanAI.Difficulty.EASY, "title": "Rookie", "kind": "Success", "badge": "PVT",
		"blurb": "Makes mistakes. Great for learning the ranks."},
	{"level": SalpakanAI.Difficulty.MEDIUM, "title": "Officer", "kind": "Secondary", "badge": "CPT",
		"blurb": "Plays solid and punishes careless moves."},
	{"level": SalpakanAI.Difficulty.HARD, "title": "General", "kind": "Primary", "badge": "G5",
		"blurb": "Reads clashes, hunts your flag, thinks ahead."},
]

var _card: PanelContainer
var _buttons: Dictionary = {}  # level -> Button


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(14)
	_card.add_child(box)
	var heading := AppTheme.label("Play vs AI", "HeadingLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var sub := AppTheme.label("Offline practice. You play white and move first.", "MutedLabel")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	for entry: Dictionary in LEVELS:
		var level: int = entry["level"]
		var row := AppTheme.hbox(12)
		var badge := TextureRect.new()
		badge.texture = PieceIcons.icon_texture(entry["badge"])
		badge.custom_minimum_size = Vector2(76, 76)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		var option := AppTheme.vbox(4)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := AppTheme.button(entry["title"], entry["kind"], func() -> void: _start(level), 56)
		_buttons[level] = b
		option.add_child(b)
		var blurb := AppTheme.label(entry["blurb"], "MutedLabel", 17)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.add_child(blurb)
		row.add_child(option)
		box.add_child(row)
	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	add_child(AppTheme.centered(_card, 500))


func open(_args: Dictionary) -> void:
	# Rookie is free for everyone; the tougher AIs need an account.
	for level: int in _buttons:
		var title: String = LEVELS.filter(func(e: Dictionary) -> bool: return e["level"] == level)[0]["title"]
		var locked := level != SalpakanAI.Difficulty.EASY and not ApiManager.is_logged_in()
		_buttons[level].text = title + (" (log in)" if locked else "")
	AppTheme.pop_in(_card)


func _start(level: int) -> void:
	if level != SalpakanAI.Difficulty.EASY and not ApiManager.is_logged_in():
		ui.toast("Log in to challenge the Officer and General AIs.", AppTheme.BLUE)
		ui.show_screen("auth", {"next": "ai_setup"})
		return
	GameSession.start_practice(level as SalpakanAI.Difficulty)
