class_name CosmeticLibrary
extends RefCounted
## Client-side definitions of the shop cosmetics. Slugs match the server's shop_items catalog.
## Every look is a set of StandardMaterial3D instances built here (with procedurally generated grain
## textures), so swapping a theme is just reassigning materials. Materials are cached and shared.

const DEFAULT_BOARD := "board_mahogany"
const DEFAULT_PIECES := "pieces_classic_wood"

const BOARD_THEMES := {
	"board_mahogany": {
		"name": "Mahogany Wood",
		"tile_a": Color("7a3a1f"), "tile_b": Color("6c3119"), "slab": Color("3a180b"),
		"line": Color("d9b26a"), "divider": Color("efc979"), "table": Color("15100c"),
		"metallic": 0.0, "roughness": 0.42, "line_glow": 0.0, "pattern": "wood",
	},
	"board_marble_slate": {
		"name": "Marble Slate",
		"tile_a": Color("e6e3dc"), "tile_b": Color("b7babe"), "slab": Color("2b2f34"),
		"line": Color("c9a45c"), "divider": Color("d8b46a"), "table": Color("111316"),
		"metallic": 0.0, "roughness": 0.16, "line_glow": 0.0, "pattern": "marble",
	},
	"board_military_steel": {
		"name": "Tactical Military Steel",
		"tile_a": Color("5c6551"), "tile_b": Color("4d5545"), "slab": Color("272b25"),
		"line": Color("d4ad3a"), "divider": Color("e3bb40"), "table": Color("0f110e"),
		"metallic": 0.75, "roughness": 0.42, "line_glow": 0.0, "pattern": "brushed",
	},
	"board_cyber_neon": {
		"name": "Cyberpunk Neon Grid",
		"tile_a": Color("0e1122"), "tile_b": Color("0a0c1a"), "slab": Color("05060d"),
		"line": Color("19f0ff"), "divider": Color("ff2bd6"), "table": Color("04040a"),
		"metallic": 0.5, "roughness": 0.14, "line_glow": 3.2, "pattern": "",
	},
}

## Each skin has a light variant for white and a dark variant for black so sides stay readable.
const PIECE_SKINS := {
	"pieces_classic_wood": {
		"name": "Classic Wooden Tokens",
		"white": {"body": Color("e8d5ad"), "ink": Color("5c1f14"), "metallic": 0.0, "roughness": 0.5, "pattern": "wood"},
		"black": {"body": Color("3b2416"), "ink": Color("ead08e"), "metallic": 0.0, "roughness": 0.5, "pattern": "wood"},
	},
	"pieces_brass_gold": {
		"name": "Polished Brass/Gold",
		"white": {"body": Color("e2b24f"), "ink": Color("2b1d0b"), "metallic": 1.0, "roughness": 0.22, "pattern": ""},
		"black": {"body": Color("2d3037"), "ink": Color("f0c75e"), "metallic": 0.9, "roughness": 0.3, "pattern": ""},
	},
	"pieces_holo_glass": {
		"name": "Holographic Glass",
		"white": {"body": Color(0.45, 0.95, 1.0, 0.4), "ink": Color("eaffff"), "metallic": 0.2, "roughness": 0.05, "pattern": "", "glow": Color("1fd8ff")},
		"black": {"body": Color(1.0, 0.42, 0.9, 0.4), "ink": Color("fff0fb"), "metallic": 0.2, "roughness": 0.05, "pattern": "", "glow": Color("ff3bd0")},
	},
}

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}


static func board_theme(slug: String) -> Dictionary:
	return BOARD_THEMES.get(slug, BOARD_THEMES[DEFAULT_BOARD])


static func piece_skin(slug: String) -> Dictionary:
	return PIECE_SKINS.get(slug, PIECE_SKINS[DEFAULT_PIECES])


## part: tile_a, tile_b, slab, line, divider, table
static func board_material(slug: String, part: String) -> StandardMaterial3D:
	var key := "board/%s/%s" % [slug, part]
	if _materials.has(key):
		return _materials[key]
	var theme := board_theme(slug)
	var m := StandardMaterial3D.new()
	match part:
		"tile_a", "tile_b", "slab":
			m.albedo_color = theme[part]
			m.metallic = theme["metallic"]
			m.roughness = theme["roughness"] + (0.12 if part == "slab" else 0.0)
			_apply_pattern(m, theme["pattern"], Vector3(0.32, 0.32, 0.32), true)
		"line", "divider":
			m.albedo_color = theme[part]
			if theme["line_glow"] > 0.0:
				m.emission_enabled = true
				m.emission = theme[part]
				m.emission_energy_multiplier = theme["line_glow"] * (1.3 if part == "divider" else 1.0)
				m.roughness = 0.3
			else:
				m.metallic = 0.85
				m.roughness = 0.28
		"table":
			m.albedo_color = theme["table"]
			m.roughness = 0.85
	_materials[key] = m
	return m


## part: body, base, insignia, emblem
static func piece_material(slug: String, side: String, part: String) -> StandardMaterial3D:
	var key := "piece/%s/%s/%s" % [slug, side, part]
	if _materials.has(key):
		return _materials[key]
	var skin: Dictionary = piece_skin(slug)[side]
	var glass: bool = skin.has("glow")
	var m := StandardMaterial3D.new()
	match part:
		"body", "base":
			var body: Color = skin["body"]
			m.albedo_color = body if part == "body" else body.darkened(0.25)
			m.metallic = skin["metallic"]
			m.roughness = skin["roughness"]
			_apply_pattern(m, skin["pattern"], Vector3(1.4, 1.4, 1.4), false)
			if glass:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.emission_enabled = true
				m.emission = skin["glow"]
				m.emission_energy_multiplier = 0.35
				m.rim_enabled = true
				m.rim = 0.8
		"insignia", "emblem":
			var ink: Color = skin["ink"]
			m.albedo_color = ink if part == "insignia" else skin["body"].lerp(ink, 0.35)
			m.metallic = 1.0 if skin["metallic"] > 0.5 else 0.2
			m.roughness = 0.3 if skin["metallic"] > 0.5 else 0.55
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if glass:
				m.albedo_color.a = 1.0
				m.emission_enabled = true
				m.emission = skin["glow"] if part == "emblem" else ink
				m.emission_energy_multiplier = 1.6
	_materials[key] = m
	return m


## Soft dark blob under each piece; stands in for SSAO contact shadows on the Compatibility renderer.
static func contact_shadow_material() -> StandardMaterial3D:
	if _materials.has("contact_shadow"):
		return _materials["contact_shadow"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.55))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	_materials["contact_shadow"] = m
	return m


static func _apply_pattern(m: StandardMaterial3D, pattern: String, scale: Vector3, world_space: bool) -> void:
	var tex := pattern_texture(pattern)
	if tex == null:
		return
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_space
	m.uv1_scale = scale
	if pattern == "brushed":
		m.uv1_scale = Vector3(scale.x * 0.15, scale.y, scale.z * 4.0)


## Seamless greyscale grain (0.7–1.0) that tints the albedo colour. Built once per pattern.
static func pattern_texture(pattern: String) -> Texture2D:
	if pattern == "":
		return null
	if _textures.has(pattern):
		return _textures[pattern]
	const SIZE := 256
	var noise := FastNoiseLite.new()
	noise.seed = pattern.hash()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02 if pattern == "wood" else 0.012
	noise.fractal_octaves = 4
	var source := noise.get_seamless_image(SIZE, SIZE)
	source.convert(Image.FORMAT_L8)
	var data := source.get_data()
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var n := data[i] / 255.0 - 0.5
			var v := 1.0
			match pattern:
				"wood":
					v = 0.74 + 0.26 * pow(absf(sin(PI * (6.0 * x / SIZE + n * 1.6))), 0.55)
				"marble":
					var vein := 1.0 - absf(sin(PI * (2.0 * (x + y) / SIZE + n * 2.4)))
					v = 1.0 - 0.38 * pow(vein, 7.0) - 0.06 * n
				_:
					v = 0.86 + 0.28 * n
			data[i] = int(clampf(v, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, data)
	image.convert(Image.FORMAT_RGB8)
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_textures[pattern] = tex
	return tex
