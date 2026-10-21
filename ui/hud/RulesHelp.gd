extends HBoxContainer
## The in-match "Rules" button (top bar): opens a card with the rank ladder and the special clash
## rules, closed again without leaving the match.

var _hud: Screen
var _button: Button


func _ready() -> void:
	_button = AppTheme.button("Rules", "Ghost", _open, 46)
	_button.tooltip_text = "Rank ladder and clash rules"
	add_child(_button)


func setup(hud: Screen) -> void:
	_hud = hud
	get_viewport().size_changed.connect(_layout)
	_layout()


## Portrait phones: just "?" so the player chips keep their room.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var narrow := view.x < view.y or view.x < 760.0
	_button.text = "?" if narrow else "Rules"
	_button.custom_minimum_size.x = 46.0 if narrow else 0.0
	_button.add_theme_font_size_override("font_size", 22 if narrow else 24)


func _open() -> void:
	if _hud == null:
		return
	var view := get_viewport().get_visible_rect().size
	var wide := view.x >= 900.0 and view.x > view.y
	var card := AppTheme.card()
	var box := AppTheme.vbox(14)
	card.add_child(box)
	var head := AppTheme.hbox(10)
	var title := AppTheme.label("Rules", "HeadingLabel", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(AppTheme.button("Close", "Ghost", _hud.ui.close_dialog, 44))
	box.add_child(head)
	var strongest := AppTheme.label("Strongest first", "", 14, AppTheme.PURPLE)
	strongest.add_theme_font_override("font", AppTheme.heading_font())
	box.add_child(strongest)
	box.add_child(RulesSheet.ladder(2 if wide else 1, 36.0))
	box.add_child(RulesSheet.rules(15))
	ProfileUi.overlay(_hud.ui, card, 760.0 if wide else 460.0)
