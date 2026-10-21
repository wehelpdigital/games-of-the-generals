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
	"ambience_sandstorm": {"name": "Sandstorm", "rarity": "rare", "desc": "Gusts of desert sand blow across your half.",
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
	"ambience_fireflies": {"name": "Fireflies", "rarity": "rare", "desc": "Warm little lights wander over your tiles.",
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
}


var style := NONE
var _actors: Array[Dictionary] = []  # {node, tick: Callable(actor, t, delta)}
var _spawners: Array[Dictionary] = []  # {every: Vector2, next: float, spawn: Callable}
var _time := 0.0


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
			_flock(false)
		"ambience_butterflies":
			for i in (3 if reduced else 5):
				_butterfly(i)
		"ambience_fireflies":
			_fireflies()
		"ambience_bats":
			_flock(true)
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

func _flock(bats: bool) -> void:
	var count := 4 if reduced else (6 if bats else 7)
	var key := "bat" if bats else "bird"
	var body_color := "2a1f3a" if bats else "3a3150"
	var body := [
		PropKit.pt(body_color, ShapeKit.capsule(0.045, 0.2), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt(body_color, ShapeKit.sphere(0.045), Vector3(0.0, 0.03, -0.1)),
	]
	if not bats:
		body.append(PropKit.pt("ffb020", ShapeKit.cone(0.02, 0.06, 8), Vector3(0.0, 0.03, -0.16), Vector3(-PI / 2.0, 0.0, 0.0), 0.0))
	var wing_poly := PackedVector2Array([Vector2(0.0, 0.03), Vector2(-0.2, 0.0), Vector2(-0.26, -0.05), Vector2(-0.12, -0.04), Vector2(0.0, -0.05)]) if bats \
		else PackedVector2Array([Vector2(0.0, 0.04), Vector2(-0.22, 0.01), Vector2(-0.18, -0.03), Vector2(0.0, -0.04)])
	var wing := [PropKit.pt("4a3a6a" if bats else "5a4f78", ShapeKit.prism(wing_poly, 0.012, 0.004), Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), 0.01)]
	for i in count:
		var parts := _winged(key, body, wing, 0.04)
		var root: Node3D = parts["root"]
		var row := int((i + 1) / 2.0)
		var offset := Vector3(row * 0.7 * (1.0 if i % 2 == 0 else -1.0), randf_range(-0.2, 0.2), row * 0.9)
		root.scale = Vector3.ONE * (2.0 if bats else 2.2)
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


func _cloud(i: int) -> void:
	var cloud := PropKit.model("cloud", [
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
