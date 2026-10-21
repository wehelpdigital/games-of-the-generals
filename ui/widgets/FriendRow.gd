class_name FriendRow
extends PanelContainer
## One player in the friends lists: photo (ringed green when online, yellow in a match), name with
## rank insignia, a sub line (status, "last seen", rank) and action buttons at the end (under the
## name on phones). Tapping the photo or name opens their player card.

const ONLINE := AppTheme.MINT
const IN_MATCH := AppTheme.GOLD

var user: Dictionary


## `entry`: a PlayerCard, optionally with `status` / `last_seen_at` (friends list). `sub` replaces
## the status line when given.
func _init(entry: Dictionary, sub := "", actions: Array = [], on_tap := Callable()) -> void:
	user = entry
	theme_type_variation = "RowPanel"
	var narrow := ProfileUi.narrow
	var line := AppTheme.hbox(8 if narrow else 12)
	add_child(line)
	var avatar := AvatarView.new(40 if narrow else 48)
	avatar.set_user(entry)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var status := str(entry.get("status", ""))
	if status == "online":
		avatar.ring_color = ONLINE
	elif status == "in_match":
		avatar.ring_color = IN_MATCH
	line.add_child(avatar)

	var names := AppTheme.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_row := AppTheme.hbox(6)
	if entry.get("rank_tier") != null:
		var insignia := RankInsignia.new(entry["rank_tier"], 20 if narrow else 22)
		insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(insignia)
	var name_label := AppTheme.label(str(entry.get("username", "?")), "", 18 if narrow else 20)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	names.add_child(title_row)
	var sub_text := sub if sub != "" else status_text(entry)
	if sub_text != "":
		var sub_label := AppTheme.label(sub_text, "MutedLabel", 14 if narrow else 15)
		if sub == "" and status in ["online", "in_match"]:
			sub_label.add_theme_color_override("font_color", ONLINE.darkened(0.25) if status == "online" else IN_MATCH.darkened(0.3))
		sub_label.clip_text = true
		sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		names.add_child(sub_label)
	line.add_child(names)

	if on_tap.is_valid():
		for target: Control in [avatar, names]:
			target.mouse_filter = Control.MOUSE_FILTER_STOP
			target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			target.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					on_tap.call())

	if actions.is_empty():
		return
	var buttons := AppTheme.hbox(6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for action: Control in actions:
		buttons.add_child(action)
	if narrow and actions.size() > 1:
		buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		names.add_child(buttons)  # Phones: two buttons go under the name, not beside it.
	else:
		line.add_child(buttons)


## "Online", "In a match", "Last seen 3 h ago"; "" when there's no status.
static func status_text(entry: Dictionary) -> String:
	match str(entry.get("status", "")):
		"online":
			return "Online"
		"in_match":
			return "In a match"
		"offline":
			var seen := str(entry.get("last_seen_at", "")) if entry.get("last_seen_at") != null else ""
			return "Last seen %s" % ago(seen) if seen != "" else "Offline"
	return PlayerRanks.name_of(entry["rank_tier"]) if entry.get("rank_tier") != null else ""


## "just now", "5 min ago", "3 h ago", "2 days ago", "a while ago".
static func ago(iso: String) -> String:
	var at := GameSession.parse_time(iso)
	if at <= 0.0:
		return "a while ago"
	var minutes := int((Time.get_unix_time_from_system() - at) / 60.0)
	if minutes < 1:
		return "just now"
	if minutes < 60:
		return "%d min ago" % minutes
	if minutes < 60 * 24:
		return "%d h ago" % (minutes / 60)
	var days := minutes / (60 * 24)
	if days < 30:
		return "%d day%s ago" % [days, "" if days == 1 else "s"]
	return "a while ago"


## A compact button for row actions.
static func action(text: String, kind: String, on_press: Callable) -> Button:
	var b := ProfileUi.small_button(text, kind, on_press, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b
