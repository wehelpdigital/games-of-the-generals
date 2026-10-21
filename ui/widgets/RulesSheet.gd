class_name RulesSheet
extends RefCounted
## The rules at a glance, shared by the How to Play page and the in-match Rules card: the rank
## ladder with each piece's insignia, and the special clash rules.

const LADDER_NOTES := {
	"G5": "The top rank", "SPY": "Beats every rank except the Private", "PVT": "Weakest, but catches the Spy",
	"FLG": "Lose it and you lose the battle",
}
const RULES := [
	["Higher rank wins", "The loser leaves the board. Equal ranks both leave."],
	["The Spy", "Beats every rank, even the 5-star General, except the Private."],
	["The Private", "Beats the Spy, whichever of them attacks."],
	["The Flag", "Any piece captures it, even the other Flag. Lose yours and the battle is over."],
	["Winning", "Capture the enemy Flag, or move your Flag onto the enemy's back row. If an enemy stands right beside it there, it must survive one more turn."],
	["Fog of war", "You never see enemy ranks. A clash shows only who won."],
]


## The 15 ranks strongest first: insignia, name, how many each side has, a short note. Two
## columns when `columns` is 2.
static func ladder(columns := 1, icon_size := 40.0) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for rank: String in Ranks.INFO:
		grid.add_child(_rank_row(rank, icon_size))
	return grid


static func _rank_row(rank: String, icon_size: float) -> Control:
	var row := AppTheme.hbox(10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	icon.texture = PieceIcons.icon_texture(rank)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count := int(Ranks.INFO[rank]["count"])
	var title := Ranks.display_name(rank) + ("  x%d" % count if count > 1 else "")
	var name_label := AppTheme.label(title, "", 17)
	name_label.add_theme_font_override("font", AppTheme.heading_font())
	words.add_child(name_label)
	if LADDER_NOTES.has(rank):
		words.add_child(AppTheme.label(LADDER_NOTES[rank], "", 14, AppTheme.MUTED))
	row.add_child(words)
	return row


## The special rules as headed lines.
static func rules(size := 16) -> VBoxContainer:
	var box := AppTheme.vbox(8)
	for entry: Array in RULES:
		var line := AppTheme.vbox(0)
		var head := AppTheme.label(entry[0], "", size + 1)
		head.add_theme_font_override("font", AppTheme.heading_font())
		line.add_child(head)
		var body := AppTheme.label(entry[1], "", size, AppTheme.MUTED)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(body)
		box.add_child(line)
	return box
