class_name ShareSheet
extends PanelContainer
## "Share & earn XP" dialog: the brag line, one button per app, and the device's share sheet when
## the browser has one. Sharing counts toward rank tasks and earns a daily XP bonus.
##
##     ShareSheet.open(ui)

var ui: UIRoot
var _busy := false


static func open(root: UIRoot) -> void:
	var sheet := ShareSheet.new()
	sheet.ui = root
	ProfileUi.overlay(root, sheet, 460)


func _init() -> void:
	theme_type_variation = "CardPanel"


func _ready() -> void:
	var box := AppTheme.vbox(12)
	add_child(box)
	var head := AppTheme.hbox(10)
	head.add_child(TileIcon.new("share", Vector2(40, 40)))
	head.add_child(ProfileUi.heading("Share & earn XP", 30))
	box.add_child(head)
	box.add_child(ProfileUi.wrap("Bring your friends to the battlefield. Sharing counts for rank tasks and gives bonus XP once a day.", 17, AppTheme.MUTED))
	var quote := AppTheme.card("Row")
	quote.add_child(ProfileUi.wrap(Share.message(Profile.data), 18))
	box.add_child(quote)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for entry: Dictionary in Share.PLATFORMS:
		var color: Color = entry["color"]
		var fg := AppTheme.INK if color.get_luminance() > 0.6 else Color.WHITE
		var b := ProfileUi.colored_button(entry["label"], color, fg, _share.bind(str(entry["key"])), 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	if Share.can_web_share():
		var more := AppTheme.button("More apps...", "Ghost", _share.bind("other"), 52)
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(more)
	box.add_child(grid)
	box.add_child(AppTheme.button("Close", "Ghost", func() -> void: ui.close_dialog(), 48))


func _share(platform: String) -> void:
	if _busy:
		return
	_busy = true
	var text := Share.message(Profile.data)
	var shared := true
	if platform == "other":
		shared = await _web_share(text)
	else:
		shared = Share.send(platform, text)
		if platform == "copy_link":
			ui.toast("Link copied! Paste it anywhere.", AppTheme.MINT)
	if not shared:
		_busy = false
		return
	ui.close_dialog()
	if not ApiManager.is_logged_in():
		return
	var res := await Profile.record_share(platform)
	if not res.ok:
		return
	var xp := int(res.data.get("xp_awarded", 0))
	ui.toast("+%d XP for sharing!" % xp if xp > 0 else "Thanks for sharing!", AppTheme.MINT if xp > 0 else AppTheme.INK)


func _web_share(text: String) -> bool:
	var result := [false, false]  # [finished, shared]
	Share.web_share(text, func(ok: bool) -> void:
		result[0] = true
		result[1] = ok)
	while not result[0] and is_inside_tree():
		await get_tree().process_frame
	return bool(result[1])
