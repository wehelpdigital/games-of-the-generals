extends Screen
## Ranked matchmaking: you're paired with players of your own rank; the server widens the search
## to ±1 rank after 45 s and ±2 after 120 s. A found match arrives by poll (every 3 s, which also
## keeps your place in the queue) or by the RankedMatched event on private-user.{id}. Leaving this
## screen cancels the search.

const POLL_SECONDS := 3.0
const WIDEN_ONE := 45.0
const WIDEN_TWO := 120.0

var _card: PanelContainer
var _blurb: Label
var _insignia: RankInsignia
var _rank_name: Label
var _xp: Label
var _idle_box: VBoxContainer
var _search_box: VBoxContainer
var _radar: Radar
var _headline: Label
var _clock: Label
var _window: PanelContainer
var _find: Button
var _back_button: Button
var _poll: Timer
var _searching := false
var _opening := false
var _waited := 0.0
var _mode := PowerupLibrary.MODE_SELECT  # Powerup rules of the running search.


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(16)
	_card.add_child(box)

	var header := AppTheme.hbox(10)
	var swords := TextureRect.new()
	swords.texture = EmojiPicker.icon("swords")
	swords.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swords.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swords.custom_minimum_size = Vector2(36, 36)
	swords.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	header.add_child(swords)
	header.add_child(AppTheme.label("Ranked Match", "HeadingLabel"))
	box.add_child(header)
	_blurb = AppTheme.label("Face players of your own rank. Win to earn XP and climb; losses cost XP.", "MutedLabel")
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_blurb)

	var rank_row := AppTheme.card("Row")
	var rank_line := AppTheme.hbox(14)
	rank_row.add_child(rank_line)
	_insignia = RankInsignia.new(0, 72.0)
	rank_line.add_child(_insignia)
	var rank_info := AppTheme.vbox(2)
	rank_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_info.add_child(AppTheme.label("YOUR RANK", "MutedLabel", 14))
	_rank_name = AppTheme.label("Private", "", 28)
	_rank_name.add_theme_font_override("font", AppTheme.heading_font())
	rank_info.add_child(_rank_name)
	_xp = AppTheme.label("", "MutedLabel", 16)
	rank_info.add_child(_xp)
	rank_line.add_child(rank_info)
	var stakes := AppTheme.vbox(4)
	stakes.add_child(AppTheme.pill("WIN +60 XP", AppTheme.MINT, Color.WHITE, 15))
	stakes.add_child(AppTheme.pill("LOSS -25 XP", AppTheme.RED, Color.WHITE, 15))
	stakes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_line.add_child(stakes)
	box.add_child(rank_row)

	_idle_box = AppTheme.vbox(10)
	_find = AppTheme.button("Find Ranked Match", "Primary", _start_search, 66)
	_idle_box.add_child(_find)
	box.add_child(_idle_box)

	_search_box = AppTheme.vbox(10)
	_search_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_radar = Radar.new()
	_radar.custom_minimum_size = Vector2(170, 170)
	_radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_search_box.add_child(_radar)
	_headline = AppTheme.label("Searching...", "", 24)
	_headline.add_theme_font_override("font", AppTheme.heading_font())
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_search_box.add_child(_headline)
	_clock = AppTheme.label("0:00", "MutedLabel", 20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_box.add_child(_clock)
	var window_row := AppTheme.hbox()
	window_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_window = AppTheme.pill("MATCHING YOUR RANK", AppTheme.BLUE, Color.WHITE, 15)
	window_row.add_child(_window)
	_search_box.add_child(window_row)
	_search_box.add_child(AppTheme.button("Cancel", "Ghost", _cancel_search, 50))
	_search_box.visible = false
	box.add_child(_search_box)

	_back_button = AppTheme.button("Back", "Ghost", _go_back, 48)
	box.add_child(_back_button)
	add_child(_page(_card, 560))

	_poll = Timer.new()
	_poll.wait_time = POLL_SECONDS
	_poll.timeout.connect(_poll_status)
	add_child(_poll)
	set_process(false)
	Social.ranked_matched.connect(_on_ranked_matched)
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: _show_rank())


func open(_args: Dictionary) -> void:
	if not ApiManager.is_logged_in():
		ui.show_screen("auth", {"next": "ranked"})
		return
	_opening = false
	_set_searching(false)
	_show_rank()
	AppTheme.pop_in(_card)
	ApiManager.fetch_user()
	Social.connect_realtime()
	# Resume a search that is still running on the server (e.g. after a page reload).
	var res: Dictionary = await Social.ranked_status()
	if not visible or not res.ok:
		return
	match str(res.data.get("status", "idle")):
		"queued":
			_waited = float(res.data.get("waited_seconds", 0))
			_mode = str(res.data.get("powerup_mode", _mode))
			_set_searching(true)
		"matched":
			_open_found(res)


func close() -> void:
	if _searching and not _opening:
		Social.cancel_ranked()
	_set_searching(false)


func _show_rank() -> void:
	var tier: Variant = ApiManager.user.get("rank_tier", 0)
	_insignia.set_tier(tier)
	_rank_name.text = PlayerRanks.name_of(tier)
	var xp: Variant = ApiManager.user.get("xp")
	_xp.text = ("%s XP" % AppTheme.num(xp)) if xp != null else "Ranked games earn XP"


func _start_search() -> void:
	GameOptions.ask(ui, {
		"title": "Ranked Match",
		"subtitle": "You'll face someone of your rank who picked the same powerup rules.",
		"confirm": "Find ranked match",
	}, _queue)


func _queue(mode: String) -> void:
	_mode = mode
	_find.disabled = true
	var res: Dictionary = await Social.queue_ranked(mode)
	_find.disabled = false
	if not res.ok:
		if res.status == 401:
			ui.show_screen("auth", {"next": "ranked"})
		elif res.status == 409 and int(res.data.get("match_id", 0)) > 0:
			ui.confirm("Finish your current match first. Jump back into it?", "Resume", _resume.bind(int(res.data["match_id"])), false)
		else:
			ui.toast(res.error, AppTheme.RED)
		return
	if str(res.data.get("status", "")) == "matched":
		_open_found(res)
		return
	_waited = float(res.data.get("waited_seconds", 0))
	_set_searching(true)


func _resume(id: int) -> void:
	var res: Dictionary = await GameSession.open_match(id)
	if not res.ok:
		ui.toast(res.error, AppTheme.RED)


func _cancel_search() -> void:
	_set_searching(false)
	await Social.cancel_ranked()
	ui.toast("Search cancelled.")


func _set_searching(on: bool) -> void:
	_searching = on
	_idle_box.visible = not on
	_search_box.visible = on
	_blurb.visible = not on
	_back_button.visible = not on
	_radar.set_process(on)
	set_process(on)
	if on:
		_poll.start()
		_update_search_text()
		AppTheme.pop_in(_search_box)
	else:
		_poll.stop()


func _process(delta: float) -> void:
	_waited += delta
	_update_search_text()


func _update_search_text() -> void:
	var tier := PlayerRanks.clamp_tier(ApiManager.user.get("rank_tier", 0))
	var seconds := int(_waited)
	_clock.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if _waited < WIDEN_ONE:
		_headline.text = "Looking for %s opponents..." % PlayerRanks.name_of(tier)
		AppTheme.set_pill(_window, "MATCHING %s ONLY" % PlayerRanks.short_of(tier), AppTheme.BLUE)
	elif _waited < WIDEN_TWO:
		_headline.text = "Widening the search..."
		AppTheme.set_pill(_window, "NOW MATCHING %s TO %s" % [PlayerRanks.short_of(tier - 1), PlayerRanks.short_of(tier + 1)], AppTheme.PURPLE)
	else:
		_headline.text = "Widening the search further..."
		AppTheme.set_pill(_window, "NOW MATCHING %s TO %s" % [PlayerRanks.short_of(tier - 2), PlayerRanks.short_of(tier + 2)], AppTheme.PINK)
	_headline.text += "\n" + {"off": "No powerups", "random": "Random powerups"}.get(_mode, "Pick-5 powerups")


func _poll_status() -> void:
	if not _searching:
		return
	var res: Dictionary = await Social.ranked_status()
	if not _searching or not res.ok:
		return
	match str(res.data.get("status", "")):
		"matched":
			_open_found(res)
		"queued":
			_waited = maxf(_waited, float(res.data.get("waited_seconds", _waited)))
		"idle":
			# The server dropped us (e.g. a long stall): quietly queue again.
			Social.queue_ranked(_mode)


func _on_ranked_matched(match_id: int) -> void:
	if not _searching or _opening or match_id <= 0:
		return
	_opening = true
	_headline.text = "Opponent found!"
	var res: Dictionary = await GameSession.open_match(match_id)
	_after_open(res)


func _open_found(res: Dictionary) -> void:
	if _opening:
		return
	_opening = true
	_headline.text = "Opponent found!"
	var found: Variant = res.data.get("match")
	var opened: Dictionary
	if found is Dictionary and not found.is_empty():
		opened = await Social.adopt_match(res)
	else:
		opened = await GameSession.open_match(int(res.data.get("match_id", 0)))
	_after_open(opened)


func _after_open(res: Dictionary) -> void:
	if res.ok:
		_searching = false  # The HUD takes over; nothing to cancel.
		return
	_opening = false
	ui.toast(res.error if res.error != "" else "Couldn't open the match.", AppTheme.RED)


## The card centred on screen; it scrolls when taller than the screen (phones, short windows).
func _page(card: Control, max_width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_child(card)
	center.add_child(margin)
	scroll.add_child(center)
	var fit := func() -> void: card.custom_minimum_size.x = minf(max_width, get_viewport_rect().size.x - 32.0)
	resized.connect(fit)
	fit.call_deferred()
	return scroll


func _go_back() -> void:
	ui.home()


## Spinning radar sweep with pulsing rings and blips, drawn in code.
class Radar:
	extends Control

	var _t := 0.0
	var _blips: Array = []

	func _process(delta: float) -> void:
		_t += delta
		if randf() < delta * 1.4:
			_blips.append({"pos": Vector2.from_angle(randf() * TAU) * randf_range(0.25, 0.85), "life": 1.4})
		for blip in _blips:
			blip["life"] -= delta
		_blips = _blips.filter(func(b: Dictionary) -> bool: return b["life"] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(center, radius + 4.0, AppTheme.INK)
		draw_circle(center, radius, Color("1f3b2f"))
		for i in 3:
			draw_arc(center, radius * (i + 1) / 3.0, 0.0, TAU, 64, Color(AppTheme.MINT, 0.35), 2.0, true)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(AppTheme.MINT, 0.25), 1.5)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(AppTheme.MINT, 0.25), 1.5)
		var pulse := fmod(_t * 0.6, 1.0)
		draw_arc(center, radius * pulse, 0.0, TAU, 64, Color(AppTheme.MINT, 0.6 * (1.0 - pulse)), 3.0, true)
		var angle := _t * 2.4
		var steps := 24
		for i in steps:
			var a0 := angle - 1.1 * i / steps
			var a1 := angle - 1.1 * (i + 1) / steps
			var alpha := 0.45 * (1.0 - float(i) / steps)
			draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a0) * radius, center + Vector2.from_angle(a1) * radius]),
				Color(AppTheme.MINT, alpha))
		draw_line(center, center + Vector2.from_angle(angle) * radius, AppTheme.MINT, 3.0, true)
		for blip in _blips:
			var fade: float = clampf(blip["life"] / 1.4, 0.0, 1.0)
			draw_circle(center + blip["pos"] * radius, 6.0, Color(AppTheme.YELLOW, fade))
		draw_circle(center, 7.0, AppTheme.MINT)
