class_name LocationPicker
extends PanelContainer
## Hometown wizard for the local leaderboards: country (Philippines first), then region, province
## and city/municipality from /api/locations, each with a search box. Players abroad type their
## city. Saving calls Profile.set_location.
##
##     LocationPicker.open(ui, func() -> void: refresh())

const COUNTRIES := [
	["PH", "Philippines"], ["US", "United States"], ["CA", "Canada"], ["AE", "United Arab Emirates"],
	["SA", "Saudi Arabia"], ["QA", "Qatar"], ["KW", "Kuwait"], ["OM", "Oman"], ["BH", "Bahrain"],
	["SG", "Singapore"], ["MY", "Malaysia"], ["HK", "Hong Kong"], ["JP", "Japan"], ["KR", "South Korea"],
	["TW", "Taiwan"], ["CN", "China"], ["ID", "Indonesia"], ["TH", "Thailand"], ["VN", "Vietnam"],
	["IN", "India"], ["AU", "Australia"], ["NZ", "New Zealand"], ["GB", "United Kingdom"], ["IE", "Ireland"],
	["DE", "Germany"], ["IT", "Italy"], ["ES", "Spain"], ["FR", "France"], ["NL", "Netherlands"],
	["NO", "Norway"], ["SE", "Sweden"], ["CH", "Switzerland"], ["IL", "Israel"], ["BR", "Brazil"], ["MX", "Mexico"],
]
const PROMPTS := {
	"country": "Where are you from?",
	"region": "Pick your region",
	"province": "Pick your province",
	"city": "Pick your city or municipality",
	"abroad": "Type your city",
}
const LIST_LIMIT := 150

var ui: UIRoot
var on_saved := Callable()

var _step := "country"
var _picked := {}  # level -> {code, name}
var _options: Array = []
var _crumbs: HFlowContainer
var _prompt: Label
var _search: LineEdit
var _list: VBoxContainer
var _city_field: LineEdit
var _error: Label
var _save: Button
var _request := 0


static func open(root: UIRoot, saved := Callable()) -> void:
	var picker := LocationPicker.new()
	picker.ui = root
	picker.on_saved = saved
	ProfileUi.overlay(root, picker, 520)


func _init() -> void:
	theme_type_variation = "CardPanel"


func _ready() -> void:
	var box := AppTheme.vbox(10)
	add_child(box)
	var head := AppTheme.hbox(10)
	head.add_child(TileIcon.new("pin", Vector2(38, 38)))
	head.add_child(ProfileUi.heading("Your hometown", 30))
	box.add_child(head)
	box.add_child(ProfileUi.wrap("Climb the local leaderboards: top of your town, your province and beyond.", 16, AppTheme.MUTED))
	_crumbs = HFlowContainer.new()
	_crumbs.add_theme_constant_override("h_separation", 6)
	_crumbs.add_theme_constant_override("v_separation", 6)
	box.add_child(_crumbs)
	_prompt = AppTheme.label("", "", 20)
	_prompt.add_theme_font_override("font", AppTheme.heading_font())
	box.add_child(_prompt)
	_search = AppTheme.field("Search...")
	_search.text_changed.connect(func(_text: String) -> void: _render_list())
	box.add_child(_search)
	_city_field = AppTheme.field("City or town")
	_city_field.text_changed.connect(func(_text: String) -> void: _update_save())
	box.add_child(_city_field)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 230
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = AppTheme.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)

	_error = AppTheme.label("", "", 16, AppTheme.RED)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	box.add_child(_error)
	var footer := AppTheme.hbox(10)
	var cancel := AppTheme.button("Cancel", "Ghost", func() -> void: ui.close_dialog(), 50)
	_save = AppTheme.button("Save", "Success", _on_save, 50)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cancel)
	footer.add_child(_save)
	box.add_child(footer)

	# Start from the current hometown when there is one.
	var country := Profile.place("country")
	_picked["country"] = country if not country.is_empty() else Profile.DEFAULT_COUNTRY
	if str(_picked["country"].get("code", "PH")) != "PH":
		var city := Profile.place("city")
		_city_field.text = str(city.get("name", ""))
		_go("abroad")
	else:
		_go("region")


func _go(step: String) -> void:
	_step = step
	_error.visible = false
	_search.text = ""
	_prompt.text = PROMPTS[step]
	_search.visible = step != "abroad"
	_city_field.visible = step == "abroad"
	_render_crumbs()
	_options = []
	_update_save()
	if step == "abroad":
		ProfileUi.clear(_list)
		_list.add_child(ProfileUi.note("Local boards outside the Philippines group players by country and city."))
		return
	ProfileUi.clear(_list)
	_list.add_child(ProfileUi.note("Loading..."))
	_request += 1
	var ticket := _request
	var parent := ""
	match step:
		"province":
			parent = str(_picked["region"]["code"])
		"city":
			parent = str(_picked["province"]["code"]) if _picked.has("province") else str(_picked["region"]["code"])
	var options := await Profile.locations(step, parent)
	if ticket != _request or not is_inside_tree():
		return
	if options.is_empty() and step == "country":
		for entry: Array in COUNTRIES:  # Offline, or an older server without the country list.
			options.append({"code": entry[0], "name": entry[1]})
	if options.is_empty() and step == "province":
		# Metro Manila has no provinces: its cities sit right under the region.
		_go("city")
		return
	_options = options
	if options.is_empty():
		ProfileUi.clear(_list)
		_list.add_child(ProfileUi.note("Couldn't load places. Check your connection and try again."))
		return
	_render_list()


func _render_crumbs() -> void:
	ProfileUi.clear(_crumbs)
	for level: String in ["country", "region", "province", "city"]:
		if not _picked.has(level):
			continue
		var chip := ProfileUi.small_button(str(_picked[level]["name"]), "Secondary" if level == _step else "Ghost",
			_back_to.bind(level), 38)
		_crumbs.add_child(chip)


func _back_to(level: String) -> void:
	# Re-pick this level: keep it highlighted, forget everything below it.
	var order := ["country", "region", "province", "city"]
	for i in range(order.find(level) + 1, order.size()):
		_picked.erase(order[i])
	_go(level)


func _render_list() -> void:
	ProfileUi.clear(_list)
	var query := _search.text.strip_edges().to_lower()
	var shown := 0
	for option: Variant in _options:
		if not option is Dictionary:
			continue
		var label := str(option.get("name", ""))
		if query != "" and not label.to_lower().contains(query):
			continue
		var b := AppTheme.button(label, "Ghost", _pick.bind(option), 46)
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var chosen: Dictionary = _picked.get(_step, {})
		if chosen.get("code") == option.get("code"):
			b.theme_type_variation = "AccentButton"
		_list.add_child(b)
		shown += 1
		if shown >= LIST_LIMIT:
			_list.add_child(ProfileUi.note("Keep typing to narrow the list...", 15))
			break
	if shown == 0:
		_list.add_child(ProfileUi.note("No match for \"%s\"." % _search.text))


func _pick(option: Dictionary) -> void:
	_picked[_step] = {"code": option.get("code"), "name": option.get("name")}
	match _step:
		"country":
			for level: String in ["region", "province", "city"]:
				_picked.erase(level)
			_go("region" if str(option.get("code")) == "PH" else "abroad")
		"region":
			_picked.erase("province")
			_picked.erase("city")
			_go("province")
		"province":
			_picked.erase("city")
			_go("city")
		"city":
			_render_crumbs()
			_render_list()
			_update_save()


func _update_save() -> void:
	if _step == "abroad":
		_save.disabled = _city_field.text.strip_edges().length() < 2
	else:
		_save.disabled = not _picked.has("city")


func _on_save() -> void:
	var body := {"country": str(_picked["country"]["code"])}
	if _step == "abroad":
		body.merge({"region": null, "province": null, "city": _city_field.text.strip_edges()})
	else:
		body["region"] = _picked["region"]["code"]
		body["province"] = _picked["province"]["code"] if _picked.has("province") else null
		body["city"] = _picked["city"]["code"]
	_save.disabled = true
	var res := await Profile.set_location(body)
	if not is_inside_tree():
		return
	if not res.ok:
		_error.text = res.error
		_error.visible = true
		_save.disabled = false
		return
	ui.close_dialog()
	ui.toast("Hometown saved! You're on the local boards now.", AppTheme.MINT)
	if on_saved.is_valid():
		on_saved.call()
