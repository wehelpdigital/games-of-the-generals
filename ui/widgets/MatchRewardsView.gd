class_name MatchRewardsView
extends PanelContainer
## The rewards strip on the game-over card: credits (with the breakdown), XP, missions that moved
## and achievements unlocked. Waits for Economy.match_rewards for the game that just ended.

const LABELS := {"win": "Win", "loss": "Played", "ranked_bonus": "Ranked", "first_win": "First win today", "practice_win": "AI win"}

var _seq := 0
var _box: VBoxContainer


func _init() -> void:
	var style := ProfileUi.box(Color("fff4d6"), 18, 3)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_box = AppTheme.vbox(6)
	add_child(_box)


func _ready() -> void:
	_seq = Economy.game_seq
	if not ApiManager.is_logged_in():
		_note("Log in to earn credits, XP and mission progress!")
		return
	if int(Economy.last_rewards.get("seq", -1)) == _seq:
		show_summary(Economy.last_rewards)
		return
	_note("Counting your rewards...")
	Economy.match_rewards.connect(_on_rewards)


func _on_rewards(summary: Dictionary) -> void:
	if int(summary.get("seq", -1)) == _seq and is_inside_tree():
		show_summary(summary)


func show_summary(summary: Dictionary) -> void:
	ProfileUi.clear(_box)
	if summary.get("failed", false):
		_note("Your rewards will show up on the dashboard.")
		return
	if summary.get("kind") == "practice" and not summary.get("counted", true):
		_note("Practice rewards are done for today. Missions still count tomorrow!")
		return
	var top := AppTheme.hbox(10)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	var credits := int(summary.get("credits", 0))
	top.add_child(CoinIcon.new(30))
	var amount := AppTheme.label("+%s" % ProfileUi.grouped(credits), "", 28)
	amount.add_theme_font_override("font", AppTheme.heading_font())
	amount.add_theme_color_override("font_color", AppTheme.INK)
	top.add_child(amount)
	if int(summary.get("xp", 0)) != 0:
		var xp := int(summary["xp"])
		top.add_child(EconomyUi.chip("%+d XP" % xp, AppTheme.PINK if xp > 0 else AppTheme.MUTED, Color.WHITE, 16))
	_box.add_child(top)
	var parts: Array[String] = []
	var breakdown: Variant = summary.get("breakdown", {})
	if breakdown is Dictionary:
		for key: String in breakdown:
			parts.append("%s +%s" % [LABELS.get(key, key.capitalize()), ProfileUi.grouped(breakdown[key])])
	if summary.get("capped", false):
		parts.append("daily cap reached")
	if not parts.is_empty():
		var line := AppTheme.label("  -  ".join(parts), "MutedLabel", 14)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(line)
	var shown := 0
	for mission: Dictionary in summary.get("missions", []):
		if shown >= 3:
			break
		_box.add_child(_mission_line(mission))
		shown += 1
	var unlocked: Array = summary.get("achievements", [])
	if not unlocked.is_empty():
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 6)
		for achievement: Dictionary in unlocked:
			flow.add_child(EconomyUi.chip("Unlocked: " + str(achievement.get("name", "")), AppTheme.PURPLE, Color.WHITE, 14))
		_box.add_child(flow)
	AppTheme.pop_in(self)
	if credits > 0 and get_parent():
		Sfx.play(self, "coins")


func _mission_line(mission: Dictionary) -> HBoxContainer:
	var row := AppTheme.hbox(8)
	row.add_child(EconomyUi.emoji(str(mission.get("icon", "2b50")), 22))
	var done: bool = mission.get("completed", false)
	var title := AppTheme.label(str(mission.get("title", "")), "", 15)
	title.add_theme_font_override("font", AppTheme.heading_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	row.add_child(title)
	var target := maxi(1, int(mission.get("target", 1)))
	var status := "Complete! Claim it" if done else "%d / %d" % [mini(target, int(mission.get("progress", 0))), target]
	row.add_child(EconomyUi.chip(status, AppTheme.MINT if done else AppTheme.BLUE, Color.WHITE, 13))
	return row


func _note(text: String) -> void:
	ProfileUi.clear(_box)
	var label := ProfileUi.wrap(text, 15, AppTheme.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label)
