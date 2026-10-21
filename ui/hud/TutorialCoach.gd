extends PanelContainer
## Boot Camp's coach: a speech card beside the board (top-left in landscape, above the action
## buttons on portrait phones) that says what to do now, reacts to what just happened, shows the
## drill's progress and offers Next / Skip / Exit. While a drill runs it lights up squares on the
## board (TutorialMarkers) and tells the lesson when the player swaps pieces during setup.

var _hud: Screen
var _run: TutorialRun
var _markers: TutorialMarkers
var _eyebrow: Label
var _title: Label
var _feedback: Label
var _text: Label
var _dots: HBoxContainer
var _main: HBoxContainer
var _minor: HBoxContainer
var _celebrated := ""  # Lesson id whose completion was already celebrated.


func _ready() -> void:
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := AppTheme.vbox(8)
	add_child(box)
	_eyebrow = AppTheme.label("", "", 13, AppTheme.PURPLE)
	_eyebrow.add_theme_font_override("font", AppTheme.heading_font())
	box.add_child(_eyebrow)
	_title = AppTheme.label("", "", 22)
	_title.add_theme_font_override("font", AppTheme.heading_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_feedback = AppTheme.label("", "", 16)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_feedback)
	_text = AppTheme.label("", "", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_dots = AppTheme.hbox(5)
	box.add_child(_dots)
	_main = AppTheme.hbox(8)
	box.add_child(_main)
	_minor = AppTheme.hbox(8)
	box.add_child(_minor)
	visible = false
	GameSession.tutorial_changed.connect(_attach)


func setup(hud: Screen) -> void:
	_hud = hud  # hud.ui.game isn't set yet while the HUD is built: the board is hooked up later.
	get_viewport().size_changed.connect(_layout)
	_attach()


func _attach() -> void:
	if _run and is_instance_valid(_run):
		if _run.changed.is_connected(_render):
			_run.changed.disconnect(_render)
		if _run.exit_requested.is_connected(_exit):
			_run.exit_requested.disconnect(_exit)
	_run = GameSession.tutorial
	if _run:
		_run.changed.connect(_render)
		_run.exit_requested.connect(_exit)
		_ensure_markers()
	elif _markers and is_instance_valid(_markers):
		_markers.queue_free()
		_markers = null
	_layout()
	_render()


func _on_setup_changed() -> void:
	if _run and is_instance_valid(_run):
		_run.on_swap()


func _ensure_markers() -> void:
	if _hud == null or _hud.ui.game == null:
		return
	var board := _hud.ui.game.board
	if not board.setup_changed.is_connected(_on_setup_changed):
		board.setup_changed.connect(_on_setup_changed)
	if _markers and is_instance_valid(_markers):
		return
	_markers = TutorialMarkers.new()
	_markers.name = "TutorialMarkers"
	board.add_child(_markers)


## Landscape: a card in the top-left column beside the board. Portrait: a full-width card above
## the action buttons.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var portrait := view.x < view.y
	custom_minimum_size.x = minf(view.x - 24.0, 520.0) if portrait else clampf(view.x * 0.24, 250.0, 320.0)
	var compact := view.y < 560.0 or portrait
	_text.add_theme_font_size_override("font_size", 16 if compact else 17)
	_title.add_theme_font_size_override("font_size", 19 if compact else 22)


func _render() -> void:
	visible = _run != null and is_instance_valid(_run)
	if not visible:
		return
	var s := _run.state()
	var graduation: bool = s["graduation"]
	_eyebrow.text = "BOOT CAMP · FINAL EXAM" if graduation else "BOOT CAMP · DRILL %d OF %d" % [int(s["index"]) + 1, int(s["count"])]
	_feedback.text = str(s["feedback"])
	_feedback.visible = _feedback.text != ""
	_feedback.add_theme_color_override("font_color", AppTheme.MINT.darkened(0.25) if s["feedback_good"] else AppTheme.RED.darkened(0.1))
	_text.text = str(s["text"])
	_text.visible = _text.text != ""
	if s["done"]:
		_title.text = ("Boot Camp graduate!" if s["won"] else "Not this time!") if graduation else "Drill complete!"
	else:
		_title.text = str(s["title"])
	_render_dots(int(s["step"]), int(s["steps"]), s["done"])
	_render_buttons(s)
	if _markers and is_instance_valid(_markers):
		_markers.show_marks(s["marks"])
	if s["done"] and _celebrated != str(s["id"]):
		_celebrated = str(s["id"])
		AppTheme.pop_in(self)
		if graduation and s["won"]:
			_celebrate_graduation()


func _render_dots(step: int, steps: int, finished: bool) -> void:
	for child in _dots.get_children():
		child.queue_free()
	_dots.visible = steps > 1
	for i in steps:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 6)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		style.bg_color = AppTheme.MINT if finished or i < step else (AppTheme.PINK if i == step else Color(AppTheme.INK, 0.15))
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)


func _render_buttons(s: Dictionary) -> void:
	for row: HBoxContainer in [_main, _minor]:
		for child in row.get_children():
			child.queue_free()
	if s["done"]:
		if s["graduation"]:
			if s["won"]:
				_add(_main, "Play a full game", "Primary", _full_game)
			else:
				_add(_main, "Try again", "Primary", func() -> void: GameSession.start_lesson(TutorialLessons.GRADUATION_ID))
			_add(_main, "Boot Camp", "Ghost", _to_boot_camp)
		else:
			var next := TutorialLessons.next_id(str(s["id"]))
			var label := "Final exam" if next == TutorialLessons.GRADUATION_ID else "Next drill"
			_add(_main, label, "Primary", func() -> void: GameSession.start_lesson(next))
			_add(_main, "Boot Camp", "Ghost", _to_boot_camp)
		return
	if s["next_button"]:
		_add(_main, "Next", "Primary", func() -> void: _run.next_pressed())
	_minor.visible = true
	if not s["graduation"]:
		_add(_minor, "Skip drill", "Ghost", _skip, 40)
	_add(_minor, "Exit", "Ghost", _to_boot_camp, 40)


func _add(row: HBoxContainer, text: String, kind: String, action: Callable, height := 48.0) -> void:
	var b := AppTheme.button(text, kind, action, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17 if height < 48.0 else 19)
	row.add_child(b)
	_main.visible = _main.get_child_count() > 0
	_minor.visible = _minor.get_child_count() > 0


func _skip() -> void:
	var next := TutorialLessons.next_id(_run.lesson_id())
	if next != "":
		GameSession.start_lesson(next)


func _full_game() -> void:
	GameSession.start_practice(SalpakanAI.Difficulty.EASY)


func _to_boot_camp() -> void:
	_exit()


func _exit() -> void:
	if _hud == null:
		return
	GameSession.leave()
	_hud.ui.game.show_attract()
	_hud.ui.show_screen("boot_camp")


## A medal card over the board: the player passed Boot Camp.
func _celebrate_graduation() -> void:
	var card := AppTheme.card()
	var box := AppTheme.vbox(14)
	card.add_child(box)
	var medal := TextureRect.new()
	medal.texture = PieceIcons.icon_texture("G5")
	medal.custom_minimum_size = Vector2(120, 120)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	box.add_child(_centered_label("BOOT CAMP GRADUATE", 30, AppTheme.INK))
	box.add_child(_centered_label("You know the ranks, the Spy, the fog and the cards. Time for real battles!", 18, AppTheme.MUTED))
	var ok := AppTheme.button("Let's go!", "Primary", _hud.ui.close_dialog, 54)
	box.add_child(ok)
	ProfileUi.overlay(_hud.ui, card, 440)


func _centered_label(text: String, size: int, color: Color) -> Label:
	var l := AppTheme.label(text, "", size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size >= 24:
		l.add_theme_font_override("font", AppTheme.heading_font())
	return l
