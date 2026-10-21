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
		"name": "Mahogany Wood", "rarity": "common", "collection": "classics", "desc": "Warm toy-box wood with a sunny centre line.",
		"swatch": [Color("e0703a"), Color("ffcf8f"), Color("f4ac66"), Color("ffe066")],
		"frame": Color("e0703a"), "bed": Color("5e2a1a"), "tile_a": Color("ffcf8f"), "tile_b": Color("f4ac66"),
		"divider": Color("ffe066"), "glow": 0.0,
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_marble_slate": {
		"name": "Marble Slate", "rarity": "rare", "collection": "classics", "desc": "Cool veined marble on a periwinkle frame.",
		"swatch": [Color("7f8fd6"), Color("f4f5ff"), Color("cdd5f3"), Color("ff8fbf")],
		"frame": Color("7f8fd6"), "bed": Color("454f8f"), "tile_a": Color("f4f5ff"), "tile_b": Color("cdd5f3"),
		"divider": Color("ff8fbf"), "glow": 0.0, "tile_pattern": "veins",
		"sky_top": Color("6aa8ff"), "sky_horizon": Color("e3f4ff"), "ambient": Color("d0d6f4"),
	},
	"board_military_steel": {
		"name": "Tactical Military Steel", "rarity": "rare", "collection": "giant_robots", "desc": "Field-green plating with hazard-yellow centre.",
		"swatch": [Color("5f8a52"), Color("b9d38f"), Color("a3c27b"), Color("ffd23f")],
		"frame": Color("5f8a52"), "bed": Color("2c3b27"), "tile_a": Color("b9d38f"), "tile_b": Color("a3c27b"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "panel",
		"sky_top": Color("2f9bff"), "sky_horizon": Color("fff1c9"), "ambient": Color("d3d9e2"),
	},
	"board_cyber_neon": {
		"name": "Cyberpunk Neon Grid", "rarity": "epic", "collection": "cyber_neon", "desc": "Midnight tiles with glowing cyan grid lines.",
		"swatch": [Color("3a2a86"), Color("221c55"), Color("22f2ff"), Color("ff3dd0")],
		"frame": Color("3a2a86"), "bed": Color("22f2ff"), "tile_a": Color("221c55"), "tile_b": Color("2b2366"),
		"divider": Color("ff3dd0"), "glow": 2.6,
		"sky_top": Color("120b3a"), "sky_horizon": Color("a53bd6"), "ambient": Color("a59cec"),
	},
	"board_obsidian": {
		"name": "Obsidian Altar", "rarity": "epic", "collection": "lava_fire", "desc": "Black volcanic glass with violet light in the seams.",
		"swatch": [Color("2a2236"), Color("1f1a2b"), Color("8b5cff"), Color("ff5cd6")],
		"frame": Color("2a2236"), "bed": Color("8b5cff"), "tile_a": Color("2c2540"), "tile_b": Color("221d33"),
		"divider": Color("ff5cd6"), "glow": 1.8, "tile_pattern": "veins",
	},
	"board_jade_temple": {
		"name": "Jade Temple", "rarity": "epic", "collection": "royal_gold", "desc": "Carved jade tiles, gold inlay, red lacquer frame.",
		"swatch": [Color("b8342d"), Color("9fe0bf"), Color("7fcfa8"), Color("d9a441")],
		"frame": Color("b8342d"), "bed": Color("d9a441"), "tile_a": Color("a6e6c6"), "tile_b": Color("84d1ac"),
		"divider": Color("ffe066"), "glow": 0.0, "tile_pattern": "veins",
	},
	"board_ice": {
		"name": "Glacier Ice", "rarity": "rare", "collection": "ice_snow", "desc": "Frosted ice slabs with a cold blue shimmer.",
		"swatch": [Color("bfe9ff"), Color("f2fbff"), Color("d6f1ff"), Color("5fb8e6")],
		"frame": Color("a9dcf7"), "bed": Color("5fb8e6"), "tile_a": Color("f2fbff"), "tile_b": Color("d6f1ff"),
		"divider": Color("ffffff"), "glow": 0.8, "tile_pattern": "veins",
	},
	"board_royal_gold": {
		"name": "Royal Gold", "rarity": "epic", "collection": "fantasy_kingdom", "desc": "Ivory and gold squares on a crimson velvet frame.",
		"swatch": [Color("7a1f3d"), Color("fff1d0"), Color("f2d68f"), Color("e0a520")],
		"frame": Color("8a2245"), "bed": Color("e0a520"), "tile_a": Color("fff1d0"), "tile_b": Color("f2d68f"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "dapple",
	},
	"board_wooden_dojo": {
		"name": "Wooden Dojo", "rarity": "common", "collection": "samurai_ronin", "desc": "Woven tatami mats framed in dark cedar.",
		"swatch": [Color("6b3e22"), Color("e8d39a"), Color("d9c07e"), Color("c8342d")],
		"frame": Color("6b3e22"), "bed": Color("3a2414"), "tile_a": Color("ecd8a0"), "tile_b": Color("dcc382"),
		"divider": Color("d23a2f"), "glow": 0.0, "tile_pattern": "weave",
	},
	"board_scifi_panel": {
		"name": "Starship Deck", "rarity": "rare", "collection": "space_opera", "desc": "Riveted hull panels with orange running lights.",
		"swatch": [Color("4a5566"), Color("c7d0db"), Color("ff8a1f"), Color("2ef6ff")],
		"frame": Color("4a5566"), "bed": Color("ff8a1f"), "tile_a": Color("c7d0db"), "tile_b": Color("b3bdc9"),
		"divider": Color("2ef6ff"), "glow": 1.6, "tile_pattern": "panel",
	},
	"board_candy": {
		"name": "Candy Land", "rarity": "common", "collection": "cute_candy", "desc": "Bubblegum and mint squares, lemon centre stripe.",
		"swatch": [Color("ff7ab6"), Color("ffd1ea"), Color("c9f5e8"), Color("ffe14d")],
		"frame": Color("ff7ab6"), "bed": Color("ffffff"), "tile_a": Color("ffd6ec"), "tile_b": Color("c9f5e8"),
		"divider": Color("ffe14d"), "glow": 0.0,
	},
	"board_coral_reef": {
		"name": "Coral Reef", "rarity": "rare", "collection": "ocean_water", "desc": "Lagoon-blue tiles rippling around a coral frame.",
		"swatch": [Color("ff7f6b"), Color("7fe0d6"), Color("5cc9c0"), Color("1f6f8b")],
		"frame": Color("ff7f6b"), "bed": Color("1f6f8b"), "tile_a": Color("86e3d9"), "tile_b": Color("62cdc3"),
		"divider": Color("ffd6a5"), "glow": 0.0, "tile_pattern": "waves",
	},
	"board_lava_forge": {
		"name": "Lava Forge", "rarity": "legendary", "collection": "lava_fire", "desc": "Cracked basalt with molten light in every seam.",
		"swatch": [Color("2b2121"), Color("3a2f2e"), Color("ff5a1f"), Color("ffb020")],
		"frame": Color("2b2121"), "bed": Color("ff5a1f"), "tile_a": Color("3d3130"), "tile_b": Color("302625"),
		"divider": Color("ffb020"), "glow": 2.2, "tile_pattern": "cracks", "pattern_glow": Color("ff6a1a"),
	},
	"board_pumpkin_patch": {
		"name": "Pumpkin Patch", "rarity": "rare", "season": "halloween", "desc": "Pumpkin-orange frame on a midnight bed.",
		"swatch": [Color("ff7a12"), Color("ffd8a8"), Color("f4a85e"), Color("8b5cf6")],
		"frame": Color("ff7a12"), "bed": Color("2b1740"), "tile_a": Color("ffd8a8"), "tile_b": Color("f4a85e"),
		"divider": Color("8b5cf6"), "glow": 0.6, "tile_pattern": "dapple",
		"sky_top": Color("2a1d3e"), "sky_horizon": Color("ff9a5a"), "ambient": Color("e0c8f0"),
	},
	"board_candy_cane": {
		"name": "Candy Cane Lane", "rarity": "rare", "season": "christmas", "desc": "Red and white stripes with an evergreen centre line.",
		"swatch": [Color("d62f3a"), Color("fff6f6"), Color("ffdede"), Color("2f8f4e")],
		"frame": Color("d62f3a"), "bed": Color("7a1520"), "tile_a": Color("fff6f6"), "tile_b": Color("ffdede"),
		"divider": Color("2f8f4e"), "glow": 0.0, "tile_pattern": "candy",
		"sky_top": Color("6f9fe0"), "sky_horizon": Color("fff0f0"), "ambient": Color("f0e0e8"),
	},
	"board_midnight_gold": {
		"name": "Midnight Gold", "rarity": "epic", "season": "new_year", "desc": "Midnight-blue tiles flecked with gold, ready for the countdown.",
		"swatch": [Color("1d1736"), Color("2a2848"), Color("222040"), Color("ffcf3f")],
		"frame": Color("1d1736"), "bed": Color("0d0a18"), "tile_a": Color("2c2a4c"), "tile_b": Color("232144"),
		"divider": Color("ffcf3f"), "glow": 1.2, "tile_pattern": "specks", "pattern_glow": Color("ffd86a"),
		"sky_top": Color("0d0a2a"), "sky_horizon": Color("4a3a8a"), "ambient": Color("c8c0f0"),
	},
	"board_sweetheart": {
		"name": "Sweetheart", "rarity": "rare", "season": "valentines", "desc": "Blush-pink tiles stamped with little hearts.",
		"swatch": [Color("ff4f7b"), Color("ffe3ec"), Color("ffc9da"), Color("ffffff")],
		"frame": Color("ff4f7b"), "bed": Color("a8244f"), "tile_a": Color("ffe3ec"), "tile_b": Color("ffc9da"),
		"divider": Color("ffffff"), "glow": 0.0, "tile_pattern": "hearts",
		"sky_top": Color("ff9ec0"), "sky_horizon": Color("fff0f5"), "ambient": Color("f4dce8"),
	},
	"board_jade_dragon": {
		"name": "Lucky Dragon", "rarity": "epic", "season": "lunar_new_year", "desc": "Lacquer red with gold dragon scales.",
		"swatch": [Color("d62828"), Color("ffe6b8"), Color("f5cf8a"), Color("ffcf3f")],
		"frame": Color("d62828"), "bed": Color("7a0f0f"), "tile_a": Color("ffe6b8"), "tile_b": Color("f5cf8a"),
		"divider": Color("ffcf3f"), "glow": 0.6, "tile_pattern": "scales",
		"sky_top": Color("ff7a5a"), "sky_horizon": Color("ffe8c8"), "ambient": Color("f4dcc8"),
	},
	"board_harvest": {
		"name": "Harvest Table", "rarity": "rare", "season": "thanksgiving", "desc": "Woven straw tiles on a warm pumpkin frame.",
		"swatch": [Color("c8641e"), Color("f5d89a"), Color("e8c078"), Color("8a4a1e")],
		"frame": Color("c8641e"), "bed": Color("5a3218"), "tile_a": Color("f5d89a"), "tile_b": Color("e8c078"),
		"divider": Color("8a4a1e"), "glow": 0.0, "tile_pattern": "weave",
		"sky_top": Color("ff9a5a"), "sky_horizon": Color("ffe8c0"), "ambient": Color("eedcc4"),
	},
	"board_seaside": {
		"name": "Seaside", "rarity": "rare", "season": "summer", "desc": "Sandy tiles, sea-blue frame and a coral centre line.",
		"swatch": [Color("12b8c4"), Color("fff2d0"), Color("f5e2b0"), Color("ff8a5a")],
		"frame": Color("12b8c4"), "bed": Color("0a6a78"), "tile_a": Color("fff2d0"), "tile_b": Color("f5e2b0"),
		"divider": Color("ff8a5a"), "glow": 0.0, "tile_pattern": "waves",
		"sky_top": Color("2fb8ff"), "sky_horizon": Color("e8fbff"), "ambient": Color("d6eef2"),
	},
	"board_kalayaan": {
		"name": "Araw ng Kalayaan", "rarity": "epic", "season": "kalayaan", "desc": "Blue frame, red grid and a golden centre line for Independence Day.",
		"swatch": [Color("0038a8"), Color("fffdf5"), Color("ce1126"), Color("fcd116")],
		"frame": Color("0038a8"), "bed": Color("ce1126"), "tile_a": Color("fffdf5"), "tile_b": Color("f2efe4"),
		"divider": Color("fcd116"), "glow": 0.4,
		"sky_top": Color("3f8cff"), "sky_horizon": Color("fff6d8"), "ambient": Color("dcdcf0"),
	},
	"board_fiesta": {
		"name": "Fiesta", "rarity": "rare", "season": "fiesta", "desc": "A woven banig mat with festive pink and green trim.",
		"swatch": [Color("ff3d7f"), Color("fff1c9"), Color("ffe0a0"), Color("27c98f")],
		"frame": Color("ff3d7f"), "bed": Color("6a1f8a"), "tile_a": Color("fff1c9"), "tile_b": Color("ffe0a0"),
		"divider": Color("27c98f"), "glow": 0.0, "tile_pattern": "weave",
		"sky_top": Color("4fb8ff"), "sky_horizon": Color("fff2d8"), "ambient": Color("eedcec"),
	},
	"board_woodblock_sea": {
		"name": "Woodblock Sea", "rarity": "epic", "collection": "great_wave", "desc": "Indigo and cream, printed with rolling waves and a red seal line.",
		"swatch": [Color("2a4a8a"), Color("f4ead2"), Color("dfe6ea"), Color("e8341c")],
		"frame": Color("2a4a8a"), "bed": Color("1d2f5a"), "tile_a": Color("f4ead2"), "tile_b": Color("dfe6ea"),
		"divider": Color("e8341c"), "glow": 0.0, "tile_pattern": "seigaiha",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_treasure_map": {
		"name": "Treasure Map", "rarity": "rare", "collection": "treasure_seas", "desc": "Old parchment with dotted routes. X marks the spot.",
		"swatch": [Color("8a5a2a"), Color("f2dfb0"), Color("e6cc94"), Color("c8342d")],
		"frame": Color("8a5a2a"), "bed": Color("4a2a14"), "tile_a": Color("f2dfb0"), "tile_b": Color("e6cc94"),
		"divider": Color("c8342d"), "glow": 0.0, "tile_pattern": "map",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_tatami_dojo": {
		"name": "Tatami Dojo", "rarity": "rare", "collection": "samurai_ronin", "desc": "Woven straw mats on a black lacquer frame.",
		"swatch": [Color("2a1a14"), Color("dcd18c"), Color("cbc078"), Color("b8282e")],
		"frame": Color("2a1a14"), "bed": Color("1a100c"), "tile_a": Color("dcd18c"), "tile_b": Color("cbc078"),
		"divider": Color("b8282e"), "glow": 0.0, "tile_pattern": "weave",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_moonlit_roof": {
		"name": "Moonlit Roof", "rarity": "rare", "collection": "ninja_clan", "desc": "Dark roof tiles under a violet moon.",
		"swatch": [Color("2a2350"), Color("504a7a"), Color("423c6a"), Color("8b5cf6")],
		"frame": Color("2a2350"), "bed": Color("120f24"), "tile_a": Color("504a7a"), "tile_b": Color("423c6a"),
		"divider": Color("8b5cf6"), "glow": 0.8, "tile_pattern": "scales",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_circuit": {
		"name": "Circuit Board", "rarity": "epic", "collection": "cyber_neon", "desc": "Glowing cyan traces on midnight panels.",
		"swatch": [Color("141a33"), Color("1b2447"), Color("141c3a"), Color("ff2bd6")],
		"frame": Color("141a33"), "bed": Color("0a0f22"), "tile_a": Color("1b2447"), "tile_b": Color("141c3a"),
		"divider": Color("ff2bd6"), "glow": 1.8, "tile_pattern": "circuit", "pattern_glow": Color("2ef6ff"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_hazard_hangar": {
		"name": "Hangar Plate", "rarity": "rare", "collection": "giant_robots", "desc": "Riveted steel plates with a hazard-stripe centre.",
		"swatch": [Color("4f5a74"), Color("c7d0db"), Color("aeb8c6"), Color("ffb020")],
		"frame": Color("4f5a74"), "bed": Color("2a2f40"), "tile_a": Color("c7d0db"), "tile_b": Color("aeb8c6"),
		"divider": Color("ffb020"), "glow": 0.0, "tile_pattern": "panel",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_city_block": {
		"name": "Smashed City", "rarity": "epic", "collection": "kaiju_attack", "desc": "Cracked asphalt with fire glowing through.",
		"swatch": [Color("3a3f4a"), Color("6a707e"), Color("5a6070"), Color("ffd23f")],
		"frame": Color("3a3f4a"), "bed": Color("1d2028"), "tile_a": Color("6a707e"), "tile_b": Color("5a6070"),
		"divider": Color("ffd23f"), "glow": 1.2, "tile_pattern": "cracks", "pattern_glow": Color("ff6a1a"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_starship_bridge": {
		"name": "Starship Bridge", "rarity": "epic", "collection": "space_opera", "desc": "Clean white deck panels lit in blue.",
		"swatch": [Color("e8eef8"), Color("f4f7fc"), Color("dfe6f2"), Color("3ad6ff")],
		"frame": Color("e8eef8"), "bed": Color("3a4a6a"), "tile_a": Color("f4f7fc"), "tile_b": Color("dfe6f2"),
		"divider": Color("3ad6ff"), "glow": 1.6, "tile_pattern": "panel",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_chrome_sunset": {
		"name": "Chrome Sunset", "rarity": "epic", "collection": "synthwave", "desc": "A violet grid glowing pink, with a sunset-orange line.",
		"swatch": [Color("ff4fa8"), Color("3a1a5a"), Color("2a1048"), Color("ffb020")],
		"frame": Color("ff4fa8"), "bed": Color("1a0b2e"), "tile_a": Color("3a1a5a"), "tile_b": Color("2a1048"),
		"divider": Color("ffb020"), "glow": 1.8, "tile_pattern": "panel_glow", "pattern_glow": Color("ff4fa8"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_pixel_arcade": {
		"name": "Pixel Field", "rarity": "rare", "collection": "arcade_8bit", "desc": "Chunky green pixels on an arcade-blue frame.",
		"swatch": [Color("2f3fbf"), Color("7fe08a"), Color("62c86e"), Color("ffd23f")],
		"frame": Color("2f3fbf"), "bed": Color("101a5a"), "tile_a": Color("7fe08a"), "tile_b": Color("62c86e"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "pixel",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_saloon_floor": {
		"name": "Saloon Floor", "rarity": "rare", "collection": "wild_west", "desc": "Dusty plank floors from the frontier.",
		"swatch": [Color("8a4a1e"), Color("d8a868"), Color("c8945a"), Color("ffcf3f")],
		"frame": Color("8a4a1e"), "bed": Color("4a2410"), "tile_a": Color("d8a868"), "tile_b": Color("c8945a"),
		"divider": Color("ffcf3f"), "glow": 0.0, "tile_pattern": "planks",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_brass_gears": {
		"name": "Brass Workshop", "rarity": "epic", "collection": "steampunk", "desc": "Riveted brass plates with a verdigris line.",
		"swatch": [Color("b8862e"), Color("e8c890"), Color("d8b070"), Color("3fbfa0")],
		"frame": Color("b8862e"), "bed": Color("4a2a14"), "tile_a": Color("e8c890"), "tile_b": Color("d8b070"),
		"divider": Color("3fbfa0"), "glow": 0.0, "tile_pattern": "panel",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_runestone": {
		"name": "Runestone", "rarity": "rare", "collection": "norse_vikings", "desc": "Grey stone carved with runes that glow ice-blue.",
		"swatch": [Color("5a6070"), Color("c9cfd6"), Color("b4bcc6"), Color("7fd6ff")],
		"frame": Color("5a6070"), "bed": Color("2a2f3a"), "tile_a": Color("c9cfd6"), "tile_b": Color("b4bcc6"),
		"divider": Color("7fd6ff"), "glow": 0.8, "tile_pattern": "glyphs",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_sandstone_glyphs": {
		"name": "Temple Sandstone", "rarity": "epic", "collection": "ancient_egypt", "desc": "Carved sandstone on a lapis and gold frame.",
		"swatch": [Color("d49a1a"), Color("f2d8a0"), Color("e6c484"), Color("1f6bd6")],
		"frame": Color("d49a1a"), "bed": Color("1f3a8a"), "tile_a": Color("f2d8a0"), "tile_b": Color("e6c484"),
		"divider": Color("1f6bd6"), "glow": 0.0, "tile_pattern": "glyphs",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_olympus_marble": {
		"name": "Olympus Marble", "rarity": "epic", "collection": "greek_gods", "desc": "White marble trimmed with gold.",
		"swatch": [Color("f4f5ff"), Color("ffffff"), Color("e8ecf5"), Color("ffcf3f")],
		"frame": Color("f4f5ff"), "bed": Color("c9a24a"), "tile_a": Color("ffffff"), "tile_b": Color("e8ecf5"),
		"divider": Color("ffcf3f"), "glow": 0.8, "tile_pattern": "veins",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_balete_wood": {
		"name": "Enchanted Grove", "rarity": "rare", "collection": "philippine_myths", "desc": "Mossy wood and a line of firefly light.",
		"swatch": [Color("5a3a24"), Color("7a9a4a"), Color("6a8a3e"), Color("c8ff6a")],
		"frame": Color("5a3a24"), "bed": Color("2a1a10"), "tile_a": Color("7a9a4a"), "tile_b": Color("6a8a3e"),
		"divider": Color("c8ff6a"), "glow": 1.2, "tile_pattern": "dapple",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_halftone_pop": {
		"name": "Halftone Pop", "rarity": "rare", "collection": "comic_hero", "desc": "Bright comic-page yellow, dotted like a print.",
		"swatch": [Color("e8341c"), Color("fff36b"), Color("ffe14d"), Color("3d8bff")],
		"frame": Color("e8341c"), "bed": Color("1d1736"), "tile_a": Color("fff36b"), "tile_b": Color("ffe14d"),
		"divider": Color("3d8bff"), "glow": 0.0, "tile_pattern": "halftone",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_quarantine": {
		"name": "Quarantine Zone", "rarity": "rare", "collection": "zombie_outbreak", "desc": "Rusty plates, green cracks and hazard tape.",
		"swatch": [Color("6a6f5a"), Color("9aa07a"), Color("8a906a"), Color("ffd23f")],
		"frame": Color("6a6f5a"), "bed": Color("2a2d24"), "tile_a": Color("9aa07a"), "tile_b": Color("8a906a"),
		"divider": Color("ffd23f"), "glow": 0.0, "tile_pattern": "cracks", "pattern_glow": Color("9be15d"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_pastel_ribbon": {
		"name": "Pastel Sparkle", "rarity": "rare", "collection": "magical_sparkle", "desc": "Pink and cream with twinkling stars.",
		"swatch": [Color("ff8ec0"), Color("fff0fa"), Color("ffe0f2"), Color("ffd23f")],
		"frame": Color("ff8ec0"), "bed": Color("8a5cff"), "tile_a": Color("fff0fa"), "tile_b": Color("ffe0f2"),
		"divider": Color("ffd23f"), "glow": 0.8, "tile_pattern": "specks", "pattern_glow": Color("ffffff"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_stage_lights": {
		"name": "Stage Lights", "rarity": "epic", "collection": "concert_stage", "desc": "A glossy black stage with violet LED panels.",
		"swatch": [Color("1d1736"), Color("2a2350"), Color("221c44"), Color("ff2bd6")],
		"frame": Color("1d1736"), "bed": Color("0a0814"), "tile_a": Color("2a2350"), "tile_b": Color("221c44"),
		"divider": Color("ff2bd6"), "glow": 2.0, "tile_pattern": "panel_glow", "pattern_glow": Color("b84dff"),
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_brick_wall": {
		"name": "Brick Wall", "rarity": "rare", "collection": "street_graffiti", "desc": "City brickwork with a mint spray-paint line.",
		"swatch": [Color("3a3f4a"), Color("c8644a"), Color("b8563e"), Color("4dffb0")],
		"frame": Color("3a3f4a"), "bed": Color("2a2a2a"), "tile_a": Color("c8644a"), "tile_b": Color("b8563e"),
		"divider": Color("4dffb0"), "glow": 0.0, "tile_pattern": "bricks",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
	"board_castle_stone": {
		"name": "Castle Stone", "rarity": "epic", "collection": "fantasy_kingdom", "desc": "Grey castle stone with a royal blue and gold frame.",
		"swatch": [Color("2f4fae"), Color("d8dbe6"), Color("c4c9d6"), Color("ffcf3f")],
		"frame": Color("2f4fae"), "bed": Color("1d2a6a"), "tile_a": Color("d8dbe6"), "tile_b": Color("c4c9d6"),
		"divider": Color("ffcf3f"), "glow": 0.0, "tile_pattern": "bricks",
		"sky_top": Color("3f8cff"), "sky_horizon": Color("ffe1c4"), "ambient": Color("dccfee"),
	},
}

## How one player's half of the board looks (rows 0–3 for white, 4–7 for black). Both players see
## both halves. "default" keeps the board theme's own tiles.
const TERRITORIES := {
	"default": {
		"name": "Board default", "rarity": "common", "collection": "classics", "desc": "Your half matches the board theme.",
		"swatch": [Color("ffcf8f"), Color("f4ac66")],
	},
	"territory_ember": {
		"name": "Ember Ground", "rarity": "epic", "collection": "lava_fire", "desc": "Scorched earth with embers glowing in the cracks.",
		"swatch": [Color("5a2a22"), Color("4a221c"), Color("ff6a1a")],
		"tile_a": Color("62302a"), "tile_b": Color("50251f"), "pattern": "cracks", "pattern_glow": Color("ff6a1a"),
	},
	"territory_frost": {
		"name": "Frostbite", "rarity": "rare", "collection": "ice_snow", "desc": "Frozen tiles laced with ice.",
		"swatch": [Color("dff4ff"), Color("c4e8ff"), Color("7fc8ef")],
		"tile_a": Color("e6f7ff"), "tile_b": Color("c9eaff"), "pattern": "veins",
	},
	"territory_meadow": {
		"name": "Spring Meadow", "rarity": "common", "collection": "nature_garden", "desc": "Fresh green grass for your army to stand on.",
		"swatch": [Color("9fdc6a"), Color("86c955")],
		"tile_a": Color("a5e070"), "tile_b": Color("8ccd5c"), "pattern": "dapple",
	},
	"territory_royal_gold": {
		"name": "Gilded Court", "rarity": "epic", "collection": "fantasy_kingdom", "desc": "Polished gold squares fit for a five-star general.",
		"swatch": [Color("ffe9a8"), Color("f2cf6a"), Color("d9a441")],
		"tile_a": Color("ffe7a0"), "tile_b": Color("f0c95e"), "pattern": "dapple", "shine": 0.6,
	},
	"territory_neon_grid": {
		"name": "Neon Grid", "rarity": "epic", "collection": "cyber_neon", "desc": "Dark panels with a glowing cyan circuit grid.",
		"swatch": [Color("141a33"), Color("1b2244"), Color("2ef6ff")],
		"tile_a": Color("19213d"), "tile_b": Color("141a33"), "pattern": "panel_glow", "pattern_glow": Color("2ef6ff"),
	},
	"territory_sakura": {
		"name": "Sakura Garden", "rarity": "rare", "collection": "sakura_blossom", "desc": "Blossom-pink stones dappled with petals.",
		"swatch": [Color("ffd6e6"), Color("ffc2da"), Color("ff8fb8")],
		"tile_a": Color("ffdbe9"), "tile_b": Color("ffc4dc"), "pattern": "dapple",
	},
	"territory_ocean": {
		"name": "Ocean Tide", "rarity": "rare", "collection": "ocean_water", "desc": "Rippling blue water under your pieces.",
		"swatch": [Color("5fc3e4"), Color("49aed3"), Color("2a7fb0")],
		"tile_a": Color("62c6e6"), "tile_b": Color("48add2"), "pattern": "waves",
	},
	"territory_starfield": {
		"name": "Starfield", "rarity": "legendary", "collection": "space_opera", "desc": "Deep space with twinkling stars.",
		"swatch": [Color("141433"), Color("1b1a40"), Color("ffffff")],
		"tile_a": Color("1a1a40"), "tile_b": Color("131332"), "pattern": "specks", "pattern_glow": Color("ffffff"),
	},
	"territory_toxic": {
		"name": "Toxic Spill", "rarity": "epic", "collection": "zombie_outbreak", "desc": "Bubbling green sludge with glowing seams.",
		"swatch": [Color("7ddc3a"), Color("66c42e"), Color("d4ff3a")],
		"tile_a": Color("5fa82b"), "tile_b": Color("4f9423"), "pattern": "cracks", "pattern_glow": Color("c8ff2e"),
	},
	"territory_desert": {
		"name": "Desert Dunes", "rarity": "common", "collection": "ancient_egypt", "desc": "Wind-rippled sand.",
		"swatch": [Color("f3d79a"), Color("e8c785")],
		"tile_a": Color("f5da9d"), "tile_b": Color("e6c27f"), "pattern": "waves",
	},
	"territory_candy": {
		"name": "Cotton Candy", "rarity": "common", "collection": "cute_candy", "desc": "Pastel pink and sky-blue squares.",
		"swatch": [Color("ffe0f0"), Color("d8f0ff")],
		"tile_a": Color("ffe0f0"), "tile_b": Color("d4efff"),
	},
	"territory_graveyard": {
		"name": "Graveyard Soil", "rarity": "rare", "season": "halloween", "desc": "Dark cracked soil glowing an eerie green.",
		"swatch": [Color("4a3f5e"), Color("3d3350"), Color("7dff9a")],
		"tile_a": Color("4a3f5e"), "tile_b": Color("3d3350"), "pattern": "cracks", "pattern_glow": Color("7dff9a"),
	},
	"territory_fresh_snow": {
		"name": "Fresh Snow", "rarity": "common", "season": "christmas", "desc": "Soft, sparkly new snow on your half.",
		"swatch": [Color("f7fbff"), Color("e2eef9"), Color("bfe3ff")],
		"tile_a": Color("f7fbff"), "tile_b": Color("e2eef9"), "pattern": "dapple",
	},
	"territory_midnight": {
		"name": "Countdown Night", "rarity": "rare", "season": "new_year", "desc": "Your half becomes a starry midnight sky.",
		"swatch": [Color("1f1d3a"), Color("18162f"), Color("ffcf3f")],
		"tile_a": Color("26244a"), "tile_b": Color("1e1c3c"), "pattern": "specks", "pattern_glow": Color("ffd86a"),
	},
	"territory_rose_petals": {
		"name": "Love Letters", "rarity": "common", "season": "valentines", "desc": "Soft pink tiles covered in hearts.",
		"swatch": [Color("ffd6e4"), Color("ffc0d4"), Color("ff4f7b")],
		"tile_a": Color("ffd6e4"), "tile_b": Color("ffc0d4"), "pattern": "hearts",
	},
	"territory_red_scales": {
		"name": "Dragon Scales", "rarity": "rare", "season": "lunar_new_year", "desc": "Your half wears lucky red dragon scales.",
		"swatch": [Color("e8443a"), Color("d6302a"), Color("ffcf3f")],
		"tile_a": Color("e8443a"), "tile_b": Color("d6302a"), "pattern": "scales",
	},
	"territory_wheat_field": {
		"name": "Wheat Field", "rarity": "common", "season": "thanksgiving", "desc": "Golden wheat stubble after the harvest.",
		"swatch": [Color("f2d27a"), Color("e6c05a"), Color("c8941e")],
		"tile_a": Color("f2d27a"), "tile_b": Color("e6c05a"), "pattern": "dapple",
	},
	"territory_beach_sand": {
		"name": "Beach Sand", "rarity": "common", "season": "summer", "desc": "Warm sand rippled by the tide.",
		"swatch": [Color("fbe8b8"), Color("f2d79a"), Color("12b8c4")],
		"tile_a": Color("fbe8b8"), "tile_b": Color("f2d79a"), "pattern": "waves",
	},
	"territory_sunrise": {
		"name": "Golden Sunrise", "rarity": "rare", "season": "kalayaan", "desc": "Warm golden tiles, bright as the morning sun.",
		"swatch": [Color("fff3c0"), Color("ffe68a"), Color("fcd116")],
		"tile_a": Color("fff3c0"), "tile_b": Color("ffe68a"), "pattern": "dapple",
	},
	"territory_banig": {
		"name": "Banig Mat", "rarity": "common", "season": "fiesta", "desc": "A hand-woven sleeping mat in fiesta colours.",
		"swatch": [Color("f5d79e"), Color("e8b870"), Color("ff3d7f")],
		"tile_a": Color("f5d79e"), "tile_b": Color("e8b870"), "pattern": "weave",
	},
	"territory_indigo_waves": {
		"name": "Indigo Waves", "rarity": "rare", "collection": "great_wave", "desc": "Rolling woodblock waves in indigo.",
		"swatch": [Color("5a7abe"), Color("4a6aae")],
		"tile_a": Color("5a7abe"), "tile_b": Color("4a6aae"), "pattern": "seigaiha",
	},
	"territory_ship_planks": {
		"name": "Ship Planks", "rarity": "common", "collection": "treasure_seas", "desc": "The deck of a sturdy ship.",
		"swatch": [Color("b77a45"), Color("a86c3a")],
		"tile_a": Color("b77a45"), "tile_b": Color("a86c3a"), "pattern": "planks",
	},
	"territory_raked_gravel": {
		"name": "Raked Gravel", "rarity": "common", "collection": "samurai_ronin", "desc": "A calm zen garden, freshly raked.",
		"swatch": [Color("e2e2da"), Color("d2d2c8")],
		"tile_a": Color("e2e2da"), "tile_b": Color("d2d2c8"), "pattern": "waves",
	},
	"territory_night_tiles": {
		"name": "Night Tiles", "rarity": "rare", "collection": "ninja_clan", "desc": "Rooftop tiles in the dead of night.",
		"swatch": [Color("48437a"), Color("3e3a6c")],
		"tile_a": Color("48437a"), "tile_b": Color("3e3a6c"), "pattern": "scales",
	},
	"territory_hangar_deck": {
		"name": "Hangar Deck", "rarity": "common", "collection": "giant_robots", "desc": "Riveted deck plating.",
		"swatch": [Color("8a94a6"), Color("7a8496")],
		"tile_a": Color("8a94a6"), "tile_b": Color("7a8496"), "pattern": "panel",
	},
	"territory_scorched_city": {
		"name": "Scorched Street", "rarity": "epic", "collection": "kaiju_attack", "desc": "Cracked asphalt with fire below.",
		"swatch": [Color("4a4f5a"), Color("3f444e"), Color("ff6a1a")],
		"tile_a": Color("4a4f5a"), "tile_b": Color("3f444e"), "pattern": "cracks", "pattern_glow": Color("ff6a1a"),
	},
	"territory_hull_plating": {
		"name": "Hull Plating", "rarity": "rare", "collection": "space_opera", "desc": "White starship hull panels.",
		"swatch": [Color("e2e8f4"), Color("d2dae8")],
		"tile_a": Color("e2e8f4"), "tile_b": Color("d2dae8"), "pattern": "panel",
	},
	"territory_pink_grid": {
		"name": "Sunset Grid", "rarity": "epic", "collection": "synthwave", "desc": "A pink neon grid on violet.",
		"swatch": [Color("2a1048"), Color("22093c"), Color("ff4fa8")],
		"tile_a": Color("2a1048"), "tile_b": Color("22093c"), "pattern": "panel_glow", "pattern_glow": Color("ff4fa8"),
	},
	"territory_pixel_grass": {
		"name": "Pixel Grass", "rarity": "common", "collection": "arcade_8bit", "desc": "Blocky green grass.",
		"swatch": [Color("6fd06a"), Color("5fc05a")],
		"tile_a": Color("6fd06a"), "tile_b": Color("5fc05a"), "pattern": "pixel",
	},
	"territory_dusty_planks": {
		"name": "Dusty Boardwalk", "rarity": "common", "collection": "wild_west", "desc": "A sun-bleached boardwalk.",
		"swatch": [Color("d8b070"), Color("c8a060")],
		"tile_a": Color("d8b070"), "tile_b": Color("c8a060"), "pattern": "planks",
	},
	"territory_copper_plates": {
		"name": "Copper Plates", "rarity": "rare", "collection": "steampunk", "desc": "Riveted copper sheets.",
		"swatch": [Color("c87a3a"), Color("b86c30")],
		"tile_a": Color("c87a3a"), "tile_b": Color("b86c30"), "pattern": "panel",
	},
	"territory_frost_runes": {
		"name": "Frost Runes", "rarity": "rare", "collection": "norse_vikings", "desc": "Frozen stone carved with runes.",
		"swatch": [Color("dfe8f0"), Color("cfdce8")],
		"tile_a": Color("dfe8f0"), "tile_b": Color("cfdce8"), "pattern": "glyphs",
	},
	"territory_lapis_gold": {
		"name": "Lapis & Gold", "rarity": "epic", "collection": "ancient_egypt", "desc": "Deep blue lapis flecked with gold.",
		"swatch": [Color("2f5fbf"), Color("2a54ab"), Color("f2c14e")],
		"tile_a": Color("2f5fbf"), "tile_b": Color("2a54ab"), "pattern": "specks", "pattern_glow": Color("f2c14e"),
	},
	"territory_cloud_marble": {
		"name": "Cloud Marble", "rarity": "rare", "collection": "greek_gods", "desc": "Soft white marble, light as a cloud.",
		"swatch": [Color("f6f8ff"), Color("e6ecf8")],
		"tile_a": Color("f6f8ff"), "tile_b": Color("e6ecf8"), "pattern": "veins",
	},
	"territory_moss_fireflies": {
		"name": "Firefly Moss", "rarity": "epic", "collection": "philippine_myths", "desc": "Forest moss twinkling with fireflies.",
		"swatch": [Color("5a8a3a"), Color("4f7f32"), Color("c8ff6a")],
		"tile_a": Color("5a8a3a"), "tile_b": Color("4f7f32"), "pattern": "specks", "pattern_glow": Color("c8ff6a"),
	},
	"territory_comic_panels": {
		"name": "Comic Panels", "rarity": "common", "collection": "comic_hero", "desc": "Clean comic-book dots.",
		"swatch": [Color("ffffff"), Color("f0f0f0")],
		"tile_a": Color("ffffff"), "tile_b": Color("f0f0f0"), "pattern": "halftone",
	},
	"territory_stardust_lilac": {
		"name": "Stardust Lilac", "rarity": "rare", "collection": "magical_sparkle", "desc": "Lilac stone full of sparkles.",
		"swatch": [Color("e6d4ff"), Color("dcc6ff"), Color("ffffff")],
		"tile_a": Color("e6d4ff"), "tile_b": Color("dcc6ff"), "pattern": "specks", "pattern_glow": Color("ffffff"),
	},
	"territory_led_floor": {
		"name": "LED Floor", "rarity": "epic", "collection": "concert_stage", "desc": "A stage floor of cyan LED squares.",
		"swatch": [Color("221c44"), Color("1a1438"), Color("3ad6ff")],
		"tile_a": Color("221c44"), "tile_b": Color("1a1438"), "pattern": "panel_glow", "pattern_glow": Color("3ad6ff"),
	},
	"territory_skate_concrete": {
		"name": "Skate Concrete", "rarity": "common", "collection": "street_graffiti", "desc": "Smooth skate-park concrete.",
		"swatch": [Color("c9ccd2"), Color("bcc0c8")],
		"tile_a": Color("c9ccd2"), "tile_b": Color("bcc0c8"), "pattern": "dapple",
	},
}

## Each skin has a light team (white) and a dark team (black) so sides read at a glance.
## body: the plaque; base: team accent stand; ink: emblem; label / label_outline: rank text;
## shine: toon highlight strength; glow: emission on the body; pattern / pattern_glow: procedural
## texture; outline / outline_glow: coloured (neon) outline instead of ink.
const PIECE_SKINS := {
	"pieces_classic_wood": {
		"name": "Classic Wooden Tokens", "rarity": "common", "collection": "classics", "desc": "Cream and plum toy blocks.",
		"swatch": [Color("fff0cf"), Color("3fa9ff"), Color("3d3760"), Color("ff4f72")],
		"white": {"body": Color("fff0cf"), "base": Color("3fa9ff"), "ink": Color("ffa400"), "label": Color("2a2350"), "label_outline": Color("fff3d6"), "shine": 0.25},
		"black": {"body": Color("3d3760"), "base": Color("ff4f72"), "ink": Color("ffc93c"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.25},
	},
	"pieces_brass_gold": {
		"name": "Polished Brass/Gold", "rarity": "rare", "collection": "royal_gold", "desc": "Gleaming brass against gunmetal.",
		"swatch": [Color("ffcd4a"), Color("ff7a3d"), Color("4f5a74"), Color("8f6dff")],
		"white": {"body": Color("ffcd4a"), "base": Color("ff7a3d"), "ink": Color("ff3f5e"), "label": Color("6b3600"), "label_outline": Color("ffe9a8"), "shine": 0.9},
		"black": {"body": Color("4f5a74"), "base": Color("8f6dff"), "ink": Color("ffd54a"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.8},
	},
	"pieces_holo_glass": {
		"name": "Holographic Glass", "rarity": "epic", "collection": "cyber_neon", "desc": "Glowing cyan and magenta glass.",
		"swatch": [Color("7ff4ff"), Color("1b9cff"), Color("ff8ae0"), Color("b84dff")],
		"white": {"body": Color("7ff4ff"), "base": Color("1b9cff"), "ink": Color("1c47d6"), "label": Color("0b2f6b"), "label_outline": Color("e8fdff"), "shine": 0.6, "glow": Color("2ee6ff")},
		"black": {"body": Color("ff8ae0"), "base": Color("b84dff"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("4a0f4a"), "shine": 0.6, "glow": Color("ff3bd0")},
	},
	"pieces_obsidian": {
		"name": "Obsidian & Quartz", "rarity": "epic", "collection": "royal_gold", "desc": "Veined white quartz versus glossy black glass.",
		"swatch": [Color("ece8f6"), Color("9b7bff"), Color("1c1a26"), Color("7a3cff")],
		"white": {"body": Color("ece8f6"), "base": Color("9b7bff"), "ink": Color("6a4bd6"), "label": Color("2a2350"), "label_outline": Color("ffffff"), "shine": 0.8, "pattern": "veins"},
		"black": {"body": Color("24212f"), "base": Color("7a3cff"), "ink": Color("c9b6ff"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.95, "pattern": "veins"},
	},
	"pieces_jade": {
		"name": "Imperial Jade", "rarity": "rare", "collection": "royal_gold", "desc": "Pale and deep jade with gold stands.",
		"swatch": [Color("c2f2d8"), Color("e0aa3e"), Color("1f7a55"), Color("f2c14e")],
		"white": {"body": Color("c2f2d8"), "base": Color("e0aa3e"), "ink": Color("2a8a5c"), "label": Color("1d4a33"), "label_outline": Color("f0fff6"), "shine": 0.7, "pattern": "veins"},
		"black": {"body": Color("1f7a55"), "base": Color("f2c14e"), "ink": Color("ffe28a"), "label": Color("ffffff"), "label_outline": Color("0f3324"), "shine": 0.7, "pattern": "veins"},
	},
	"pieces_candy": {
		"name": "Candy Pop", "rarity": "common", "collection": "cute_candy", "desc": "Bubblegum pink versus grape, with mint and lemon stands.",
		"swatch": [Color("ffd1ea"), Color("6fe3c7"), Color("8e4bd9"), Color("ffe14d")],
		"white": {"body": Color("ffd1ea"), "base": Color("6fe3c7"), "ink": Color("ff4f9a"), "label": Color("7a1f4f"), "label_outline": Color("fff4fa"), "shine": 0.55},
		"black": {"body": Color("8e4bd9"), "base": Color("ffe14d"), "ink": Color("ffe14d"), "label": Color("ffffff"), "label_outline": Color("3b1766"), "shine": 0.55},
	},
	"pieces_ice_crystal": {
		"name": "Ice Crystal", "rarity": "epic", "collection": "ice_snow", "desc": "Frosted crystal that glows from inside.",
		"swatch": [Color("e6faff"), Color("7fd6ff"), Color("2f5d9e"), Color("bfefff")],
		"white": {"body": Color("e6faff"), "base": Color("7fd6ff"), "ink": Color("3aa7e6"), "label": Color("0f3f66"), "label_outline": Color("ffffff"), "shine": 0.85, "glow": Color("9ef3ff"), "pattern": "veins"},
		"black": {"body": Color("2f5d9e"), "base": Color("bfefff"), "ink": Color("bfefff"), "label": Color("ffffff"), "label_outline": Color("0d2445"), "shine": 0.85, "glow": Color("3a8dff"), "pattern": "veins"},
	},
	"pieces_lava_rock": {
		"name": "Lava Rock", "rarity": "legendary", "collection": "lava_fire", "desc": "Pumice and basalt with molten cracks.",
		"swatch": [Color("cbbfb4"), Color("ff7b2e"), Color("2a2224"), Color("ff3b1f")],
		"white": {"body": Color("cbbfb4"), "base": Color("ff7b2e"), "ink": Color("ff5a1f"), "label": Color("3a2420"), "label_outline": Color("fff1e6"), "shine": 0.3, "pattern": "cracks", "pattern_glow": Color("ff7a1a")},
		"black": {"body": Color("2e2527"), "base": Color("ff3b1f"), "ink": Color("ffb020"), "label": Color("ffffff"), "label_outline": Color("1a1012"), "shine": 0.35, "pattern": "cracks", "pattern_glow": Color("ff4a14")},
	},
	"pieces_carbon_fiber": {
		"name": "Carbon Fiber", "rarity": "rare", "collection": "giant_robots", "desc": "Race-car weave: silver/red versus black/green.",
		"swatch": [Color("dde1e8"), Color("e8344e"), Color("2b2e33"), Color("3cff8f")],
		"white": {"body": Color("dde1e8"), "base": Color("e8344e"), "ink": Color("e8344e"), "label": Color("2b2e33"), "label_outline": Color("ffffff"), "shine": 0.85, "pattern": "weave"},
		"black": {"body": Color("34383e"), "base": Color("3cff8f"), "ink": Color("3cff8f"), "label": Color("ffffff"), "label_outline": Color("121417"), "shine": 0.85, "pattern": "weave"},
	},
	"pieces_pearl": {
		"name": "Pearl", "rarity": "rare", "collection": "ocean_water", "desc": "Lustrous white pearl versus black pearl.",
		"swatch": [Color("fff7f2"), Color("ff9ec7"), Color("33343f"), Color("4fd1c5")],
		"white": {"body": Color("fff7f2"), "base": Color("ff9ec7"), "ink": Color("ff7ab0"), "label": Color("5a3048"), "label_outline": Color("ffffff"), "shine": 1.0, "pattern": "dapple"},
		"black": {"body": Color("363744"), "base": Color("4fd1c5"), "ink": Color("8ef0e6"), "label": Color("ffffff"), "label_outline": Color("17181f"), "shine": 1.0, "pattern": "dapple"},
	},
	"pieces_sakura": {
		"name": "Sakura Blossom", "rarity": "rare", "collection": "sakura_blossom", "desc": "Blossom pink and plum wood on leafy stands.",
		"swatch": [Color("ffe3ee"), Color("78c46b"), Color("5a2742"), Color("ff8fb8")],
		"white": {"body": Color("ffe3ee"), "base": Color("78c46b"), "ink": Color("ff6f9f"), "label": Color("6b2445"), "label_outline": Color("fff6fa"), "shine": 0.4, "pattern": "dapple"},
		"black": {"body": Color("5a2742"), "base": Color("ff8fb8"), "ink": Color("ffc2d8"), "label": Color("ffffff"), "label_outline": Color("2a0f1f"), "shine": 0.4, "pattern": "dapple"},
	},
	"pieces_galaxy": {
		"name": "Galaxy", "rarity": "legendary", "collection": "space_opera", "desc": "Lilac nebula versus deep space, full of stars.",
		"swatch": [Color("c8b8ff"), Color("5d7bff"), Color("1b1440"), Color("b05cff")],
		"white": {"body": Color("c8b8ff"), "base": Color("5d7bff"), "ink": Color("5d3bd6"), "label": Color("241554"), "label_outline": Color("f4f0ff"), "shine": 0.6, "pattern": "specks", "pattern_glow": Color("ffffff")},
		"black": {"body": Color("221a52"), "base": Color("b05cff"), "ink": Color("e0c6ff"), "label": Color("ffffff"), "label_outline": Color("0d0a24"), "shine": 0.6, "pattern": "specks", "pattern_glow": Color("ffffff"), "glow": Color("3b2a9e")},
	},
	"pieces_neon_wireframe": {
		"name": "Neon Wireframe", "rarity": "legendary", "collection": "synthwave", "desc": "Dark chips outlined in glowing cyan or magenta neon.",
		"swatch": [Color("1a2440"), Color("2ef6ff"), Color("2a1238"), Color("ff3bd6")],
		"white": {"body": Color("1b2747"), "base": Color("123a52"), "ink": Color("2ef6ff"), "label": Color("2ef6ff"), "label_outline": Color("0a1226"), "shine": 0.5, "outline": Color("2ef6ff"), "outline_glow": 2.4, "pattern": "panel_glow", "pattern_glow": Color("2ef6ff")},
		"black": {"body": Color("2c1239"), "base": Color("4a1250"), "ink": Color("ff3bd6"), "label": Color("ff7ae6"), "label_outline": Color("17061f"), "shine": 0.5, "outline": Color("ff3bd6"), "outline_glow": 2.4, "pattern": "panel_glow", "pattern_glow": Color("ff3bd6")},
	},
	"pieces_royal_gold": {
		"name": "Royal Court", "rarity": "epic", "collection": "fantasy_kingdom", "desc": "Ivory versus royal purple, both on gold.",
		"swatch": [Color("fff4dc"), Color("e0a520"), Color("4a1e6b"), Color("f0c03a")],
		"white": {"body": Color("fff4dc"), "base": Color("e0a520"), "ink": Color("c98a12"), "label": Color("5a3a08"), "label_outline": Color("ffffff"), "shine": 0.7},
		"black": {"body": Color("4f2073"), "base": Color("f0c03a"), "ink": Color("f0c03a"), "label": Color("ffe9a8"), "label_outline": Color("24093a"), "shine": 0.7},
	},
	"pieces_jack_o_lantern": {
		"name": "Jack-o'-Lantern", "rarity": "rare", "season": "halloween", "desc": "Pumpkin orange against a witchy purple-black.",
		"swatch": [Color("ff8a1f"), Color("2b1740"), Color("2b2140"), Color("7dff9a")],
		"white": {"body": Color("ff8a1f"), "base": Color("2b1740"), "ink": Color("2b1740"), "label": Color("2b1740"), "label_outline": Color("ffe0b8"), "shine": 0.35},
		"black": {"body": Color("2b2140"), "base": Color("ff7a12"), "ink": Color("7dff9a"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.35},
	},
	"pieces_gingerbread": {
		"name": "Gingerbread", "rarity": "rare", "season": "christmas", "desc": "Fresh-baked cookies with white and green icing.",
		"swatch": [Color("c8803f"), Color("ffffff"), Color("7a4a26"), Color("2f8f4e")],
		"white": {"body": Color("c8803f"), "base": Color("ffffff"), "ink": Color("e63946"), "label": Color("4a2a12"), "label_outline": Color("fff4e0"), "shine": 0.2},
		"black": {"body": Color("7a4a26"), "base": Color("2f8f4e"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("3a1f0a"), "shine": 0.2},
	},
	"pieces_champagne": {
		"name": "Champagne Toast", "rarity": "epic", "season": "new_year", "desc": "Bubbly gold against midnight blue.",
		"swatch": [Color("fff3c4"), Color("1d1736"), Color("ffcf3f"), Color("d4a017")],
		"white": {"body": Color("fff3c4"), "base": Color("1d1736"), "ink": Color("d4a017"), "label": Color("3a2a00"), "label_outline": Color("ffffff"), "shine": 0.9},
		"black": {"body": Color("1d1736"), "base": Color("ffcf3f"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("0d0a18"), "shine": 0.9},
	},
	"pieces_sweetheart": {
		"name": "Sweethearts", "rarity": "rare", "season": "valentines", "desc": "Candy-heart pink and deep rose.",
		"swatch": [Color("ffe3ec"), Color("ff4f7b"), Color("a8244f"), Color("ffc9da")],
		"white": {"body": Color("ffe3ec"), "base": Color("ff4f7b"), "ink": Color("ff2f5f"), "label": Color("6b1030"), "label_outline": Color("ffffff"), "shine": 0.6},
		"black": {"body": Color("a8244f"), "base": Color("ffc9da"), "ink": Color("ffe3ec"), "label": Color("ffffff"), "label_outline": Color("4a0a20"), "shine": 0.6},
	},
	"pieces_red_gold": {
		"name": "Red & Gold", "rarity": "rare", "season": "lunar_new_year", "desc": "Lucky red lacquer with gold trim.",
		"swatch": [Color("fff1d0"), Color("d62828"), Color("b81d1d"), Color("ffcf3f")],
		"white": {"body": Color("fff1d0"), "base": Color("d62828"), "ink": Color("d62828"), "label": Color("6a0a0a"), "label_outline": Color("ffffff"), "shine": 0.7},
		"black": {"body": Color("b81d1d"), "base": Color("ffcf3f"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("4a0505"), "shine": 0.8},
	},
	"pieces_harvest": {
		"name": "Harvest Basket", "rarity": "rare", "season": "thanksgiving", "desc": "Woven wicker and roasted chestnut.",
		"swatch": [Color("f8e3b0"), Color("c8641e"), Color("7a4220"), Color("f2b84a")],
		"white": {"body": Color("f8e3b0"), "base": Color("c8641e"), "ink": Color("8a4a1e"), "label": Color("4a2a10"), "label_outline": Color("fff6e0"), "shine": 0.25, "pattern": "weave"},
		"black": {"body": Color("7a4220"), "base": Color("f2b84a"), "ink": Color("f2b84a"), "label": Color("ffffff"), "label_outline": Color("2a1408"), "shine": 0.25, "pattern": "weave"},
	},
	"pieces_pastel_easter": {
		"name": "Painted Eggs", "rarity": "rare", "season": "summer", "desc": "Soft pastel shells with dappled paint.",
		"swatch": [Color("fff7fb"), Color("8fd8ff"), Color("b8a6ff"), Color("ffe38a")],
		"white": {"body": Color("fff7fb"), "base": Color("8fd8ff"), "ink": Color("ff8ec0"), "label": Color("4a3a6a"), "label_outline": Color("ffffff"), "shine": 0.5, "pattern": "dapple"},
		"black": {"body": Color("b8a6ff"), "base": Color("ffe38a"), "ink": Color("fffbe6"), "label": Color("ffffff"), "label_outline": Color("3a2a7a"), "shine": 0.5, "pattern": "dapple"},
	},
	"pieces_kalayaan": {
		"name": "Sun & Stars", "rarity": "epic", "season": "kalayaan", "desc": "White and blue with golden sun-and-star emblems.",
		"swatch": [Color("fffdf5"), Color("0038a8"), Color("ce1126"), Color("fcd116")],
		"white": {"body": Color("fffdf5"), "base": Color("0038a8"), "ink": Color("fcd116"), "label": Color("0038a8"), "label_outline": Color("ffffff"), "shine": 0.5},
		"black": {"body": Color("0038a8"), "base": Color("ce1126"), "ink": Color("fcd116"), "label": Color("ffffff"), "label_outline": Color("001a5a"), "shine": 0.5},
	},
	"pieces_fiesta": {
		"name": "Fiesta Pastillas", "rarity": "rare", "season": "fiesta", "desc": "Sweet as a town fiesta: cream, pink and violet.",
		"swatch": [Color("fff1c9"), Color("ff3d7f"), Color("6a1f8a"), Color("27c98f")],
		"white": {"body": Color("fff1c9"), "base": Color("ff3d7f"), "ink": Color("27c98f"), "label": Color("6a1f8a"), "label_outline": Color("ffffff"), "shine": 0.4},
		"black": {"body": Color("6a1f8a"), "base": Color("ffcf3f"), "ink": Color("ff3d7f"), "label": Color("ffffff"), "label_outline": Color("2a0a3a"), "shine": 0.4},
	},
	"pieces_woodblock": {
		"name": "Woodblock Print", "rarity": "rare", "collection": "great_wave", "desc": "Cream paper and indigo ink with a red seal.",
		"swatch": [Color("f4ead2"), Color("2a4a8a"), Color("2a4a8a"), Color("f4ead2")],
		"white": {"body": Color("f4ead2"), "base": Color("2a4a8a"), "ink": Color("e8341c"), "label": Color("1d2f5a"), "label_outline": Color("ffffff"), "shine": 0.3},
		"black": {"body": Color("2a4a8a"), "base": Color("f4ead2"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("1d2f5a"), "shine": 0.3},
	},
	"pieces_doubloon": {
		"name": "Doubloons", "rarity": "epic", "collection": "treasure_seas", "desc": "Pirate gold against tar-black.",
		"swatch": [Color("ffd54a"), Color("8a5a2a"), Color("2a2d40"), Color("ffcf3f")],
		"white": {"body": Color("ffd54a"), "base": Color("8a5a2a"), "ink": Color("8a2a1a"), "label": Color("6b3600"), "label_outline": Color("ffe9a8"), "shine": 0.95},
		"black": {"body": Color("2a2d40"), "base": Color("ffcf3f"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.6},
	},
	"pieces_lacquer": {
		"name": "Red Lacquer", "rarity": "epic", "collection": "samurai_ronin", "desc": "Glossy vermilion and black lacquer with gold.",
		"swatch": [Color("c8303a"), Color("1d1416"), Color("1d1416"), Color("c8303a")],
		"white": {"body": Color("c8303a"), "base": Color("1d1416"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("5a0a0a"), "shine": 0.9},
		"black": {"body": Color("1d1416"), "base": Color("c8303a"), "ink": Color("ffcf3f"), "label": Color("ffcf3f"), "label_outline": Color("000000"), "shine": 0.9},
	},
	"pieces_shadow_cloth": {
		"name": "Shadow Cloth", "rarity": "rare", "collection": "ninja_clan", "desc": "Ash-grey and midnight cloth.",
		"swatch": [Color("c9c2dd"), Color("4a4570"), Color("2a2350"), Color("8b5cf6")],
		"white": {"body": Color("c9c2dd"), "base": Color("4a4570"), "ink": Color("2a2350"), "label": Color("2a2350"), "label_outline": Color("ffffff"), "shine": 0.2},
		"black": {"body": Color("2a2350"), "base": Color("8b5cf6"), "ink": Color("c9b6ff"), "label": Color("ffffff"), "label_outline": Color("120f24"), "shine": 0.2},
	},
	"pieces_armor_plate": {
		"name": "Armour Plating", "rarity": "rare", "collection": "giant_robots", "desc": "Hero white and gunmetal with warning orange.",
		"swatch": [Color("e8eef8"), Color("2f6bd8"), Color("4f5a74"), Color("ffb020")],
		"white": {"body": Color("e8eef8"), "base": Color("2f6bd8"), "ink": Color("ff3d4a"), "label": Color("1d2a4a"), "label_outline": Color("ffffff"), "shine": 0.7, "pattern": "panel"},
		"black": {"body": Color("4f5a74"), "base": Color("ffb020"), "ink": Color("ffb020"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.7, "pattern": "panel"},
	},
	"pieces_monster_scale": {
		"name": "Monster Scales", "rarity": "rare", "collection": "kaiju_attack", "desc": "Scaly green hide versus volcanic black.",
		"swatch": [Color("9be15d"), Color("3f8a2a"), Color("3f4a3a"), Color("ff6a1a")],
		"white": {"body": Color("9be15d"), "base": Color("3f8a2a"), "ink": Color("1d4a1a"), "label": Color("1d4a1a"), "label_outline": Color("e8ffd8"), "shine": 0.4, "pattern": "scales"},
		"black": {"body": Color("3f4a3a"), "base": Color("ff6a1a"), "ink": Color("ff6a1a"), "label": Color("ffffff"), "label_outline": Color("1a2014"), "shine": 0.4, "pattern": "scales"},
	},
	"pieces_star_captain": {
		"name": "Star Captain", "rarity": "rare", "collection": "space_opera", "desc": "Crisp white uniforms versus crimson.",
		"swatch": [Color("f4f7fc"), Color("3a6bd6"), Color("2a2d40"), Color("e8341c")],
		"white": {"body": Color("f4f7fc"), "base": Color("3a6bd6"), "ink": Color("ffb020"), "label": Color("1d2a4a"), "label_outline": Color("ffffff"), "shine": 0.6},
		"black": {"body": Color("2a2d40"), "base": Color("e8341c"), "ink": Color("e8341c"), "label": Color("ffffff"), "label_outline": Color("120f24"), "shine": 0.6},
	},
	"pieces_chrome": {
		"name": "Chrome '84", "rarity": "epic", "collection": "synthwave", "desc": "Mirror chrome with pink and cyan stands.",
		"swatch": [Color("e8ecf5"), Color("ff4fa8"), Color("2a1048"), Color("3ad6ff")],
		"white": {"body": Color("e8ecf5"), "base": Color("ff4fa8"), "ink": Color("3ad6ff"), "label": Color("2a1048"), "label_outline": Color("ffffff"), "shine": 1.0},
		"black": {"body": Color("2a1048"), "base": Color("3ad6ff"), "ink": Color("ff4fa8"), "label": Color("ffffff"), "label_outline": Color("120624"), "shine": 0.9},
	},
	"pieces_arcade": {
		"name": "Arcade Pixels", "rarity": "common", "collection": "arcade_8bit", "desc": "White and arcade blue, pixel-printed.",
		"swatch": [Color("ffffff"), Color("2f3fbf"), Color("2f3fbf"), Color("ffd23f")],
		"white": {"body": Color("ffffff"), "base": Color("2f3fbf"), "ink": Color("ff4d6d"), "label": Color("2f3fbf"), "label_outline": Color("ffffff"), "shine": 0.3, "pattern": "pixel"},
		"black": {"body": Color("2f3fbf"), "base": Color("ffd23f"), "ink": Color("ffd23f"), "label": Color("ffffff"), "label_outline": Color("101a5a"), "shine": 0.3, "pattern": "pixel"},
	},
	"pieces_sheriff_tin": {
		"name": "Sheriff Tin", "rarity": "rare", "collection": "wild_west", "desc": "Polished tin stars against saddle leather.",
		"swatch": [Color("d8dee8"), Color("8a4a1e"), Color("5a3a24"), Color("d8a868")],
		"white": {"body": Color("d8dee8"), "base": Color("8a4a1e"), "ink": Color("c8342d"), "label": Color("4a2410"), "label_outline": Color("ffffff"), "shine": 0.85},
		"black": {"body": Color("5a3a24"), "base": Color("d8a868"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("2a1a10"), "shine": 0.4},
	},
	"pieces_brass_walnut": {
		"name": "Brass & Walnut", "rarity": "epic", "collection": "steampunk", "desc": "Polished brass and dark walnut.",
		"swatch": [Color("e8b850"), Color("5a3a24"), Color("4a2a1a"), Color("c87a3a")],
		"white": {"body": Color("e8b850"), "base": Color("5a3a24"), "ink": Color("3fbfa0"), "label": Color("4a2a14"), "label_outline": Color("fff0c8"), "shine": 0.9},
		"black": {"body": Color("4a2a1a"), "base": Color("c87a3a"), "ink": Color("e8b850"), "label": Color("ffffff"), "label_outline": Color("1d1008"), "shine": 0.6},
	},
	"pieces_iron_fur": {
		"name": "Iron & Fur", "rarity": "rare", "collection": "norse_vikings", "desc": "Cold iron and warm fur.",
		"swatch": [Color("d8dee8"), Color("8a6a4a"), Color("4a4f5e"), Color("c8a070")],
		"white": {"body": Color("d8dee8"), "base": Color("8a6a4a"), "ink": Color("3f6a8a"), "label": Color("2a3a4a"), "label_outline": Color("ffffff"), "shine": 0.7},
		"black": {"body": Color("4a4f5e"), "base": Color("c8a070"), "ink": Color("9fd8ff"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.6},
	},
	"pieces_pharaoh": {
		"name": "Pharaoh Gold", "rarity": "epic", "collection": "ancient_egypt", "desc": "Gold and lapis fit for a pharaoh.",
		"swatch": [Color("ffd54a"), Color("1f3a8a"), Color("1f3a8a"), Color("ffd54a")],
		"white": {"body": Color("ffd54a"), "base": Color("1f3a8a"), "ink": Color("1f6bd6"), "label": Color("1f3a8a"), "label_outline": Color("fff3c4"), "shine": 0.9},
		"black": {"body": Color("1f3a8a"), "base": Color("ffd54a"), "ink": Color("ffd54a"), "label": Color("ffffff"), "label_outline": Color("0a1a4a"), "shine": 0.8},
	},
	"pieces_marble_laurel": {
		"name": "Marble & Laurel", "rarity": "rare", "collection": "greek_gods", "desc": "White marble and night marble with gold laurels.",
		"swatch": [Color("ffffff"), Color("4a8ad6"), Color("3a3f5a"), Color("ffcf3f")],
		"white": {"body": Color("ffffff"), "base": Color("4a8ad6"), "ink": Color("6aa84a"), "label": Color("2a3a5a"), "label_outline": Color("ffffff"), "shine": 0.7, "pattern": "veins"},
		"black": {"body": Color("3a3f5a"), "base": Color("ffcf3f"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("1d1f2e"), "shine": 0.7, "pattern": "veins"},
	},
	"pieces_capiz": {
		"name": "Capiz Shell", "rarity": "epic", "collection": "philippine_myths", "desc": "Glowing capiz shell and deep forest green.",
		"swatch": [Color("fff6ea"), Color("2a8a5a"), Color("2a5a4a"), Color("ffd27a")],
		"white": {"body": Color("fff6ea"), "base": Color("2a8a5a"), "ink": Color("ff9ec7"), "label": Color("2a5a4a"), "label_outline": Color("ffffff"), "shine": 0.9, "pattern": "veins"},
		"black": {"body": Color("2a5a4a"), "base": Color("ffd27a"), "ink": Color("ffd27a"), "label": Color("ffffff"), "label_outline": Color("0f2a20"), "shine": 0.7, "pattern": "veins"},
	},
	"pieces_hero_primary": {
		"name": "Hero Primaries", "rarity": "common", "collection": "comic_hero", "desc": "Bold red, blue and yellow, straight off the page.",
		"swatch": [Color("ffffff"), Color("e8341c"), Color("3d8bff"), Color("ffd23f")],
		"white": {"body": Color("ffffff"), "base": Color("e8341c"), "ink": Color("3d8bff"), "label": Color("1d1736"), "label_outline": Color("ffffff"), "shine": 0.5},
		"black": {"body": Color("3d8bff"), "base": Color("ffd23f"), "ink": Color("ffd23f"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.5},
	},
	"pieces_undead": {
		"name": "Undead", "rarity": "rare", "collection": "zombie_outbreak", "desc": "Sickly green and rotten brown.",
		"swatch": [Color("b8d48a"), Color("6a4a3a"), Color("3f4a2a"), Color("9be15d")],
		"white": {"body": Color("b8d48a"), "base": Color("6a4a3a"), "ink": Color("5a1f1f"), "label": Color("3a2a1a"), "label_outline": Color("f0ffd8"), "shine": 0.2},
		"black": {"body": Color("3f4a2a"), "base": Color("9be15d"), "ink": Color("9be15d"), "label": Color("ffffff"), "label_outline": Color("1a2010"), "shine": 0.2},
	},
	"pieces_pastel_gem": {
		"name": "Pastel Charms", "rarity": "rare", "collection": "magical_sparkle", "desc": "Candy pink and lilac charms.",
		"swatch": [Color("fff0fa"), Color("ff8ec0"), Color("8a5cff"), Color("ffd1ea")],
		"white": {"body": Color("fff0fa"), "base": Color("ff8ec0"), "ink": Color("b84dff"), "label": Color("8a3a6a"), "label_outline": Color("ffffff"), "shine": 0.8},
		"black": {"body": Color("8a5cff"), "base": Color("ffd1ea"), "ink": Color("ffffff"), "label": Color("ffffff"), "label_outline": Color("3a1a6a"), "shine": 0.8},
	},
	"pieces_idol": {
		"name": "Idol Spotlight", "rarity": "epic", "collection": "concert_stage", "desc": "Stage white and night violet in the spotlight.",
		"swatch": [Color("ffffff"), Color("b84dff"), Color("2a1a4a"), Color("3ad6ff")],
		"white": {"body": Color("ffffff"), "base": Color("b84dff"), "ink": Color("ff2bd6"), "label": Color("4a1a6a"), "label_outline": Color("ffffff"), "shine": 0.9},
		"black": {"body": Color("2a1a4a"), "base": Color("3ad6ff"), "ink": Color("3ad6ff"), "label": Color("ffffff"), "label_outline": Color("120624"), "shine": 0.8},
	},
	"pieces_street_art": {
		"name": "Street Art", "rarity": "rare", "collection": "street_graffiti", "desc": "Concrete grey and asphalt, tagged in neon.",
		"swatch": [Color("f4f4f4"), Color("ff6a1a"), Color("2a2a2a"), Color("4dffb0")],
		"white": {"body": Color("f4f4f4"), "base": Color("ff6a1a"), "ink": Color("3ad6ff"), "label": Color("2a2a2a"), "label_outline": Color("ffffff"), "shine": 0.3},
		"black": {"body": Color("2a2a2a"), "base": Color("4dffb0"), "ink": Color("ff3bd6"), "label": Color("ffffff"), "label_outline": Color("000000"), "shine": 0.3},
	},
	"pieces_knights_steel": {
		"name": "Knight's Steel", "rarity": "rare", "collection": "fantasy_kingdom", "desc": "Polished plate armour with royal colours.",
		"swatch": [Color("dfe4ee"), Color("2f4fae"), Color("4a4f5e"), Color("8a1f2a")],
		"white": {"body": Color("dfe4ee"), "base": Color("2f4fae"), "ink": Color("ffcf3f"), "label": Color("1d2a6a"), "label_outline": Color("ffffff"), "shine": 0.85},
		"black": {"body": Color("4a4f5e"), "base": Color("8a1f2a"), "ink": Color("ffcf3f"), "label": Color("ffffff"), "label_outline": Color("1d1736"), "shine": 0.8},
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
	var emissive := pattern in ["cracks", "specks", "panel_glow", "circuit"]
	var tex := pattern_texture(pattern)
	if emissive:
		m.emission_enabled = true
		m.emission = glow if glow is Color else Color.WHITE
		m.emission_energy_multiplier = 2.0 if pattern != "specks" else 2.6
		m.emission_texture = tex
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # The pattern masks the glow colour.
		if pattern == "panel_glow":
			m.albedo_texture = pattern_texture("panel")
		elif pattern == "circuit":
			m.albedo_texture = pattern_texture("circuit_board")
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
		"hearts":
			# Little hearts on a diagonal lattice, a shade darker than the tile.
			var cell := Vector2(fposmod(u * 4.0 + (0.5 if fposmod(floor(v * 4.0), 2.0) > 0.5 else 0.0), 1.0), fposmod(v * 4.0, 1.0))
			var q := (cell - Vector2(0.5, 0.45)) * Vector2(2.6, -2.6)
			var f := pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * q.y * q.y * q.y
			return 0.8 if f < 0.0 else 1.0
		"candy":
			# Candy-cane diagonal stripes.
			return 0.68 if fposmod((u + v) * 4.0, 1.0) < 0.5 else 1.0
		"scales":
			# Overlapping scales (dragon / koi): arcs on offset rows.
			var row := floori(v * 6.0)
			var su := fposmod(u * 6.0 + (0.5 if row % 2 == 1 else 0.0), 1.0)
			var sv := fposmod(v * 6.0, 1.0)
			var d := Vector2(su - 0.5, sv).length()
			return 0.74 if absf(d - 0.5) < 0.06 else (0.9 if d < 0.5 else 1.0)
		"seigaiha":
			# Woodblock waves: rows of fan-shaped shells, each row tucked in front of the one above.
			var su := u * 4.0
			var sv := v * 4.0
			var top := floori(sv * 2.0) + 1
			for j in range(top, top - 3, -1):  # Front rows first: the first shell that holds the point shows.
				var dx := fposmod(su - (0.5 if posmod(j, 2) == 1 else 0.0), 1.0) - 0.5
				var dy := sv - j * 0.5
				var d := Vector2(dx, dy).length()
				if dy <= 0.0 and d < 0.5:
					return 0.72 if fposmod(d * 6.0, 1.0) < 0.4 else 1.0
			return 1.0
		"planks":
			# Floor planks: rows with dark seams, staggered butt joints and a little grain.
			var row := floori(v * 5.0)
			var pv := fposmod(v * 5.0, 1.0)
			var pu := fposmod(u * 2.0 + _hash(row, 3) * 0.7, 1.0)
			if pv < 0.06 or pu < 0.015:
				return 0.62
			return 0.9 + 0.1 * sin(TAU * (u * 9.0 + pv * 0.6 + _hash(row, 9) * 3.0))
		"map":
			# Parchment with a faint grid and a dashed route curving across.
			var grid := minf(fposmod(u * 4.0, 1.0), fposmod(v * 4.0, 1.0))
			var route := absf(v - 0.5 - 0.22 * sin(TAU * u))
			var dash := fposmod(u * 16.0, 1.0) < 0.55
			if route < 0.018 and dash:
				return 0.55
			return 0.86 if grid < 0.012 else 0.95 + 0.05 * sin(TAU * (u * 3.0 + v * 5.0))
		"circuit":
			# Glow mask: traces along hashed cell edges, with pads at the joints.
			var cx := floori(u * 4.0)
			var cy := floori(v * 4.0)
			var fu := fposmod(u * 4.0, 1.0)
			var fv := fposmod(v * 4.0, 1.0)
			var lit := 0.0
			if _hash(cx, cy) > 0.45 and absf(fv - 0.5) < 0.04:
				lit = 1.0
			if _hash(cy + 31, cx + 7) > 0.5 and absf(fu - 0.5) < 0.04:
				lit = 1.0
			if Vector2(fu - 0.5, fv - 0.5).length() < 0.1 and _hash(cx + 13, cy + 5) > 0.3:
				lit = 1.0
			return lit
		"circuit_board":
			return 1.0 - 0.08 * float((floori(u * 8.0) + floori(v * 8.0)) % 2)
		"pixel":
			# Chunky pixels: an 8×8 grid of slightly different shades.
			var px := floori(u * 8.0)
			var py := floori(v * 8.0)
			var h := _hash(px + 101, py + 57)
			return 0.8 if h < 0.15 else (0.9 if h < 0.5 else 1.0)
		"bricks":
			var row := floori(v * 6.0)
			var bu := fposmod(u * 3.0 + (0.5 if row % 2 == 1 else 0.0), 1.0)
			var bv := fposmod(v * 6.0, 1.0)
			if bv < 0.1 or bu < 0.035:
				return 0.62
			return 0.88 + 0.12 * _hash(floori(u * 3.0 + (0.5 if row % 2 == 1 else 0.0)), row)
		"halftone":
			# Comic-print dots that grow toward one corner of each tile.
			var cell := Vector2(fposmod(u * 10.0, 1.0), fposmod(v * 10.0, 1.0)) - Vector2(0.5, 0.5)
			var radius := 0.12 + 0.26 * (0.5 + 0.5 * sin(TAU * (u + v)))
			return 0.72 if cell.length() < radius else 1.0
		"glyphs":
			# Carved marks: one short stroke, ring or bar per cell (hashed, so it tiles).
			var cx := floori(u * 6.0)
			var cy := floori(v * 6.0)
			var q := Vector2(fposmod(u * 6.0, 1.0), fposmod(v * 6.0, 1.0)) - Vector2(0.5, 0.5)
			var kind := int(_hash(cx + 3, cy + 17) * 4.0)
			var mark := false
			match kind:
				0:
					mark = absf(q.x) < 0.06 and absf(q.y) < 0.3
				1:
					mark = absf(q.length() - 0.2) < 0.05
				2:
					mark = absf(q.y) < 0.06 and absf(q.x) < 0.28
				_:
					mark = absf(q.x - q.y) < 0.07 and absf(q.x) < 0.25
			return 0.68 if mark else 1.0
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
