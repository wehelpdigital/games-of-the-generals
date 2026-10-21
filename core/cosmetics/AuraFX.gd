class_name AuraFX
extends RefCounted
## Auras: a persistent effect around every piece of one side, visible to both players. Each aura
## is a pulsing glow ring on the stand plus a handful of particles (at most 8 per piece) drawn with
## FxTextures sprites, so 42 auras stay cheap on mobile WebGL. The aura node is a child of the
## piece's rig, so it follows lifts and slides and disappears with the piece.
##
## Style keys: glow (ring colour), glow_mix (darken instead of add), shape, colors (over life),
## additive, amount, lifetime, size, rise (speed range), gravity, radius, height, spin,
## rainbow, flicker.

const NONE := "none"

const STYLES := {
	"none": {"name": "No aura", "rarity": "common", "collection": "classics", "desc": "Just your pieces.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	"aura_flame": {"name": "Fire", "rarity": "rare", "collection": "lava_fire", "desc": "Cartoon flames lick up around every piece.",
		"swatch": [Color("ffd23f"), Color("ff7a1a"), Color("e8341c")],
		"glow": Color("ff6a1a"), "shape": "flame", "colors": [Color("ffe14d"), Color("ff8a1f"), Color("ff3d1f")],
		"additive": false, "amount": 8, "lifetime": 0.75, "size": 0.34, "rise": Vector2(0.35, 0.65), "gravity": 0.5,
		"radius": 0.44, "height": 0.06},
	"aura_ghostly": {"name": "Ghostly", "rarity": "epic", "collection": "spooky", "desc": "Pale wisps of mist and a cold, eerie glow.",
		"swatch": [Color("eef6ff"), Color("b8d4ff"), Color("7f9cd6")],
		"glow": Color("b8dcff"), "shape": "puff", "colors": [Color("f2f8ff", 0.0), Color("dcebff", 0.55), Color("a9c4f0", 0.0)],
		"additive": true, "amount": 8, "lifetime": 2.2, "size": 0.47, "rise": Vector2(0.08, 0.22), "gravity": 0.04,
		"radius": 0.4, "height": 0.1, "spin": 25.0},
	"aura_neon": {"name": "Neon", "rarity": "epic", "collection": "cyber_neon", "desc": "A crisp neon ring that scans up and down your pieces.",
		"swatch": [Color("ff2bd6"), Color("2ef6ff"), Color("1a0f33")],
		"glow": Color("ff2bd6"), "ring_shape": "ring", "ring_boost": 2.4, "scan": 0.7, "shape": "sparkle",
		"colors": [Color("ffffff"), Color("ff8ff0"), Color("ff2bd6")],
		"additive": true, "amount": 4, "lifetime": 0.9, "size": 0.16, "rise": Vector2(0.1, 0.3), "gravity": 0.0,
		"radius": 0.48, "height": 0.3},
	"aura_frost": {"name": "Frost", "rarity": "rare", "collection": "ice_snow", "desc": "Snowflakes drift around an icy ring.",
		"swatch": [Color("e6faff"), Color("9ee6ff"), Color("4fb3ff")],
		"glow": Color("8fe6ff"), "shape": "snowflake", "colors": [Color("ffffff"), Color("c8f2ff"), Color("8fd8ff")],
		"additive": false, "amount": 7, "lifetime": 2.2, "size": 0.18, "rise": Vector2(0.05, 0.2), "gravity": -0.05,
		"radius": 0.48, "height": 0.6, "spin": 90.0},
	"aura_lightning": {"name": "Lightning", "rarity": "epic", "collection": "sky_weather", "desc": "Crackling electric arcs.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")],
		"glow": Color("5fc8ff"), "shape": "bolt", "colors": [Color("ffffff"), Color("aee9ff"), Color("4fa8ff")],
		"additive": true, "amount": 5, "lifetime": 0.22, "size": 0.42, "rise": Vector2(0.0, 0.05), "gravity": 0.0,
		"radius": 0.46, "height": 0.4, "flicker": true},
	"aura_holy_light": {"name": "Holy Light", "rarity": "epic", "collection": "greek_gods", "desc": "A warm golden glow with rising sparkles.",
		"swatch": [Color("fffbe6"), Color("ffe58a"), Color("ffc93c")],
		"glow": Color("ffe58a"), "shape": "sparkle", "colors": [Color("ffffff"), Color("fff1b0"), Color("ffd24a")],
		"additive": true, "amount": 7, "lifetime": 1.6, "size": 0.21, "rise": Vector2(0.25, 0.5), "gravity": 0.0,
		"radius": 0.38, "height": 0.1},
	"aura_shadow_smoke": {"name": "Shadow Smoke", "rarity": "epic", "collection": "ninja_clan", "desc": "Dark smoke curls around your army.",
		"swatch": [Color("2a2236"), Color("5a3d7a"), Color("8b5cff")],
		"glow": Color("3b2a5a"), "glow_mix": true, "shape": "puff", "colors": [Color("4a3a66", 0.75), Color("2a2236", 0.6), Color("120e1a", 0.3)],
		"additive": false, "amount": 7, "lifetime": 1.8, "size": 0.42, "rise": Vector2(0.1, 0.3), "gravity": 0.08,
		"radius": 0.44, "height": 0.08, "spin": 40.0},
	"aura_sakura": {"name": "Sakura Petals", "rarity": "rare", "collection": "sakura_blossom", "desc": "Cherry-blossom petals swirl down.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")],
		"glow": Color("ff9ec7"), "shape": "petal", "colors": [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")],
		"additive": false, "amount": 7, "lifetime": 2.0, "size": 0.17, "rise": Vector2(0.0, 0.15), "gravity": -0.12,
		"radius": 0.5, "height": 0.75, "spin": 160.0},
	"aura_galaxy": {"name": "Galaxy", "rarity": "legendary", "collection": "space_opera", "desc": "A swirl of tiny stars and nebula light.",
		"swatch": [Color("1b1440"), Color("5d7bff"), Color("b05cff"), Color("ffffff")],
		"glow": Color("8a6bff"), "shape": "star", "colors": [Color("ffffff"), Color("c9b8ff"), Color("6f8bff")],
		"additive": true, "amount": 8, "lifetime": 1.8, "size": 0.16, "rise": Vector2(0.05, 0.25), "gravity": 0.05,
		"radius": 0.5, "height": 0.4, "spin": 120.0, "rainbow_ring": 0.35},
	"aura_toxic": {"name": "Toxic", "rarity": "rare", "collection": "zombie_outbreak", "desc": "Bubbling green fumes.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")],
		"glow": Color("9cff3a"), "shape": "bubble", "colors": [Color("eaff9a"), Color("9cff3a"), Color("4fc41a")],
		"additive": true, "amount": 7, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.25, 0.5), "gravity": 0.1,
		"radius": 0.4, "height": 0.06},
	"aura_rainbow": {"name": "Rainbow", "rarity": "legendary", "collection": "cute_candy", "desc": "A colour-cycling ring with rainbow sparkles.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")],
		"glow": Color("ffffff"), "shape": "sparkle", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")],
		"additive": true, "amount": 8, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.2, 0.45), "gravity": 0.0,
		"radius": 0.42, "height": 0.1, "rainbow": true, "rainbow_ring": 1.0},
	"aura_hearts": {"name": "Hearts", "rarity": "common", "collection": "cute_candy", "desc": "Little hearts float up. Aww.",
		"swatch": [Color("ffd1e1"), Color("ff6f9f"), Color("ff3b6e")],
		"glow": Color("ff6f9f"), "shape": "heart", "colors": [Color("ffc2d8"), Color("ff6f9f"), Color("ff3b6e")],
		"additive": false, "amount": 6, "lifetime": 1.6, "size": 0.18, "rise": Vector2(0.25, 0.45), "gravity": 0.0,
		"radius": 0.38, "height": 0.15},
	"aura_music": {"name": "Rhythm", "rarity": "rare", "collection": "concert_stage", "desc": "Music notes bounce around your pieces.",
		"swatch": [Color("ffffff"), Color("7fd6ff"), Color("b05cff")],
		"glow": Color("7fd6ff"), "shape": "note", "colors": [Color("ffffff"), Color("b8e6ff"), Color("c9a0ff")],
		"additive": false, "amount": 5, "lifetime": 1.6, "size": 0.21, "rise": Vector2(0.25, 0.45), "gravity": 0.0,
		"radius": 0.46, "height": 0.2, "spin": 30.0},
	"aura_witch_wisps": {"name": "Witch's Wisps", "rarity": "epic", "season": "halloween", "desc": "Green and purple witch-fire flickers around every piece.",
		"swatch": [Color("7dff5a"), Color("8b5cf6"), Color("2b1740")],
		"glow": Color("7dff5a"), "shape": "flame", "colors": [Color("d8ff8a"), Color("7dff5a"), Color("8b5cf6")],
		"additive": false, "amount": 8, "lifetime": 0.85, "size": 0.3, "rise": Vector2(0.3, 0.6), "gravity": 0.45,
		"radius": 0.44, "height": 0.06},
	"aura_love_hearts": {"name": "Lovestruck", "rarity": "rare", "season": "valentines", "desc": "Little hearts float up around every piece.",
		"swatch": [Color("ffe3ec"), Color("ff7aa0"), Color("ff2f5f")],
		"glow": Color("ff4f7b"), "shape": "heart", "colors": [Color("ffe3ec"), Color("ff7aa0"), Color("ff2f5f")],
		"additive": false, "amount": 6, "lifetime": 1.6, "size": 0.22, "rise": Vector2(0.2, 0.4), "gravity": 0.0,
		"radius": 0.42, "height": 0.2},
	"aura_sunburst": {"name": "Sunburst", "rarity": "epic", "season": "kalayaan", "desc": "Golden little suns rise around your pieces.",
		"swatch": [Color("fff6c8"), Color("fcd116"), Color("ffb020")],
		"glow": Color("fcd116"), "shape": "sun", "colors": [Color("fff6c8"), Color("fcd116"), Color("ffb020")],
		"additive": false, "amount": 5, "lifetime": 1.8, "size": 0.26, "rise": Vector2(0.15, 0.3), "gravity": 0.0,
		"radius": 0.42, "height": 0.25, "spin": 60.0},
	"aura_lucky_coins": {"name": "Lucky Coins", "rarity": "rare", "season": "lunar_new_year", "desc": "Gold coins spin up around your pieces for good fortune.",
		"swatch": [Color("fff1b0"), Color("ffcf3f"), Color("d62828")],
		"glow": Color("ffcf3f"), "shape": "coin", "colors": [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")],
		"additive": false, "amount": 6, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.3, 0.5), "gravity": -0.2,
		"radius": 0.42, "height": 0.15, "spin": 220.0},
	"aura_sea_spray": {"name": "Sea Spray", "rarity": "rare", "collection": "great_wave", "desc": "Foam bubbles froth up around your pieces.",
		"swatch": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")],
		"glow": Color("9fd8ff"), "shape": "bubble", "colors": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")],
		"additive": false, "amount": 7, "lifetime": 1.4, "size": 0.2, "rise": Vector2(0.2, 0.45), "gravity": 0.1,
		"radius": 0.46, "height": 0.05},
	"aura_treasure_glint": {"name": "Treasure Glint", "rarity": "rare", "collection": "treasure_seas", "desc": "Gold doubloons tumble around a golden ring.",
		"swatch": [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")],
		"glow": Color("ffcf3f"), "shape": "coin", "colors": [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")],
		"additive": false, "amount": 6, "lifetime": 1.6, "size": 0.17, "rise": Vector2(0.2, 0.4), "gravity": 0.3,
		"radius": 0.44, "height": 0.2, "spin": 180.0},
	"aura_ink_brush": {"name": "Ink Brush", "rarity": "epic", "collection": "samurai_ronin", "desc": "Wisps of sumi ink curl around your pieces.",
		"swatch": [Color("1d1736", 0.0), Color("1d1736", 0.7), Color("3a3560", 0.0)],
		"glow": Color("2a2350"), "shape": "puff", "colors": [Color("1d1736", 0.0), Color("1d1736", 0.7), Color("3a3560", 0.0)],
		"additive": false, "amount": 7, "lifetime": 1.8, "size": 0.4, "rise": Vector2(0.1, 0.25), "gravity": 0.0,
		"radius": 0.42, "height": 0.05, "spin": 30.0, "glow_mix": true},
	"aura_shadow_wisps": {"name": "Shadow Wisps", "rarity": "rare", "collection": "ninja_clan", "desc": "Shadows gather and curl around every piece.",
		"swatch": [Color("3a2f6a", 0.0), Color("2a2350", 0.6), Color("1a1438", 0.0)],
		"glow": Color("6a5acd"), "shape": "puff", "colors": [Color("3a2f6a", 0.0), Color("2a2350", 0.6), Color("1a1438", 0.0)],
		"additive": false, "amount": 8, "lifetime": 1.6, "size": 0.36, "rise": Vector2(0.15, 0.3), "gravity": 0.0,
		"radius": 0.42, "height": 0.05, "spin": 40.0},
	"aura_power_core": {"name": "Power Core", "rarity": "epic", "collection": "giant_robots", "desc": "A humming cyan core ring with sparks.",
		"swatch": [Color("ffffff"), Color("aef9ff"), Color("3ad6ff")],
		"glow": Color("3ad6ff"), "ring_shape": "ring", "ring_boost": 2.0, "shape": "sparkle", "colors": [Color("ffffff"), Color("aef9ff"), Color("3ad6ff")],
		"additive": true, "amount": 6, "lifetime": 0.8, "size": 0.16, "rise": Vector2(0.2, 0.5), "gravity": 0.0,
		"radius": 0.44, "height": 0.15, "flicker": true},
	"aura_rubble_dust": {"name": "Rubble Dust", "rarity": "rare", "collection": "kaiju_attack", "desc": "Bits of rubble rattle around, as if something huge is coming.",
		"swatch": [Color("d8c8a8"), Color("a89878"), Color("786848")],
		"glow": Color("c8a070"), "shape": "square", "colors": [Color("d8c8a8"), Color("a89878"), Color("786848")],
		"additive": false, "amount": 6, "lifetime": 1.0, "size": 0.1, "rise": Vector2(0.3, 0.6), "gravity": 1.2,
		"radius": 0.44, "height": 0.05, "spin": 240.0},
	"aura_shield_bubble": {"name": "Deflector Shield", "rarity": "epic", "collection": "space_opera", "desc": "A shimmering blue shield ring scans your pieces.",
		"swatch": [Color("ffffff"), Color("c8f2ff"), Color("6a8aff")],
		"glow": Color("3ad6ff"), "ring_shape": "ring", "ring_boost": 1.8, "scan": 0.5, "shape": "sparkle", "colors": [Color("ffffff"), Color("c8f2ff"), Color("6a8aff")],
		"additive": true, "amount": 4, "lifetime": 1.0, "size": 0.14, "rise": Vector2(0.1, 0.3), "gravity": 0.0,
		"radius": 0.5, "height": 0.3},
	"aura_sunset_haze": {"name": "Sunset Haze", "rarity": "rare", "collection": "synthwave", "desc": "Glowing dots in sunset orange, pink and violet.",
		"swatch": [Color("ffb020"), Color("ff4fa8"), Color("8a2bd6")],
		"glow": Color("ff4fa8"), "shape": "dot", "colors": [Color("ffb020"), Color("ff4fa8"), Color("8a2bd6")],
		"additive": true, "amount": 6, "lifetime": 1.2, "size": 0.14, "rise": Vector2(0.2, 0.4), "gravity": 0.0,
		"radius": 0.44, "height": 0.1},
	"aura_pixel_hearts": {"name": "Extra Lives", "rarity": "common", "collection": "arcade_8bit", "desc": "Pixel hearts pop up, one life at a time.",
		"swatch": [Color("ffffff"), Color("ff8aa0"), Color("ff4d6d")],
		"glow": Color("ff4d6d"), "shape": "heart", "colors": [Color("ffffff"), Color("ff8aa0"), Color("ff4d6d")],
		"additive": false, "amount": 4, "lifetime": 1.2, "size": 0.18, "rise": Vector2(0.3, 0.5), "gravity": 0.0,
		"radius": 0.42, "height": 0.25, "flicker": true},
	"aura_dust_devil": {"name": "Dust Devil", "rarity": "common", "collection": "wild_west", "desc": "Little whirls of desert dust.",
		"swatch": [Color("e8d0a0", 0.0), Color("d8b880", 0.7), Color("b8945a", 0.0)],
		"glow": Color("d8a868"), "shape": "puff", "colors": [Color("e8d0a0", 0.0), Color("d8b880", 0.7), Color("b8945a", 0.0)],
		"additive": false, "amount": 7, "lifetime": 1.2, "size": 0.3, "rise": Vector2(0.15, 0.3), "gravity": 0.0,
		"radius": 0.44, "height": 0.05, "spin": 120.0},
	"aura_clockwork": {"name": "Clockwork", "rarity": "epic", "collection": "steampunk", "desc": "Brass cogs turn slowly around your pieces.",
		"swatch": [Color("ffe0a0"), Color("e8b850"), Color("a8742a")],
		"glow": Color("e8b850"), "shape": "gear", "colors": [Color("ffe0a0"), Color("e8b850"), Color("a8742a")],
		"additive": false, "amount": 5, "lifetime": 2.0, "size": 0.22, "rise": Vector2(0.1, 0.25), "gravity": 0.0,
		"radius": 0.46, "height": 0.15, "spin": 90.0},
	"aura_frost_rune": {"name": "Rune Frost", "rarity": "rare", "collection": "norse_vikings", "desc": "Glowing runes rise from an icy ring.",
		"swatch": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")],
		"glow": Color("9fd8ff"), "shape": "rune", "colors": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")],
		"additive": true, "amount": 5, "lifetime": 1.6, "size": 0.2, "rise": Vector2(0.15, 0.3), "gravity": 0.0,
		"radius": 0.44, "height": 0.1},
	"aura_scarab_gold": {"name": "Sun Disc", "rarity": "epic", "collection": "ancient_egypt", "desc": "Golden sun discs rise on a ring of gold.",
		"swatch": [Color("fff1b0"), Color("ffcf3f"), Color("e0a520")],
		"glow": Color("ffcf3f"), "shape": "sun", "colors": [Color("fff1b0"), Color("ffcf3f"), Color("e0a520")],
		"additive": false, "amount": 5, "lifetime": 1.6, "size": 0.18, "rise": Vector2(0.15, 0.3), "gravity": 0.0,
		"radius": 0.44, "height": 0.1, "spin": 60.0},
	"aura_divine_light": {"name": "Divine Light", "rarity": "epic", "collection": "greek_gods", "desc": "Golden sparks and a halo of light.",
		"swatch": [Color("ffffff"), Color("fff1b0"), Color("ffcf3f")],
		"glow": Color("fff1b0"), "shape": "sparkle", "colors": [Color("ffffff"), Color("fff1b0"), Color("ffcf3f")],
		"additive": true, "amount": 7, "lifetime": 1.0, "size": 0.2, "rise": Vector2(0.3, 0.6), "gravity": 0.0,
		"radius": 0.42, "height": 0.1},
	"aura_diwata_glow": {"name": "Diwata's Glow", "rarity": "epic", "collection": "philippine_myths", "desc": "Forest-spirit lights drift around your pieces.",
		"swatch": [Color("ffffff"), Color("e8ffa0"), Color("9be15d")],
		"glow": Color("c8ff6a"), "shape": "dot", "colors": [Color("ffffff"), Color("e8ffa0"), Color("9be15d")],
		"additive": true, "amount": 8, "lifetime": 2.0, "size": 0.12, "rise": Vector2(0.05, 0.2), "gravity": 0.0,
		"radius": 0.5, "height": 0.2, "flicker": true},
	"aura_hero_glow": {"name": "Hero Shine", "rarity": "rare", "collection": "comic_hero", "desc": "Comic-book stars pop around your pieces.",
		"swatch": [Color("ffffff"), Color("ffe14d"), Color("ff9f1c")],
		"glow": Color("ffd23f"), "shape": "star", "colors": [Color("ffffff"), Color("ffe14d"), Color("ff9f1c")],
		"additive": false, "amount": 5, "lifetime": 0.9, "size": 0.2, "rise": Vector2(0.3, 0.6), "gravity": 0.0,
		"radius": 0.42, "height": 0.15, "spin": 180.0},
	"aura_stench_cloud": {"name": "Stench Cloud", "rarity": "rare", "collection": "zombie_outbreak", "desc": "A green, smelly haze. Hold your nose.",
		"swatch": [Color("c8ff6a", 0.0), Color("9be15d", 0.6), Color("5a8a2a", 0.0)],
		"glow": Color("9be15d"), "shape": "puff", "colors": [Color("c8ff6a", 0.0), Color("9be15d", 0.6), Color("5a8a2a", 0.0)],
		"additive": false, "amount": 7, "lifetime": 1.8, "size": 0.36, "rise": Vector2(0.1, 0.25), "gravity": 0.0,
		"radius": 0.42, "height": 0.05, "spin": 30.0, "glow_mix": true},
	"aura_wish_sparkles": {"name": "Wish Sparkles", "rarity": "rare", "collection": "magical_sparkle", "desc": "Pastel stars twinkle around your pieces.",
		"swatch": [Color("ffffff"), Color("ffc2e0"), Color("b84dff")],
		"glow": Color("ff8ec0"), "shape": "star", "colors": [Color("ffffff"), Color("ffc2e0"), Color("b84dff")],
		"additive": true, "amount": 7, "lifetime": 1.2, "size": 0.18, "rise": Vector2(0.15, 0.35), "gravity": 0.0,
		"radius": 0.44, "height": 0.1, "spin": 120.0},
	"aura_light_sticks": {"name": "Encore", "rarity": "epic", "collection": "concert_stage", "desc": "A pulsing violet ring that scans to the beat.",
		"swatch": [Color("ffffff"), Color("ff8ff0"), Color("b84dff")],
		"glow": Color("b84dff"), "ring_shape": "ring", "ring_boost": 2.2, "scan": 0.9, "shape": "note", "colors": [Color("ffffff"), Color("ff8ff0"), Color("b84dff")],
		"additive": false, "amount": 4, "lifetime": 1.2, "size": 0.18, "rise": Vector2(0.2, 0.4), "gravity": 0.0,
		"radius": 0.48, "height": 0.2},
	"aura_spray_mist": {"name": "Spray Mist", "rarity": "rare", "collection": "street_graffiti", "desc": "A rainbow mist of spray paint.",
		"swatch": [Color("ffffff"), Color("ffffff"), Color("ffffff")],
		"glow": Color("ff6a1a"), "shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")],
		"additive": false, "amount": 8, "lifetime": 1.0, "size": 0.12, "rise": Vector2(0.2, 0.4), "gravity": 0.0,
		"radius": 0.44, "height": 0.1, "rainbow": true},
	"aura_enchanted": {"name": "Enchanted", "rarity": "rare", "collection": "fantasy_kingdom", "desc": "A violet enchantment glitters around your pieces.",
		"swatch": [Color("ffffff"), Color("d6c2ff"), Color("8a5cff")],
		"glow": Color("8b5cf6"), "shape": "sparkle", "colors": [Color("ffffff"), Color("d6c2ff"), Color("8a5cff")],
		"additive": true, "amount": 7, "lifetime": 1.2, "size": 0.18, "rise": Vector2(0.2, 0.4), "gravity": 0.0,
		"radius": 0.44, "height": 0.1},
}

static var _ring_materials: Dictionary = {}
static var _ring_mesh: PlaneMesh


## A ready-to-attach aura node for `style`, or null for "none"/unknown styles.
static func create(style: String) -> Node3D:
	if style == NONE or not STYLES.has(style):
		return null
	var s: Dictionary = STYLES[style]
	var root := Node3D.new()
	root.name = "Aura"

	var ring := MeshInstance3D.new()
	ring.mesh = _ring()
	ring.material_override = _ring_material(style, false)
	ring.position.y = 0.012
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	if s.get("scan", 0.0) > 0.0:
		# A second ring that the shader sweeps up and down the piece (neon scanner).
		var scan := MeshInstance3D.new()
		scan.mesh = _ring()
		scan.material_override = _ring_material(style, true)
		scan.position.y = 0.05
		scan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(scan)

	var p := FxTextures.particles(s["shape"], s.get("additive", false), s.get("amount", 6), s.get("lifetime", 1.0), s.get("size", 0.15))
	p.local_coords = true
	p.preprocess = s.get("lifetime", 1.0)
	p.position.y = s.get("height", 0.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = s.get("radius", 0.42)
	p.emission_ring_inner_radius = s.get("radius", 0.42) * 0.7
	p.emission_ring_height = 0.15
	p.direction = Vector3.UP
	p.spread = 20.0
	var rise: Vector2 = s.get("rise", Vector2(0.2, 0.4))
	p.initial_velocity_min = rise.x
	p.initial_velocity_max = rise.y
	p.gravity = Vector3(0.0, s.get("gravity", 0.0), 0.0)
	FxTextures.random_angle(p, s["shape"])
	var spin: float = s.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.3), Vector2(0.2, 1.0), Vector2(0.8, 0.9), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(s["colors"])
	if s.get("rainbow", false):
		p.color_initial_ramp = FxTextures.rainbow()
	if s.get("flicker", false):
		p.explosiveness = 0.0
		p.randomness = 1.0
		p.emission_ring_height = 0.6
		p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.5, 1.1), Vector2(1.0, 0.6)])
	root.add_child(p)
	return root


static func _ring() -> PlaneMesh:
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(1.3, 1.3)
	return _ring_mesh


## One shader material per style, shared by every piece. The pulse phase comes from the piece's
## world position so neighbouring rings don't throb in lockstep.
static func _ring_material(style: String, scanning: bool) -> ShaderMaterial:
	var key := "%s/%s" % [style, scanning]
	if _ring_materials.has(key):
		return _ring_materials[key]
	var s: Dictionary = STYLES[style]
	var mix: bool = s.get("glow_mix", false)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D ring_tex : source_color, filter_linear_mipmap;
uniform float rainbow = 0.0;
uniform float boost = 1.0;
uniform float scan = 0.0;
varying float phase;
varying float sweep;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void vertex() {
	phase = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	sweep = 0.5 + 0.5 * sin(TIME * 1.8 + phase);
	VERTEX.y += sweep * scan;
	VERTEX.xz *= 1.0 - 0.3 * sweep * step(0.001, scan);
}
void fragment() {
	vec4 t = texture(ring_tex, UV);
	float pulse = 0.72 + 0.28 * sin(TIME * 2.6 + phase);
	float ang = atan(UV.y - 0.5, UV.x - 0.5) / 6.2832;
	vec3 c = mix(tint.rgb, hue(fract(TIME * 0.3 + ang + phase * 0.05)), rainbow);
	ALBEDO = c * boost;
	ALPHA = t.a * tint.a * pulse * (scan > 0.0 ? 1.0 - 0.5 * sweep : 1.0);
}
""" % ("blend_mix" if mix else "blend_add")
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", Color(s["glow"], 0.8 if mix else 0.95))
	m.set_shader_parameter("ring_tex", FxTextures.texture(s.get("ring_shape", "glow_ring")))
	m.set_shader_parameter("rainbow", s.get("rainbow_ring", 0.0))
	m.set_shader_parameter("boost", s.get("ring_boost", 1.0))
	m.set_shader_parameter("scan", s.get("scan", 0.0) if scanning else 0.0)
	m.render_priority = 1
	_ring_materials[key] = m
	return m
