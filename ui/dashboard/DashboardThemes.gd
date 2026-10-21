class_name DashboardThemes
extends RefCounted
## Dashboard looks the admin picks (settings → dashboard_theme, or a season's theme): a tint over
## the 3D board, accent colours, card paper and the ambient decoration (DashboardAmbient style).

const THEMES := {
	"classic": {
		"label": "Classic", "deco": "confetti",
		"tint_top": Color("fff8ec"), "tint_top_a": 0.0, "tint_bottom": Color("fff8ec"), "tint_bottom_a": 0.7,
		"accent": Color("ff4f8b"), "accent2": Color("3d8bff"), "card": Color("fff8ec"),
	},
	"night_ops": {
		"label": "Night Ops", "deco": "fireflies",
		"tint_top": Color("06140f"), "tint_top_a": 0.78, "tint_bottom": Color("0d2a1d"), "tint_bottom_a": 0.6,
		"accent": Color("2fbf71"), "accent2": Color("a3ff7a"), "card": Color("eef6f0"),
	},
	"sakura": {
		"label": "Sakura", "deco": "petals",
		"tint_top": Color("ffc4dc"), "tint_top_a": 0.4, "tint_bottom": Color("fff0f6"), "tint_bottom_a": 0.72,
		"accent": Color("ff5f9e"), "accent2": Color("b86bf0"), "card": Color("fff4f8"),
	},
	"neon_city": {
		"label": "Neon City", "deco": "neon",
		"tint_top": Color("0c0626"), "tint_top_a": 0.8, "tint_bottom": Color("2a0b4a"), "tint_bottom_a": 0.66,
		"accent": Color("ff2fb9"), "accent2": Color("12d8f0"), "card": Color("f5f0ff"),
	},
	"jungle": {
		"label": "Jungle", "deco": "leaves",
		"tint_top": Color("0c3a20"), "tint_top_a": 0.5, "tint_bottom": Color("1f5c34"), "tint_bottom_a": 0.6,
		"accent": Color("1fae6d"), "accent2": Color("ffbe2e"), "card": Color("f3fbef"),
	},
	"winter": {
		"label": "Winter", "deco": "snow",
		"tint_top": Color("b9e4ff"), "tint_top_a": 0.42, "tint_bottom": Color("ffffff"), "tint_bottom_a": 0.72,
		"accent": Color("3d8bff"), "accent2": Color("38c6f4"), "card": Color("f5fbff"),
	},
	"halloween": {
		"label": "Halloween", "deco": "bats",
		"tint_top": Color("170b2b"), "tint_top_a": 0.8, "tint_bottom": Color("3d1a05"), "tint_bottom_a": 0.62,
		"accent": Color("ff7a12"), "accent2": Color("8b5cf6"), "card": Color("fff3e6"),
	},
	"christmas": {
		"label": "Christmas", "deco": "lights",
		"tint_top": Color("0b3320"), "tint_top_a": 0.6, "tint_bottom": Color("5a0c15"), "tint_bottom_a": 0.55,
		"accent": Color("e63946"), "accent2": Color("23a05a"), "card": Color("fffaf0"),
	},
	"summer": {
		"label": "Summer", "deco": "sun",
		"tint_top": Color("ffd77a"), "tint_top_a": 0.34, "tint_bottom": Color("ff9f5a"), "tint_bottom_a": 0.5,
		"accent": Color("ff7a1a"), "accent2": Color("12b8c4"), "card": Color("fffaf0"),
	},
	"valentines": {
		"label": "Valentine's", "deco": "hearts",
		"tint_top": Color("ffc4d6"), "tint_top_a": 0.45, "tint_bottom": Color("fff0f4"), "tint_bottom_a": 0.72,
		"accent": Color("ff4f7b"), "accent2": Color("c2185b"), "card": Color("fff5f8"),
	},
	"lunar_new_year": {
		"label": "Lunar New Year", "deco": "lanterns",
		"tint_top": Color("5a0a0a"), "tint_top_a": 0.6, "tint_bottom": Color("b3201c"), "tint_bottom_a": 0.45,
		"accent": Color("d62828"), "accent2": Color("f4b400"), "card": Color("fff8ec"),
	},
	"kalayaan": {
		"label": "Kalayaan", "deco": "stars",
		"tint_top": Color("0038a8"), "tint_top_a": 0.45, "tint_bottom": Color("f2f6ff"), "tint_bottom_a": 0.7,
		"accent": Color("0038a8"), "accent2": Color("ce1126"), "card": Color("f7f9ff"),
	},
	"thanksgiving": {
		"label": "Harvest", "deco": "autumn",
		"tint_top": Color("7a3a12"), "tint_top_a": 0.42, "tint_bottom": Color("ffe2b8"), "tint_bottom_a": 0.6,
		"accent": Color("c8641e"), "accent2": Color("7a4a1e"), "card": Color("fff6ea"),
	},
	"fiesta": {
		"label": "Fiesta", "deco": "bunting",
		"tint_top": Color("fff2a8"), "tint_top_a": 0.3, "tint_bottom": Color("fff8dc"), "tint_bottom_a": 0.66,
		"accent": Color("ff3d7f"), "accent2": Color("00a6a6"), "card": Color("fffdf2"),
	},
	"new_year": {
		"label": "New Year", "deco": "fireworks",
		"tint_top": Color("0d0a24"), "tint_top_a": 0.8, "tint_bottom": Color("2a1f4a"), "tint_bottom_a": 0.62,
		"accent": Color("ffcf3f"), "accent2": Color("ff4f8b"), "card": Color("fffaf0"),
	},
}


static func get_theme(key: Variant) -> Dictionary:
	return THEMES.get(str(key), THEMES["classic"])


static func keys() -> Array:
	return THEMES.keys()


## Vertical gradient over the board for a theme.
static func tint_texture(theme: Dictionary) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(theme["tint_top"], theme["tint_top_a"]))
	gradient.set_color(1, Color(theme["tint_bottom"], theme["tint_bottom_a"]))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	return tex


## Card panel style in the theme's paper colour.
static func card_style(theme: Dictionary, radius := 26) -> StyleBoxFlat:
	var s := ProfileUi.box(theme["card"], radius, 4)
	s.set_content_margin_all(18)
	s.shadow_color = Color(AppTheme.INK, 0.35)
	s.shadow_offset = Vector2(0, 6)
	s.shadow_size = 2
	return s


## The theme for the server's dashboard_theme, recoloured by its dashboard_palette when one comes
## with it ({background, primary, accent} as hex). A theme the client doesn't know is built from
## the palette alone, over the classic decoration.
static func resolve(key: Variant, palette: Variant) -> Dictionary:
	var known := THEMES.has(str(key))
	var theme: Dictionary = (THEMES[str(key)] if known else THEMES["classic"]).duplicate()
	if not palette is Dictionary:
		return theme
	var primary := str(palette.get("primary", ""))
	var accent := str(palette.get("accent", ""))
	var background := str(palette.get("background", ""))
	if Color.html_is_valid(primary):
		theme["accent"] = Color.html(primary)
	if Color.html_is_valid(accent):
		theme["accent2"] = Color.html(accent)
	if not known and Color.html_is_valid(background):
		var bg := Color.html(background)
		var dark := bg.get_luminance() < 0.4
		theme["tint_top"] = bg
		theme["tint_bottom"] = bg
		theme["tint_top_a"] = 0.75 if dark else 0.3
		theme["tint_bottom_a"] = 0.6 if dark else 0.7
		theme["card"] = bg.lerp(Color.WHITE, 0.85) if dark else bg.lerp(Color.WHITE, 0.6)
	return theme
