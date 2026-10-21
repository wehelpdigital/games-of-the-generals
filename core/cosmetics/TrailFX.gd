class_name TrailFX
extends RefCounted
## Move trails: particles left behind in world space while one of a side's pieces slides to a new
## tile. A short-lived CPUParticles3D is parented to the moving piece's rig (so it starts at the
## piece's height) but simulates in world space, so the particles stay where they were dropped.
##
## Style keys: shape, colors (over life), additive, amount, lifetime, size, velocity, gravity,
## spin, rainbow, flicker.

const NONE := "none"

const STYLES := {
	"none": {"name": "No trail", "rarity": "common", "collection": "classics", "desc": "Pieces move without a trace.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	"trail_sparkle": {"name": "Sparkle", "rarity": "common", "collection": "magical_sparkle", "desc": "A twinkle of golden sparkles.",
		"swatch": [Color("ffffff"), Color("ffe58a"), Color("ffc93c")],
		"shape": "sparkle", "colors": [Color("fff6c8"), Color("ffd24a"), Color("ffa21f")], "additive": false,
		"amount": 26, "lifetime": 0.7, "size": 0.26, "velocity": 0.3, "gravity": -0.3},
	"trail_fire": {"name": "Fire Streak", "rarity": "rare", "collection": "lava_fire", "desc": "Your pieces leave flames behind.",
		"swatch": [Color("fff3a8"), Color("ff7a1a"), Color("e8341c")],
		"shape": "flame", "colors": [Color("ffe14d"), Color("ff8a1f"), Color("e8341c")], "additive": false,
		"amount": 30, "lifetime": 0.6, "size": 0.38, "velocity": 0.25, "gravity": 1.2},
	"trail_smoke": {"name": "Smoke", "rarity": "common", "collection": "ninja_clan", "desc": "A puffy cartoon smoke trail.",
		"swatch": [Color("f4f1ff"), Color("c9c2dd"), Color("8f88a6")],
		"shape": "puff", "colors": [Color("ffffff", 0.9), Color("d9d4e8", 0.7), Color("a49dba", 0.4)], "additive": false,
		"amount": 20, "lifetime": 0.9, "size": 0.42, "velocity": 0.15, "gravity": 0.3, "spin": 60.0},
	"trail_stardust": {"name": "Stardust", "rarity": "epic", "collection": "space_opera", "desc": "Cosmic stars and blue dust.",
		"swatch": [Color("1b1440"), Color("6f8bff"), Color("c9b8ff")],
		"shape": "star", "colors": [Color("e9e2ff"), Color("a58bff"), Color("4f6bff")], "additive": false,
		"amount": 28, "lifetime": 0.9, "size": 0.22, "velocity": 0.4, "gravity": -0.2, "spin": 180.0},
	"trail_petals": {"name": "Petal Drift", "rarity": "rare", "collection": "sakura_blossom", "desc": "Cherry-blossom petals scatter behind.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")],
		"shape": "petal", "colors": [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")], "additive": false,
		"amount": 22, "lifetime": 1.0, "size": 0.22, "velocity": 0.4, "gravity": -0.6, "spin": 220.0},
	"trail_bubbles": {"name": "Bubbles", "rarity": "common", "collection": "ocean_water", "desc": "A stream of soapy bubbles.",
		"swatch": [Color("e6faff"), Color("9ee6ff"), Color("ff9ec7")],
		"shape": "bubble", "colors": [Color("ffffff"), Color("c8f2ff"), Color("ffc2e0")], "additive": false,
		"amount": 18, "lifetime": 1.0, "size": 0.26, "velocity": 0.25, "gravity": 0.5},
	"trail_lightning": {"name": "Lightning Dash", "rarity": "epic", "collection": "sky_weather", "desc": "Electric bolts crackle in your wake.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")],
		"shape": "bolt", "colors": [Color("e8fbff"), Color("6fd3ff"), Color("3a5bff")], "additive": false,
		"amount": 16, "lifetime": 0.3, "size": 0.46, "velocity": 0.1, "gravity": 0.0, "flicker": true},
	"trail_rainbow": {"name": "Rainbow Road", "rarity": "legendary", "collection": "cute_candy", "desc": "A rainbow ribbon of glowing dots.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")],
		"shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 36, "lifetime": 0.8, "size": 0.26, "velocity": 0.05, "gravity": 0.0, "rainbow": true},
	"trail_hearts": {"name": "Love Trail", "rarity": "rare", "collection": "cute_candy", "desc": "Hearts pop out behind every step.",
		"swatch": [Color("ffd1e1"), Color("ff6f9f"), Color("ff3b6e")],
		"shape": "heart", "colors": [Color("ffc2d8"), Color("ff6f9f"), Color("ff3b6e")], "additive": false,
		"amount": 16, "lifetime": 0.9, "size": 0.22, "velocity": 0.35, "gravity": 0.6},
	"trail_pixels": {"name": "8-Bit Dash", "rarity": "rare", "collection": "arcade_8bit", "desc": "Retro pixels pop behind your pieces.",
		"swatch": [Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")],
		"shape": "square", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 24, "lifetime": 0.6, "size": 0.14, "velocity": 0.4, "gravity": -1.5, "pixels": true},
	"trail_bat_swarm": {"name": "Bat Swarm", "rarity": "rare", "season": "halloween", "desc": "A flutter of little bats follows every move.",
		"swatch": [Color("2b1740"), Color("8b5cf6"), Color("ff7a12")],
		"shape": "bat", "colors": [Color("4a2a6e"), Color("2b1740"), Color("1d1030")], "additive": false,
		"amount": 18, "lifetime": 0.9, "size": 0.3, "velocity": 0.6, "gravity": -0.8},
	"trail_candy_cane": {"name": "Candy Canes", "rarity": "rare", "season": "christmas", "desc": "Striped candy canes tumble out behind your pieces.",
		"swatch": [Color("e63946"), Color("ffffff"), Color("2f8f4e")],
		"shape": "candy_cane", "colors": [Color("ff5a64"), Color("e63946"), Color("b81f2e")], "additive": false,
		"amount": 16, "lifetime": 0.8, "size": 0.3, "velocity": 0.35, "gravity": 0.6, "spin": 240.0},
	"trail_sparklers": {"name": "Sparklers", "rarity": "rare", "season": "new_year", "desc": "A crackle of New Year sparklers follows every move.",
		"swatch": [Color("ffffff"), Color("fff1b0"), Color("ffcf3f")],
		"shape": "sparkle", "colors": [Color("ffffff"), Color("fff1b0"), Color("ffcf3f")], "additive": false,
		"amount": 30, "lifetime": 0.5, "size": 0.22, "velocity": 0.6, "gravity": -1.0, "flicker": true},
	"trail_gold_coins": {"name": "Gold Coins", "rarity": "rare", "season": "lunar_new_year", "desc": "Lucky coins spill out behind your pieces.",
		"swatch": [Color("fff1b0"), Color("ffcf3f"), Color("d62828")],
		"shape": "coin", "colors": [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")], "additive": false,
		"amount": 16, "lifetime": 0.8, "size": 0.26, "velocity": 0.35, "gravity": -1.5, "spin": 300.0},
	"trail_rose_petals": {"name": "Rose Petals", "rarity": "rare", "season": "valentines", "desc": "Red rose petals drift down where you've been.",
		"swatch": [Color("ffc9da"), Color("ff7aa0"), Color("d6204a")],
		"shape": "petal", "colors": [Color("ffc9da"), Color("ff7aa0"), Color("d6204a")], "additive": false,
		"amount": 20, "lifetime": 0.9, "size": 0.24, "velocity": 0.3, "gravity": -0.4, "spin": 240.0},
	"trail_autumn_leaves": {"name": "Falling Leaves", "rarity": "common", "season": "thanksgiving", "desc": "Red and gold leaves swirl behind every move.",
		"swatch": [Color("ffc93c"), Color("ff8a1f"), Color("c8341c")],
		"shape": "leaf", "colors": [Color("ffc93c"), Color("ff8a1f"), Color("c8341c")], "additive": false,
		"amount": 16, "lifetime": 1.0, "size": 0.28, "velocity": 0.3, "gravity": -0.5, "spin": 200.0},
	"trail_hibiscus": {"name": "Hibiscus", "rarity": "common", "season": "summer", "desc": "Tropical flowers pop up in your wake.",
		"swatch": [Color("ff8ec0"), Color("ff4f7b"), Color("ffcf3f")],
		"shape": "flower", "colors": [Color("ff8ec0"), Color("ff4f7b"), Color("ffcf3f")], "additive": false,
		"amount": 14, "lifetime": 0.9, "size": 0.28, "velocity": 0.3, "gravity": -0.3, "spin": 120.0},
	"trail_gold_stars": {"name": "Golden Stars", "rarity": "rare", "season": "kalayaan", "desc": "Golden stars trail behind every move, bright as Independence Day.",
		"swatch": [Color("fff6c8"), Color("fcd116"), Color("0038a8")],
		"shape": "star", "colors": [Color("fff6c8"), Color("fcd116"), Color("ffb020")], "additive": false,
		"amount": 20, "lifetime": 0.8, "size": 0.24, "velocity": 0.35, "gravity": -0.2, "spin": 180.0},
	"trail_fiesta_confetti": {"name": "Fiesta Confetti", "rarity": "common", "season": "fiesta", "desc": "A burst of fiesta confetti with every step.",
		"swatch": [Color("ff3d7f"), Color("ffcf3f"), Color("27c98f"), Color("3d8bff")],
		"shape": "square", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 26, "lifetime": 0.8, "size": 0.13, "velocity": 0.5, "gravity": -1.2, "spin": 360.0, "rainbow": true},
	"trail_koi": {"name": "Koi Swim", "rarity": "epic", "collection": "great_wave", "desc": "Little koi swim along behind every move.",
		"swatch": [Color("ffffff"), Color("ff8a3a"), Color("e8341c")],
		"shape": "koi", "colors": [Color("ffffff"), Color("ff8a3a"), Color("e8341c")], "additive": false,
		"amount": 10, "lifetime": 1.0, "size": 0.3, "velocity": 0.2, "gravity": -0.2, "spin": 40.0},
	"trail_sea_foam": {"name": "Sea Foam Wake", "rarity": "common", "collection": "treasure_seas", "desc": "A foamy wake like a ship at full sail.",
		"swatch": [Color("ffffff"), Color("dff4ff"), Color("9fd8ff")],
		"shape": "bubble", "colors": [Color("ffffff"), Color("dff4ff"), Color("9fd8ff")], "additive": false,
		"amount": 20, "lifetime": 0.8, "size": 0.2, "velocity": 0.2, "gravity": 0.4},
	"trail_maple": {"name": "Red Maple", "rarity": "rare", "collection": "samurai_ronin", "desc": "Red maple leaves swirl behind your pieces.",
		"swatch": [Color("ff6a3a"), Color("e8341c"), Color("a81f1a")],
		"shape": "leaf", "colors": [Color("ff6a3a"), Color("e8341c"), Color("a81f1a")], "additive": false,
		"amount": 14, "lifetime": 1.1, "size": 0.26, "velocity": 0.3, "gravity": -0.4, "spin": 200.0},
	"trail_smoke_bomb": {"name": "Smoke Bomb", "rarity": "rare", "collection": "ninja_clan", "desc": "Your pieces vanish in puffs of violet smoke.",
		"swatch": [Color("6a5a8a", 0.9), Color("4a4070", 0.7), Color("2a2350", 0.3)],
		"shape": "puff", "colors": [Color("6a5a8a", 0.9), Color("4a4070", 0.7), Color("2a2350", 0.3)], "additive": false,
		"amount": 22, "lifetime": 0.9, "size": 0.45, "velocity": 0.2, "gravity": 0.3, "spin": 80.0},
	"trail_data_stream": {"name": "Data Stream", "rarity": "rare", "collection": "cyber_neon", "desc": "Bits of glowing data trail behind you.",
		"swatch": [Color("aef9ff"), Color("2ef6ff"), Color("ff2bd6")],
		"shape": "square", "colors": [Color("aef9ff"), Color("2ef6ff"), Color("ff2bd6")], "additive": false,
		"amount": 26, "lifetime": 0.6, "size": 0.1, "velocity": 0.3, "gravity": -0.8, "flicker": true},
	"trail_thruster": {"name": "Thruster Burn", "rarity": "epic", "collection": "giant_robots", "desc": "Blue jet flames push every move.",
		"swatch": [Color("ffffff"), Color("aef9ff"), Color("3a8aff")],
		"shape": "flame", "colors": [Color("ffffff"), Color("aef9ff"), Color("3a8aff")], "additive": false,
		"amount": 28, "lifetime": 0.5, "size": 0.3, "velocity": 0.2, "gravity": 0.8},
	"trail_rubble": {"name": "Rubble Trail", "rarity": "common", "collection": "kaiju_attack", "desc": "Chunks of rubble kick up behind you.",
		"swatch": [Color("a8a8a8"), Color("7a7a7a"), Color("5a5a5a")],
		"shape": "square", "colors": [Color("a8a8a8"), Color("7a7a7a"), Color("5a5a5a")], "additive": false,
		"amount": 18, "lifetime": 0.8, "size": 0.12, "velocity": 0.6, "gravity": -2.5, "spin": 300.0},
	"trail_warp": {"name": "Warp Streaks", "rarity": "epic", "collection": "space_opera", "desc": "Starlight stretches into streaks at warp speed.",
		"swatch": [Color("ffffff"), Color("aef0ff"), Color("6a8aff")],
		"shape": "streak", "colors": [Color("ffffff"), Color("aef0ff"), Color("6a8aff")], "additive": false,
		"amount": 24, "lifetime": 0.5, "size": 0.4, "velocity": 0.0, "gravity": 0.0},
	"trail_neon_streak": {"name": "Neon Streak", "rarity": "rare", "collection": "synthwave", "desc": "Glowing sunset dots in your wake.",
		"swatch": [Color("ffb020"), Color("ff4fa8"), Color("8a2bd6")],
		"shape": "dot", "colors": [Color("ffb020"), Color("ff4fa8"), Color("8a2bd6")], "additive": false,
		"amount": 30, "lifetime": 0.7, "size": 0.2, "velocity": 0.05, "gravity": 0.0},
	"trail_dust_kick": {"name": "Dust Kick", "rarity": "common", "collection": "wild_west", "desc": "Boots kick up the desert dust.",
		"swatch": [Color("e8d0a0", 0.9), Color("d8b880", 0.7), Color("b8945a", 0.3)],
		"shape": "puff", "colors": [Color("e8d0a0", 0.9), Color("d8b880", 0.7), Color("b8945a", 0.3)], "additive": false,
		"amount": 16, "lifetime": 0.8, "size": 0.35, "velocity": 0.25, "gravity": 0.2, "spin": 60.0},
	"trail_cogs": {"name": "Spinning Cogs", "rarity": "rare", "collection": "steampunk", "desc": "Brass cogs tumble out behind you.",
		"swatch": [Color("ffe0a0"), Color("e8b850"), Color("a8742a")],
		"shape": "gear", "colors": [Color("ffe0a0"), Color("e8b850"), Color("a8742a")], "additive": false,
		"amount": 12, "lifetime": 0.9, "size": 0.2, "velocity": 0.3, "gravity": -0.5, "spin": 180.0},
	"trail_frost_runes": {"name": "Frost Runes", "rarity": "rare", "collection": "norse_vikings", "desc": "Glowing runes mark your path.",
		"swatch": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")],
		"shape": "rune", "colors": [Color("ffffff"), Color("c8f2ff"), Color("7fc8ef")], "additive": false,
		"amount": 12, "lifetime": 1.0, "size": 0.2, "velocity": 0.2, "gravity": 0.3},
	"trail_golden_sand": {"name": "Golden Sand", "rarity": "common", "collection": "ancient_egypt", "desc": "A trickle of glittering desert sand.",
		"swatch": [Color("fff1b0"), Color("e8c078"), Color("c8944a")],
		"shape": "dot", "colors": [Color("fff1b0"), Color("e8c078"), Color("c8944a")], "additive": false,
		"amount": 30, "lifetime": 0.8, "size": 0.1, "velocity": 0.3, "gravity": -0.6},
	"trail_laurel": {"name": "Laurel Leaves", "rarity": "rare", "collection": "greek_gods", "desc": "Laurel leaves fall wherever you go.",
		"swatch": [Color("c8e88a"), Color("8ab84a"), Color("5a8a2a")],
		"shape": "leaf", "colors": [Color("c8e88a"), Color("8ab84a"), Color("5a8a2a")], "additive": false,
		"amount": 14, "lifetime": 1.0, "size": 0.22, "velocity": 0.3, "gravity": -0.3, "spin": 160.0},
	"trail_firefly": {"name": "Firefly Path", "rarity": "rare", "collection": "philippine_myths", "desc": "Fireflies follow your pieces.",
		"swatch": [Color("ffffff"), Color("e8ffa0"), Color("9be15d")],
		"shape": "dot", "colors": [Color("ffffff"), Color("e8ffa0"), Color("9be15d")], "additive": false,
		"amount": 16, "lifetime": 1.4, "size": 0.14, "velocity": 0.2, "gravity": 0.15, "flicker": true},
	"trail_speed_lines": {"name": "Speed Lines", "rarity": "common", "collection": "comic_hero", "desc": "WHOOSH! Comic speed lines.",
		"swatch": [Color("ffffff"), Color("ffe14d"), Color("ffffff")],
		"shape": "streak", "colors": [Color("ffffff"), Color("ffe14d"), Color("ffffff")], "additive": false,
		"amount": 22, "lifetime": 0.4, "size": 0.35, "velocity": 0.0, "gravity": 0.0},
	"trail_ooze": {"name": "Ooze Drip", "rarity": "rare", "collection": "zombie_outbreak", "desc": "Drips of green ooze.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")],
		"shape": "bubble", "colors": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")], "additive": false,
		"amount": 18, "lifetime": 0.9, "size": 0.2, "velocity": 0.1, "gravity": -0.5},
	"trail_ribbon_stars": {"name": "Twinkle Path", "rarity": "rare", "collection": "magical_sparkle", "desc": "Pastel stars sparkle behind you.",
		"swatch": [Color("ffffff"), Color("ffc2e0"), Color("b84dff")],
		"shape": "star", "colors": [Color("ffffff"), Color("ffc2e0"), Color("b84dff")], "additive": false,
		"amount": 20, "lifetime": 0.9, "size": 0.2, "velocity": 0.3, "gravity": -0.2, "spin": 180.0},
	"trail_light_sticks": {"name": "Light Stick Wave", "rarity": "rare", "collection": "concert_stage", "desc": "Glowing light-stick streaks follow the beat.",
		"swatch": [Color("ff2bd6"), Color("b84dff"), Color("3ad6ff")],
		"shape": "streak", "colors": [Color("ff2bd6"), Color("b84dff"), Color("3ad6ff")], "additive": false,
		"amount": 20, "lifetime": 0.6, "size": 0.3, "velocity": 0.0, "gravity": 0.0},
	"trail_spray_paint": {"name": "Spray Paint", "rarity": "rare", "collection": "street_graffiti", "desc": "A rainbow spray of paint behind you.",
		"swatch": [Color("ffffff"), Color("ffffff"), Color("ffffff")],
		"shape": "dot", "colors": [Color("ffffff"), Color("ffffff"), Color("ffffff")], "additive": false,
		"amount": 30, "lifetime": 0.7, "size": 0.14, "velocity": 0.35, "gravity": -0.6, "rainbow": true},
	"trail_royal_sparkle": {"name": "Royal Sparkle", "rarity": "rare", "collection": "fantasy_kingdom", "desc": "Gold and royal blue sparkles.",
		"swatch": [Color("ffffff"), Color("ffcf3f"), Color("2f4fae")],
		"shape": "sparkle", "colors": [Color("ffffff"), Color("ffcf3f"), Color("2f4fae")], "additive": false,
		"amount": 22, "lifetime": 0.8, "size": 0.2, "velocity": 0.3, "gravity": -0.3},
}


## Starts a trail on `parent` (a moving piece's rig) for `duration` seconds.
static func emit(parent: Node3D, style: String, duration: float) -> void:
	if style == NONE or not STYLES.has(style) or not parent.is_inside_tree():
		return
	var s: Dictionary = STYLES[style]
	var lifetime: float = s.get("lifetime", 0.7)
	var p := FxTextures.particles(s["shape"], s.get("additive", false), s.get("amount", 20), lifetime, s.get("size", 0.15))
	p.local_coords = false
	p.position.y = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = s.get("velocity", 0.3)
	p.gravity = Vector3(0.0, s.get("gravity", 0.0), 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	FxTextures.random_angle(p, s["shape"])
	var spin: float = s.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.6, 0.85), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(s["colors"])
	if s.get("rainbow", false):
		p.color_initial_ramp = FxTextures.rainbow()
	if s.get("pixels", false):
		var palette := Gradient.new()
		palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		palette.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
		palette.colors = PackedColorArray([Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")])
		p.color_initial_ramp = palette
		p.angle_min = 0.0
		p.angle_max = 0.0
	if s.get("flicker", false):
		p.randomness = 1.0
	p.emitting = true
	parent.add_child(p)
	var tree := parent.get_tree()
	# Bind the instance id, not the node: the piece (and its trail) may be freed first.
	var id := p.get_instance_id()
	tree.create_timer(maxf(duration, 0.1)).timeout.connect(_stop.bind(id))
	tree.create_timer(maxf(duration, 0.1) + lifetime + 0.2).timeout.connect(_free.bind(id))


static func _stop(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.emitting = false


static func _free(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.queue_free()
