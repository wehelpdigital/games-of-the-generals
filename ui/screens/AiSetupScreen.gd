extends Screen
## Pick an AI difficulty and start an offline practice game.

const LEVELS := [
	{"level": SalpakanAI.Difficulty.EASY, "title": "Rookie", "kind": "Success",
		"blurb": "Makes mistakes. Great for learning the ranks."},
	{"level": SalpakanAI.Difficulty.MEDIUM, "title": "Officer", "kind": "Secondary",
		"blurb": "Plays solid and punishes careless moves."},
	{"level": SalpakanAI.Difficulty.HARD, "title": "General", "kind": "Primary",
		"blurb": "Reads clashes, hunts your flag, thinks ahead."},
]

var _card: PanelContainer


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
		var option := AppTheme.vbox(4)
		var b := AppTheme.button(entry["title"], entry["kind"], func() -> void: _start(level), 60)
		option.add_child(b)
		var blurb := AppTheme.label(entry["blurb"], "MutedLabel", 17)
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.add_child(blurb)
		box.add_child(option)
	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	add_child(AppTheme.centered(_card, 460))


func open(_args: Dictionary) -> void:
	AppTheme.pop_in(_card)


func _start(level: int) -> void:
	GameSession.start_practice(level as SalpakanAI.Difficulty)
