class_name FeatureShowcase
extends PanelContainer
## Guest-only card on the title screen: cycles through what a free account unlocks and dresses
## the orbiting 3D board to match (chip shapes, arenas, toppers, effects...), with a sign-up
## button. The title screen hides it once the player is logged in.

signal sign_up

const SECONDS := 5.0
const SLIDES := [
	{"title": "Chip Shapes", "text": "Wish Orbs, dice, gems, poker chips and more: 15 shapes for your army.",
		"dress": ["shape", "chip"], "pic": ["shape", "shape_wish_orb"]},
	{"title": "Arenas", "text": "Battle in a lava pit, a neon city, a snowy summit and more.",
		"dress": ["arena", "board"], "pic": ["arena", "lava_pit"]},
	{"title": "Table Toppers", "text": "Plant your own flag (even with your photo), or a cactus, a rubber duck, a robot...",
		"dress": ["toppers"], "pic": ["topper", "topper_flag_gold"]},
	{"title": "Auras & Effects", "text": "Glows, move trails and knockout effects your rival can see.",
		"dress": ["aura", "glow", "trail", "kill"], "pic": ["kill", "kill_kraken"]},
	{"title": "Icon Packs", "text": "20 icon sets for your ranks: samurai, space, pirates and more.",
		"dress": ["icons", "territory"], "pic": ["icons", "knights"]},
	{"title": "Powerups", "text": "Spy Card, Smoke Screen, Freeze, Mine Field: 23 tricks to turn a battle.",
		"dress": []},
	{"title": "Ranks & Hometown Boards", "text": "Rise from Private to General of the Army and top your town's leaderboard.",
		"dress": []},
	{"title": "Guilds, Chat & Voice", "text": "Squad up in a guild, chat, throw taunts and talk live in voice chat.",
		"dress": []},
	{"title": "Daily Rewards", "text": "Login streaks, missions and achievements earn credits for the shop.",
		"dress": []},
]

## Called with (my_side_loadout, rival_loadout) whenever the board should change its look.
var dress: Callable

var _index := -1
var _look: Dictionary = {}
var _timer: Timer
var _body: VBoxContainer
var _title: Label
var _text: Label
var _dots: HBoxContainer
var _pic_box: Control  # Holds the slide's shop picture (ShopThumbs) when it has one.


func _ready() -> void:
	theme_type_variation = "CardPanel"  # Same look as AppTheme.card().
	mouse_filter = Control.MOUSE_FILTER_STOP
	_body = AppTheme.vbox(8)
	add_child(_body)
	var pill := AppTheme.pill("FREE WITH AN ACCOUNT", AppTheme.MINT, Color.WHITE, 15)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_body.add_child(pill)
	_pic_box = Control.new()
	_pic_box.custom_minimum_size = Vector2(0, 120)
	_pic_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_pic_box)
	_title = AppTheme.label("", "Heading", 26)
	_body.add_child(_title)
	_text = AppTheme.label("", "", 17, AppTheme.MUTED)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.y = 46
	_body.add_child(_text)
	var row := AppTheme.hbox(10)
	_dots = AppTheme.hbox(6)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in SLIDES.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		dot.gui_input.connect(_on_dot_input.bind(i))
		_dots.add_child(dot)
	row.add_child(_dots)
	row.add_child(AppTheme.button("Join free", "Primary", func() -> void: sign_up.emit(), 42))
	_body.add_child(row)
	_timer = Timer.new()
	_timer.wait_time = SECONDS
	_timer.timeout.connect(func() -> void: show_slide(_index + 1))
	add_child(_timer)


func start() -> void:
	if PerfProbe.flag("plain"):  # PERF-TEMP
		return
	_look = {}
	show_slide(0 if _index < 0 else _index)
	_timer.start()


func stop() -> void:
	_timer.stop()


func show_slide(index: int) -> void:
	PerfProbe.mark("slide %d" % index)  # PERF-TEMP
	_index = posmod(index, SLIDES.size())
	var slide: Dictionary = SLIDES[_index]
	_title.text = slide["title"]
	_text.text = slide["text"]
	_show_picture(slide.get("pic", []))
	for i in _dots.get_child_count():
		var style := StyleBoxFlat.new()
		style.bg_color = AppTheme.PINK if i == _index else Color(AppTheme.INK, 0.2)
		style.set_corner_radius_all(5)
		(_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", style)
	_body.modulate.a = 0.0
	create_tween().tween_property(_body, "modulate:a", 1.0, 0.25)
	_dress(slide)


## The slide's item picture (a baked still or looping clip from the shop), if it has one.
func _show_picture(pic: Array) -> void:
	for child in _pic_box.get_children():
		child.queue_free()
	var view: ThumbView = ThumbView.new(pic[0], pic[1], 120.0) if pic.size() == 2 else null
	_pic_box.visible = view != null and view.has_picture()
	if _pic_box.visible:
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pic_box.add_child(view)


func _dress(slide: Dictionary) -> void:
	if not dress.is_valid() or not Graphics.live_showcase():
		return  # Browsers and phones: swapping looks compiles shaders with the page frozen.
	var fresh := Loadout.random_loadout()
	var rival := {}
	if _look.is_empty():
		_look = fresh.duplicate(true)
		rival = Loadout.random_loadout()
	var keys: Array = slide["dress"]
	for key: String in keys:
		_look[key] = fresh[key]
	if "shape" in keys and _look["shape"] == Loadout.DEFAULTS["shape"]:
		_look["shape"] = "shape_wish_orb"  # Show off a real shape, not the classic tile.
	if keys.is_empty():
		rival = Loadout.random_loadout()  # Nothing to dress on my side: refresh the rival instead.
	dress.call(_look.duplicate(true), rival)


func _on_dot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_slide(index)
		_timer.start()
