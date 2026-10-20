class_name CosmeticLibrary
extends RefCounted
## Client-side definitions of the shop cosmetics, in the game's cel-shaded "toy anime" style.
## Slugs match the server's shop_items catalog. Every look is a set of toon StandardMaterial3Ds
## (hard light bands, toon highlights, rim light) plus flat ink-outline materials, so swapping a
## theme is just reassigning materials. Materials are cached and shared between all pieces.

const DEFAULT_BOARD := "board_mahogany"
const DEFAULT_PIECES := "pieces_classic_wood"
const INK := Color("1d1736")  ## Outline colour: a deep plum reads softer than black.

## frame: outer platform; bed: the grid lines between tiles; divider: the centre line.
## sky_* / ambient: the backdrop the board brings with it (ambient tints every shadow).
const BOARD_THEMES := {
	"board_mahogany": {
		"name": "Mahogany Wood",
		"frame": Color("e0703a"), "bed": Color("5e2a1a"), "tile_a": Color("ffcf8f"), "tile_b": Color("f4ac66"),
		"divider": Color("ffe066"), "glow": 0.0, "floor": Color("ffd9b0"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_marble_slate": {
		"name": "Marble Slate",
		"frame": Color("7f8fd6"), "bed": Color("454f8f"), "tile_a": Color("f4f5ff"), "tile_b": Color("cdd5f3"),
		"divider": Color("ff8fbf"), "glow": 0.0, "floor": Color("dff6ef"),
		"sky_top": Color("6aa8ff"), "sky_horizon": Color("e3f4ff"), "ambient": Color("d0d6f4"),
	},
	"board_military_steel": {
		"name": "Tactical Military Steel",
		"frame": Color("5f8a52"), "bed": Color("2c3b27"), "tile_a": Color("b9d38f"), "tile_b": Color("a3c27b"),
		"divider": Color("ffd23f"), "glow": 0.0, "floor": Color("f1e3b6"),
		"sky_top": Color("2f9bff"), "sky_horizon": Color("fff1c9"), "ambient": Color("d3d9e2"),
	},
	"board_cyber_neon": {
		"name": "Cyberpunk Neon Grid",
		"frame": Color("3a2a86"), "bed": Color("22f2ff"), "tile_a": Color("221c55"), "tile_b": Color("2b2366"),
		"divider": Color("ff3dd0"), "glow": 2.6, "floor": Color("251a5e"),
		"sky_top": Color("120b3a"), "sky_horizon": Color("a53bd6"), "ambient": Color("a59cec"),
	},
}

## Each skin has a light team (white) and a dark team (black) so sides read at a glance.
## body: the plaque; base: team accent stand; ink: insignia fill; label: rank text colours.
const PIECE_SKINS := {
	"pieces_classic_wood": {
		"name": "Classic Wooden Tokens",
		"white": {"body": Color("fff0cf"), "base": Color("3fa9ff"), "ink": Color("ffa400"), "label": Color("2a2350"), "label_outline": Color("fff3d6"), "shine": 0.25},
		"black": {"body": Color("3d3760"), "base": Color("ff4f72"), "ink": Color("ffc93c"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.25},
	},
	"pieces_brass_gold": {
		"name": "Polished Brass/Gold",
		"white": {"body": Color("ffcd4a"), "base": Color("ff7a3d"), "ink": Color("ff3f5e"), "label": Color("6b3600"), "label_outline": Color("ffe9a8"), "shine": 0.9},
		"black": {"body": Color("4f5a74"), "base": Color("8f6dff"), "ink": Color("ffd54a"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.8},
	},
	"pieces_holo_glass": {
		"name": "Holographic Glass",
		"white": {"body": Color("7ff4ff"), "base": Color("1b9cff"), "ink": Color("1c47d6"), "label": Color("0b2f6b"), "label_outline": Color("e8fdff"), "shine": 0.6, "glow": Color("2ee6ff")},
		"black": {"body": Color("ff8ae0"), "base": Color("b84dff"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("4a0f4a"), "shine": 0.6, "glow": Color("ff3bd0")},
	},
}

static var _materials: Dictionary = {}
static var _font: Font


static func board_theme(slug: String) -> Dictionary:
	return BOARD_THEMES.get(slug, BOARD_THEMES[DEFAULT_BOARD])


static func piece_skin(slug: String) -> Dictionary:
	return PIECE_SKINS.get(slug, PIECE_SKINS[DEFAULT_PIECES])


## part: frame, bed, tile_a, tile_b, divider, floor, outline
static func board_material(slug: String, part: String) -> Material:
	var key := "board/%s/%s" % [slug, part]
	if _materials.has(key):
		return _materials[key]
	var theme := board_theme(slug)
	var m: StandardMaterial3D
	match part:
		"tile_a", "tile_b", "frame":
			m = toon(theme[part])
		"bed", "divider":
			m = toon(theme[part])
			if theme["glow"] > 0.0:
				m.emission_enabled = true
				m.emission = theme[part]
				m.emission_energy_multiplier = theme["glow"]
		"floor":
			m = _floor(theme["floor"])
		"outline":
			m = outline_material(INK)
	_materials[key] = m
	return m


## part: body, base, insignia, emblem, outline
static func piece_material(slug: String, side: String, part: String) -> Material:
	var key := "piece/%s/%s/%s" % [slug, side, part]
	if _materials.has(key):
		return _materials[key]
	var skin: Dictionary = piece_skin(slug)[side]
	var glow: Variant = skin.get("glow")
	var m: StandardMaterial3D
	match part:
		"body":
			m = toon(skin["body"], skin["shine"])
			if glow is Color:
				m.emission_enabled = true
				m.emission = glow
				m.emission_energy_multiplier = 0.55
		"base":
			m = toon(skin["base"], skin["shine"] * 0.5)
		"insignia":
			m = toon(skin["ink"], 0.6)
			if glow is Color:
				m.emission_enabled = true
				m.emission = skin["ink"]
				m.emission_energy_multiplier = 1.4
		"emblem":
			m = toon(skin["ink"], 0.4)
		"outline":
			m = outline_material(INK)
	if part in ["insignia", "emblem"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


## {color, outline} for the rank text on a piece face.
static func piece_label_colors(slug: String, side: String) -> Dictionary:
	var skin: Dictionary = piece_skin(slug)[side]
	return {"color": skin["label"], "outline": skin["label_outline"]}


## Backdrop colours for the environment: {sky_top, sky_horizon, ambient}.
static func board_environment(slug: String) -> Dictionary:
	var theme := board_theme(slug)
	return {"sky_top": theme["sky_top"], "sky_horizon": theme["sky_horizon"], "ambient": theme["ambient"]}


## Cel-shaded material: hard terminator (toon diffuse) and, when `shine` > 0, a small crisp toon
## highlight plus a rim light so rounded pieces pop. Flat surfaces (the board) use shine 0: rim
## light on a surface seen at a grazing angle would wash it out.
static func toon(color: Color, shine := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.roughness = 0.3
	if shine <= 0.0:
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return m
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = lerpf(0.45, 0.2, shine)
	m.metallic_specular = lerpf(0.2, 0.7, shine)
	m.rim_enabled = true
	m.rim = lerpf(0.1, 0.35, shine)
	m.rim_tint = 0.5
	return m


## Inverted-hull outline: draw only the back faces of a slightly grown copy, flat ink colour.
static func outline_material(color: Color) -> StandardMaterial3D:
	var key := "outline/%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = color
	_materials[key] = m
	return m


## Soft tinted blob under each piece; grounds pieces even where real shadows are cut short.
static func contact_shadow_material() -> StandardMaterial3D:
	if _materials.has("contact_shadow"):
		return _materials["contact_shadow"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.16, 0.1, 0.32, 0.35))
	gradient.set_color(1, Color(0.16, 0.1, 0.32, 0.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _radial(gradient)
	_materials["contact_shadow"] = m
	return m


## Rounded display font (Fredoka, OFL) shared by 3D labels and, if wanted, the UI.
static func display_font(weight := 650) -> Font:
	if _font == null:
		var base: Font = load("res://assets/fonts/Fredoka.ttf")
		var variation := FontVariation.new()
		variation.base_font = base
		var server := TextServerManager.get_primary_interface()
		variation.variation_opentype = {server.name_to_tag("wght"): weight}
		_font = variation
	return _font


## Ground under the board: the theme colour with soft polka dots, like a game-menu backdrop.
static func _floor(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.albedo_texture = _dots_texture()
	m.uv1_scale = Vector3(60.0, 60.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _dots_texture() -> Texture2D:
	if _materials.has("dots_texture"):
		return _materials["dots_texture"]
	const SIZE := 64
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			# Two dots per tile on a diagonal lattice.
			var d1 := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
			var d2 := Vector2(x + 0.5 - 48.0, y + 0.5 - 48.0).length()
			var dot := 1.0 - smoothstep(6.0, 7.5, minf(d1, d2))
			var v := lerpf(0.94, 1.0, dot)
			image.set_pixel(x, y, Color(v, v, v))
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_materials["dots_texture"] = tex
	return tex


static func _radial(gradient: Gradient) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex
