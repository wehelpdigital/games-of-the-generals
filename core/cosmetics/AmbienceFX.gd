class_name AmbienceFX
extends Node3D
## Ambience: animated scenery over one player's half of the board: weather, sky shows, creatures
## and little people. The opponent sees it too. Everything is built in "side space": x runs across
## the board, +Z points toward the owner (their half spans z 0 → 4, the frame rim is z 4–4.5) and
## y is up from the tiles. The node is turned half a turn for black. CPU particles, billboards and
## tiny toon models only (WebGL 2 safe); nothing is bigger or more opaque than it needs to be, so the
## pieces stay readable.

const NONE := "none"
const HALF_X := 4.5    ## Half the playing area's width.
const RIM_X := 4.74    ## Middle of the frame rim along the board's sides.
const RIM_Z := 4.24    ## Middle of the frame rim on the owner's edge.
const RIM_Y := Board3D.FRAME_TOP
const PEOPLE_SCALE := 1.7
## Walkers follow a U around the owner's half on the frame rim: up the left side from the centre
## line, along the owner's edge, back up the right side. Its corners and total length:
const RIM_PATH := [Vector2(-RIM_X, 0.15), Vector2(-RIM_X, RIM_Z), Vector2(RIM_X, RIM_Z), Vector2(RIM_X, 0.15)]

## Device setting "Reduce ambience": fewer particles and fewer fly-bys.
static var reduced := false

const STYLES := {
	"none": {"name": "No ambience", "rarity": "common", "desc": "A calm, clear sky.",
		"swatch": [Color("e9e4f5"), Color("c9c2dd")]},
	# Weather.
	"ambience_snowfall": {"name": "Gentle Snowfall", "rarity": "common", "desc": "Soft snowflakes drift over your side.",
		"swatch": [Color("ffffff"), Color("dff3ff"), Color("9ccfff")]},
	"ambience_blizzard": {"name": "Blizzard", "rarity": "epic", "desc": "A howling snowstorm sweeps across your half.",
		"swatch": [Color("ffffff"), Color("bfe3ff"), Color("6c8fb5")]},
	"ambience_rain": {"name": "Rain Shower", "rarity": "common", "desc": "Steady rain with tiny splashes on your tiles.",
		"swatch": [Color("dff0ff"), Color("7fb8ff"), Color("3a6bb5")]},
	"ambience_thunderstorm": {"name": "Thunderstorm", "rarity": "epic", "desc": "Dark clouds, pouring rain and lightning flashes.",
		"swatch": [Color("3a3f5a"), Color("7fb8ff"), Color("fffbd1")]},
	"ambience_fog": {"name": "Rolling Fog", "rarity": "rare", "desc": "Low mist creeps between your pieces.",
		"swatch": [Color("f2f4f8"), Color("c9d2de"), Color("9aa6b8")]},
	"ambience_sandstorm": {"name": "Sandstorm", "rarity": "rare", "collection": "ancient_egypt", "desc": "Gusts of desert sand blow across your half.",
		"swatch": [Color("f6dfa8"), Color("e0b46a"), Color("a8783a")]},
	"ambience_clouds": {"name": "Drifting Clouds", "rarity": "common", "desc": "Fluffy clouds float by, their shadows gliding over the board.",
		"swatch": [Color("ffffff"), Color("e6f2ff"), Color("8fb8e6")]},
	# Sky shows.
	"ambience_meteors": {"name": "Meteor Shower", "rarity": "epic", "desc": "Blazing meteors streak across your sky.",
		"swatch": [Color("fff3a8"), Color("ff8a1f"), Color("3a1f5a")]},
	"ambience_aurora": {"name": "Aurora Lights", "rarity": "legendary", "desc": "Shimmering northern lights ripple above your side.",
		"swatch": [Color("4dffb0"), Color("3ad6ff"), Color("b05cff")]},
	"ambience_fireworks": {"name": "Fireworks Night", "rarity": "epic", "desc": "Rockets launch from behind you and burst overhead.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")]},
	"ambience_ufo": {"name": "UFO Fly-by", "rarity": "legendary", "desc": "A flying saucer drops by to scan your army, then zips away.",
		"swatch": [Color("c9d2de"), Color("4dffb0"), Color("6a3cff")]},
	"ambience_balloons": {"name": "Hot-Air Balloons", "rarity": "rare", "desc": "Striped balloons rise lazily beside your side.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("3d8bff")]},
	"ambience_paper_planes": {"name": "Paper Planes", "rarity": "common", "desc": "Paper planes loop and glide over your half.",
		"swatch": [Color("ffffff"), Color("e8eef8"), Color("9aa6b8")]},
	# Creatures.
	"ambience_birds": {"name": "Bird Flock", "rarity": "rare", "desc": "A flock of birds flaps across in a V.",
		"swatch": [Color("3a3150"), Color("ffb020"), Color("9ccfff")]},
	"ambience_butterflies": {"name": "Butterflies", "rarity": "common", "desc": "Colourful butterflies flutter around your pieces.",
		"swatch": [Color("ff7ab8"), Color("ffd23f"), Color("6fc3ff")]},
	"ambience_fireflies": {"name": "Fireflies", "rarity": "rare", "collection": "philippine_myths", "desc": "Warm little lights wander over your tiles.",
		"swatch": [Color("fffbb0"), Color("d4ff6a"), Color("1d2a1a")]},
	"ambience_bats": {"name": "Bat Swarm", "rarity": "rare", "desc": "Bats flit across your side at dusk.",
		"swatch": [Color("2a1f3a"), Color("6a3cff"), Color("ff8a1f")]},
	"ambience_ghosts": {"name": "Friendly Ghosts", "rarity": "epic", "desc": "Little ghosts float and peek around your pieces.",
		"swatch": [Color("ffffff"), Color("d6dcff"), Color("6a5acd")]},
	# Little people.
	"ambience_villagers": {"name": "Village Stroll", "rarity": "epic", "desc": "Tiny villagers stroll along the edge of your board.",
		"swatch": [Color("ff8a5a"), Color("3d8bff"), Color("ffd23f")]},
	"ambience_army_march": {"name": "Toy Army March", "rarity": "legendary", "desc": "A column of toy soldiers marches along your edge, drum and all.",
		"swatch": [Color("e8341c"), Color("1d1736"), Color("ffd23f")]},
	"ambience_parade": {"name": "Tiny Parade", "rarity": "legendary", "desc": "A float, a band and confetti parade past your side.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("b05cff")]},
	# Seasonal.
	"ambience_cherry_blossoms": {"name": "Cherry Blossoms", "rarity": "rare", "desc": "Pink petals tumble softly over your half.",
		"swatch": [Color("ffe3ee"), Color("ffb3d1"), Color("ff7ab0")]},
	"ambience_autumn_leaves": {"name": "Autumn Leaves", "rarity": "common", "desc": "Red and gold leaves twirl down over your side.",
		"swatch": [Color("ffb020"), Color("ff6a1a"), Color("c8341c")]},
	"ambience_confetti": {"name": "Confetti Rain", "rarity": "rare", "desc": "A never-ending party of falling confetti.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("6f8bff")]},
	"ambience_bubbles": {"name": "Bubble Breeze", "rarity": "common", "desc": "Soap bubbles float up from your tiles and pop.",
		"swatch": [Color("ffffff"), Color("b8ecff"), Color("ffb3ec")]},
	# Holidays.
	"ambience_haunted_night": {"name": "Haunted Night", "rarity": "epic", "season": "halloween", "desc": "Jack-o'-lantern lights float through purple mist while bats flit overhead.",
		"swatch": [Color("2a1d3e"), Color("ff8a1f"), Color("8b5cf6")]},
	"ambience_santa_sleigh": {"name": "Santa's Sleigh", "rarity": "legendary", "season": "christmas", "desc": "A sleigh and four reindeer fly over your half in a trail of sparkles, through gentle snow.",
		"swatch": [Color("d62f3a"), Color("8a5a2a"), Color("ffcf3f"), Color("ffffff")]},
	"ambience_midnight_fireworks": {"name": "Midnight Countdown", "rarity": "epic", "season": "new_year", "desc": "Gold and silver fireworks and a shower of golden sparkles.",
		"swatch": [Color("1d1736"), Color("ffcf3f"), Color("e8eef8")]},
	"ambience_heart_balloons": {"name": "Heart Balloons", "rarity": "rare", "season": "valentines", "desc": "Heart-shaped balloons float up from your side.",
		"swatch": [Color("ff2f5f"), Color("ff7aa0"), Color("ffb3d1")]},
	"ambience_red_lanterns": {"name": "Lantern Festival", "rarity": "epic", "season": "lunar_new_year", "desc": "Strings of glowing red lanterns sway above your half.",
		"swatch": [Color("e8282e"), Color("ffcf3f"), Color("5a3a24")]},
	"ambience_harvest_breeze": {"name": "Harvest Breeze", "rarity": "common", "season": "thanksgiving", "desc": "A gusty autumn wind full of red and gold leaves.",
		"swatch": [Color("ffc93c"), Color("ff8a1f"), Color("c8341c")]},
	"ambience_seaside_gulls": {"name": "Seaside Gulls", "rarity": "rare", "season": "summer", "desc": "Seagulls glide past while the sun glints over your side.",
		"swatch": [Color("ffffff"), Color("12b8c4"), Color("fff1b0")]},
	"ambience_kalayaan_fireworks": {"name": "Kalayaan Sky", "rarity": "epic", "season": "kalayaan", "desc": "Blue, red and gold fireworks with golden stars drifting down.",
		"swatch": [Color("0038a8"), Color("ce1126"), Color("fcd116")]},
	"ambience_banderitas": {"name": "Banderitas", "rarity": "rare", "season": "fiesta", "desc": "Strings of colourful fiesta bunting flutter over your half.",
		"swatch": [Color("ff3d7f"), Color("ffcf3f"), Color("27c98f"), Color("3d8bff")]},
	# Themed collections.
	"ambience_wave_spray": {"name": "Wave Spray", "rarity": "epic", "collection": "great_wave", "desc": "Sea spray bursts up beside the board and drifts over your half as foam mist.",
		"swatch": [Color("ffffff"), Color("8fc6ff"), Color("2a4a8a")]},
	"ambience_broadside": {"name": "Broadside", "rarity": "legendary", "collection": "treasure_seas", "desc": "Distant cannons flash and boom; cannonballs arc overhead and splash down.",
		"swatch": [Color("2a2d40"), Color("ffb020"), Color("f2ece2")]},
	"ambience_maple_wind": {"name": "Maple Wind", "rarity": "rare", "collection": "samurai_ronin", "desc": "Crimson maple leaves swept along by a strong wind.",
		"swatch": [Color("ff6a3a"), Color("e8341c"), Color("7a1010")]},
	"ambience_smoke_bombs": {"name": "Smoke Bombs", "rarity": "epic", "collection": "ninja_clan", "desc": "Smoke bombs pop along your rim and throwing stars whistle past.",
		"swatch": [Color("8a7aa8"), Color("3a2d55"), Color("c9d2de")]},
	"ambience_neon_drones": {"name": "Drone Patrol", "rarity": "epic", "collection": "cyber_neon", "desc": "Neon drones hum over your half, sweeping scan beams through a light neon drizzle.",
		"swatch": [Color("2ef6ff"), Color("ff2bd6"), Color("1b2447")]},
	"ambience_searchlights": {"name": "Hangar Searchlights", "rarity": "rare", "collection": "giant_robots", "desc": "Big searchlights sweep the sky on both sides of the board.",
		"swatch": [Color("fff6c8"), Color("4a5060"), Color("2f6bd8")]},
	"ambience_choppers": {"name": "Chopper Patrol", "rarity": "epic", "collection": "kaiju_attack", "desc": "Helicopters circle overhead, their spotlights hunting for something big.",
		"swatch": [Color("e8eef8"), Color("ffb020"), Color("2a2d40")]},
	"ambience_starfighters": {"name": "Starfighter Chase", "rarity": "legendary", "collection": "space_opera", "desc": "Three starfighters loop and chase each other above your half.",
		"swatch": [Color("e8eef8"), Color("3ad6ff"), Color("2a2d40")]},
	"ambience_laser_horizon": {"name": "Laser Horizon", "rarity": "epic", "collection": "synthwave", "desc": "Pink and cyan lasers fan out across the sky under twinkling stars.",
		"swatch": [Color("ff4fa8"), Color("3ad6ff"), Color("2a1048")]},
	"ambience_pixel_weather": {"name": "Pixel Weather", "rarity": "rare", "collection": "arcade_8bit", "desc": "Blocky clouds drift by, dropping pixel rain and the odd gold coin.",
		"swatch": [Color("ffffff"), Color("3d8bff"), Color("ffcf3f")]},
	"ambience_tumbleweeds": {"name": "Tumbleweed Breeze", "rarity": "common", "collection": "wild_west", "desc": "Tumbleweeds bounce past in a dusty breeze while vultures circle.",
		"swatch": [Color("c8a066"), Color("e8c890"), Color("4a3a2e")]},
	"ambience_steam_works": {"name": "Steam Works", "rarity": "rare", "collection": "steampunk", "desc": "Brass vents on your rim hiss steam while little gears float up.",
		"swatch": [Color("e8b850"), Color("c8743a"), Color("f2ece2")]},
	"ambience_raven_watch": {"name": "Raven Watch", "rarity": "rare", "collection": "norse_vikings", "desc": "Ravens cross a cold sky dusted with light snow.",
		"swatch": [Color("1d1a2a"), Color("ffffff"), Color("7fd6ff")]},
	"ambience_heavenly_rays": {"name": "Heavenly Rays", "rarity": "legendary", "collection": "greek_gods", "desc": "Golden sunbeams break through the clouds and glitter drifts down.",
		"swatch": [Color("fff6c8"), Color("ffd24a"), Color("ffffff")]},
	"ambience_sound_effects": {"name": "Sound Effects", "rarity": "epic", "collection": "comic_hero", "desc": "POW! ZAP! BAM! Comic sound effects pop up all around your half.",
		"swatch": [Color("fff36b"), Color("ff5a3a"), Color("3d8bff")]},
	"ambience_toxic_mist": {"name": "Toxic Mist", "rarity": "rare", "collection": "zombie_outbreak", "desc": "Green mist creeps over your tiles while bubbles rise and pop.",
		"swatch": [Color("b8ff6a"), Color("7ad04a"), Color("2a3a1a")]},
	"ambience_twinkle_dust": {"name": "Twinkle Dust", "rarity": "rare", "collection": "magical_sparkle", "desc": "Pastel stars float up while sparkles and little hearts drift down.",
		"swatch": [Color("ffb3ec"), Color("c9a8ff"), Color("ffffff")]},
	"ambience_stage_lights": {"name": "Stage Lights", "rarity": "legendary", "collection": "concert_stage", "desc": "Coloured spotlights sweep your half and confetti cannons fire.",
		"swatch": [Color("ff4fa8"), Color("3ad6ff"), Color("ffd23f")]},
	"ambience_street_beats": {"name": "Street Beats", "rarity": "rare", "collection": "street_graffiti", "desc": "Music notes bounce up and spray-paint clouds puff on your rim.",
		"swatch": [Color("ff3bd6"), Color("4dffb0"), Color("ffd23f")]},
	"ambience_dragon_flyover": {"name": "Dragon Flyover", "rarity": "legendary", "collection": "fantasy_kingdom", "desc": "A dragon sweeps across the sky and lets out a burst of fire.",
		"swatch": [Color("2f8a5a"), Color("c8342d"), Color("ffb020")]},
}


var style := NONE
var _actors: Array[Dictionary] = []  # {node, tick: Callable(actor, t, delta)}
var _spawners: Array[Dictionary] = []  # {every: Vector2, next: float, spawn: Callable}
var _time := 0.0
var _firework_palette: Array = []  # Themed shows (New Year gold, Kalayaan blue/red/gold); empty = any hue.


## A ready node for `side`'s half, or null for "none". Add it under the board.
static func create(side: String, slug: String) -> AmbienceFX:
	if slug == NONE or not STYLES.has(slug):
		return null
	var fx := AmbienceFX.new()
	fx.name = "Ambience_%s" % side
	fx.style = slug
	fx.rotation.y = 0.0 if side == Ranks.WHITE else PI
	return fx


func _ready() -> void:
	match style:
		"ambience_snowfall":
			_fall("snowflake", false, 80, 0.2, [Color("ffffff"), Color("e2f2ff"), Color("b8dcff")], 0.6, Vector3(0.25, 0.0, 0.0), 120.0)
		"ambience_blizzard":
			var snow := _fall("snowflake", false, 130, 0.18, [Color("ffffff"), Color("e2f2ff"), Color("b8dcff")], 1.6, Vector3(4.5, 0.0, 0.0), 300.0)
			snow.position.x -= 3.0
			var streaks := _fall("streak", false, 60, 0.5, [Color("ffffff", 0.0), Color("e8f4ff", 0.85), Color("b8dcff", 0.0)], 2.2, Vector3(6.0, 0.0, 0.0), 0.0, Vector2(0.08, 0.55))
			streaks.position.x -= 4.0
			_fog(12, [Color("f2f8ff", 0.0), Color("dceaff", 0.38), Color("c8daf2", 0.0)], 2.2)
		"ambience_rain":
			_rain(90)
		"ambience_thunderstorm":
			_rain(120)
			_storm_clouds()
			_every(Vector2(3.5, 7.0), _lightning)
		"ambience_fog":
			_fog(22, [Color("f6f8fb", 0.0), Color("e2e8f0", 0.3), Color("cfd8e3", 0.0)], 0.35)
		"ambience_sandstorm":
			var sand := _fall("dot", false, 150, 0.11, [Color("e8c078"), Color("c8944a"), Color("a8783a")], 0.25, Vector3(5.0, 0.0, 0.0), 0.0)
			sand.position = Vector3(-4.5, 1.0, 2.2)
			sand.emission_box_extents = Vector3(3.0, 1.0, 2.2)
			_fog(14, [Color("f0d098", 0.0), Color("d8b070", 0.42), Color("b8884a", 0.0)], 2.6)
		"ambience_clouds":
			for i in 3:
				_cloud(i)
		"ambience_meteors":
			_every(Vector2(0.7, 1.6), _meteor)
		"ambience_aurora":
			_aurora()
		"ambience_fireworks":
			_every(Vector2(0.6, 1.4), _firework)
		"ambience_ufo":
			_ufo()
		"ambience_balloons":
			for i in 3:
				_balloon(i)
		"ambience_paper_planes":
			for i in 3:
				_paper_plane(i)
		"ambience_birds":
			_flock("bird")
		"ambience_butterflies":
			for i in (3 if reduced else 5):
				_butterfly(i)
		"ambience_fireflies":
			_fireflies()
		"ambience_bats":
			_flock("bat")
		"ambience_ghosts":
			for i in 3:
				_ghost(i)
		"ambience_villagers":
			for i in (3 if reduced else 5):
				_villager(i)
		"ambience_army_march":
			_army()
		"ambience_parade":
			_parade()
		"ambience_cherry_blossoms":
			var petals := _fall("petal", false, 50, 0.24, [Color("ffe3ee"), Color("ffc2db"), Color("ff9ec7")], 0.5, Vector3(0.6, 0.0, 0.0), 220.0)
			petals.tangential_accel_min = -0.6
			petals.tangential_accel_max = 0.6
		"ambience_autumn_leaves":
			var leaves := _fall("leaf", false, 38, 0.3, [Color("ffc93c"), Color("ff8a1f"), Color("d6401c")], 0.55, Vector3(0.5, 0.0, 0.0), 260.0)
			leaves.color_initial_ramp = FxTextures.gradient([Color("ffd23f"), Color("ff8a1f"), Color("d6401c"), Color("a8341c")], false)
		"ambience_confetti":
			var confetti := _fall("square", false, 80, 0.13, [Color.WHITE, Color.WHITE, Color.WHITE], 0.7, Vector3(0.2, 0.0, 0.0), 540.0)
			confetti.color_initial_ramp = FxTextures.rainbow()
		"ambience_bubbles":
			_bubbles()
		"ambience_haunted_night":
			_fog(12, [Color("6a4a9a", 0.0), Color("5a3a8a", 0.32), Color("3a2a5a", 0.0)], 0.35)
			_pumpkin_lights()
			_flock("bat")
		"ambience_santa_sleigh":
			_fall("snowflake", false, 40, 0.16, [Color("ffffff"), Color("e2f2ff"), Color("b8dcff")], 0.5, Vector3(0.2, 0.0, 0.0), 120.0)
			_sleigh()
		"ambience_midnight_fireworks":
			_firework_palette = [Color("ffcf3f"), Color("fff1b0"), Color("e8eef8"), Color("ffb020")]
			_every(Vector2(0.5, 1.1), _firework)
			_fall("sparkle", false, 36, 0.16, [Color("fff6c8"), Color("ffd24a"), Color("ffa21f")], 0.4, Vector3.ZERO, 180.0)
		"ambience_heart_balloons":
			_heart_balloons()
			_fall("heart", false, 18, 0.18, [Color("ffe3ec"), Color("ff7aa0"), Color("ff2f5f")], 0.35, Vector3(0.2, 0.0, 0.0), 60.0)
		"ambience_red_lanterns":
			_lantern_strings()
			_fall("coin", false, 14, 0.16, [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")], 0.45, Vector3.ZERO, 260.0)
		"ambience_harvest_breeze":
			var gust := _fall("leaf", false, 46, 0.3, [Color("ffc93c"), Color("ff8a1f"), Color("d6401c")], 0.7, Vector3(2.6, 0.0, 0.0), 300.0)
			gust.position.x -= 2.5
			gust.color_initial_ramp = FxTextures.gradient([Color("ffd23f"), Color("ff8a1f"), Color("d6401c"), Color("8a4a1e")], false)
		"ambience_seaside_gulls":
			_flock("gull")
			_glints()
		"ambience_kalayaan_fireworks":
			_firework_palette = [Color("3d6bff"), Color("ff3d4a"), Color("fcd116"), Color("ffffff")]
			_every(Vector2(0.6, 1.3), _firework)
			_fall("star", false, 22, 0.2, [Color("fff6c8"), Color("fcd116"), Color("ffb020")], 0.35, Vector3.ZERO, 120.0)
		"ambience_banderitas":
			_banderitas()
			_fall("square", false, 24, 0.1, [Color.WHITE, Color.WHITE, Color.WHITE], 0.6, Vector3(0.3, 0.0, 0.0), 540.0).color_initial_ramp = FxTextures.rainbow()
		"ambience_wave_spray":
			_every(Vector2(0.7, 1.4), _spray_burst)
			_fog(10, [Color("ffffff", 0.0), Color("e8f4ff", 0.3), Color("c8e0ff", 0.0)], 0.5)
		"ambience_broadside":
			_every(Vector2(1.6, 3.0), _cannon_shot)
			_flock("gull")
		"ambience_maple_wind":
			var maple := _fall("leaf", false, 44, 0.28, [Color("ff6a3a"), Color("e8341c"), Color("b81c1c")], 0.6, Vector3(2.0, 0.0, 0.0), 300.0)
			maple.position.x -= 2.0
			maple.color_initial_ramp = FxTextures.gradient([Color("ff7a3a"), Color("e8341c"), Color("b81c1c"), Color("7a1010")], false)
			_fog(8, [Color("fff4ec", 0.0), Color("f2e2d8", 0.22), Color("e0ccc0", 0.0)], 0.6)
		"ambience_smoke_bombs":
			_every(Vector2(0.8, 1.8), _smoke_pop)
			_every(Vector2(2.4, 4.0), _shuriken_throw)
			_fall("leaf", false, 16, 0.22, [Color("8ad06a"), Color("5fa84a"), Color("3a7a3a")], 0.5, Vector3(1.4, 0.0, 0.0), 260.0)
		"ambience_neon_drones":
			for i in 3:
				_drone(i)
			_fall("streak", false, 50, 0.5, [Color("ff2bd6", 0.0), Color("2ef6ff", 0.7), Color("ff2bd6", 0.0)], 5.0, Vector3(0.4, -2.0, 0.0), 0.0, Vector2(0.05, 0.6))
		"ambience_searchlights":
			for i in 4:
				var x: float = [-HALF_X - 2.4, -HALF_X - 4.2, HALF_X + 2.4, HALF_X + 4.2][i]
				var light := _beam(Vector3(x, Board3D.GROUND_Y, -1.0 + (i % 2) * 3.0), Vector3(PI, 0.0, 0.0), 16.0, Vector2(0.2, 1.2), Color(1.0, 0.96, 0.78, 0.13))
				light.add_child(PropKit.model("searchlight", [
					PropKit.pt("4a5060", ShapeKit.cylinder(0.3, 0.26, 0.4, 16), Vector3.ZERO),
					PropKit.pt("fff6c8|g2.0", ShapeKit.cylinder(0.27, 0.27, 0.02, 16), Vector3(0.0, -0.21, 0.0), Vector3.ZERO, 0.0),
				]))
				_actor(light, _tick_sweep, {"base": Vector3(PI, 0.0, 0.0), "swing": Vector2(0.6, 0.3), "phase": i * 1.9, "speed": 0.45})
		"ambience_choppers":
			for i in 2:
				_chopper(i)
		"ambience_starfighters":
			for i in 3:
				_starfighter(i)
			_twinkle(30, 0.22, [Color("ffffff"), Color("c8e0ff"), Color("9cf6ff")], Vector3(0.0, 4.8, 0.0), Vector3(HALF_X + 3.0, 1.0, 3.0))
		"ambience_laser_horizon":
			for i in 6:
				var color := Color("ff4fa8") if i % 2 == 0 else Color("3ad6ff")
				var laser := _beam(Vector3(-5.0 + i * 2.0, Board3D.GROUND_Y, -7.0), Vector3(PI + 0.55, 0.0, 0.0), 18.0, Vector2(0.03, 0.16), Color(color, 0.4))
				_actor(laser, _tick_sweep, {"base": Vector3(PI + 0.55, 0.0, 0.0), "swing": Vector2(0.7, 0.15), "phase": i * 0.9, "speed": 0.7})
			_twinkle(30, 0.2, [Color("ffffff"), Color("ffd1f0"), Color("9cf6ff")], Vector3(0.0, 5.0, -1.0), Vector3(HALF_X + 3.0, 1.0, 3.0))
		"ambience_pixel_weather":
			for i in 3:
				_cloud(i, true)
			_fall("square", false, 44, 0.1, [Color("9cdcff"), Color("3d8bff"), Color("2f3fbf")], 2.2, Vector3.ZERO, 0.0)
			_fall("coin", false, 8, 0.22, [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")], 0.8, Vector3.ZERO, 200.0)
		"ambience_tumbleweeds":
			for i in 3:
				_tumbleweed(i)
			var dust := _fall("dot", false, 40, 0.1, [Color("e8c890"), Color("c8a066"), Color("a8804a")], 0.3, Vector3(2.4, 0.0, 0.0), 0.0)
			dust.position = Vector3(-4.0, 0.9, 2.2)
			dust.emission_box_extents = Vector3(3.0, 0.8, 2.2)
			_flock("vulture")
		"ambience_steam_works":
			_steam_vents()
			_rising("gear", 12, 0.3, [Color("e8b850"), Color("c8743a"), Color("d8a03a")], 0.3, 60.0)
		"ambience_raven_watch":
			_flock("raven")
			_fall("snowflake", false, 30, 0.16, [Color("ffffff"), Color("e2f2ff"), Color("b8dcff")], 0.4, Vector3(0.4, 0.0, 0.0), 100.0)
		"ambience_heavenly_rays":
			_cloud(0)
			_cloud(2)
			for i in 4:
				var ray := _beam(Vector3(-3.3 + i * 2.2, 8.0, 0.4 + (i % 2) * 2.0), Vector3(-0.15, 0.0, 0.18 - i * 0.12), 9.5, Vector2(0.4, 1.1), Color(1.0, 0.9, 0.6, 0.06))
				_actor(ray, _tick_ray, {"mat": (ray.get_child(0) as MeshInstance3D).material_override, "alpha": 0.075, "phase": i * 1.7})
			_fall("sparkle", false, 30, 0.14, [Color("fff6c8"), Color("ffd24a"), Color("ffa21f")], 0.35, Vector3.ZERO, 150.0)
		"ambience_sound_effects":
			_every(Vector2(0.9, 1.8), _comic_pop)
		"ambience_toxic_mist":
			_fog(16, [Color("b8ff6a", 0.0), Color("7ad04a", 0.3), Color("4a8a2a", 0.0)], 0.3)
			_rising("bubble", 18, 0.26, [Color("d4ff3a"), Color("8ad04a"), Color("b8ff6a")], 0.4)
		"ambience_twinkle_dust":
			_rising("star", 18, 0.22, [Color("ffb3ec"), Color("c9a8ff"), Color("ffffff")], 0.35, 90.0)
			_fall("sparkle", false, 26, 0.14, [Color("ffffff"), Color("ffd1f0"), Color("c9a8ff")], 0.3, Vector3.ZERO, 150.0)
			_fall("heart", false, 10, 0.16, [Color("ffe3ec"), Color("ff8ec0"), Color("ff5aa0")], 0.35, Vector3(0.2, 0.0, 0.0), 60.0)
		"ambience_stage_lights":
			var spots := [Color("ff4fa8"), Color("3ad6ff"), Color("b84dff"), Color("ffd23f")]
			for i in 4:
				var spot := _beam(Vector3(-3.6 + i * 2.4, 6.4, -1.0), Vector3(-0.4, 0.0, 0.0), 8.5, Vector2(0.1, 1.1), Color(spots[i], 0.08))
				_actor(spot, _tick_sweep, {"base": Vector3(-0.4, 0.0, 0.0), "swing": Vector2(0.4, 0.15), "phase": i * 1.4, "speed": 0.9})
			_every(Vector2(2.5, 4.5), _confetti_cannon)
			_rising("note", 10, 0.28, [Color("ff4fa8"), Color("3ad6ff"), Color("ffd23f")], 0.45)
		"ambience_street_beats":
			_rising("note", 16, 0.3, [Color("ff3bd6"), Color("4dffb0"), Color("ffd23f"), Color("3ad6ff")], 0.5)
			_every(Vector2(1.2, 2.4), _paint_puff)
		"ambience_dragon_flyover":
			_dragon()


func _process(delta: float) -> void:
	_time += delta
	for actor: Dictionary in _actors:
		if is_instance_valid(actor["node"]):
			(actor["tick"] as Callable).call(actor, _time, delta)
	for spawner: Dictionary in _spawners:
		if _time >= spawner["next"]:
			var every: Vector2 = spawner["every"]
			spawner["next"] = _time + randf_range(every.x, every.y) * (2.0 if reduced else 1.0)
			(spawner["spawn"] as Callable).call()


func _scaled(amount: int) -> int:
	return maxi(4, int(amount * (0.5 if reduced else 1.0)))


func _every(range_seconds: Vector2, spawn: Callable) -> void:
	_spawners.append({"every": range_seconds, "next": randf_range(0.1, 0.6), "spawn": spawn})


func _actor(node: Node3D, tick: Callable, extra := {}) -> Dictionary:
	add_child(node)
	var actor := {"node": node, "tick": tick}
	actor.merge(extra)
	_actors.append(actor)
	return actor


# --- Particle weather ----------------------------------------------------------------------------

## Things falling over the half: snow, petals, leaves, confetti... `wind` pushes them sideways.
func _fall(shape: String, additive: bool, amount: int, size: float, colors: Array, speed: float,
		wind: Vector3, spin: float, stretch := Vector2.ZERO) -> CPUParticles3D:
	var height := 4.6
	var lifetime := height / maxf(speed, 0.2) + 0.6
	var p := FxTextures.particles(shape, additive, _scaled(amount), lifetime, size)
	if stretch != Vector2.ZERO:
		var q := QuadMesh.new()
		q.size = stretch
		p.mesh = q
	p.local_coords = true
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, height, 2.0)
	p.emission_box_extents = Vector3(HALF_X + 0.4, 0.2, 2.3)
	p.direction = Vector3.DOWN
	p.spread = 8.0
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed * 1.2
	p.gravity = wind
	if spin > 0.0:
		FxTextures.random_angle(p, shape)
		p.angular_velocity_min = -spin
		p.angular_velocity_max = spin
	else:
		p.angle_min = 0.0
		p.angle_max = 0.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.4), Vector2(0.1, 1.0), Vector2(0.85, 1.0), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(colors)
	p.emitting = true
	add_child(p)
	return p


func _rain(amount: int) -> void:
	_fall("streak", false, amount, 0.6, [Color("d8ecff", 0.0), Color("7fb2f0", 0.9), Color("4f86d0", 0.0)], 5.5, Vector3(0.6, -2.0, 0.0), 0.0, Vector2(0.065, 0.75))
	# Tiny splashes hopping off the tiles.
	var splash := FxTextures.particles("dot", false, _scaled(40), 0.35, 0.1)
	splash.local_coords = true
	splash.preprocess = 0.35
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.position = Vector3(0.0, 0.04, 2.0)
	splash.emission_box_extents = Vector3(HALF_X, 0.01, 2.0)
	splash.direction = Vector3.UP
	splash.spread = 50.0
	splash.initial_velocity_min = 0.6
	splash.initial_velocity_max = 1.1
	splash.gravity = Vector3(0.0, -7.0, 0.0)
	splash.color_ramp = FxTextures.gradient([Color("e8f4ff", 0.95), Color("7fb2f0", 0.7)])
	splash.emitting = true
	add_child(splash)


## Low drifting mist (fog, blizzard and sandstorm haze). `drift` is its sideways speed.
func _fog(amount: int, colors: Array, drift: float) -> void:
	var p := FxTextures.particles("puff", false, _scaled(amount), 7.0, 2.2)
	p.local_coords = true
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(-1.0, 0.45, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.2, 2.0)
	p.direction = Vector3.RIGHT
	p.spread = 15.0
	p.initial_velocity_min = drift * 0.6
	p.initial_velocity_max = drift
	p.gravity = Vector3.ZERO
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -10.0
	p.angular_velocity_max = 10.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.color_ramp = FxTextures.gradient(colors, false)
	p.emitting = true
	add_child(p)


func _storm_clouds() -> void:
	# Two dark banks over the board's sides, so the rain and lightning have a source without the
	# clouds covering the pieces.
	for dir: float in [-1.0, 1.0]:
		var p := FxTextures.particles("puff", false, _scaled(9), 9.0, 2.0)
		p.local_coords = true
		p.preprocess = 9.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.position = Vector3(dir * (HALF_X + 1.4), 3.6, 2.0)
		p.emission_box_extents = Vector3(0.9, 0.4, 2.2)
		p.direction = Vector3(0.0, 0.0, -1.0)
		p.spread = 30.0
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.15
		p.gravity = Vector3.ZERO
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.color_ramp = FxTextures.gradient([Color("4a4f6a", 0.0), Color("3a3f5a", 0.7), Color("2a2d40", 0.65), Color("2a2d40", 0.0)], false)
		p.emitting = true
		add_child(p)


func _lightning() -> void:
	var bolt := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 4.4)
	bolt.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_texture = FxTextures.texture("bolt")
	m.albedo_color = Color("e8f6ff")
	m.render_priority = 3
	bolt.material_override = m
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.position = Vector3(randf_range(-HALF_X, HALF_X), 2.6, randf_range(0.4, 3.4))
	add_child(bolt)
	var light := OmniLight3D.new()
	light.light_color = Color("d8ecff")
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position = bolt.position + Vector3(0.0, 1.5, 0.0)
	add_child(light)
	var t := create_tween()
	for k in 3:
		t.tween_property(m, "albedo_color:a", 0.1, 0.04)
		t.tween_property(m, "albedo_color:a", 1.0, 0.04)
	t.tween_property(m, "albedo_color:a", 0.0, 0.2)
	t.parallel().tween_property(light, "light_energy", 0.0, 0.3)
	t.tween_callback(bolt.queue_free)
	t.tween_callback(light.queue_free)


func _fireflies() -> void:
	var p := FxTextures.particles("sparkle", false, _scaled(30), 3.2, 0.3)
	p.local_coords = true
	p.preprocess = 3.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, 1.0, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.6, 2.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.tangential_accel_min = -0.4
	p.tangential_accel_max = 0.4
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.0), Vector2(0.15, 1.0), Vector2(0.35, 0.35), Vector2(0.55, 1.0), Vector2(0.8, 0.5), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient([Color("ffe600"), Color("c8f000"), Color("8ad000")])
	p.emitting = true
	add_child(p)
	var glow := FxTextures.particles("dot", true, _scaled(28), 3.2, 0.5)
	glow.local_coords = true
	glow.preprocess = 3.2
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	glow.position = p.position
	glow.emission_box_extents = p.emission_box_extents
	glow.direction = Vector3.UP
	glow.spread = 180.0
	glow.initial_velocity_min = 0.1
	glow.initial_velocity_max = 0.35
	glow.gravity = Vector3.ZERO
	glow.scale_amount_curve = p.scale_amount_curve
	glow.color_ramp = FxTextures.gradient([Color("fffbb0", 0.5), Color("e6ff7a", 0.4), Color("b8ff4a", 0.3)])
	glow.emitting = true
	add_child(glow)


func _bubbles() -> void:
	var p := FxTextures.particles("bubble", false, _scaled(30), 3.6, 0.36)
	p.local_coords = true
	p.preprocess = 3.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, 0.25, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.1, 2.0)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.15, 0.0, 0.0)
	p.angle_min = 0.0
	p.angle_max = 0.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.2), Vector2(0.2, 1.0), Vector2(0.92, 1.05), Vector2(0.96, 1.4), Vector2(1.0, 0.0)])
	p.color_initial_ramp = FxTextures.gradient([Color("ffffff", 1.0), Color("8fdcff", 1.0), Color("ff9ee6", 1.0)], false)
	p.emitting = true
	add_child(p)


# --- Sky shows -----------------------------------------------------------------------------------

func _meteor() -> void:
	var root := Node3D.new()
	var start := Vector3(randf_range(-HALF_X - 2.0, HALF_X - 1.0), 6.2, randf_range(-0.5, 1.5))
	var end := start + Vector3(randf_range(2.5, 4.0), -3.8, randf_range(2.0, 3.0))
	root.position = start
	add_child(root)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.2, 1.4, 0.6)
	head.material_override = m
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	var trail := FxTextures.particles("flame", false, 34, 0.55, 0.5)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.06
	trail.spread = 180.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.gravity = Vector3.ZERO
	trail.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	trail.color_ramp = FxTextures.gradient([Color("fff3a8"), Color("ff8a1f"), Color("c8341c")])
	trail.emitting = true
	root.add_child(trail)
	var t := create_tween()
	t.tween_property(root, "position", end, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(head, "scale", Vector3.ONE * 0.2, 0.25).set_delay(0.65)
	t.tween_callback(func() -> void: trail.emitting = false)
	t.tween_interval(0.6)
	t.tween_callback(root.queue_free)


func _firework() -> void:
	var launch := Vector3(randf_range(-HALF_X, HALF_X), 0.0, 5.0)
	var burst_at := Vector3(launch.x + randf_range(-1.0, 1.0), randf_range(3.6, 4.8), randf_range(1.0, 2.6))
	var rocket := FxTextures.particles("sparkle", true, 18, 0.35, 0.16)
	rocket.local_coords = false
	rocket.spread = 180.0
	rocket.initial_velocity_min = 0.0
	rocket.initial_velocity_max = 0.3
	rocket.gravity = Vector3(0.0, -1.0, 0.0)
	rocket.color_ramp = FxTextures.gradient([Color("ffffff"), Color("fff1b0"), Color("ffb020")])
	rocket.emitting = true
	rocket.position = launch
	add_child(rocket)
	var t := create_tween()
	t.tween_property(rocket, "position", burst_at, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		rocket.emitting = false
		_firework_burst(burst_at))
	t.tween_interval(0.5)
	t.tween_callback(rocket.queue_free)


func _firework_burst(at: Vector3) -> void:
	var hue := randf()
	var base := Color.from_hsv(hue, 0.75, 1.0)
	if not _firework_palette.is_empty():
		base = _firework_palette.pick_random()
		hue = base.h
	var p := FxTextures.particles("star" if randf() < 0.5 else "sparkle", false, _scaled(50), 1.3, 0.3)
	p.local_coords = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = at
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0.0, -1.2, 0.0)
	p.damping_min = 0.8
	p.damping_max = 1.2
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient([Color("ffffff"), base, Color.from_hsv(fposmod(hue + 0.1, 1.0), 0.8, 0.9)])
	p.emitting = true
	add_child(p)
	var light := OmniLight3D.new()
	light.light_color = base
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = at
	add_child(light)
	var t := create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.6)
	t.tween_callback(light.queue_free)
	t.tween_interval(1.0)
	t.tween_callback(p.queue_free)


func _aurora() -> void:
	var ribbon := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(13.0, 1.6)
	plane.subdivide_width = 48
	plane.orientation = PlaneMesh.FACE_Z
	ribbon.mesh = plane
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float speed = 0.35;
void vertex() {
	VERTEX.z += sin(VERTEX.x * 0.7 + TIME * speed * 2.0) * 0.6 + sin(VERTEX.x * 1.9 - TIME * speed * 3.1) * 0.2;
	VERTEX.y += sin(VERTEX.x * 1.1 + TIME * speed) * 0.25;
}
void fragment() {
	float band = UV.x * 3.0 + TIME * speed * 0.6;
	vec3 green = vec3(0.25, 1.0, 0.65);
	vec3 teal = vec3(0.2, 0.75, 1.0);
	vec3 violet = vec3(0.7, 0.35, 1.0);
	vec3 col = mix(mix(green, teal, 0.5 + 0.5 * sin(band)), violet, 0.5 + 0.5 * sin(band * 0.7 + 1.3));
	float curtain = 0.55 + 0.45 * sin(UV.x * 40.0 + sin(UV.x * 7.0 + TIME) * 3.0);
	float vertical = smoothstep(0.0, 0.35, 1.0 - UV.y) * smoothstep(0.0, 0.12, UV.y);
	float ends = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
	ALBEDO = col;
	ALPHA = curtain * vertical * ends * 0.55;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	ribbon.material_override = m
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.position = Vector3(0.0, 4.6, 0.2)
	ribbon.rotation.x = deg_to_rad(-12.0)
	add_child(ribbon)
	var sparkle := FxTextures.particles("sparkle", true, _scaled(16), 2.0, 0.12)
	sparkle.local_coords = true
	sparkle.preprocess = 2.0
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkle.position = Vector3(0.0, 4.2, 0.8)
	sparkle.emission_box_extents = Vector3(5.5, 0.8, 0.4)
	sparkle.gravity = Vector3.ZERO
	sparkle.initial_velocity_max = 0.05
	sparkle.color_ramp = FxTextures.gradient([Color("ffffff"), Color("aaffdd"), Color("b05cff")])
	sparkle.emitting = true
	add_child(sparkle)


# --- Models --------------------------------------------------------------------------------------

## Two flapping wings around a body; returns {root, left, right} pivots.
func _winged(key: String, body: Array, wing: Array, span: float) -> Dictionary:
	var root := PropKit.model(key + "/body", body)
	var left := Node3D.new()
	left.position = Vector3(-span, 0.0, 0.0)
	left.add_child(PropKit.model(key + "/wing", wing))
	root.add_child(left)
	var right := Node3D.new()
	right.position = Vector3(span, 0.0, 0.0)
	right.scale = Vector3(-1.0, 1.0, 1.0)
	right.add_child(PropKit.model(key + "/wing", wing))
	root.add_child(right)
	return {"root": root, "left": left, "right": right}


func _flap(actor: Dictionary, t: float, rate: float, amount: float) -> void:
	var a := sin(t * rate + float(actor.get("phase", 0.0))) * amount
	(actor["left"] as Node3D).rotation.z = a
	(actor["right"] as Node3D).rotation.z = a


# --- Fly-bys -------------------------------------------------------------------------------------

## A flock crossing the sky: "bird", "bat", "gull", "raven" or "vulture".
func _flock(kind: String) -> void:
	var bats := kind == "bat"
	var count := 4 if reduced else (6 if bats else (3 if kind == "vulture" else 7))
	var key := kind
	var body_color: String = {"bat": "2a1f3a", "gull": "ffffff", "raven": "1d1a2a", "vulture": "4a3a2e"}.get(kind, "3a3150")
	var body := [
		PropKit.pt(body_color, ShapeKit.capsule(0.045, 0.2), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt(body_color, ShapeKit.sphere(0.045), Vector3(0.0, 0.03, -0.1)),
	]
	if not bats:
		var beak: String = {"raven": "3a3a48", "vulture": "e8d0a0"}.get(kind, "ffb020")
		body.append(PropKit.pt(beak, ShapeKit.cone(0.02, 0.06, 8), Vector3(0.0, 0.03, -0.16), Vector3(-PI / 2.0, 0.0, 0.0), 0.0))
	var wing_poly := PackedVector2Array([Vector2(0.0, 0.03), Vector2(-0.2, 0.0), Vector2(-0.26, -0.05), Vector2(-0.12, -0.04), Vector2(0.0, -0.05)]) if bats \
		else PackedVector2Array([Vector2(0.0, 0.04), Vector2(-0.22, 0.01), Vector2(-0.18, -0.03), Vector2(0.0, -0.04)])
	var wing_color: String = {"bat": "4a3a6a", "gull": "dfe6ee", "raven": "2a2640", "vulture": "5a4636"}.get(kind, "5a4f78")
	var wing := [PropKit.pt(wing_color, ShapeKit.prism(wing_poly, 0.012, 0.004), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.01)]
	for i in count:
		var parts := _winged(key, body, wing, 0.04)
		var root: Node3D = parts["root"]
		var row := int((i + 1) / 2.0)
		var offset := Vector3(row * 0.7 * (1.0 if i % 2 == 0 else -1.0), randf_range(-0.2, 0.2), row * 0.9)
		root.scale = Vector3.ONE * (2.0 if bats else (2.7 if kind == "vulture" else 2.2))
		_actor(root, _tick_flock, {"left": parts["left"], "right": parts["right"], "offset": offset,
			"phase": randf() * TAU, "bats": bats, "last": i == count - 1})
	_flock_reset()


var _flock_from := Vector3.ZERO
var _flock_to := Vector3.ZERO
var _flock_start := 0.0
var _flock_time := 6.0


func _flock_reset() -> void:
	var y := randf_range(2.2, 3.2)
	var z := randf_range(0.8, 3.0)
	var dir := 1.0 if randf() < 0.5 else -1.0
	_flock_from = Vector3(-8.0 * dir, y, z)
	_flock_to = Vector3(8.0 * dir, y + randf_range(-0.5, 0.5), z + randf_range(-1.0, 1.0))
	_flock_start = _time + randf_range(0.0, 2.5) * (2.0 if reduced else 1.0)
	_flock_time = randf_range(5.0, 7.0)


func _tick_flock(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var k := (t - _flock_start) / _flock_time
	if k > 1.0 and actor["last"]:
		_flock_reset()
	node.visible = k >= 0.0 and k <= 1.0
	if not node.visible:
		return
	var heading := (_flock_to - _flock_from).normalized()
	var offset: Vector3 = actor["offset"]
	var side := heading.cross(Vector3.UP).normalized()
	var pos := _flock_from.lerp(_flock_to, k) + side * offset.x - heading * offset.z + Vector3(0.0, offset.y, 0.0)
	var bats: bool = actor["bats"]
	if bats:
		pos.y += sin(t * 5.0 + float(actor["phase"])) * 0.18
	node.position = pos
	node.look_at(to_global(pos + heading), Vector3.UP)
	_flap(actor, t, 22.0 if bats else 13.0, 0.9 if bats else 0.6)


func _butterfly(i: int) -> void:
	var colors := ["ff7ab8", "ffd23f", "6fc3ff", "b05cff", "4dffb0"]
	var color: String = colors[i % colors.size()]
	var body := [PropKit.pt("2a1f3a", ShapeKit.capsule(0.015, 0.1), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), 0.0)]
	var wing_poly := PackedVector2Array([Vector2(0.0, 0.0), Vector2(-0.08, 0.07), Vector2(-0.12, 0.02), Vector2(-0.07, -0.05), Vector2(0.0, -0.03)])
	var wing := [PropKit.pt(color, ShapeKit.prism(wing_poly, 0.006, 0.002), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.008)]
	var parts := _winged("butterfly_" + color, body, wing, 0.012)
	var root: Node3D = parts["root"]
	root.scale = Vector3.ONE * 2.8
	var center := Vector3(randf_range(-HALF_X + 0.8, HALF_X - 0.8), randf_range(1.0, 1.6), randf_range(0.6, 3.4))
	_actor(root, _tick_butterfly, {"left": parts["left"], "right": parts["right"], "center": center,
		"phase": randf() * TAU, "radius": Vector2(randf_range(0.6, 1.4), randf_range(0.4, 0.9))})


func _tick_butterfly(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var c: Vector3 = actor["center"]
	var r: Vector2 = actor["radius"]
	var ph: float = actor["phase"]
	var pos := c + Vector3(sin(t * 0.7 + ph) * r.x, sin(t * 2.3 + ph) * 0.18, sin(t * 1.1 + ph * 1.7) * r.y)
	var ahead := c + Vector3(sin((t + 0.1) * 0.7 + ph) * r.x, pos.y - c.y, sin((t + 0.1) * 1.1 + ph * 1.7) * r.y)
	node.position = pos
	if not ahead.is_equal_approx(pos):
		node.look_at(to_global(ahead), Vector3.UP)
	_flap(actor, t, 24.0, 1.1)


func _paper_plane(i: int) -> void:
	var poly := PackedVector2Array([Vector2(0.0, -0.22), Vector2(0.13, 0.12), Vector2(0.0, 0.07), Vector2(-0.13, 0.12)])
	var plane := PropKit.model("paper_plane", [
		PropKit.pt("ffffff", ShapeKit.prism(poly, 0.012, 0.003), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.012),
		PropKit.pt("dde4f0", ShapeKit.prism(PackedVector2Array([Vector2(0.0, -0.2), Vector2(0.015, 0.1), Vector2(-0.015, 0.1)]), 0.05, 0.002), Vector3(0.0, -0.025, 0.0), Vector3(-PI / 2.0, 0.0, 0.0), 0.0),
	])
	plane.scale = Vector3.ONE * 2.0
	var center := Vector3(randf_range(-2.0, 2.0), 2.2 + i * 0.35, randf_range(1.2, 2.8))
	_actor(plane, _tick_plane, {"center": center, "phase": i * TAU / 3.0, "radius": Vector2(randf_range(2.4, 3.6), randf_range(1.0, 1.6)),
		"speed": randf_range(0.35, 0.5)})


func _tick_plane(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var c: Vector3 = actor["center"]
	var r: Vector2 = actor["radius"]
	var a := t * float(actor["speed"]) + float(actor["phase"])
	var pos := c + Vector3(cos(a) * r.x, sin(a * 2.0) * 0.25, sin(a) * r.y)
	var ahead := c + Vector3(cos(a + 0.05) * r.x, sin((a + 0.05) * 2.0) * 0.25, sin(a + 0.05) * r.y)
	node.position = pos
	node.look_at(to_global(ahead), Vector3.UP)
	node.rotate_object_local(Vector3.FORWARD, -0.45)  # Bank into the turn.


func _ufo() -> void:
	var saucer := PropKit.model("ufo", [
		PropKit.pt("c9d2de", ShapeKit.sphere(0.5, 0.18, 28), Vector3.ZERO),
		PropKit.pt("9aa6b8", ShapeKit.torus(0.42, 0.55, 28, 6), Vector3(0.0, -0.01, 0.0)),
		PropKit.pt("9cf6ff|a0.7", ShapeKit.sphere(0.2, 0.26, 20), Vector3(0.0, 0.09, 0.0)),
		PropKit.pt("4dffb0|g2.0", ShapeKit.sphere(0.04), Vector3(0.38, -0.02, 0.0), Vector3.ZERO, 0.0),
		PropKit.pt("ff5cd6|g2.0", ShapeKit.sphere(0.04), Vector3(-0.38, -0.02, 0.0), Vector3.ZERO, 0.0),
		PropKit.pt("ffd23f|g2.0", ShapeKit.sphere(0.04), Vector3(0.0, -0.02, 0.38), Vector3.ZERO, 0.0),
		PropKit.pt("6f8bff|g2.0", ShapeKit.sphere(0.04), Vector3(0.0, -0.02, -0.38), Vector3.ZERO, 0.0),
	])
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.75
	cone.height = 2.6
	cone.radial_segments = 20
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.3, 1.0, 0.7, 0.0)
	beam.material_override = m
	beam.position = Vector3(0.0, -1.35, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	saucer.add_child(beam)
	saucer.visible = false
	_actor(saucer, _tick_ufo, {"beam": m, "cycle": 9.0, "start": 0.5})


func _tick_ufo(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var cycle: float = float(actor["cycle"]) * (1.6 if reduced else 1.0)
	var k := fposmod(t - float(actor["start"]), cycle)
	var hover := Vector3(sin(t * 0.3) * 1.5, 2.9, 2.0)
	var beam: StandardMaterial3D = actor["beam"]
	node.visible = k < 6.0
	if k < 1.4:
		var e := ease(k / 1.4, 0.3)
		node.position = Vector3(-9.0, 4.5, 0.5).lerp(hover, e)
		beam.albedo_color.a = 0.0
	elif k < 4.4:
		node.position = hover + Vector3(0.0, sin(t * 2.0) * 0.08, 0.0)
		beam.albedo_color.a = 0.22 * clampf(minf(k - 1.6, 4.2 - k) * 3.0, 0.0, 1.0)
	elif k < 6.0:
		var e := ease((k - 4.4) / 1.6, 2.5)
		node.position = hover.lerp(Vector3(9.0, 5.5, 0.0), e)
		beam.albedo_color.a = 0.0
	node.rotation.y = t * 3.0


func _balloon(i: int) -> void:
	var colors := [["ff4d6d", "ffd23f"], ["3d8bff", "ffffff"], ["4dffb0", "b05cff"]]
	var pair: Array = colors[i % colors.size()]
	var parts := [
		PropKit.pt(pair[0], ShapeKit.sphere(0.32, 0.72, 20), Vector3(0.0, 0.62, 0.0)),
		PropKit.pt(pair[1], ShapeKit.torus(0.27, 0.33, 24, 6), Vector3(0.0, 0.62, 0.0)),
		PropKit.pt("8a5a2a", ShapeKit.box(Vector3(0.16, 0.12, 0.16), 0.02, 0.01), Vector3(0.0, 0.08, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.006, 0.006, 0.36, 4), Vector3(0.07, 0.3, 0.0), Vector3(0.0, 0.0, 0.18), 0.0),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.006, 0.006, 0.36, 4), Vector3(-0.07, 0.3, 0.0), Vector3(0.0, 0.0, -0.18), 0.0),
	]
	var balloon := PropKit.model("balloon_%d" % (i % colors.size()), parts)
	var x: float = [-HALF_X - 0.9, HALF_X + 0.9, 0.0][i % 3]
	var z: float = [1.2, 2.6, -0.4][i % 3]
	_actor(balloon, _tick_balloon, {"x": x, "z": z, "phase": i * 7.0, "period": randf_range(18.0, 24.0)})


func _tick_balloon(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var period: float = actor["period"]
	var k := fposmod(t + float(actor["phase"]), period) / period
	node.position = Vector3(float(actor["x"]) + sin(t * 0.4 + float(actor["phase"])) * 0.3, lerpf(-0.6, 6.5, k), float(actor["z"]))
	node.scale = Vector3.ONE * 1.4 * clampf(minf(k * 8.0, (1.0 - k) * 6.0), 0.0, 1.0)
	node.rotation.y = sin(t * 0.3 + float(actor["phase"])) * 0.4


func _cloud(i: int, pixel := false) -> void:
	var cloud: Node3D
	if pixel:
		cloud = PropKit.model("pixel_cloud", [
			PropKit.pt("ffffff", _cube(Vector3(1.6, 0.4, 0.8)), Vector3.ZERO, Vector3.ZERO, 0.03),
			PropKit.pt("ffffff", _cube(Vector3(0.8, 0.4, 0.8)), Vector3(-0.2, 0.4, 0.0), Vector3.ZERO, 0.03),
			PropKit.pt("eef4ff", _cube(Vector3(0.4, 0.4, 0.8)), Vector3(0.4, 0.32, 0.0), Vector3.ZERO, 0.03),
		])
	else:
		cloud = PropKit.model("cloud", [
			PropKit.pt("ffffff", ShapeKit.sphere(0.55, 0.6, 16), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 0.0),
			PropKit.pt("ffffff", ShapeKit.sphere(0.42, 0.48, 16), Vector3(0.55, -0.05, 0.1), Vector3.ZERO, 0.0),
			PropKit.pt("ffffff", ShapeKit.sphere(0.45, 0.5, 16), Vector3(-0.55, -0.04, -0.05), Vector3.ZERO, 0.0),
			PropKit.pt("eef4ff", ShapeKit.sphere(0.36, 0.4, 16), Vector3(0.2, 0.22, -0.1), Vector3.ZERO, 0.0),
		])
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6, 1.6)
	shadow.mesh = plane
	shadow.material_override = FxTextures.decal_material("dot", Color(0.1, 0.1, 0.2, 0.22), false)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	var z := 0.6 + i * 1.3
	_actor(cloud, _tick_cloud, {"shadow": shadow, "z": z, "y": 4.4 + i * 0.3, "speed": randf_range(0.25, 0.4), "offset": i * 4.5})


func _tick_cloud(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var span := 16.0
	var x := fposmod(t * float(actor["speed"]) + float(actor["offset"]), span) - span / 2.0
	node.position = Vector3(x, float(actor["y"]), float(actor["z"]))
	var shadow: MeshInstance3D = actor["shadow"]
	shadow.position = Vector3(x + 0.6, 0.03, float(actor["z"]))
	shadow.visible = absf(x + 0.6) < HALF_X + 0.6


func _ghost(i: int) -> void:
	var ghost := MeshInstance3D.new()
	ghost.mesh = FxTextures.quad(0.95)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = FxTextures.texture("ghost")
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	m.render_priority = 2
	ghost.material_override = m
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_actor(ghost, _tick_ghost, {"mat": m, "phase": i * 2.4, "center": Vector3(-3.0 + i * 3.0, 1.3, 1.0 + i)})


func _tick_ghost(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var ph: float = actor["phase"]
	var c: Vector3 = actor["center"]
	node.position = c + Vector3(sin(t * 0.5 + ph) * 1.4, sin(t * 1.8 + ph) * 0.15, sin(t * 0.35 + ph) * 1.0)
	var cycle := fposmod(t * 0.25 + ph, 1.0)
	(actor["mat"] as StandardMaterial3D).albedo_color.a = 0.75 * clampf(minf(cycle * 5.0, (1.0 - cycle) * 5.0), 0.0, 1.0)


# --- Little people on the rim --------------------------------------------------------------------

func _person(key: String, coat: String, head: String, hat: Array, extra: Array = []) -> Node3D:
	var parts := [
		PropKit.pt(coat, ShapeKit.capsule(0.075, 0.22), Vector3(0.0, 0.13, 0.0)),
		PropKit.pt(head, ShapeKit.sphere(0.065), Vector3(0.0, 0.3, 0.0)),
		PropKit.pt("1d1736", ShapeKit.sphere(0.012), Vector3(-0.022, 0.31, -0.058), Vector3.ZERO, 0.0),
		PropKit.pt("1d1736", ShapeKit.sphere(0.012), Vector3(0.022, 0.31, -0.058), Vector3.ZERO, 0.0),
	]
	parts.append_array(hat)
	parts.append_array(extra)
	return PropKit.model(key, parts)


func _villager(i: int) -> void:
	var coats := ["ff8a5a", "3d8bff", "4dbf6a", "b05cff", "ffd23f"]
	var hats := [
		[PropKit.pt("8a5a2a", ShapeKit.cylinder(0.11, 0.11, 0.015, 16), Vector3(0.0, 0.36, 0.0)), PropKit.pt("8a5a2a", ShapeKit.cylinder(0.05, 0.06, 0.07, 12), Vector3(0.0, 0.4, 0.0))],
		[PropKit.pt("ff4d6d", ShapeKit.cone(0.07, 0.12, 12), Vector3(0.0, 0.42, 0.0))],
		[PropKit.pt("ffffff", ShapeKit.sphere(0.07, 0.07, 12), Vector3(0.0, 0.36, 0.0))],
	]
	var person := _person("villager_%d" % i, coats[i % coats.size()], "ffd6b0", hats[i % hats.size()])
	_actor(person, _tick_villager, {"forward": i % 2 == 0, "speed": randf_range(0.35, 0.55), "offset": i * 3.7})


func _tick_villager(actor: Dictionary, t: float, _delta: float) -> void:
	var length := _rim_length()
	var along := fposmod(t * float(actor["speed"]) + float(actor["offset"]), length)
	if not actor["forward"]:
		along = length - along
	_place_on_rim(actor["node"], along, actor["forward"], t * 8.0 + float(actor["offset"]))


func _army() -> void:
	var soldier := [
		PropKit.pt("1d1736", ShapeKit.cylinder(0.065, 0.06, 0.16, 14), Vector3(0.0, 0.44, 0.0)),
		PropKit.pt("ffd23f", ShapeKit.sphere(0.018), Vector3(0.0, 0.4, -0.06), Vector3.ZERO, 0.0),
		PropKit.pt("8a8f9e", ShapeKit.cylinder(0.01, 0.01, 0.3, 6), Vector3(0.09, 0.27, 0.0), Vector3.ZERO, 0.008),
	]
	var count := 5 if reduced else 8
	for i in count:
		var extra: Array = soldier.duplicate()
		var key := "soldier"
		if i == 0:
			# The drummer leads.
			extra = [soldier[0], soldier[1], PropKit.pt("ffffff", ShapeKit.cylinder(0.07, 0.07, 0.08, 14), Vector3(0.0, 0.14, -0.09), Vector3(PI / 2.0, 0.0, 0.0)),
				PropKit.pt("e8341c", ShapeKit.torus(0.06, 0.075, 14, 4), Vector3(0.0, 0.14, -0.09), Vector3(PI / 2.0, 0.0, 0.0), 0.0)]
			key = "drummer"
		var person := _person(key, "e8341c", "ffd6b0", [], extra)
		_actor(person, _tick_column, {"index": i, "count": count, "gap": 0.42, "speed": 0.5, "step_rate": 6.0})


func _parade() -> void:
	var float_parts := [
		PropKit.pt("ff4d6d", ShapeKit.box(Vector3(0.62, 0.3, 0.12), 0.04, 0.015), Vector3(0.0, 0.1, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("ffd23f", ShapeKit.box(Vector3(0.66, 0.34, 0.03), 0.05, 0.01), Vector3(0.0, 0.17, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("1d1736", ShapeKit.cylinder(0.05, 0.05, 0.03, 12), Vector3(-0.2, 0.04, -0.17), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt("1d1736", ShapeKit.cylinder(0.05, 0.05, 0.03, 12), Vector3(0.2, 0.04, -0.17), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt("8a8f9e", ShapeKit.cylinder(0.008, 0.008, 0.4, 6), Vector3(0.0, 0.38, 0.0), Vector3.ZERO, 0.0),
		PropKit.pt("4dffb0", ShapeKit.sphere(0.14, 0.17, 16), Vector3(0.0, 0.64, 0.0)),
		PropKit.pt("b05cff", ShapeKit.sphere(0.1, 0.12, 16), Vector3(0.18, 0.54, 0.0)),
	]
	var parade_float := PropKit.model("parade_float", float_parts)
	var band := 2 if reduced else 4
	_actor(parade_float, _tick_column, {"index": 0, "count": band + 1, "gap": 0.5, "speed": 0.42, "step_rate": 0.0, "lead_gap": 0.6})
	var trumpet := [PropKit.pt("ffd23f|g0.4", ShapeKit.cone(0.035, 0.12, 10), Vector3(0.0, 0.3, -0.12), Vector3(-PI / 2.0, 0.0, 0.0), 0.008)]
	for i in band:
		var hat := [PropKit.pt("ffd23f", ShapeKit.cylinder(0.06, 0.065, 0.06, 12), Vector3(0.0, 0.38, 0.0)), PropKit.pt("ffffff", ShapeKit.sphere(0.025), Vector3(0.0, 0.43, 0.0), Vector3.ZERO, 0.0)]
		var player := _person("bandsman", "3d8bff", "ffd6b0", hat, trumpet)
		_actor(player, _tick_column, {"index": i + 1, "count": band + 1, "gap": 0.5, "speed": 0.42, "step_rate": 7.0, "lead_gap": 0.6})
	var confetti := FxTextures.particles("square", false, _scaled(30), 1.4, 0.06)
	confetti.local_coords = true
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	confetti.emission_sphere_radius = 0.2
	confetti.direction = Vector3.UP
	confetti.spread = 40.0
	confetti.initial_velocity_min = 1.0
	confetti.initial_velocity_max = 1.6
	confetti.gravity = Vector3(0.0, -2.2, 0.0)
	confetti.color_initial_ramp = FxTextures.rainbow()
	confetti.angular_velocity_min = -400.0
	confetti.angular_velocity_max = 400.0
	confetti.emitting = true
	parade_float.add_child(confetti)
	confetti.position = Vector3(0.0, 0.8, 0.0)


## A column (army, parade) marching the rim path; member `index` walks `gap` behind the leader.
func _tick_column(actor: Dictionary, t: float, _delta: float) -> void:
	var length := _rim_length()
	var gap: float = actor["gap"]
	var tail := float(actor["count"]) * gap + 1.0
	var lead := fposmod(t * float(actor["speed"]), length + tail)
	var along := lead - float(actor["index"]) * gap - (float(actor.get("lead_gap", 0.0)) if int(actor["index"]) > 0 else 0.0)
	var rate: float = actor["step_rate"]
	_place_on_rim(actor["node"], along, true, t * rate if rate > 0.0 else 0.0)


static func _rim_length() -> float:
	var total := 0.0
	for i in RIM_PATH.size() - 1:
		total += (RIM_PATH[i + 1] - RIM_PATH[i]).length()
	return total


## Puts a walker `along` the rim path, facing its direction of travel. Walkers pop in and out at
## the path's ends (the centre line), and hide while off the path.
func _place_on_rim(node: Node3D, along: float, forward: bool, step: float) -> void:
	var length := _rim_length()
	var fade := clampf(minf(along, length - along) * 3.0, 0.0, 1.0)
	node.visible = fade > 0.01
	if not node.visible:
		return
	var at := Vector2.ZERO
	var heading := Vector2.RIGHT
	var left := along
	for i in RIM_PATH.size() - 1:
		var a: Vector2 = RIM_PATH[i]
		var b: Vector2 = RIM_PATH[i + 1]
		var seg := (b - a).length()
		if left <= seg or i == RIM_PATH.size() - 2:
			at = a + (b - a) * clampf(left / seg, 0.0, 1.0)
			heading = (b - a).normalized()
			break
		left -= seg
	if not forward:
		heading = -heading
	node.scale = Vector3.ONE * PEOPLE_SCALE * fade
	node.position = Vector3(at.x, RIM_Y + absf(sin(step)) * 0.035, at.y)
	node.rotation = Vector3(0.0, atan2(-heading.x, -heading.y), sin(step) * 0.08)


# --- Holiday ambience ----------------------------------------------------------------------------

## Floating jack-o'-lantern lights drifting over the tiles.
func _pumpkin_lights() -> void:
	var p := FxTextures.particles("pumpkin", false, _scaled(14), 4.0, 0.3)
	p.local_coords = true
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, 1.5, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.5, 2.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.25
	p.gravity = Vector3.ZERO
	p.angle_min = -15.0
	p.angle_max = 15.0
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.0), Vector2(0.2, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient([Color("ffb04a"), Color("ff8a1f"), Color("ff7a12")])
	p.emitting = true
	add_child(p)


## Santa's sleigh and four reindeer cross the sky every few seconds, trailing sparkles.
func _sleigh() -> void:
	var team := Node3D.new()
	var parts := [
		PropKit.pt("d62f3a", ShapeKit.box(Vector3(0.5, 0.22, 0.3), 0.05, 0.02), Vector3(0, 0.15, 0)),
		PropKit.pt("d62f3a", ShapeKit.box(Vector3(0.12, 0.34, 0.3), 0.05, 0.02), Vector3(0.24, 0.2, 0)),
		PropKit.pt("ffcf3f", ShapeKit.box(Vector3(0.62, 0.025, 0.025), 0.008, 0.004), Vector3(0.02, 0.0, 0.13)),
		PropKit.pt("ffcf3f", ShapeKit.box(Vector3(0.62, 0.025, 0.025), 0.008, 0.004), Vector3(0.02, 0.0, -0.13)),
		PropKit.pt("ffcf3f", ShapeKit.torus(0.05, 0.07, 12, 4), Vector3(0.34, 0.06, 0.13), Vector3(PI / 2.0, 0, 0), 0.0),
		PropKit.pt("ffcf3f", ShapeKit.torus(0.05, 0.07, 12, 4), Vector3(0.34, 0.06, -0.13), Vector3(PI / 2.0, 0, 0), 0.0),
		PropKit.pt("8a5a2a", ShapeKit.sphere(0.13, 0.22, 12), Vector3(-0.17, 0.33, 0)),
		PropKit.pt("d62f3a", ShapeKit.capsule(0.08, 0.2, 12), Vector3(0.02, 0.36, 0)),
		PropKit.pt("ffd6b0", ShapeKit.sphere(0.06, -1.0, 12), Vector3(0.02, 0.52, 0)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.06, 0.08, 10), Vector3(0.06, 0.48, 0), Vector3.ZERO, 0.0),
		PropKit.pt("d62f3a", ShapeKit.cone(0.06, 0.12, 10), Vector3(0.0, 0.61, 0), Vector3(0, 0, 0.4)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.025, -1.0, 8), Vector3(-0.05, 0.66, 0), Vector3.ZERO, 0.0),
	]
	team.add_child(PropKit.model("sleigh", parts))
	for i in 4:
		var deer := [
			PropKit.pt("8a5a2a", ShapeKit.capsule(0.055, 0.26, 10), Vector3(0, 0.0, 0), Vector3(0, 0, PI / 2.0)),
			PropKit.pt("8a5a2a", ShapeKit.sphere(0.05, -1.0, 10), Vector3(0.15, 0.08, 0)),
			PropKit.pt("c8a070", ShapeKit.cone(0.015, 0.09, 6), Vector3(0.13, 0.15, 0.025), Vector3(0.3, 0, -0.3), 0.0),
			PropKit.pt("c8a070", ShapeKit.cone(0.015, 0.09, 6), Vector3(0.13, 0.15, -0.025), Vector3(-0.3, 0, -0.3), 0.0),
			PropKit.pt("6a4020", ShapeKit.cylinder(0.012, 0.012, 0.12, 5), Vector3(0.08, -0.08, 0.03), Vector3(0, 0, 0.6), 0.0),
			PropKit.pt("6a4020", ShapeKit.cylinder(0.012, 0.012, 0.12, 5), Vector3(-0.08, -0.08, -0.03), Vector3(0, 0, -0.6), 0.0),
		]
		if i == 0:
			deer.append(PropKit.pt("ff3d3d|g2.0", ShapeKit.sphere(0.02, -1.0, 8), Vector3(0.2, 0.08, 0), Vector3.ZERO, 0.0))
		var reindeer := PropKit.model("reindeer_lead" if i == 0 else "reindeer", deer)
		reindeer.position = Vector3(0.62 + floori(i / 2.0) * 0.38, 0.22, 0.12 if i % 2 == 0 else -0.12)
		team.add_child(reindeer)
	var trail := FxTextures.particles("sparkle", false, _scaled(30), 0.9, 0.16)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.1
	trail.spread = 180.0
	trail.initial_velocity_max = 0.15
	trail.gravity = Vector3(0, -0.4, 0)
	trail.color_ramp = FxTextures.gradient([Color("ffffff"), Color("fff1b0"), Color("ffcf3f")])
	trail.position = Vector3(-0.3, 0.1, 0)
	trail.emitting = true
	team.add_child(trail)
	team.scale = Vector3.ONE * 1.6
	_actor(team, _tick_sleigh, {"trail": trail, "cycle": 10.0})


func _tick_sleigh(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var cycle: float = float(actor["cycle"]) * (1.6 if reduced else 1.0)
	var k := fposmod(t + 1.0, cycle) / 5.5
	node.visible = k <= 1.0
	(actor["trail"] as CPUParticles3D).emitting = node.visible
	if not node.visible:
		return
	node.position = Vector3(lerpf(-9.0, 9.0, k), 3.3 + sin(k * PI) * 0.6 + sin(t * 4.0) * 0.06, lerpf(1.0, 2.6, k))
	node.rotation = Vector3(0.0, 0.0, cos(k * PI) * 0.12)


## Heart-shaped balloons drifting up from the tiles on ribbons.
func _heart_balloons() -> void:
	var colors := ["ff2f5f", "ff7aa0", "e8344e", "ffb3d1"]
	for i in (4 if reduced else 7):
		var color: String = colors[i % colors.size()]
		var balloon := PropKit.model("heart_balloon_" + color, [
			PropKit.pt(color, ShapeKit.sphere(0.11, -1.0, 14), Vector3(-0.075, 0.05, 0)),
			PropKit.pt(color, ShapeKit.sphere(0.11, -1.0, 14), Vector3(0.075, 0.05, 0)),
			PropKit.pt(color, ShapeKit.cone(0.155, 0.2, 14), Vector3(0, -0.09, 0), Vector3(PI, 0, 0)),
			PropKit.pt("ffffff", ShapeKit.sphere(0.025, -1.0, 6), Vector3(-0.09, 0.1, 0.09), Vector3.ZERO, 0.0),
			PropKit.pt("c8c0b0", ShapeKit.cylinder(0.004, 0.004, 0.5, 4), Vector3(0, -0.44, 0), Vector3.ZERO, 0.0),
		])
		balloon.scale = Vector3.ONE * 1.5
		_actor(balloon, _tick_heart_balloon, {"x": randf_range(-HALF_X, HALF_X), "z": randf_range(0.5, 3.6),
			"phase": i * 2.3, "period": randf_range(11.0, 15.0)})


func _tick_heart_balloon(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var period: float = actor["period"]
	var ph: float = actor["phase"]
	var k := fposmod(t + ph, period) / period
	node.position = Vector3(float(actor["x"]) + sin(t * 0.6 + ph) * 0.35, lerpf(1.2, 6.5, k), float(actor["z"]))
	node.scale = Vector3.ONE * 1.5 * clampf(minf(k * 10.0, (1.0 - k) * 6.0), 0.0, 1.0)
	node.rotation.z = sin(t * 1.2 + ph) * 0.15


## Strings of glowing red lanterns across your half.
func _lantern_strings() -> void:
	for row in 2:
		var z := 1.0 + row * 2.0
		var cord := []
		for i in 10:
			var x0 := lerpf(-HALF_X - 0.6, HALF_X + 0.6, i / 10.0)
			var x1 := lerpf(-HALF_X - 0.6, HALF_X + 0.6, (i + 1) / 10.0)
			var a := Vector3(x0, _sag(x0), z)
			var b := Vector3(x1, _sag(x1), z)
			cord.append(PropKit.pt("5a3a24", ShapeKit.cylinder(0.008, 0.008, (b - a).length(), 4), (a + b) * 0.5,
				Vector3(0, 0, atan2(b.y - a.y, b.x - a.x) - PI / 2.0), 0.0))
		add_child(PropKit.model("lantern_cord_%d" % row, cord))
		for i in 5:
			var x := lerpf(-3.6, 3.6, i / 4.0) + (0.4 if row == 1 else 0.0)
			var lantern := PropKit.model("hanging_lantern", [
				PropKit.pt("ffcf3f", ShapeKit.cylinder(0.06, 0.07, 0.04, 12), Vector3(0, -0.08, 0)),
				PropKit.pt("e8282e|g0.8", ShapeKit.sphere(0.13, 0.22, 16), Vector3(0, -0.22, 0)),
				PropKit.pt("ffcf3f", ShapeKit.cylinder(0.07, 0.06, 0.04, 12), Vector3(0, -0.35, 0)),
				PropKit.pt("ffcf3f", ShapeKit.cylinder(0.006, 0.006, 0.08, 5), Vector3(0, -0.41, 0), Vector3.ZERO, 0.0),
				PropKit.pt("e8282e", ShapeKit.cone(0.03, 0.1, 8), Vector3(0, -0.49, 0), Vector3(PI, 0, 0)),
			])
			lantern.position = Vector3(x, _sag(x), z)
			lantern.scale = Vector3.ONE * 1.3
			_actor(lantern, _tick_hanging, {"phase": i * 1.3 + row, "amount": 0.08})


func _sag(x: float) -> float:
	var u := x / (HALF_X + 0.6)
	return 3.2 - 0.45 * (1.0 - u * u)


func _tick_hanging(actor: Dictionary, t: float, _delta: float) -> void:
	(actor["node"] as Node3D).rotation.z = sin(t * 1.4 + float(actor["phase"])) * float(actor["amount"])


## Fiesta banderitas: strings of little triangle flags fluttering over your half.
func _banderitas() -> void:
	var colors := ["ff3d7f", "ffcf3f", "27c98f", "3d8bff", "ff8a1f", "b05cff", "ffffff"]
	var flag := PackedVector2Array([Vector2(-0.13, 0.0), Vector2(0.13, 0.0), Vector2(0.0, -0.24)])
	for row in (2 if reduced else 3):
		var z := 0.7 + row * 1.3
		var cord := []
		for i in 10:
			var x0 := lerpf(-HALF_X - 0.6, HALF_X + 0.6, i / 10.0)
			var x1 := lerpf(-HALF_X - 0.6, HALF_X + 0.6, (i + 1) / 10.0)
			var a := Vector3(x0, _sag(x0) - 0.4, z)
			var b := Vector3(x1, _sag(x1) - 0.4, z)
			cord.append(PropKit.pt("f6efe0", ShapeKit.cylinder(0.006, 0.006, (b - a).length(), 4), (a + b) * 0.5,
				Vector3(0, 0, atan2(b.y - a.y, b.x - a.x) - PI / 2.0), 0.0))
		add_child(PropKit.model("bunting_cord_%d" % row, cord))
		var count := 16
		for i in count:
			var x := lerpf(-HALF_X - 0.3, HALF_X + 0.3, (i + 0.5) / count)
			var color: String = colors[(i + row * 3) % colors.size()]
			var pennant := PropKit.model("banderita_" + color, [PropKit.pt(color, ShapeKit.prism(flag, 0.01, 0.002), Vector3.ZERO, Vector3.ZERO, 0.01)])
			pennant.position = Vector3(x, _sag(x) - 0.4, z)
			pennant.scale = Vector3.ONE * 1.4
			_actor(pennant, _tick_pennant, {"phase": i * 0.7 + row * 1.9})


func _tick_pennant(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var ph: float = actor["phase"]
	node.rotation = Vector3(sin(t * 3.0 + ph) * 0.35, 0.0, sin(t * 1.7 + ph) * 0.06)


## Sun glints twinkling over the half (beach days).
func _glints() -> void:
	var p := FxTextures.particles("sparkle", false, _scaled(18), 1.2, 0.22)
	p.local_coords = true
	p.preprocess = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, 0.5, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.4, 2.0)
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.05
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient([Color("ffffff"), Color("fff6c8"), Color("fff1b0")])
	p.emitting = true
	add_child(p)

# --- Themed collections --------------------------------------------------------------------------

## A one-shot puff of particles at `at` that cleans itself up.
func _burst_at(shape: String, additive: bool, at: Vector3, amount: int, lifetime: float, size: float, colors: Array,
		speed: Vector2, gravity := Vector3.ZERO, dir := Vector3.UP, spread := 180.0) -> CPUParticles3D:
	var p := FxTextures.particles(shape, additive, _scaled(amount), lifetime, size)
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = true
	p.position = at
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = gravity
	FxTextures.random_angle(p, shape)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.4), Vector2(0.2, 1.0), Vector2(1.0, 0.85)])
	p.color_ramp = FxTextures.gradient(colors)
	p.emitting = true
	add_child(p)
	create_tween().tween_callback(p.queue_free).set_delay(lifetime + 0.3)
	return p


## Things drifting up from the tiles: notes, bubbles, stars, gears.
func _rising(shape: String, amount: int, size: float, colors: Array, speed: float, spin := 0.0) -> CPUParticles3D:
	var lifetime := 3.8
	var p := FxTextures.particles(shape, false, _scaled(amount), lifetime, size)
	p.local_coords = true
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = Vector3(0.0, 0.5, 2.0)
	p.emission_box_extents = Vector3(HALF_X, 0.3, 2.0)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed * 1.3
	p.gravity = Vector3(0.1, 0.0, 0.0)
	if spin > 0.0:
		FxTextures.random_angle(p, shape)
		p.angular_velocity_min = -spin
		p.angular_velocity_max = spin
	else:
		p.angle_min = -12.0
		p.angle_max = 12.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.0), Vector2(0.15, 1.0), Vector2(0.85, 1.0), Vector2(1.0, 0.0)])
	p.color_initial_ramp = FxTextures.gradient(colors, false)
	p.emitting = true
	add_child(p)
	return p


## Stars twinkling in place inside a box (sky shows).
func _twinkle(amount: int, size: float, colors: Array, center: Vector3, extents: Vector3) -> void:
	var p := FxTextures.particles("sparkle", true, _scaled(amount), 1.6, size)
	p.local_coords = true
	p.preprocess = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.position = center
	p.emission_box_extents = extents
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.03
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(colors)
	p.emitting = true
	add_child(p)


## A soft additive light cone from the pivot's origin along its -Y (searchlights, stage lights,
## sun rays). Turn the returned pivot to aim it.
func _beam(at: Vector3, rot: Vector3, length: float, width: Vector2, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation = rot
	var cone := CylinderMesh.new()
	cone.top_radius = width.x
	cone.bottom_radius = width.y
	cone.height = length
	cone.radial_segments = 18
	cone.cap_top = false
	cone.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.material_override = m
	beam.position = Vector3(0.0, -length * 0.5, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)
	return pivot


## Swings a beam pivot around its resting aim.
func _tick_sweep(actor: Dictionary, t: float, _delta: float) -> void:
	var base: Vector3 = actor["base"]
	var swing: Vector2 = actor["swing"]
	var ph: float = actor["phase"]
	var speed: float = actor["speed"]
	(actor["node"] as Node3D).rotation = base + Vector3(sin(t * speed * 0.7 + ph) * swing.y, 0.0, sin(t * speed + ph) * swing.x)


## Fades a beam's glow in and out.
func _tick_ray(actor: Dictionary, t: float, _delta: float) -> void:
	var m: StandardMaterial3D = actor["mat"]
	m.albedo_color.a = float(actor["alpha"]) * (0.55 + 0.45 * sin(t * 0.6 + float(actor["phase"])))


## Something hovering in a slow loop over the half, facing where it goes (drones, helicopters).
## A "rotor" child spins.
func _tick_hover(actor: Dictionary, t: float, delta: float) -> void:
	var node: Node3D = actor["node"]
	var c: Vector3 = actor["center"]
	var r: Vector2 = actor["radius"]
	var a := t * float(actor["speed"]) + float(actor["phase"])
	var pos := c + Vector3(cos(a) * r.x, sin(a * 1.7) * 0.15, sin(a) * r.y)
	var ahead := c + Vector3(cos(a + 0.05) * r.x, pos.y - c.y, sin(a + 0.05) * r.y)
	node.position = pos
	if not ahead.is_equal_approx(pos):
		node.look_at(to_global(ahead), Vector3.UP)
	if actor.has("rotor"):
		(actor["rotor"] as Node3D).rotate_y(delta * 26.0)


## A spot on the frame rim around the owner's half.
func _rim_spot() -> Vector3:
	var along := randf() * _rim_length()
	for i in RIM_PATH.size() - 1:
		var a: Vector2 = RIM_PATH[i]
		var b: Vector2 = RIM_PATH[i + 1]
		var seg := (b - a).length()
		if along <= seg:
			var at := a + (b - a) * (along / seg)
			return Vector3(at.x, RIM_Y, at.y)
		along -= seg
	return Vector3(RIM_X, RIM_Y, RIM_Z)


# Great Wave: spray bursting up from the sea beside the board.
func _spray_burst() -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var at := Vector3(side * randf_range(HALF_X + 0.9, HALF_X + 2.0), -0.2, randf_range(-0.5, 4.2))
	_burst_at("dot", false, at, 34, 1.4, 0.18, [Color("ffffff"), Color("dff3ff"), Color("8fc6ff")],
		Vector2(2.4, 3.6), Vector3(-side * 0.6, -4.5, 0.0), Vector3(-side * 0.35, 1.0, 0.0), 22.0)
	_burst_at("puff", false, at + Vector3(0.0, 0.3, 0.0), 6, 1.6, 0.9, [Color("ffffff", 0.7), Color("e8f4ff", 0.45), Color("c8e0ff", 0.0)],
		Vector2(0.3, 0.8), Vector3.ZERO, Vector3.UP, 50.0)


# Treasure Seas: distant cannon fire, a ball arcing overhead and a splash.
func _cannon_shot() -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var from := Vector3(side * randf_range(HALF_X + 3.5, HALF_X + 6.0), 0.4, randf_range(-3.0, 1.5))
	var to := Vector3(-side * randf_range(HALF_X + 3.0, HALF_X + 6.0), -0.3, randf_range(-5.0, -1.0))
	_burst_at("dot", true, from, 14, 0.35, 0.3, [Color("fff6c8"), Color("ffb020"), Color("ff6a1a")], Vector2(1.0, 2.2), Vector3.ZERO, Vector3(-side, 0.4, 0.0), 35.0)
	_burst_at("puff", false, from, 10, 2.2, 1.0, [Color("f2ece2", 0.85), Color("c9c2b0", 0.55), Color("a8a090", 0.0)], Vector2(0.3, 0.9), Vector3(0.0, 0.25, 0.0))
	var ball := PropKit.model("cannonball", [PropKit.pt("2a2d40", ShapeKit.sphere(0.14, -1.0, 12), Vector3.ZERO)])
	ball.scale = Vector3.ONE * 1.4
	ball.position = from
	add_child(ball)
	var fly := func(k: float) -> void:
		ball.position = from.lerp(to, k) + Vector3(0.0, sin(k * PI) * 5.0, 0.0)
	var t := create_tween()
	t.tween_method(fly, 0.0, 1.0, 1.7)
	t.tween_callback(func() -> void:
		_burst_at("dot", false, to, 20, 1.0, 0.13, [Color("ffffff"), Color("dff3ff"), Color("8fc6ff")], Vector2(1.6, 2.6), Vector3(0.0, -5.0, 0.0), Vector3.UP, 25.0))
	t.tween_callback(ball.queue_free)


# Ninja Clan: smoke bombs popping on the rim; now and then a throwing star whizzes past.
func _smoke_pop(colors: Array = [Color("8a7aa8", 0.85), Color("5a4a78", 0.6), Color("3a2d55", 0.0)]) -> void:
	var at := _rim_spot() + Vector3(0.0, 0.25, 0.0)
	_burst_at("puff", false, at, 9, 1.5, 0.8, colors, Vector2(0.3, 0.9), Vector3(0.0, 0.3, 0.0))


# Street Graffiti: a cloud of spray paint.
func _paint_puff() -> void:
	var c: Color = [Color("ff3bd6"), Color("4dffb0"), Color("ffd23f"), Color("3ad6ff")].pick_random()
	_smoke_pop([Color(c, 0.8), Color(c, 0.5), Color(c, 0.0)])


func _shuriken_throw() -> void:
	var star := PropKit.model("shuriken", [
		PropKit.pt("c9d2de", ShapeKit.prism(InsigniaFactory.star_polygon(4, 0.2, 0.06), 0.02, 0.005), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.012),
		PropKit.pt("2a2350", ShapeKit.cylinder(0.04, 0.04, 0.03, 12), Vector3.ZERO, Vector3.ZERO, 0.0),
	])
	star.scale = Vector3.ONE * 1.5
	var dir := 1.0 if randf() < 0.5 else -1.0
	var y := randf_range(1.4, 2.2)
	var z := randf_range(0.6, 3.4)
	star.position = Vector3(-8.0 * dir, y, z)
	add_child(star)
	var t := create_tween()
	t.tween_property(star, "position", Vector3(8.0 * dir, y - 0.4, z + randf_range(-0.6, 0.6)), 0.9)
	t.parallel().tween_property(star, "rotation:y", 30.0 * dir, 0.9)
	t.tween_callback(star.queue_free)


# Neon drones, helicopters and starfighters.
func _drone(i: int) -> void:
	var glow: String = ["2ef6ff", "ff2bd6", "b84dff"][i % 3]
	var parts := [
		PropKit.pt("1b2447", ShapeKit.box(Vector3(0.26, 0.26, 0.08), 0.06, 0.015), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt(glow + "|g2.0", ShapeKit.sphere(0.045, -1.0, 10), Vector3(0.0, -0.04, -0.12), Vector3.ZERO, 0.0),
	]
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var arm := Vector3(cos(a), 0.0, sin(a)) * 0.22
		parts.append(PropKit.pt("2a2d40", ShapeKit.cylinder(0.014, 0.014, 0.22, 6), arm * 0.5, Vector3(0.0, -a, PI / 2.0), 0.0))
		parts.append(PropKit.pt(glow + "|a0.5", ShapeKit.cylinder(0.1, 0.1, 0.012, 16), arm + Vector3(0.0, 0.035, 0.0), Vector3.ZERO, 0.0))
		parts.append(PropKit.pt(glow + "|g1.6", ShapeKit.sphere(0.022, -1.0, 8), arm + Vector3(0.0, -0.02, 0.0), Vector3.ZERO, 0.0))
	var drone := PropKit.model("drone_" + glow, parts)
	drone.scale = Vector3.ONE * 1.5
	drone.add_child(_beam(Vector3(0.0, -0.05, 0.0), Vector3.ZERO, 1.7, Vector2(0.03, 0.42), Color(Color(glow), 0.1)))
	_actor(drone, _tick_hover, {"center": Vector3(-2.6 + i * 2.6, 2.5 + i * 0.25, 2.0), "radius": Vector2(1.6, 1.2),
		"speed": 0.45 + i * 0.08, "phase": i * 2.1})


func _chopper(i: int) -> void:
	var paint: String = ["e8eef8", "ffb020"][i % 2]
	var body := [
		PropKit.pt(paint, ShapeKit.sphere(0.2, 0.32, 16), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("9cf6ff|a0.8", ShapeKit.sphere(0.14, 0.2, 14), Vector3(0.0, 0.03, -0.12)),
		PropKit.pt(paint, ShapeKit.cylinder(0.03, 0.06, 0.5, 8), Vector3(0.0, 0.04, 0.38), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("e8341c", ShapeKit.box(Vector3(0.02, 0.14, 0.1), 0.01, 0.004), Vector3(0.0, 0.1, 0.6), Vector3(0.0, PI / 2.0, 0.0)),
		PropKit.pt("2a2d40", ShapeKit.cylinder(0.012, 0.012, 0.44, 6), Vector3(0.12, -0.2, 0.0), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt("2a2d40", ShapeKit.cylinder(0.012, 0.012, 0.44, 6), Vector3(-0.12, -0.2, 0.0), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt("2a2d40", ShapeKit.cylinder(0.02, 0.02, 0.1, 6), Vector3(0.0, 0.18, 0.0), Vector3.ZERO, 0.0),
		PropKit.pt("ff3d4a|g2.0", ShapeKit.sphere(0.02, -1.0, 6), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, 0.0),
	]
	var chopper := PropKit.model("chopper_" + paint, body)
	var rotor := PropKit.model("chopper_rotor", [
		PropKit.pt("2a2d40", ShapeKit.box(Vector3(0.9, 0.035, 0.012), 0.01, 0.004), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt("2a2d40", ShapeKit.box(Vector3(0.9, 0.035, 0.012), 0.01, 0.004), Vector3.ZERO, Vector3(PI / 2.0, PI / 2.0, 0.0), 0.0),
	])
	rotor.position = Vector3(0.0, 0.23, 0.0)
	chopper.add_child(rotor)
	chopper.add_child(_beam(Vector3(0.0, -0.18, -0.1), Vector3(0.3, 0.0, 0.0), 2.4, Vector2(0.04, 0.55), Color(1.0, 0.96, 0.8, 0.11)))
	chopper.scale = Vector3.ONE * 1.6
	_actor(chopper, _tick_hover, {"rotor": rotor, "center": Vector3(0.0, 3.0 + i * 0.4, 1.8), "radius": Vector2(3.4, 1.6),
		"speed": 0.32, "phase": i * PI})


func _starfighter(i: int) -> void:
	var paint: String = ["e8eef8", "c9d2de", "ffb020"][i % 3]
	var wing := PackedVector2Array([Vector2(0.0, 0.32), Vector2(-0.28, -0.2), Vector2(0.0, -0.1), Vector2(0.28, -0.2)])
	var fighter := PropKit.model("starfighter_" + paint, [
		PropKit.pt(paint, ShapeKit.prism(wing, 0.03, 0.008), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.014),
		PropKit.pt("2a2d40", ShapeKit.capsule(0.05, 0.36), Vector3(0.0, 0.03, -0.02), Vector3(PI / 2.0, 0.0, 0.0), 0.012),
		PropKit.pt("9cf6ff|a0.85", ShapeKit.sphere(0.04, 0.05, 10), Vector3(0.0, 0.07, -0.08), Vector3.ZERO, 0.0),
		PropKit.pt("3ad6ff|g2.5", ShapeKit.cylinder(0.035, 0.035, 0.02, 10), Vector3(0.0, 0.03, 0.17), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
	])
	fighter.scale = Vector3.ONE * 1.8
	var trail := FxTextures.particles("dot", true, _scaled(24), 0.5, 0.14)
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.05
	trail.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	trail.color_ramp = FxTextures.gradient([Color("ffffff"), Color("3ad6ff"), Color("2a5aff")])
	trail.position = Vector3(0.0, 0.03, 0.19)
	trail.emitting = true
	fighter.add_child(trail)
	_actor(fighter, _tick_plane, {"center": Vector3(0.0, 3.4, 1.8), "phase": -i * 0.45, "radius": Vector2(4.2, 1.8), "speed": 0.55})


# Arcade: blocky clouds.
static func _cube(size: Vector3) -> Callable:
	return func(grow: float) -> Mesh:
		var m := BoxMesh.new()
		m.size = size + Vector3.ONE * grow * 2.0
		return m


# Wild West: tumbleweeds bouncing past beside the board.
func _tumbleweed(i: int) -> void:
	var parts := [PropKit.pt("8a6a3a", ShapeKit.sphere(0.13, -1.0, 10), Vector3.ZERO, Vector3.ZERO, 0.0)]
	for k in 5:
		parts.append(PropKit.pt("c8a066", ShapeKit.torus(0.2, 0.23, 16, 4), Vector3.ZERO, Vector3(k * 0.7, k * 1.25, k * 0.45), 0.012))
	var weed := PropKit.model("tumbleweed", parts)
	weed.scale = Vector3.ONE * 1.6
	_actor(weed, _tick_tumbleweed, {"lane": i % 3, "speed": randf_range(1.3, 1.9), "offset": i * 6.0})


func _tick_tumbleweed(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var span := 24.0
	var u := fposmod(t * float(actor["speed"]) + float(actor["offset"]), span) - span / 2.0
	var hop := absf(sin(t * 3.4 + float(actor["offset"]))) * 0.45
	var y := Board3D.GROUND_Y + 0.37 + hop
	match int(actor["lane"]):
		0:
			node.position = Vector3(u, y, -6.4)
			node.rotation = Vector3(0.0, 0.0, -u / 0.37)
		1:
			node.position = Vector3(-HALF_X - 1.6, y, -u)
			node.rotation = Vector3(-u / 0.37, 0.0, 0.0)
		_:
			node.position = Vector3(HALF_X + 1.6, y, u)
			node.rotation = Vector3(u / 0.37, 0.0, 0.0)


# Steampunk: brass vents puffing steam on the rim corners.
func _steam_vents() -> void:
	var vent := [
		PropKit.pt("c8743a", ShapeKit.cylinder(0.07, 0.09, 0.22, 12), Vector3(0.0, 0.11, 0.0)),
		PropKit.pt("e8b850", ShapeKit.torus(0.06, 0.1, 14, 4), Vector3(0.0, 0.22, 0.0), Vector3.ZERO, 0.012),
		PropKit.pt("e8b850", ShapeKit.cylinder(0.025, 0.025, 0.1, 8), Vector3(0.1, 0.12, 0.0), Vector3(0.0, 0.0, PI / 2.0), 0.01),
		PropKit.pt("c8342d", ShapeKit.cylinder(0.035, 0.035, 0.02, 10), Vector3(0.15, 0.12, 0.0), Vector3(0.0, 0.0, PI / 2.0), 0.0),
	]
	for spot: Vector2 in [Vector2(-RIM_X, RIM_Z), Vector2(RIM_X, RIM_Z), Vector2(-RIM_X, 2.1), Vector2(RIM_X, 2.1)]:
		var pipe := PropKit.model("steam_vent", vent)
		pipe.position = Vector3(spot.x, RIM_Y, spot.y)
		pipe.scale = Vector3.ONE * 1.5
		add_child(pipe)
		var steam := FxTextures.particles("puff", false, _scaled(10), 1.8, 0.6)
		steam.local_coords = true
		steam.preprocess = 1.8
		steam.position = pipe.position + Vector3(0.0, 0.38, 0.0)
		steam.direction = Vector3.UP
		steam.spread = 12.0
		steam.initial_velocity_min = 0.7
		steam.initial_velocity_max = 1.1
		steam.gravity = Vector3(0.25, 0.2, 0.0)
		steam.angle_min = -180.0
		steam.angle_max = 180.0
		steam.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.3), Vector2(0.4, 1.0), Vector2(1.0, 1.6)])
		steam.color_ramp = FxTextures.gradient([Color("ffffff", 0.75), Color("f2ece2", 0.45), Color("e8e0d4", 0.0)])
		steam.emitting = true
		add_child(steam)


# Fantasy Kingdom: a dragon crosses the sky and breathes a puff of fire on the way.
func _dragon() -> void:
	var scales := "2f8a5a"
	var body := [
		PropKit.pt(scales, ShapeKit.capsule(0.11, 0.5, 12), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("ffcf6a", ShapeKit.capsule(0.07, 0.36, 10), Vector3(0.0, -0.05, -0.02), Vector3(PI / 2.0, 0.0, 0.0), 0.0),
		PropKit.pt(scales, ShapeKit.capsule(0.06, 0.26, 10), Vector3(0.0, 0.1, -0.3), Vector3(-(PI / 2.0 - 0.6), 0.0, 0.0)),
		PropKit.pt(scales, ShapeKit.sphere(0.09, 0.14, 12), Vector3(0.0, 0.18, -0.44)),
		PropKit.pt(scales, ShapeKit.capsule(0.045, 0.14, 8), Vector3(0.0, 0.16, -0.52), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("fff4dc", ShapeKit.cone(0.02, 0.09, 6), Vector3(0.04, 0.26, -0.41), Vector3(0.5, 0.0, -0.3), 0.0),
		PropKit.pt("fff4dc", ShapeKit.cone(0.02, 0.09, 6), Vector3(-0.04, 0.26, -0.41), Vector3(0.5, 0.0, 0.3), 0.0),
		PropKit.pt("ffd23f|g1.5", ShapeKit.sphere(0.016, -1.0, 6), Vector3(0.05, 0.2, -0.5), Vector3.ZERO, 0.0),
		PropKit.pt("ffd23f|g1.5", ShapeKit.sphere(0.016, -1.0, 6), Vector3(-0.05, 0.2, -0.5), Vector3.ZERO, 0.0),
		PropKit.pt(scales, ShapeKit.cone(0.08, 0.5, 10), Vector3(0.0, -0.02, 0.48), Vector3(PI / 2.0 - 0.15, 0.0, 0.0)),
		PropKit.pt("c8342d", ShapeKit.prism(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, -0.08), Vector2(-0.06, -0.08)]), 0.01, 0.002), Vector3(0.0, 0.02, 0.73), Vector3(-PI / 2.0, 0.0, 0.0), 0.0),
	]
	var wing_poly := PackedVector2Array([Vector2(0.0, 0.12), Vector2(-0.3, 0.16), Vector2(-0.62, 0.06), Vector2(-0.5, -0.06),
		Vector2(-0.36, 0.0), Vector2(-0.24, -0.1), Vector2(-0.12, -0.02), Vector2(0.0, -0.12)])
	var wing := [PropKit.pt("c8342d", ShapeKit.prism(wing_poly, 0.016, 0.004), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.014)]
	var parts := _winged("dragon", body, wing, 0.08)
	var root: Node3D = parts["root"]
	root.scale = Vector3.ONE * 2.4
	root.visible = false
	_actor(root, _tick_dragon, {"left": parts["left"], "right": parts["right"], "phase": 0.0, "cycle": 11.0, "fired": -1})


func _tick_dragon(actor: Dictionary, t: float, _delta: float) -> void:
	var node: Node3D = actor["node"]
	var cycle: float = float(actor["cycle"]) * (1.5 if reduced else 1.0)
	var lap := floori((t + 2.0) / cycle)
	var k := fposmod(t + 2.0, cycle) / 6.5
	node.visible = k <= 1.0
	if not node.visible:
		return
	var dir := 1.0 if lap % 2 == 0 else -1.0
	var from := Vector3(-10.0 * dir, 3.4, 0.2)
	var to := Vector3(10.0 * dir, 3.9, 2.8)
	var pos := from.lerp(to, k) + Vector3(0.0, sin(k * PI) * 0.7 + sin(t * 2.2) * 0.12, 0.0)
	node.position = pos
	node.look_at(to_global(pos + (to - from).normalized()), Vector3.UP)
	_flap(actor, t, 5.5, 0.55)
	if k > 0.45 and int(actor["fired"]) != lap:
		actor["fired"] = lap
		var mouth := pos + (to - from).normalized() * 1.4 + Vector3(0.0, 0.3, 0.0)
		_burst_at("flame", true, mouth, 22, 0.8, 0.5, [Color("fff6c8"), Color("ffb020"), Color("ff4a1a"), Color("8a1010")],
			Vector2(2.5, 4.0), Vector3(0.0, 0.6, 0.0), (to - from).normalized() + Vector3(0.0, -0.25, 0.0), 14.0)


# Comic Hero: sound effects pop up around the edges of the half.
const COMIC_WORDS := ["POW!", "ZAP!", "BAM!", "WHAM!", "BOOM!", "KAPOW!", "THWACK!", "ZOK!"]
const COMIC_COLORS := ["fff36b", "ff5a3a", "3d8bff", "4dffb0", "ff4fa8"]


func _comic_pop() -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var at := Vector3(side * randf_range(HALF_X - 0.5, HALF_X + 1.6), randf_range(1.8, 2.9), randf_range(0.3, 3.6))
	if randf() < 0.3:
		at = Vector3(randf_range(-HALF_X + 1.0, HALF_X - 1.0), randf_range(3.0, 3.6), randf_range(-0.6, 0.6))
	var pop := Node3D.new()
	pop.position = at
	add_child(pop)
	var burst := MeshInstance3D.new()
	burst.mesh = FxTextures.quad(1.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = FxTextures.texture("star")
	m.albedo_color = Color(COMIC_COLORS[randi() % COMIC_COLORS.size()])
	m.render_priority = 2
	burst.material_override = m
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pop.add_child(burst)
	var label := Label3D.new()
	label.text = COMIC_WORDS[randi() % COMIC_WORDS.size()]
	label.font = load(KillFX.WORD_FONT)
	label.font_size = 80
	label.pixel_size = 0.004
	label.modulate = Color("ffffff")
	label.outline_modulate = Color("1d1736")
	label.outline_size = 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 4
	pop.add_child(label)
	pop.scale = Vector3.ONE * 0.2
	var t := create_tween()
	t.tween_property(pop, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(m, "albedo_color:a", 0.0, 0.3)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.3)
	t.tween_callback(pop.queue_free)


# Concert Stage: a confetti cannon fires from one side.
func _confetti_cannon() -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var at := Vector3(side * (HALF_X + 0.8), 0.4, randf_range(0.5, 3.5))
	var p := _burst_at("square", false, at, 40, 2.2, 0.1, [Color.WHITE, Color.WHITE, Color.WHITE], Vector2(3.0, 5.0),
		Vector3(0.0, -2.0, 0.0), Vector3(-side * 0.6, 1.0, 0.0), 25.0)
	p.color_initial_ramp = FxTextures.rainbow()
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
