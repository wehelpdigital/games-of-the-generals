class_name ArenaLibrary
extends RefCounted
## Arenas: the world around the board (sky, light, fog, ground, decor and ambient particles). An
## arena is personal: each player sees their own. Arena3D builds them; this file is the catalogue.
##
## Item keys used by the shop: name, rarity, swatch, desc. The rest drives Arena3D:
## sky [top, horizon, ground] or "space", ambient + ambient_energy, light + light_energy,
## fog (depth fog colour, omitted = none) + fog_range (begin, end), ground {pattern, a, b, c, glow,
## glow_strength, scale} (pattern -1 = no ground), particles (preset name or "").

const ARENAS := {
	"classic": {
		"name": "Sunny Plaza", "rarity": "common", "desc": "The original sunny peach plaza with polka dots.",
		"swatch": [Color("ffd9b0"), Color("3f8cff"), Color("ffe1c4")],
		"sky": [Color("3f8cff"), Color("ffe1c4"), Color("ebcfb5")], "ambient": Color("dccfee"), "ambient_energy": 0.62,
		"light": Color("fff5e6"), "light_energy": 0.21,
		"ground": {"pattern": 0, "a": Color("ffd9b0")},
		"particles": "",
	},
	"desert_canyon": {
		"name": "Desert Canyon", "rarity": "common", "desc": "Rippled dunes, cacti and towering red mesas.",
		"swatch": [Color("f2c98a"), Color("d9774a"), Color("4f9f55")],
		"sky": [Color("4fa6ff"), Color("ffe0b0"), Color("f2c98a")], "ambient": Color("ffe6c8"), "ambient_energy": 0.62,
		"light": Color("ffe8c8"), "light_energy": 0.25,
		"fog": Color("f7d9a8"), "fog_range": Vector2(20.0, 70.0),
		"ground": {"pattern": 5, "a": Color("f4cd8f"), "b": Color("dda66a"), "scale": 0.5},
		"particles": "dust",
	},
	"sakura_garden": {
		"name": "Sakura Garden", "rarity": "rare", "desc": "Cherry blossoms, stone lanterns and drifting petals.",
		"swatch": [Color("ffb3d1"), Color("8fd06b"), Color("e0453a")],
		"sky": [Color("8ec9ff"), Color("ffd9ec"), Color("b9e3a5")], "ambient": Color("f3e0f0"), "ambient_energy": 0.6,
		"light": Color("fff2ec"), "light_energy": 0.22,
		"fog": Color("ffe3f0"), "fog_range": Vector2(18.0, 65.0),
		"ground": {"pattern": 2, "a": Color("98d873"), "b": Color("74bf5a"), "c": Color("ffc1dc"), "scale": 0.6},
		"particles": "petals",
	},
	"frozen_tundra": {
		"name": "Frozen Tundra", "rarity": "rare", "desc": "Snowfields, ice spikes and snowy pines under falling snow.",
		"swatch": [Color("f4f9ff"), Color("7fdcff"), Color("2f6b5a")],
		"sky": [Color("9cc9ff"), Color("eaf6ff"), Color("dbe9f7")], "ambient": Color("d8e8ff"), "ambient_energy": 0.66,
		"light": Color("eef6ff"), "light_energy": 0.23,
		"fog": Color("e6f2ff"), "fog_range": Vector2(16.0, 60.0),
		"ground": {"pattern": 3, "a": Color("f6fbff"), "b": Color("c9def3"), "scale": 0.4},
		"particles": "snow",
	},
	"candy_land": {
		"name": "Candy Land", "rarity": "rare", "desc": "Giant lollipops, gumdrops and a sprinkle storm.",
		"swatch": [Color("ffd1e8"), Color("c9f5e3"), Color("ff5a8a")],
		"sky": [Color("ff9ed2"), Color("fff0f7"), Color("ffd1e8")], "ambient": Color("ffe8f6"), "ambient_energy": 0.66,
		"light": Color("fff4fa"), "light_energy": 0.22,
		"fog": Color("ffe6f3"), "fog_range": Vector2(20.0, 70.0),
		"ground": {"pattern": 7, "a": Color("ffd6ea"), "b": Color("cdf5e6"), "c": Color("ff5a8a"), "glow": Color("ffd23f"), "scale": 1.0},
		"particles": "sprinkles",
	},
	"ocean_reef": {
		"name": "Ocean Reef", "rarity": "rare", "desc": "Under the sea: coral, kelp, caustics and bubbles.",
		"swatch": [Color("1f7fae"), Color("ff7a9a"), Color("3fae6a")],
		"sky": [Color("0b4f8f"), Color("2fa5c8"), Color("1f7fae")], "ambient": Color("9fe0ff"), "ambient_energy": 0.62,
		"light": Color("dcf6ff"), "light_energy": 0.22,
		"fog": Color("2a8bba"), "fog_range": Vector2(14.0, 46.0),
		"ground": {"pattern": 6, "a": Color("ecd8ac"), "b": Color("d4bd8c"), "glow": Color("ffffff"), "glow_strength": 0.34, "scale": 0.7},
		"particles": "bubbles",
	},
	"cloud_kingdom": {
		"name": "Cloud Kingdom", "rarity": "epic", "desc": "Above the clouds, with floating islands and a rainbow.",
		"swatch": [Color("ffffff"), Color("7ec8ff"), Color("ffcf3f")],
		"sky": [Color("5fb8ff"), Color("e8f6ff"), Color("ffffff")], "ambient": Color("e6eeff"), "ambient_energy": 0.68,
		"light": Color("fffaf0"), "light_energy": 0.23,
		"fog": Color("eaf5ff"), "fog_range": Vector2(22.0, 75.0),
		"ground": {"pattern": 10, "a": Color("ffffff"), "b": Color("cdd6f2"), "c": Color("9ed3ff"), "scale": 0.35},
		"particles": "sparkles",
	},
	"jungle_temple": {
		"name": "Jungle Temple", "rarity": "epic", "desc": "Mossy ruins and a stepped pyramid deep in the jungle.",
		"swatch": [Color("8d9478"), Color("3f9a4a"), Color("5fffb0")],
		"sky": [Color("4f9c7a"), Color("d6f0b8"), Color("8fa77a")], "ambient": Color("d6f2c6"), "ambient_energy": 0.6,
		"light": Color("fff4dc"), "light_energy": 0.24,
		"fog": Color("a8d49a"), "fog_range": Vector2(16.0, 58.0),
		"ground": {"pattern": 8, "a": Color("a3a58a"), "b": Color("5f9445"), "c": Color("4a4a3c"), "scale": 0.5},
		"particles": "fireflies",
	},
	"neon_city": {
		"name": "Neon City", "rarity": "epic", "desc": "A night-time city of glowing grids and neon towers.",
		"swatch": [Color("141225"), Color("19f0ff"), Color("ff3dd0")],
		"sky": [Color("0a0620"), Color("3d1460"), Color("120b2a")], "ambient": Color("b0a6ff"), "ambient_energy": 0.56,
		"light": Color("d9d6ff"), "light_energy": 0.2,
		"fog": Color("2a1050"), "fog_range": Vector2(18.0, 64.0),
		"ground": {"pattern": 4, "a": Color("15132a"), "b": Color("241f45"), "c": Color("ff3dd0"), "glow": Color("19f0ff"), "glow_strength": 1.25, "scale": 0.5},
		"particles": "sparks",
	},
	"haunted_grove": {
		"name": "Haunted Grove", "rarity": "epic", "desc": "Dead trees, tombstones, jack-o'-lanterns and creeping mist.",
		"swatch": [Color("2b2140"), Color("8d86a6"), Color("ff8a2a")],
		"sky": [Color("120b26"), Color("4a2c6e"), Color("2b2140")], "ambient": Color("bcaee8"), "ambient_energy": 0.56,
		"light": Color("cfd8ff"), "light_energy": 0.21,
		"fog": Color("3a2a5e"), "fog_range": Vector2(15.0, 52.0),
		"ground": {"pattern": 9, "a": Color("2f2546"), "b": Color("3d2f58"), "c": Color("7a6aa8"), "glow": Color("7dff9a"), "glow_strength": 1.4, "scale": 0.5},
		"particles": "wisps",
	},
	"lava_pit": {
		"name": "Lava Pit", "rarity": "legendary", "desc": "Cracked volcanic rock over rivers of glowing lava.",
		"swatch": [Color("2a1d1f"), Color("ff6a1a"), Color("ffd23f")],
		"sky": [Color("1a0d10"), Color("5a1f12"), Color("2a1d1f")], "ambient": Color("ffbe9a"), "ambient_energy": 0.56,
		"light": Color("ffc38f"), "light_energy": 0.25,
		"fog": Color("5a2414"), "fog_range": Vector2(16.0, 56.0),
		"ground": {"pattern": 1, "a": Color("2c2022"), "b": Color("45302c"), "glow": Color("ff6a1a"), "glow_strength": 1.8, "scale": 0.45},
		"particles": "embers",
	},
	"deep_space": {
		"name": "Deep Space", "rarity": "legendary", "desc": "A floating asteroid among planets, nebulae and stars.",
		"swatch": [Color("0b0b24"), Color("8f6bff"), Color("ffb36b")],
		"sky": "space", "ambient": Color("c3cbff"), "ambient_energy": 0.62,
		"light": Color("f2f4ff"), "light_energy": 0.24,
		"ground": {"pattern": -1},
		"particles": "stardust",
	},
	"spooky_graveyard": {
		"name": "Spooky Graveyard", "rarity": "epic", "season": "halloween",
		"desc": "Crooked tombstones, glowing jack-o'-lanterns, Undas candles and a huge orange moon.",
		"swatch": [Color("2a1d3e"), Color("ff7a12"), Color("9a94b0")],
		"sky": [Color("150a2a"), Color("ff7a3a"), Color("3a2346")], "ambient": Color("c8b4f0"), "ambient_energy": 0.56,
		"light": Color("ffd8b0"), "light_energy": 0.22,
		"fog": Color("402a55"), "fog_range": Vector2(16.0, 55.0),
		"ground": {"pattern": 9, "a": Color("2d2440"), "b": Color("3a2e52"), "c": Color("6a5a90"), "glow": Color("ff8a2a"), "glow_strength": 1.2, "scale": 0.5},
		"particles": "wisps",
	},
	"snowy_village": {
		"name": "Snowy Village", "rarity": "epic", "season": "christmas",
		"desc": "Gingerbread-coloured houses with glowing windows, snowy pines and lamp posts.",
		"swatch": [Color("f6fbff"), Color("d62f3a"), Color("2f8f4e")],
		"sky": [Color("6f9fe0"), Color("e8f2ff"), Color("dbe9f7")], "ambient": Color("dce8ff"), "ambient_energy": 0.66,
		"light": Color("fff2e0"), "light_energy": 0.23,
		"fog": Color("e8f2ff"), "fog_range": Vector2(16.0, 60.0),
		"ground": {"pattern": 3, "a": Color("f8fcff"), "b": Color("d6e6f5"), "scale": 0.4},
		"particles": "snow",
	},
}


static func arena(slug: String) -> Dictionary:
	return ARENAS.get(slug, ARENAS["classic"])
