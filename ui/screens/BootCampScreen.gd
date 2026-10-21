extends Screen
## Boot Camp: eight quick drills on the real board, then a short graduation game against the
## Rookie AI. Free and offline, guests included. Shows progress, a big Start / Continue button and
## every drill to replay.

var _page: Dictionary
var _body: VBoxContainer
var _back_to := ""


func _ready() -> void:
	_page = ProfileUi.page(self, "Boot Camp", _back, 760)
	_body = _page["body"]
	get_viewport().size_changed.connect(_on_resized)


func open(args: Dictionary) -> void:
	_back_to = str(args.get("back", ""))
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])


func _on_resized() -> void:
	_layout()
	if visible:
		_render()  # Phone and wide rows differ.


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _back() -> void:
	if _back_to != "" and ui.has_screen(_back_to):
		ui.show_screen(_back_to)
	else:
		ui.home()


func _render() -> void:
	ProfileUi.clear(_body)
	var done := TutorialProgress.done_count()
	var total := TutorialLessons.LESSONS.size()
	var graduate := TutorialProgress.is_graduate()
	_body.add_child(_hero(done, total, graduate))
	_body.add_child(ProfileUi.eyebrow("DRILLS"))
	for i in total:
		_body.add_child(_lesson_row(TutorialLessons.LESSONS[i], i + 1))
	_body.add_child(ProfileUi.eyebrow("FINAL EXAM"))
	_body.add_child(_lesson_row(TutorialLessons.GRADUATION, 0))
	var rules := ProfileUi.small_button("Read the rules", "Ghost", func() -> void: ui.show_screen("how_to_play", {"back": "boot_camp"}), 48)
	_body.add_child(rules)


## The headline card: what Boot Camp is, progress, and the one button that matters.
func _hero(done: int, total: int, graduate: bool) -> Control:
	var card := AppTheme.card("Row")
	card.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
	var box := AppTheme.vbox(10)
	card.add_child(box)
	var top := AppTheme.hbox(12)
	var medal := TextureRect.new()
	medal.texture = PieceIcons.icon_texture("G5" if graduate else "PVT")
	medal.custom_minimum_size = Vector2(48, 48) if ProfileUi.narrow else Vector2(64, 64)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(medal)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := ProfileUi.heading("Graduate!" if graduate else "Learn Salpakan in 5 minutes", 22 if ProfileUi.narrow else 26)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = 80
	words.add_child(heading)
	words.add_child(ProfileUi.wrap("Eight quick drills on the real board, then a short game against the Rookie AI. Free, offline, no account needed.", 16, AppTheme.MUTED))
	top.add_child(words)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.max_value = total
	bar.value = done
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	var fill := StyleBoxFlat.new()
	fill.bg_color = AppTheme.MINT
	fill.set_corner_radius_all(7)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(AppTheme.INK, 0.12)
	back.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	box.add_child(AppTheme.label("%d of %d drills done%s" % [done, total, "  ·  Graduated" if graduate else ""], "", 15, AppTheme.MUTED))
	var next := TutorialProgress.next_lesson()
	var label := "Start Boot Camp"
	if graduate:
		label = "Play the drills again"
		next = TutorialLessons.LESSONS[0]["id"]
	elif next == TutorialLessons.GRADUATION_ID:
		label = "Take the final exam"
	elif done > 0:
		label = "Continue: %s" % TutorialLessons.get_lesson(next)["title"]
	var start := ProfileUi.colored_button(label, AppTheme.PINK, Color.WHITE, _start.bind(next), 60)
	box.add_child(start)
	return card


func _lesson_row(lesson: Dictionary, number: int) -> Control:
	var row := AppTheme.card("Row")
	var line := AppTheme.hbox(12)
	row.add_child(line)
	var done := TutorialProgress.is_graduate() if number == 0 else TutorialProgress.is_done(lesson["id"])
	var badge := TextureRect.new()
	badge.texture = PieceIcons.badge_or_mystery(str(lesson["icon"]))
	badge.custom_minimum_size = Vector2(40, 40) if ProfileUi.narrow else Vector2(48, 48)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(badge)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := AppTheme.label(("%d. " % number if number > 0 else "") + str(lesson["title"]), "", 18 if ProfileUi.narrow else 20)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 80
	words.add_child(title)
	words.add_child(ProfileUi.wrap(str(lesson["blurb"]), 15, AppTheme.MUTED))
	line.add_child(words)
	if done and not ProfileUi.narrow:  # Phones: "Replay" says it's done.
		var check := AppTheme.pill("DONE", AppTheme.MINT, Color.WHITE, 14)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(check)
	var play := ProfileUi.small_button("Replay" if done else "Play", "Ghost" if done else "Secondary", _start.bind(str(lesson["id"])), 44)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(play)
	return row


func _start(lesson_id: String) -> void:
	GameSession.start_lesson(lesson_id)
