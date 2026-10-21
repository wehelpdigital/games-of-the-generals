class_name SeasonOfferCard
extends PanelContainer
## Dashboard card for the running season's shop offer (ServerConfig "season"): its name, how long
## it lasts, a peek at a few of its items and a button into the shop's Seasonal shelf. Hidden when
## no season is live.

const PEEK := 4  # Item pictures shown on the card.

var _ui: UIRoot
var _title: Label
var _left: Label
var _blurb: Label
var _peek: HBoxContainer
var _count: Label
var _button: Button


func _init() -> void:
	visible = false
	var box := AppTheme.vbox(10)
	add_child(box)
	var head := AppTheme.hbox(8)
	head.add_child(ProfileUi.eyebrow("Season offer", AppTheme.PINK))
	head.add_child(AppTheme.spacer())
	_left = AppTheme.label("", "MutedLabel", 14)
	head.add_child(_left)
	box.add_child(head)
	_title = AppTheme.label("", "HeadingLabel", 26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_blurb = ProfileUi.wrap("", 15, AppTheme.MUTED)
	box.add_child(_blurb)
	_peek = AppTheme.hbox(8)
	box.add_child(_peek)
	var foot := AppTheme.hbox(10)
	_count = AppTheme.label("", "MutedLabel", 15)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_count)
	_button = ProfileUi.colored_button("Shop the collection", AppTheme.PINK, Color.WHITE, _open_shop, 46)
	_button.add_theme_font_size_override("font_size", 17)
	foot.add_child(_button)
	box.add_child(foot)


func setup(ui_root: UIRoot) -> void:
	_ui = ui_root


func set_colors(theme: Dictionary) -> void:
	add_theme_stylebox_override("panel", DashboardThemes.card_style(theme))
	var accent: Color = theme["accent"]
	_button.add_theme_stylebox_override("normal", ProfileUi.candy(accent, false))
	_button.add_theme_stylebox_override("hover", ProfileUi.candy(accent.lightened(0.12), false))
	_button.add_theme_stylebox_override("pressed", ProfileUi.candy(accent.darkened(0.06), true))


func refresh() -> void:
	var season: Variant = ServerConfig.get_value("season")
	var slug := str(season.get("slug", "")) if season is Dictionary else ""
	visible = slug != "" and ApiManager.is_logged_in()
	if not visible:
		return
	_title.text = str(season.get("name", "Season"))
	var about: Variant = season.get("description")
	_blurb.text = str(about) if about != null else ""
	_blurb.visible = _blurb.text != ""
	var left := EconomyUi.time_left(str(season.get("ends_at", "")) if season.get("ends_at") != null else "")
	_left.text = "%s left" % left if left != "" else ""
	var items := _season_items(slug)
	_count.text = "%d items" % items.size() if not items.is_empty() else ""
	ProfileUi.clear(_peek)
	for item: Array in items.slice(0, PEEK):
		# ThumbView: shop pictures come from the website, loading (with a shimmer) once on screen.
		var picture := ThumbView.new(item[0], item[1], 64.0)
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picture.tooltip_text = str(CosmeticCatalog.info(item[0], item[1]).get("name", item[1]))
		_peek.add_child(picture)
	_peek.visible = _peek.get_child_count() > 0


## [category, slug] of every cosmetic tagged with this season, in catalogue order.
func _season_items(slug: String) -> Array:
	var found := []
	for category: Dictionary in CosmeticCatalog.CATEGORIES:
		var key := str(category["key"])
		for item_slug: String in CosmeticCatalog.slugs(key):
			if CosmeticCatalog.season_of(key, item_slug) == slug:
				found.append([key, item_slug])
	return found


func _open_shop() -> void:
	if _ui:
		_ui.show_screen("shop", {"category": "seasonal"})
