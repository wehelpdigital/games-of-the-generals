class_name CosmeticLibrary
extends RefCounted
## Client-side definitions of the material cosmetics: chip designs (piece skins), board themes and
## territories (how each player's half of the board looks), in the game's cel-shaded toy style.
## Every look is a set of toon StandardMaterial3Ds (hard light bands, toon highlights, rim light,
## optional procedural patterns) plus flat ink-outline materials, so swapping is just reassigning
## materials. Materials are cached and shared between all pieces and tiles.
##
## Every catalog entry carries shop info: {name, rarity, swatch: [Color], desc}. Auras, move trails
## and kill effects live in core/cosmetics/ (AuraFX, TrailFX, KillFX); icon packs in PieceIcons.

const DEFAULT_BOARD := "board_mahogany"
const DEFAULT_PIECES := "pieces_classic_wood"
const DEFAULT_TERRITORY := "default"
const INK := Color("1d1736")  ## Outline colour: a deep plum reads softer than black.

## frame: outer platform; bed: the grid lines between tiles; divider: the centre line;
## glow: emission on bed/divider; tile_pattern / pattern_glow: optional procedural tile texture.
const BOARD_THEMES := {
	"board_mahogany": {
		"name": "Mahogany Wood", "rarity": "common", "desc": "Warm toy-box wood with a sunny centre line.",
		"swatch": [Color("e0703a"), Color("ffcf8f"), Color("f4ac66"), Color("ffe066")],
		"frame": Color("e0703a"), "bed": Color("5e2a1a"), "tile_a": Color("ffcf8f"), "tile_b": Color("f4ac66"),
		"divider": Color("ffe066"), "glow": 0.0,
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_marble_slate": {
		"name": "Marble Slate", "rarity": "rare", "desc": "Cool veined marble on a periwinkle frame.",
		"swatch": [Color("7f8fd6"), Color("f4f5ff"), Color("cdd5f3"), Color("ff8fbf")],
		"frame": Color("7f8fd6"), "bed": Color("454f8f"), "tile_a": Color("f4f5ff"), "tile_b": Color("cdd5f3"),
		"divider": Color("ff8fbf"), "glow": 0.0, "tile_pattern": "veins",
		"sky_top": Color("6aa8ff"), "sky_horizon": Color("e3f4ff"), "ambient": Color("d0d6f4"),
	},
	"board_military_steel": {
		"name": "Tactical Military Steel", "rarity": "rare", "desc": "Field-green plating with hazard-yellow centre.",
		"swatch": [Color("5f8a52"), Color("b9d38f"), Color("a3c27b"), Color("ffd23f")],
		"frame": Color("5f8a52"), "bed": Color("2c3b27"), "tile_a": Color("b9d38f"), "tile_b": Color("a3c27b"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "panel",
		"sky_top": Color("2f9bff"), "sky_horizon": Color("fff1c9"), "ambient": Color("d3d9e2"),
	},
	"board_cyber_neon": {
		"name": "Cyberpunk Neon Grid", "rarity": "epic", "desc": "Midnight tiles with glowing cyan grid lines.",
		"swatch": [Color("3a2a86"), Color("221c55"), Color("22f2ff"), Color("ff3dd0")],
		"frame": Color("3a2a86"), "bed": Color("22f2ff"), "tile_a": Color("221c55"), "tile_b": Color("2b2366"),
		"divider": Color("ff3dd0"), "glow": 2.6,
		"sky_top": Color("120b3a"), "sky_horizon": Color("a53bd6"), "ambient": Color("a59cec"),
	},
	"board_obsidian": {
		"name": "Obsidian Altar", "rarity": "epic", "desc": "Black volcanic glass with violet light in the seams.",
		"swatch": [Color("2a2236"), Color("1f1a2b"), Color("8b5cff"), Color("ff5cd6")],
		"frame": Color("2a2236"), "bed": Color("8b5cff"), "tile_a": Color("2c2540"), "tile_b": Color("221d33"),
		"divider": Color("ff5cd6"), "glow": 1.8, "tile_pattern": "veins",
	},
	"board_jade_temple": {
		"name": "Jade Temple", "rarity": "epic", "desc": "Carved jade tiles, gold inlay, red lacquer frame.",
		"swatch": [Color("b8342d"), Color("9fe0bf"), Color("7fcfa8"), Color("d9a441")],
		"frame": Color("b8342d"), "bed": Color("d9a441"), "tile_a": Color("a6e6c6"), "tile_b": Color("84d1ac"),
		"divider": Color("ffe066"), "glow": 0.0, "tile_pattern": "veins",
	},
	"board_ice": {
		"name": "Glacier Ice", "rarity": "rare", "desc": "Frosted ice slabs with a cold blue shimmer.",
		"swatch": [Color("bfe9ff"), Color("f2fbff"), Color("d6f1ff"), Color("5fb8e6")],
		"frame": Color("a9dcf7"), "bed": Color("5fb8e6"), "tile_a": Color("f2fbff"), "tile_b": Color("d6f1ff"),
		"divider": Color("ffffff"), "glow": 0.8, "tile_pattern": "veins",
	},
	"board_royal_gold": {
		"name": "Royal Gold", "rarity": "epic", "desc": "Ivory and gold squares on a crimson velvet frame.",
		"swatch": [Color("7a1f3d"), Color("fff1d0"), Color("f2d68f"), Color("e0a520")],
		"frame": Color("8a2245"), "bed": Color("e0a520"), "tile_a": Color("fff1d0"), "tile_b": Color("f2d68f"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "dapple",
	},
	"board_wooden_dojo": {
		"name": "Wooden Dojo", "rarity": "common", "desc": "Woven tatami mats framed in dark cedar.",
		"swatch": [Color("6b3e22"), Color("e8d39a"), Color("d9c07e"), Color("c8342d")],
		"frame": Color("6b3e22"), "bed": Color("3a2414"), "tile_a": Color("ecd8a0"), "tile_b": Color("dcc382"),
		"divider": Color("d23a2f"), "glow": 0.0, "tile_pattern": "weave",
	},
	"board_scifi_panel": {
		"name": "Starship Deck", "rarity": "rare", "desc": "Riveted hull panels with orange running lights.",
		"swatch": [Color("4a5566"), Color("c7d0db"), Color("ff8a1f"), Color("2ef6ff")],
		"frame": Color("4a5566"), "bed": Color("ff8a1f"), "tile_a": Color("c7d0db"), "tile_b": Color("b3bdc9"),
		"divider": Color("2ef6ff"), "glow": 1.6, "tile_pattern": "panel",
	},
	"board_candy": {
		"name": "Candy Land", "rarity": "common", "desc": "Bubblegum and mint squares, lemon centre stripe.",
		"swatch": [Color("ff7ab6"), Color("ffd1ea"), Color("c9f5e8"), Color("ffe14d")],
		"frame": Color("ff7ab6"), "bed": Color("ffffff"), "tile_a": Color("ffd6ec"), "tile_b": Color("c9f5e8"),
		"divider": Color("ffe14d"), "glow": 0.0,
	},
	"board_coral_reef": {
		"name": "Coral Reef", "rarity": "rare", "desc": "Lagoon-blue tiles rippling around a coral frame.",
		"swatch": [Color("ff7f6b"), Color("7fe0d6"), Color("5cc9c0"), Color("1f6f8b")],
		"frame": Color("ff7f6b"), "bed": Color("1f6f8b"), "tile_a": Color("86e3d9"), "tile_b": Color("62cdc3"),
		"divider": Color("ffd6a5"), "glow": 0.0, "tile_pattern": "waves",
	},
	"board_lava_forge": {
		"name": "Lava Forge", "rarity": "legendary", "desc": "Cracked basalt with molten light in every seam.",
		"swatch": [Color("2b2121"), Color("3a2f2e"), Color("ff5a1f"), Color("ffb020")],
		"frame": Color("2b2121"), "bed": Color("ff5a1f"), "tile_a": Color("3d3130"), "tile_b": Color("302625"),
		"divider": Color("ffb020"), "glow": 2.2, "tile_pattern": "cracks", "pattern_glow": Color("ff6a1a"),
	},
}

## How one player's half of the board looks (rows 0–3 for white, 4–7 for black). Both players see
## both halves. "default" keeps the board theme's own tiles.
const TERRITORIES := {
	"default": {
		"name": "Board default", "rarity": "common", "desc": "Your half matches the board theme.",
		"swatch": [Color("ffcf8f"), Color("f4ac66")],
	},
	"territory_ember": {
		"name": "Ember Ground", "rarity": "epic", "desc": "Scorched earth with embers glowing in the cracks.",
		"swatch": [Color("5a2a22"), Color("4a221c"), Color("ff6a1a")],
		"tile_a": Color("62302a"), "tile_b": Color("50251f"), "pattern": "cracks", "pattern_glow": Color("ff6a1a"),
	},
	"territory_frost": {
		"name": "Frostbite", "rarity": "rare", "desc": "Frozen tiles laced with ice.",
		"swatch": [Color("dff4ff"), Color("c4e8ff"), Color("7fc8ef")],
		"tile_a": Color("e6f7ff"), "tile_b": Color("c9eaff"), "pattern": "veins",
	},
	"territory_meadow": {
		"name": "Spring Meadow", "rarity": "common", "desc": "Fresh green grass for your army to stand on.",
		"swatch": [Color("9fdc6a"), Color("86c955")],
		"tile_a": Color("a5e070"), "tile_b": Color("8ccd5c"), "pattern": "dapple",
	},
	"territory_royal_gold": {
		"name": "Gilded Court", "rarity": "epic", "desc": "Polished gold squares fit for a five-star general.",
		"swatch": [Color("ffe9a8"), Color("f2cf6a"), Color("d9a441")],
		"tile_a": Color("ffe7a0"), "tile_b": Color("f0c95e"), "pattern": "dapple", "shine": 0.6,
	},
	"territory_neon_grid": {
		"name": "Neon Grid", "rarity": "epic", "desc": "Dark panels with a glowing cyan circuit grid.",
		"swatch": [Color("141a33"), Color("1b2244"), Color("2ef6ff")],
		"tile_a": Color("19213d"), "tile_b": Color("141a33"), "pattern": "panel_glow", "pattern_glow": Color("2ef6ff"),
	},
	"territory_sakura": {
		"name": "Sakura Garden", "rarity": "rare", "desc": "Blossom-pink stones dappled with petals.",
		"swatch": [Color("ffd6e6"), Color("ffc2da"), Color("ff8fb8")],
		"tile_a": Color("ffdbe9"), "tile_b": Color("ffc4dc"), "pattern": "dapple",
	},
	"territory_ocean": {
		"name": "Ocean Tide", "rarity": "rare", "desc": "Rippling blue water under your pieces.",
		"swatch": [Color("5fc3e4"), Color("49aed3"), Color("2a7fb0")],
		"tile_a": Color("62c6e6"), "tile_b": Color("48add2"), "pattern": "waves",
	},
	"territory_starfield": {
		"name": "Starfield", "rarity": "legendary", "desc": "Deep space with twinkling stars.",
		"swatch": [Color("141433"), Color("1b1a40"), Color("ffffff")],
		"tile_a": Color("1a1a40"), "tile_b": Color("131332"), "pattern": "specks", "pattern_glow": Color("ffffff"),
	},
	"territory_toxic": {
		"name": "Toxic Spill", "rarity": "epic", "desc": "Bubbling green sludge with glowing seams.",
		"swatch": [Color("7ddc3a"), Color("66c42e"), Color("d4ff3a")],
		"tile_a": Color("5fa82b"), "tile_b": Color("4f9423"), "pattern": "cracks", "pattern_glow": Color("c8ff2e"),
	},
	"territory_desert": {
		"name": "Desert Dunes", "rarity": "common", "desc": "Wind-rippled sand.",
		"swatch": [Color("f3d79a"), Color("e8c785")],
		"tile_a": Color("f5da9d"), "tile_b": Color("e6c27f"), "pattern": "waves",
	},
	"territory_candy": {
		"name": "Cotton Candy", "rarity": "common", "desc": "Pastel pink and sky-blue squares.",
		"swatch": [Color("ffe0f0"), Color("d8f0ff")],
		"tile_a": Color("ffe0f0"), "tile_b": Color("d4efff"),
	},
}

## Each skin has a light team (white) and a dark team (black) so sides read at a glance.
## body: the plaque; base: team accent stand; ink: emblem; label / label_outline: rank text;
## shine: toon highlight strength; glow: emission on the body; pattern / pattern_glow: procedural
## texture; outline / outline_glow: coloured (neon) outline instead of ink.
const PIECE_SKINS := {
	"pieces_classic_wood": {
		"name": "Classic Wooden Tokens", "rarity": "common", "desc": "Cream and plum toy blocks.",
		"swatch": [Color("fff0cf"), Color("3fa9ff"), Color("3d3760"), Color("ff4f72")],
		"white": {"body": Color("fff0cf"), "base": Color("3fa9ff"), "ink": Color("ffa400"), "label": Color("2a2350"), "label_outline": Color("fff3d6"), "shine": 0.25},
		"black": {"body": Color("3d3760"), "base": Color("ff4f72"), "ink": Color("ffc93c"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.25},
	},
	"pieces_brass_gold": {
		"name": "Polished Brass/Gold", "rarity": "rare", "desc": "Gleaming brass against gunmetal.",
		"swatch": [Color("ffcd4a"), Color("ff7a3d"), Color("4f5a74"), Color("8f6dff")],
		"white": {"body": Color("ffcd4a"), "base": Color("ff7a3d"), "ink": Color("ff3f5e"), "label": Color("6b3600"), "label_outline": Color("ffe9a8"), "shine": 0.9},
		"black": {"body": Color("4f5a74"), "base": Color("8f6dff"), "ink": Color("ffd54a"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.8},
	},
	"pieces_holo_glass": {
		"name": "Holographic Glass", "rarity": "epic", "desc": "Glowing cyan and magenta glass.",
		"swatch": [Color("7ff4ff"), Color("1b9cff"), Color("ff8ae0"), Color("b84dff")],
		"white": {"body": Color("7ff4ff"), "base": Color("1b9cff"), "ink": Color("1c47d6"), "label": Color("0b2f6b"), "label_outline": Color("e8fdff"), "shine": 0.6, "glow": Color("2ee6ff")},
		"black": {"body": Color("ff8ae0"), "base": Color("b84dff"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("4a0f4a"), "shine": 0.6, "glow": Color("ff3bd0")},
	},
	"pieces_obsidian": {
		"name": "Obsidian & Quartz", "rarity": "epic", "desc": "Veined white quartz versus glossy black glass.",
		"swatch": [Color("ece8f6"), Color("9b7bff"), Color("1c1a26"), Color("7a3cff")],
		"white": {"body": Color("ece8f6"), "base": Color("9b7bff"), "ink": Color("6a4bd6"), "label": Color("2a2350"), "label_outline": Color("ffffff"), "shine": 0.8, "pattern": "veins"},
		"black": {"body": Color("24212f"), "base": Color("7a3cff"), "ink": Color("c9b6ff"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.95, "pattern": "veins"},
	},
	"pieces_jade": {
		"name": "Imperial Jade", "rarity": "rare", "desc": "Pale and deep jade with gold stands.",
		"swatch": [Color("c2f2d8"), Color("e0aa3e"), Color("1f7a55"), Color("f2c14e")],
		"white": {"body": Color("c2f2d8"), "base": Color("e0aa3e"), "ink": Color("2a8a5c"), "label": Color("1d4a33"), "label_outline": Color("f0fff6"), "shine": 0.7, "pattern": "veins"},
		"black": {"body": Color("1f7a55"), "base": Color("f2c14e"), "ink": Color("ffe28a"), "label": Color("ffffff"), "label_outline": Color("0f3324"), "shine": 0.7, "pattern": "veins"},
	},
	"pieces_candy": {
		"name": "Candy Pop", "rarity": "common", "desc": "Bubblegum pink versus grape, with mint and lemon stands.",
		"swatch": [Color("ffd1ea"), Color("6fe3c7"), Color("8e4bd9"), Color("ffe14d")],
		"white": {"body": Color("ffd1ea"), "base": Color("6fe3c7"), "ink": Color("ff4f9a"), "label": Color("7a1f4f"), "label_outline": Color("fff4fa"), "shine": 0.55},
		"black": {"body": Color("8e4bd9"), "base": Color("ffe14d"), "ink": Color("ffe14d"), "label": Color("ffffff"), "label_outline": Color("3b1766"), "shine": 0.55},
	},
	"pieces_ice_crystal": {
		"name": "Ice Crystal", "rarity": "epic", "desc": "Frosted crystal that glows from inside.",
		"swatch": [Color("e6faff"), Color("7fd6ff"), Color("2f5d9e"), Color("bfefff")],
		"white": {"body": Color("e6faff"), "base": Color("7fd6ff"), "ink": Color("3aa7e6"), "label": Color("0f3f66"), "label_outline": Color("ffffff"), "shine": 0.85, "glow": Color("9ef3ff"), "pattern": "veins"},
		"black": {"body": Color("2f5d9e"), "base": Color("bfefff"), "ink": Color("bfefff"), "label": Color("ffffff"), "label_outline": Color("0d2445"), "shine": 0.85, "glow": Color("3a8dff"), "pattern": "veins"},
	},
	"pieces_lava_rock": {
		"name": "Lava Rock", "rarity": "legendary", "desc": "Pumice and basalt with molten cracks.",
		"swatch": [Color("cbbfb4"), Color("ff7b2e"), Color("2a2224"), Color("ff3b1f")],
		"white": {"body": Color("cbbfb4"), "base": Color("ff7b2e"), "ink": Color("ff5a1f"), "label": Color("3a2420"), "label_outline": Color("fff1e6"), "shine": 0.3, "pattern": "cracks", "pattern_glow": Color("ff7a1a")},
		"black": {"body": Color("2e2527"), "base": Color("ff3b1f"), "ink": Color("ffb020"), "label": Color("ffffff"), "label_outline": Color("1a1012"), "shine": 0.35, "pattern": "cracks", "pattern_glow": Color("ff4a14")},
	},
	"pieces_carbon_fiber": {
		"name": "Carbon Fiber", "rarity": "rare", "desc": "Race-car weave: silver/red versus black/green.",
		"swatch": [Color("dde1e8"), Color("e8344e"), Color("2b2e33"), Color("3cff8f")],
		"white": {"body": Color("dde1e8"), "base": Color("e8344e"), "ink": Color("e8344e"), "label": Color("2b2e33"), "label_outline": Color("ffffff"), "shine": 0.85, "pattern": "weave"},
		"black": {"body": Color("34383e"), "base": Color("3cff8f"), "ink": Color("3cff8f"), "label": Color("ffffff"), "label_outline": Color("121417"), "shine": 0.85, "pattern": "weave"},
	},
	"pieces_pearl": {
		"name": "Pearl", "rarity": "rare", "desc": "Lustrous white pearl versus black pearl.",
		"swatch": [Color("fff7f2"), Color("ff9ec7"), Color("33343f"), Color("4fd1c5")],
		"white": {"body": Color("fff7f2"), "base": Color("ff9ec7"), "ink": Color("ff7ab0"), "label": Color("5a3048"), "label_outline": Color("ffffff"), "shine": 1.0, "pattern": "dapple"},
		"black": {"body": Color("363744"), "base": Color("4fd1c5"), "ink": Color("8ef0e6"), "label": Color("ffffff"), "label_outline": Color("17181f"), "shine": 1.0, "pattern": "dapple"},
	},
	"pieces_sakura": {
		"name": "Sakura Blossom", "rarity": "rare", "desc": "Blossom pink and plum wood on leafy stands.",
		"swatch": [Color("ffe3ee"), Color("78c46b"), Color("5a2742"), Color("ff8fb8")],
		"white": {"body": Color("ffe3ee"), "base": Color("78c46b"), "ink": Color("ff6f9f"), "label": Color("6b2445"), "label_outline": Color("fff6fa"), "shine": 0.4, "pattern": "dapple"},
		"black": {"body": Color("5a2742"), "base": Color("ff8fb8"), "ink": Color("ffc2d8"), "label": Color("ffffff"), "label_outline": Color("2a0f1f"), "shine": 0.4, "pattern": "dapple"},
	},
	"pieces_galaxy": {
		"name": "Galaxy", "rarity": "legendary", "desc": "Lilac nebula versus deep space, full of stars.",
		"swatch": [Color("c8b8ff"), Color("5d7bff"), Color("1b1440"), Color("b05cff")],
		"white": {"body": Color("c8b8ff"), "base": Color("5d7bff"), "ink": Color("5d3bd6"), "label": Color("241554"), "label_outline": Color("f4f0ff"), "shine": 0.6, "pattern": "specks", "pattern_glow": Color("ffffff")},
		"black": {"body": Color("221a52"), "base": Color("b05cff"), "ink": Color("e0c6ff"), "label": Color("ffffff"), "label_outline": Color("0d0a24"), "shine": 0.6, "pattern": "specks", "pattern_glow": Color("ffffff"), "glow": Color("3b2a9e")},
	},
	"pieces_neon_wireframe": {
		"name": "Neon Wireframe", "rarity": "legendary", "desc": "Dark chips outlined in glowing cyan or magenta neon.",
		"swatch": [Color("1a2440"), Color("2ef6ff"), Color("2a1238"), Color("ff3bd6")],
		"white": {"body": Color("1b2747"), "base": Color("123a52"), "ink": Color("2ef6ff"), "label": Color("2ef6ff"), "label_outline": Color("0a1226"), "shine": 0.5, "outline": Color("2ef6ff"), "outline_glow": 2.4, "pattern": "panel_glow", "pattern_glow": Color("2ef6ff")},
		"black": {"body": Color("2c1239"), "base": Color("4a1250"), "ink": Color("ff3bd6"), "label": Color("ff7ae6"), "label_outline": Color("17061f"), "shine": 0.5, "outline": Color("ff3bd6"), "outline_glow": 2.4, "pattern": "panel_glow", "pattern_glow": Color("ff3bd6")},
	},
	"pieces_royal_gold": {
		"name": "Royal Court", "rarity": "epic", "desc": "Ivory versus royal purple, both on gold.",
		"swatch": [Color("fff4dc"), Color("e0a520"), Color("4a1e6b"), Color("f0c03a")],
		"white": {"body": Color("fff4dc"), "base": Color("e0a520"), "ink": Color("c98a12"), "label": Color("5a3a08"), "label_outline": Color("ffffff"), "shine": 0.7},
		"black": {"body": Color("4f2073"), "base": Color("f0c03a"), "ink": Color("f0c03a"), "label": Color("ffe9a8"), "label_outline": Color("24093a"), "shine": 0.7},
	},
}

static var _materials: Dictionary = {}
static var _font: Font


static func board_theme(slug: String) -> Dictionary:
	return BOARD_THEMES.get(slug, BOARD_THEMES[DEFAULT_BOARD])


static func piece_skin(slug: String) -> Dictionary:
	return PIECE_SKINS.get(slug, PIECE_SKINS[DEFAULT_PIECES])


static func territory(slug: String) -> Dictionary:
	return TERRITORIES.get(slug, TERRITORIES[DEFAULT_TERRITORY])


## part: frame, bed, tile_a, tile_b, divider, outline
static func board_material(slug: String, part: String) -> Material:
	var key := "board/%s/%s" % [slug, part]
	if _materials.has(key):
		return _materials[key]
	var theme := board_theme(slug)
	var m: StandardMaterial3D
	match part:
		"tile_a", "tile_b":
			m = toon(theme[part])
			_apply_pattern(m, theme.get("tile_pattern", ""), theme.get("pattern_glow"), true, 0.5)
		"frame":
			m = toon(theme[part])
		"bed", "divider":
			m = toon(theme[part])
			if theme["glow"] > 0.0:
				m.emission_enabled = true
				m.emission = theme[part]
				m.emission_energy_multiplier = theme["glow"]
		"outline":
			m = outline_material(INK)
		_:
			m = toon(theme.get("tile_a", Color.WHITE))
	_materials[key] = m
	return m


## Tile material for one half of the board; null for "default" (use the board theme's tiles).
## part: tile_a, tile_b
static func territory_material(slug: String, part: String) -> Material:
	if slug == DEFAULT_TERRITORY or not TERRITORIES.has(slug):
		return null
	var key := "territory/%s/%s" % [slug, part]
	if _materials.has(key):
		return _materials[key]
	var info: Dictionary = TERRITORIES[slug]
	var m := toon(info[part], info.get("shine", 0.0))
	if info.get("shine", 0.0) > 0.0:
		m.rim_enabled = false  # Flat tiles at a grazing angle would wash out.
	_apply_pattern(m, info.get("pattern", ""), info.get("pattern_glow"), true, 0.5)
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
			_apply_pattern(m, skin.get("pattern", ""), skin.get("pattern_glow"), false, 1.6)
		"base":
			m = toon(skin["base"], skin["shine"] * 0.5)
			if skin.has("outline"):
				m.emission_enabled = true
				m.emission = skin["outline"]
				m.emission_energy_multiplier = 0.35
		"insignia":
			m = toon(skin["ink"], 0.6)
			if glow is Color:
				m.emission_enabled = true
				m.emission = skin["ink"]
				m.emission_energy_multiplier = 1.4
		"emblem":
			m = toon(skin["ink"], 0.4)
			if skin.has("outline"):
				m.emission_enabled = true
				m.emission = skin["ink"]
				m.emission_energy_multiplier = 1.2
		"outline":
			if skin.has("outline"):
				var neon: Color = skin["outline"]
				var boost: float = skin.get("outline_glow", 1.0)
				m = outline_material(Color(neon.r * boost, neon.g * boost, neon.b * boost, 1.0))
			else:
				m = outline_material(INK)
	if part in ["insignia", "emblem"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


## {color, outline} for the rank text on a piece face.
static func piece_label_colors(slug: String, side: String) -> Dictionary:
	var skin: Dictionary = piece_skin(slug)[side]
	return {"color": skin["label"], "outline": skin["label_outline"]}


## Deprecated: arenas own the sky and ambient now. Kept for callers that still ask.
static func board_environment(slug: String) -> Dictionary:
	var theme := board_theme(slug)
	return {"sky_top": theme.get("sky_top", Color("3f8cff")), "sky_horizon": theme.get("sky_horizon", Color("ffe1c4")),
		"ambient": theme.get("ambient", Color("dccfee"))}


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


## Inverted-hull outline: draw only the back faces of a slightly grown copy, flat colour. Colours
## brighter than 1.0 (HDR) bloom under the environment's glow, which is how neon outlines shine.
static func outline_material(color: Color) -> StandardMaterial3D:
	var key := "outline/%s/%s/%s/%s" % [color.r, color.g, color.b, color.a]
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


## Unshaded ground with soft polka dots (the classic menu backdrop), for arenas that want it.
static func polka_floor_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.albedo_texture = _dots_texture()
	m.uv1_scale = Vector3(60.0, 60.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# --- Procedural patterns ----------------------------------------------------------------------

## Adds a seamless procedural texture. Plain patterns tint the albedo; glowing ones (cracks,
## specks, panel_glow) add an emission map in `glow` colour. World-space triplanar mapping keeps
## board patterns continuous across tiles; pieces map in object space.
static func _apply_pattern(m: StandardMaterial3D, pattern: String, glow: Variant, world: bool, scale: float) -> void:
	if pattern == "":
		return
	var emissive := pattern in ["cracks", "specks", "panel_glow"]
	var tex := pattern_texture(pattern)
	if emissive:
		m.emission_enabled = true
		m.emission = glow if glow is Color else Color.WHITE
		m.emission_energy_multiplier = 2.0 if pattern != "specks" else 2.6
		m.emission_texture = tex
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # The pattern masks the glow colour.
		if pattern == "panel_glow":
			m.albedo_texture = pattern_texture("panel")
	else:
		m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func pattern_texture(pattern: String) -> Texture2D:
	var key := "pattern/" + pattern
	if _materials.has(key):
		return _materials[key]
	const SIZE := 128
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / SIZE
			var v := (y + 0.5) / SIZE
			var value := _pattern_value(pattern, u, v, x, y, SIZE)
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_materials[key] = tex
	return tex


@warning_ignore("integer_division")
static func _pattern_value(pattern: String, u: float, v: float, x: int, y: int, _size: int) -> float:
	match pattern:
		"weave":
			# Basket weave: alternating cells with shading across the strand.
			var cu := floori(u * 8.0)
			var cv := floori(v * 8.0)
			var along := fposmod(u * 8.0, 1.0) if (cu + cv) % 2 == 0 else fposmod(v * 8.0, 1.0)
			return 0.78 + 0.22 * sin(along * PI)
		"veins":
			var t := 2.0 * u + v + 0.15 * sin(TAU * v * 3.0) + 0.1 * sin(TAU * u * 5.0)
			var vein := pow(1.0 - absf(sin(TAU * t * 0.5)), 10.0)
			return 1.0 - 0.32 * vein - 0.05 * sin(TAU * (u * 3.0 + v * 2.0))
		"dapple":
			return 0.9 + 0.1 * sin(TAU * (u * 3.0 + v * 2.0)) * sin(TAU * (u * 2.0 - v * 5.0))
		"waves":
			return 0.86 + 0.14 * sin(TAU * (v * 4.0 + 0.25 * sin(TAU * u * 2.0)))
		"panel":
			var gu := fposmod(u * 2.0, 1.0)
			var gv := fposmod(v * 2.0, 1.0)
			var line := minf(minf(gu, 1.0 - gu), minf(gv, 1.0 - gv))
			var rivet := minf(Vector2(gu - 0.12, gv - 0.12).length(), Vector2(gu - 0.88, gv - 0.88).length())
			return 0.72 if line < 0.025 or rivet < 0.03 else 1.0
		"panel_glow":
			var gu := fposmod(u * 2.0, 1.0)
			var gv := fposmod(v * 2.0, 1.0)
			var line := minf(minf(gu, 1.0 - gu), minf(gv, 1.0 - gv))
			return 1.0 - smoothstep(0.012, 0.04, line)
		"cracks":
			var a := sin(TAU * (u * 3.0 + 0.22 * sin(TAU * v * 2.0)))
			var b := sin(TAU * (v * 3.0 + 0.22 * sin(TAU * u * 2.0)))
			var c := sin(TAU * (u * 2.0 + v * 3.0 + 0.3 * sin(TAU * u)))
			var d := minf(minf(absf(a), absf(b)), absf(c) * 1.4)
			return 1.0 - smoothstep(0.03, 0.12, d)
		"specks":
			# One possible star per 8×8-pixel cell, hashed so it tiles seamlessly.
			var cx := x / 8
			var cy := y / 8
			var h := _hash(cx, cy)
			if h > 0.4:
				return 0.0
			var sx := cx * 8 + 2 + int(_hash(cy + 17, cx + 3) * 4.0)
			var sy := cy * 8 + 2 + int(_hash(cx + 29, cy + 11) * 4.0)
			var dist := Vector2(x - sx, y - sy).length()
			var radius := 0.8 + _hash(cx + 5, cy + 7) * 1.6
			return clampf(1.0 - dist / radius, 0.0, 1.0)
	return 1.0


static func _hash(a: int, b: int) -> float:
	var n := (a * 374761393 + b * 668265263) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	return float(n % 10000) / 10000.0


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
