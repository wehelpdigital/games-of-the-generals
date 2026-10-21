extends PanelContainer
## Boot Camp's coach: a speech card that says what to do now, reacts to what just happened, shows
## the drill's progress and offers Next / Skip / Exit. Landscape: top-left beside the board (the
## board's picture nudged right). Portrait phones: a full-width card under the turn banner, with
## the board's picture moved down into the room left below it. While a drill runs it lights up
## squares on the board (TutorialMarkers) and tells the lesson when the player swaps pieces
## during setup.

var _hud: Screen
var _slot: Control  # The HUD's "left" column we were registered in.
var _run: TutorialRun
var _markers: TutorialMarkers
var _eyebrow: Label
var _title: Label
var _feedback: Label
var _text: Label
var _dots: HBoxContainer
var _main: HBoxContainer
var _minor: HBoxContainer
var _portrait := false
var _short := false  # Landscape with little height (phones).
var _detached := false  # Out of the HUD's column, placed by hand.
var _shifting := false  # The board's picture is moved for us and must be put back.
var _celebrated := ""  # Lesson id whose completion was already celebrated.


func _ready() -> void:
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # Keep our width even if the column is wider.
	var box := AppTheme.vbox(8)
	add_child(box)
	var header := AppTheme.hbox(10)
	box.add_child(header)
	_eyebrow = AppTheme.label("", "", 13, AppTheme.PURPLE)
	_eyebrow.add_theme_font_override("font", AppTheme.heading_font())
	_eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_eyebrow)
	_dots = AppTheme.hbox(5)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_dots)
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
	_main = AppTheme.hbox(8)
	box.add_child(_main)
	_minor = AppTheme.hbox(8)
	box.add_child(_minor)
	visible = false
	GameSession.tutorial_changed.connect(_attach)


func setup(hud: Screen) -> void:
	_hud = hud  # hud.ui.game isn't set yet while the HUD is built: the board is hooked up later.
	_slot = get_parent_control()
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
	_frame_board()


## Moves the board's picture out from under the card: right in landscape (a little on short
## screens, where the action column is close), down in portrait, to the middle of the room
## between the card and whatever sits above the action buttons.
func _frame_board() -> void:
	if _hud == null or _hud.ui.game == null:
		return
	if _run == null or not visible:
		if _shifting:  # Put back only our own shift: other screens (My Board) use it too.
			_shifting = false
			_hud.ui.game.rig.screen_shift = Vector2.ZERO
		return
	var view := get_viewport().get_visible_rect().size
	var shift := Vector2(0.06, 0.0)
	if _portrait:
		var middle := (get_global_rect().end.y + _bottom_room()) * 0.5
		shift = Vector2(0.0, clampf((middle - view.y * 0.52) / view.y, 0.0, 0.2))  # The board's picture centres a bit low.
	elif _short and not _detached:
		shift.x = 0.03
	_shifting = true
	_hud.ui.game.rig.screen_shift = shift


## Portrait: the top of what stacks above the action buttons (the HUD's bottom column: powerup
## cards and the like), below which the board shouldn't reach.
func _bottom_room() -> float:
	var bottom := _slot.get_global_rect().end.y  # The column grows upward from a fixed bottom edge.
	for child in _column_widgets():
		bottom -= child.get_combined_minimum_size().y + 10.0
	return bottom


## The other widgets showing in the HUD's column (the powerup cards).
func _column_widgets() -> Array[Control]:
	var shown: Array[Control] = []
	for child in _slot.get_children():
		if child != self and child is Control and (child as Control).visible:
			shown.append(child)
	return shown


## Where the card lives: in the HUD's top-left column (roomy landscape), or out of it and placed by
## hand (`_place`) when the column can't hold it: portrait, where the column sits at the bottom,
## and short landscape screens while the powerup cards share the column. Out of the column it's
## a child of the HUD at the column's spot in the drawing order.
func _dock() -> void:
	var detach := _portrait or (_short and not _column_widgets().is_empty())
	if detach == _detached:
		return
	_detached = detach
	if detach:
		reparent(_hud, false)
		_hud.move_child(self, _slot.get_index())
	else:
		reparent(_slot, false)
		_slot.move_child(self, 0)


## Portrait: under the turn banner, centred. Short landscape: beside the powerup cards.
func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var want := get_combined_minimum_size()
	if size != want:
		size = want  # Shrink back after a longer message.
	if _portrait:
		global_position = Vector2(roundf((view.x - want.x) * 0.5), _hud.top_reserved() + 8.0)
	else:
		var x := _slot.global_position.x
		for child in _column_widgets():
			x = maxf(x, _slot.global_position.x + child.get_combined_minimum_size().x)
		global_position = Vector2(x + 12.0, _slot.global_position.y)


func _process(_delta: float) -> void:
	if _hud == null or _slot == null or not visible:
		return
	_dock()
	if _detached:
		_place()
	_frame_board()


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


## Size and type for the screen: full width in portrait, a side card in landscape (a bit wider and
## with one row of buttons on short screens, so it stays short).
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var one_row := _one_row()
	_portrait = view.x < view.y
	_short = not _portrait and view.y < 560.0
	if _portrait:
		custom_minimum_size.x = minf(view.x - 24.0, 520.0)
	elif _short:
		custom_minimum_size.x = clampf(view.x * 0.36, 250.0, 300.0)
	else:
		custom_minimum_size.x = clampf(view.x * 0.24, 250.0, 320.0)
	var compact := _portrait or _short
	_text.add_theme_font_size_override("font_size", 15 if compact else 17)
	_feedback.add_theme_font_size_override("font_size", 15 if compact else 16)
	_title.add_theme_font_size_override("font_size", 18 if compact else 22)
	if _slot:
		_dock()
	if one_row != _one_row():
		_render()


## Phones: Next, Skip and Exit share one row.
func _one_row() -> bool:
	return _portrait or _short


func _render() -> void:
	visible = _run != null and is_instance_valid(_run)
	set_process(visible)
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
	var minor := _main if _one_row() else _minor  # Phones: one row of buttons, to keep the card short.
	if not s["graduation"]:
		_add(minor, "Skip" if _one_row() else "Skip drill", "Ghost", _skip, 40)
	_add(minor, "Exit", "Ghost", _to_boot_camp, 40)


func _add(row: HBoxContainer, text: String, kind: String, action: Callable, height := 48.0) -> void:
	if _one_row():
		height = 40.0
	var b := AppTheme.button(text, kind, action, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17 if height < 48.0 else 19)
	if kind == "Primary" and _one_row():
		b.size_flags_stretch_ratio = 1.6  # Next stays the obvious one.
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
