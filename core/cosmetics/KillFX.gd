class_name KillFX
extends Node3D
## Kill effects: what plays where a piece is eliminated, in the style of the side that won the
## clash. "classic" is the comic burst (ClashFX). Every effect is built from FxTextures sprites,
## simple meshes, CPUParticles3D and tweens (WebGL 2 safe), and frees itself when done.

const LIFETIME := 1.6

const STYLES := {
	"classic": {"name": "Comic Burst", "rarity": "common", "desc": "The classic POW! burst.",
		"swatch": [Color("ffe066"), Color("ffffff"), Color("1d1736")]},
	"kill_fire_explosion": {"name": "Fire Explosion", "rarity": "rare", "desc": "A fireball and a puff of smoke.",
		"swatch": [Color("fff3a8"), Color("ff7a1a"), Color("e8341c"), Color("4a3a3a")]},
	"kill_ice_shatter": {"name": "Ice Shatter", "rarity": "rare", "desc": "The loser freezes and shatters into shards.",
		"swatch": [Color("ffffff"), Color("9ee6ff"), Color("3aa7e6")]},
	"kill_pixel_burst": {"name": "8-Bit Burst", "rarity": "common", "desc": "Retro pixels explode everywhere.",
		"swatch": [Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f")]},
	"kill_confetti": {"name": "Party Confetti", "rarity": "common", "desc": "Celebrate with a confetti cannon.",
		"swatch": [Color("ff4d6d"), Color("ffd23f"), Color("4dffb0"), Color("b05cff")]},
	"kill_lightning_strike": {"name": "Lightning Strike", "rarity": "epic", "desc": "A bolt from the sky.",
		"swatch": [Color("fffbd1"), Color("6fd3ff"), Color("3a5bff")]},
	"kill_black_hole": {"name": "Black Hole", "rarity": "legendary", "desc": "Sucked into a swirling void.",
		"swatch": [Color("0d0a18"), Color("6a3cff"), Color("ff5cd6")]},
	"kill_sakura_burst": {"name": "Sakura Storm", "rarity": "epic", "desc": "A whirl of cherry-blossom petals.",
		"swatch": [Color("ffe3ee"), Color("ff9ec7"), Color("ff6f9f")]},
	"kill_ghost": {"name": "Spooky Ghost", "rarity": "rare", "desc": "The fallen piece floats away as a ghost.",
		"swatch": [Color("ffffff"), Color("b8c6ff"), Color("6a5acd")]},
	"kill_toxic_splat": {"name": "Toxic Splat", "rarity": "rare", "desc": "Splash of bubbling green goo.",
		"swatch": [Color("d4ff3a"), Color("7ddc3a"), Color("3a8a1f")]},
	"kill_star_shower": {"name": "Star Shower", "rarity": "epic", "desc": "A fountain of golden stars.",
		"swatch": [Color("fff1b0"), Color("ffc93c"), Color("ff9f1c")]},
	# Action kills: your winning chip does the deed (see ACTIONS).
	"kill_bazooka": {"name": "Bazooka Blast", "rarity": "epic", "desc": "Your chip pulls out a bazooka. One rocket, one less enemy.",
		"swatch": [Color("4f6a3a"), Color("e8341c"), Color("ffb020")]},
	"kill_wizard_fireball": {"name": "Wizard's Fireball", "rarity": "epic", "desc": "A wizard hat pops on and a fireball arcs over.",
		"swatch": [Color("6a3cff"), Color("ffd23f"), Color("ff7a1a")]},
	"kill_earth_shaman": {"name": "Earth Shaman", "rarity": "legendary", "desc": "The ground rumbles, cracks open and swallows the loser whole.",
		"swatch": [Color("8a5a2a"), Color("27c98f"), Color("ffd23f")]},
	"kill_airstrike": {"name": "Airstrike", "rarity": "legendary", "desc": "A toy jet swoops in and drops a whistling bomb.",
		"swatch": [Color("9aa6b8"), Color("2a2d40"), Color("ffb020")]},
	"kill_ninja_slash": {"name": "Ninja Slash", "rarity": "epic", "desc": "A blur, a flash of steel, and the loser falls in two.",
		"swatch": [Color("1d1736"), Color("e8341c"), Color("e8f6ff")]},
	"kill_storm_caller": {"name": "Storm Caller", "rarity": "epic", "desc": "A dark cloud gathers over the loser. Then: lightning.",
		"swatch": [Color("3a3f5a"), Color("6fd3ff"), Color("fffbd1")]},
	"kill_orbital_laser": {"name": "Orbital Laser", "rarity": "legendary", "desc": "A target locks on, and a beam from orbit leaves a crater.",
		"swatch": [Color("ff3d5a"), Color("9cf6ff"), Color("ffffff")]},
	"kill_anvil_drop": {"name": "Anvil Drop", "rarity": "rare", "desc": "Look up! A cartoon anvil flattens the loser.",
		"swatch": [Color("4a4f5e"), Color("8a8f9e"), Color("ffd24a")]},
	"kill_pocket_wormhole": {"name": "Pocket Wormhole", "rarity": "legendary", "desc": "Your chip tosses a tiny wormhole that swallows the loser.",
		"swatch": [Color("0d0a18"), Color("8a5cff"), Color("ff5cd6")]},
	"kill_freeze_ray": {"name": "Freeze Ray", "rarity": "rare", "desc": "Zap! The loser freezes solid, then shatters.",
		"swatch": [Color("27c9b8"), Color("9cf6ff"), Color("ffffff")]},
	"kill_catapult": {"name": "Catapult", "rarity": "rare", "desc": "A pocket catapult lobs a boulder right on target.",
		"swatch": [Color("8a5a2a"), Color("8a8f9e"), Color("d8c8a8")]},
	"kill_pirate_cannon": {"name": "Pirate Cannon", "rarity": "rare", "desc": "Fire in the hole! A cannonball and a puff of smoke.",
		"swatch": [Color("2a2d40"), Color("8a5a2a"), Color("ff7a1a")]},
	"kill_tornado": {"name": "Twister", "rarity": "epic", "desc": "A little tornado whisks the loser off into the sky.",
		"swatch": [Color("c9d2de"), Color("9aa6b8"), Color("d8c4a0")]},
	"kill_ufo_abduction": {"name": "UFO Abduction", "rarity": "legendary", "desc": "A saucer swoops down and beams the loser up.",
		"swatch": [Color("c9d2de"), Color("4dffb0"), Color("6a3cff")]},
	"kill_kraken": {"name": "Kraken Grab", "rarity": "legendary", "desc": "Churning water opens under the loser, and kraken tentacles drag it down.",
		"swatch": [Color("8a3cb8"), Color("3d8bff"), Color("e0b0ff")]},
	"kill_boxing_glove": {"name": "Spring Punch", "rarity": "rare", "desc": "A spring-loaded glove knocks the loser clean off the table.",
		"swatch": [Color("e8341c"), Color("ffffff"), Color("c9d2de")]},
	"kill_dragon_breath": {"name": "Dragon Breath", "rarity": "legendary", "desc": "A little dragon pops up and breathes a stream of fire.",
		"swatch": [Color("27c98f"), Color("ffa21f"), Color("ff3d1f")]},
	"kill_bubble_trap": {"name": "Bubble Trap", "rarity": "rare", "desc": "The loser is trapped in a bubble and floats away. Pop!",
		"swatch": [Color("bfefff"), Color("ffb3ec"), Color("ffffff")]},
	"kill_meteor_call": {"name": "Meteor Call", "rarity": "epic", "desc": "Your chip calls down a meteor from the sky.",
		"swatch": [Color("ff8a1f"), Color("fff36b"), Color("4a3a3a")]},
	# Holiday action kills.
	"kill_ghost_pop": {"name": "BOO!", "rarity": "epic", "season": "halloween", "desc": "A cheeky ghost swoops out and spooks the loser right off the board.",
		"swatch": [Color("ffffff"), Color("b8c6ff"), Color("8b5cf6")]},
	"kill_gift_box": {"name": "Surprise Present", "rarity": "epic", "season": "christmas", "desc": "A present drops on the loser. Pop goes the lid: ribbons and confetti!",
		"swatch": [Color("d62f3a"), Color("ffcf3f"), Color("2f8f4e")]},
	"kill_firecracker": {"name": "Firecracker String", "rarity": "rare", "season": "new_year", "desc": "Your chip tosses a string of firecrackers. Pop-pop-pop-BANG!",
		"swatch": [Color("e8282e"), Color("ffcf3f"), Color("e6e6e6")]},
	"kill_cupid_arrow": {"name": "Cupid's Arrow", "rarity": "rare", "season": "valentines", "desc": "One arrow, and the loser floats away lovestruck.",
		"swatch": [Color("ffcf3f"), Color("ff2f5f"), Color("ffe3ec")]},
	"kill_lion_dance": {"name": "Lion Dance", "rarity": "legendary", "season": "lunar_new_year", "desc": "A lion-dance head bounds over, chomps twice and sends the loser flying in a shower of coins.",
		"swatch": [Color("e8282e"), Color("ffcf3f"), Color("27c98f")]},
}

## Action kills: `impact` is when the loser goes down (seconds after the effect starts), `death`
## how it leaves the board (Piece3D.eliminate). Each stays under ACTION_LIFETIME.
const ACTIONS := {
	"kill_bazooka": {"impact": 0.45, "death": "burn"},
	"kill_wizard_fireball": {"impact": 0.55, "death": "burn"},
	"kill_earth_shaman": {"impact": 0.35, "death": "sink"},
	"kill_airstrike": {"impact": 0.75, "death": "burn"},
	"kill_ninja_slash": {"impact": 0.3, "death": "split"},
	"kill_storm_caller": {"impact": 0.55, "death": "burn"},
	"kill_orbital_laser": {"impact": 0.5, "death": "burn"},
	"kill_anvil_drop": {"impact": 0.45, "death": "squash"},
	"kill_pocket_wormhole": {"impact": 0.4, "death": "vanish"},
	"kill_freeze_ray": {"impact": 0.5, "death": "shatter"},
	"kill_catapult": {"impact": 0.6, "death": "squash"},
	"kill_pirate_cannon": {"impact": 0.4, "death": "burn"},
	"kill_tornado": {"impact": 0.4, "death": "lift"},
	"kill_ufo_abduction": {"impact": 0.45, "death": "lift"},
	"kill_kraken": {"impact": 0.47, "death": "sink"},
	"kill_boxing_glove": {"impact": 0.3, "death": "fly"},
	"kill_dragon_breath": {"impact": 0.5, "death": "burn"},
	"kill_bubble_trap": {"impact": 0.35, "death": "lift"},
	"kill_meteor_call": {"impact": 0.6, "death": "burn"},
	"kill_ghost_pop": {"impact": 0.45, "death": "vanish"},
	"kill_gift_box": {"impact": 0.4, "death": "shatter"},
	"kill_firecracker": {"impact": 0.55, "death": "burn"},
	"kill_cupid_arrow": {"impact": 0.35, "death": "lift"},
	"kill_lion_dance": {"impact": 0.5, "death": "fly"},
}
const ACTION_LIFETIME := 1.8
const PROP_SCALE := 1.7  ## Action props are drawn bigger than life so they read from the play camera.
const LIFT := 1.5        ## ...and float higher above the winner.

var _strength := 1.0
var _src := Vector3.ZERO  ## Action kills: from the loser (this node) to the winner.


## Plays `style` at board-local `at` under `parent`. `color` tints the classic burst.
static func play(parent: Node3D, at: Vector3, style: String, color := Color(1.0, 0.7, 0.25), strength := 1.0) -> void:
	if style == "classic" or not STYLES.has(style):
		ClashFX.burst(parent, at, color, strength)
		return
	var fx := KillFX.new()
	parent.add_child(fx)
	fx.position = at
	fx._strength = strength
	match style:
		"kill_fire_explosion":
			fx._fire()
		"kill_ice_shatter":
			fx._ice()
		"kill_pixel_burst":
			fx._pixels()
		"kill_confetti":
			fx._confetti()
		"kill_lightning_strike":
			fx._lightning()
		"kill_black_hole":
			fx._black_hole()
		"kill_sakura_burst":
			fx._sakura()
		"kill_ghost":
			fx._ghost()
		"kill_toxic_splat":
			fx._toxic()
		"kill_star_shower":
			fx._stars()
	fx.get_tree().create_timer(LIFETIME).timeout.connect(fx.queue_free)


static func is_action(style: String) -> bool:
	return ACTIONS.has(style)


## How the loser leaves the board for `style` ("" = the usual pop).
static func death_of(style: String) -> String:
	return str(ACTIONS.get(style, {}).get("death", ""))


## Plays an action kill: the winner at `from` takes down the loser at `to` (board-local, both at
## piece height). Returns the seconds until impact, when the caller should eliminate the loser.
static func play_action(parent: Node3D, from: Vector3, to: Vector3, style: String, strength := 1.0) -> float:
	var fx := KillFX.new()
	parent.add_child(fx)
	fx.position = to
	fx._strength = strength
	fx._src = from - to
	fx._act(style)
	fx.get_tree().create_timer(ACTION_LIFETIME).timeout.connect(fx.queue_free)
	return float(ACTIONS[style]["impact"])


# --- Styles -----------------------------------------------------------------------------------

func _fire() -> void:
	var ball := _sphere(Color("ff5a1a"), 0.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * 2.2 * _strength, 0.35).from(Vector3.ONE * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ball.material_override, "albedo_color:a", 0.0, 0.45).set_delay(0.08)
	var core := _sphere(Color("ffc23a"), 0.2)
	t.tween_property(core, "scale", Vector3.ONE * 1.6, 0.25).from(Vector3.ONE * 0.2)
	t.tween_property(core.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.05)
	_burst("flame", false, 26, 0.7, 0.34, [Color("ffe14d"), Color("ff8a1f"), Color("e8341c")], 2.5, 4.5, Vector3(0, 2.0, 0))
	# Smoke fades in, so it rises out of the fireball instead of sitting in front of it.
	var smoke := _burst("puff", false, 10, 1.3, 0.45, [Color("6a5a5a", 0.0), Color("6a5a5a", 0.8), Color("4a3a3a", 0.5), Color("2a2222", 0.0)], 0.6, 1.4, Vector3(0, 1.0, 0))
	smoke.position.y = 0.2
	_flash(Color("ff9a3a"), 2.5)
	_ground_ring(Color("ff6a1a"), 2.4)


func _ice() -> void:
	var block := _sphere(Color("bfefff"), 0.32, false)
	var t := create_tween()
	t.tween_property(block, "scale", Vector3.ONE * 1.2, 0.12).from(Vector3.ONE * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_property(block, "scale", Vector3.ONE * 0.01, 0.06)
	var shards := _burst("shard", false, 24, 1.1, 0.24, [Color("ffffff"), Color("c8f2ff"), Color("6fc3ff")], 2.0, 4.5, Vector3(0, -9.0, 0), 0.18)
	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0
	_burst("snowflake", true, 10, 1.0, 0.16, [Color("ffffff"), Color("aee9ff"), Color("6fc3ff")], 0.8, 1.8, Vector3(0, -0.5, 0), 0.18)
	_flash(Color("aee9ff"), 1.5)
	_ground_ring(Color("5fc8ff"), 2.8)


func _pixels() -> void:
	var p := _burst("square", false, 40, 1.0, 0.16, [Color.WHITE, Color.WHITE, Color.WHITE], 2.5, 5.0, Vector3(0, -8.0, 0), 0.12)
	var palette := Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	palette.colors = PackedColorArray([Color("ff4d6d"), Color("4dffb0"), Color("6f8bff"), Color("ffd23f"), Color("ffffff")])
	p.color_initial_ramp = palette
	p.angle_min = 0.0
	p.angle_max = 0.0
	var big := _burst("square", false, 8, 0.6, 0.26, [Color("ffffff"), Color("ffd23f"), Color("ff4d6d")], 1.5, 2.5, Vector3.ZERO, 0.05)
	big.angle_min = 0.0
	big.angle_max = 0.0
	_flash(Color("ffffff"), 3.0)


func _confetti() -> void:
	var p := _burst("square", false, 46, 1.5, 0.14, [Color.WHITE, Color.WHITE, Color.WHITE], 2.5, 5.0, Vector3(0, -4.0, 0), 0.1)
	p.color_initial_ramp = FxTextures.rainbow()
	p.direction = Vector3.UP
	p.spread = 70.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)])
	_burst("sparkle", true, 12, 0.7, 0.2, [Color("ffffff"), Color("fff1b0"), Color("ffc93c")], 1.0, 2.5, Vector3.ZERO, 0.1)
	_flash(Color("fff1b0"), 2.5)


func _lightning() -> void:
	# Two crossed billboard bolts from the sky down to the piece, flickering, then a spark shower.
	for i in 2:
		var bolt := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 5.0)
		bolt.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.albedo_texture = FxTextures.texture("bolt")
		m.albedo_color = Color("dff6ff") if i == 0 else Color("6fb8ff")
		m.render_priority = 3
		bolt.material_override = m
		bolt.position = Vector3(0.0, 2.4, 0.0)
		bolt.scale = Vector3(1.0 + i * 0.4, 1.0, 1.0)
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bolt)
		var t := create_tween()
		for k in 4:
			t.tween_property(m, "albedo_color:a", 0.15, 0.04)
			t.tween_property(m, "albedo_color:a", 1.0, 0.04)
		t.tween_property(m, "albedo_color:a", 0.0, 0.25)
	_burst("sparkle", true, 26, 0.6, 0.2, [Color("ffffff"), Color("aee9ff"), Color("4fa8ff")], 2.5, 5.0, Vector3(0, -6.0, 0), 0.1)
	_flash(Color("cfefff"), 3.0)
	_ground_ring(Color("4fa8ff"), 2.2)


func _black_hole() -> void:
	var hole := _sphere(Color("0d0a18"), 0.28, false)
	hole.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.56
	torus.rings = 40
	torus.ring_segments = 8
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.6, 0.6, 2.2, 1.0)
	ring.material_override = rm
	ring.rotation.x = 0.35
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(hole, "scale", Vector3.ONE * 1.6, 0.3).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.3).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "rotation:y", TAU * 2.0, 1.2)
	t.chain().tween_property(hole, "scale", Vector3.ONE * 0.01, 0.25).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ring, "scale", Vector3.ONE * 0.01, 0.25).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rm, "albedo_color:a", 0.0, 0.25).set_delay(0.6)
	# Debris spiralling inward.
	var suck := FxTextures.particles("star", true, 30, 0.8, 0.14)
	suck.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	suck.emission_sphere_radius = 1.4
	suck.initial_velocity_min = 0.0
	suck.initial_velocity_max = 0.0
	suck.radial_accel_min = -6.0
	suck.radial_accel_max = -4.0
	suck.tangential_accel_min = 3.0
	suck.tangential_accel_max = 5.0
	suck.gravity = Vector3.ZERO
	suck.color_ramp = FxTextures.gradient([Color("ffffff"), Color("ff5cd6"), Color("6a3cff")])
	suck.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.1)])
	suck.lifetime = 0.8
	suck.one_shot = false
	suck.emitting = true
	add_child(suck)
	get_tree().create_timer(0.7).timeout.connect(_stop_emitting.bind(suck.get_instance_id()))
	_flash(Color("8a5cff"), 3.0)


func _sakura() -> void:
	var p := _burst("petal", false, 34, 1.5, 0.22, [Color("ffe3ee"), Color("ffb3d1"), Color("ff8fb8")], 1.5, 3.5, Vector3(0, -1.2, 0), 0.15)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.tangential_accel_min = 2.0
	p.tangential_accel_max = 4.0
	_burst("sparkle", true, 10, 0.8, 0.16, [Color("ffffff"), Color("ffd6e6"), Color("ff9ec7")], 0.8, 1.6, Vector3.ZERO, 0.1)
	_flash(Color("ffb3d1"), 2.0)
	_ground_ring(Color("ff9ec7"), 2.2)


func _ghost() -> void:
	var ghost := MeshInstance3D.new()
	ghost.mesh = FxTextures.quad(0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = FxTextures.texture("ghost")
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	m.render_priority = 3
	ghost.material_override = m
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	var t := create_tween().set_parallel(true)
	t.tween_property(m, "albedo_color:a", 0.92, 0.2)
	t.tween_property(ghost, "position:y", 1.5, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.4).set_delay(1.0)
	var wobble := create_tween().set_loops(3)
	wobble.tween_property(ghost, "position:x", 0.18, 0.22).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(ghost, "position:x", -0.18, 0.22).set_trans(Tween.TRANS_SINE)
	var wisps := _burst("dot", true, 16, 1.0, 0.14, [Color("e6ecff"), Color("b8c6ff"), Color("6a5acd")], 0.3, 0.9, Vector3(0, 0.8, 0), 0.25)
	wisps.explosiveness = 0.4
	_flash(Color("b8c6ff"), 1.5)


func _toxic() -> void:
	var splash := _burst("dot", false, 30, 0.9, 0.22, [Color("eaff9a"), Color("8be03a"), Color("3a8a1f")], 2.0, 3.8, Vector3(0, -9.0, 0), 0.12)
	splash.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.2)])
	_burst("bubble", true, 12, 1.4, 0.2, [Color("eaff9a"), Color("9cff3a"), Color("4fc41a")], 0.3, 0.9, Vector3(0, 0.6, 0), 0.3)
	var puddle := _ground_ring(Color("7ddc3a"), 2.0, "puff", false)
	puddle.material_override.albedo_color = Color("6fc42e", 0.9)
	_flash(Color("b6ff3a"), 2.5)


func _stars() -> void:
	var p := _burst("star", false, 30, 1.3, 0.28, [Color("fff1b0"), Color("ffd24a"), Color("ff9f1c")], 2.5, 4.5, Vector3(0, -6.0, 0), 0.1)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	_burst("sparkle", true, 12, 0.6, 0.3, [Color("ffffff"), Color("fff1b0"), Color("ffc93c")], 0.5, 1.5, Vector3.ZERO, 0.05)
	_flash(Color("ffe066"), 3.5)
	_ground_ring(Color("ffc93c"), 2.4)


# --- Action kills ------------------------------------------------------------------------------
# Performed by the winning chip: a prop pops up on it (a bazooka, a wizard hat, a catapult...) and
# takes the loser down. The node sits on the loser; `_src` points from the loser to the winner.

func _act(style: String) -> void:
	match style:
		"kill_bazooka":
			_bazooka()
		"kill_wizard_fireball":
			_wizard_fireball()
		"kill_earth_shaman":
			_earth_shaman()
		"kill_airstrike":
			_airstrike()
		"kill_ninja_slash":
			_ninja_slash()
		"kill_storm_caller":
			_storm_caller()
		"kill_orbital_laser":
			_orbital_laser()
		"kill_anvil_drop":
			_anvil_drop()
		"kill_pocket_wormhole":
			_pocket_wormhole()
		"kill_freeze_ray":
			_freeze_ray()
		"kill_catapult":
			_catapult()
		"kill_pirate_cannon":
			_pirate_cannon()
		"kill_tornado":
			_tornado()
		"kill_ufo_abduction":
			_ufo_abduction()
		"kill_kraken":
			_kraken()
		"kill_boxing_glove":
			_boxing_glove()
		"kill_dragon_breath":
			_dragon_breath()
		"kill_bubble_trap":
			_bubble_trap()
		"kill_meteor_call":
			_meteor_call()
		"kill_ghost_pop":
			_ghost_pop()
		"kill_gift_box":
			_gift_box()
		"kill_firecracker":
			_firecracker()
		"kill_cupid_arrow":
			_cupid_arrow()
		"kill_lion_dance":
			_lion_dance()


func _bazooka() -> void:
	var muzzle := _src + Vector3(0.0, 0.63, 0.0)
	var gun := _prop_on_winner("bazooka", [
		PropKit.pt("4f6a3a", ShapeKit.cylinder(0.07, 0.07, 0.6, 14), Vector3(0.0, 0.0, -0.05), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("2f3f24", ShapeKit.torus(0.06, 0.09, 14, 5), Vector3(0.0, 0.0, -0.35), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("2f3f24", ShapeKit.box(Vector3(0.05, 0.14, 0.06), 0.015, 0.008), Vector3(0.0, -0.1, 0.05)),
		PropKit.pt("ffd23f", ShapeKit.box(Vector3(0.03, 0.06, 0.03), 0.01, 0.005), Vector3(0.0, 0.09, -0.1)),
	], 0.42, 0.95)
	_recoil(gun, 0.12)
	var rocket := PropKit.model("rocket", [
		PropKit.pt("e8341c", ShapeKit.cylinder(0.045, 0.045, 0.22, 12), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("ffffff", ShapeKit.cone(0.045, 0.1, 12), Vector3(0.0, 0.0, -0.16), Vector3(-PI / 2.0, 0.0, 0.0)),
		PropKit.pt("ffd23f", ShapeKit.box(Vector3(0.14, 0.05, 0.01), 0.005, 0.003), Vector3(0.0, 0.0, 0.09)),
		PropKit.pt("ffd23f", ShapeKit.box(Vector3(0.01, 0.05, 0.14), 0.005, 0.003), Vector3(0.0, 0.0, 0.09), Vector3(0.0, 0.0, PI / 2.0)),
	])
	add_child(rocket)
	rocket.scale = Vector3.ONE * PROP_SCALE
	rocket.visible = false
	_after(0.12, func() -> void: rocket.visible = true)
	_trail_puffs(rocket, Color("d8d0c8"), 0.12)
	_fly(rocket, muzzle + _toward() * 0.5, Vector3.ZERO, 0.33, 0.15, 0.12)
	_after(0.45, func() -> void:
		rocket.queue_free()
		_fire())


func _wizard_fireball() -> void:
	_prop_on_winner("wizard_hat", [
		PropKit.pt("6a3cff", ShapeKit.cone(0.2, 0.42, 18), Vector3(0.0, 0.21, 0.0)),
		PropKit.pt("4a2ab8", ShapeKit.cylinder(0.3, 0.3, 0.03, 22), Vector3(0.0, 0.0, 0.0)),
		PropKit.pt("ffd23f|g0.6", ShapeKit.torus(0.15, 0.19, 18, 5), Vector3(0.0, 0.07, 0.0)),
		PropKit.pt("ffd23f|g0.8", ShapeKit.sphere(0.045), Vector3(0.0, 0.2, -0.13), Vector3.ZERO, 0.0),
	], 0.36, 1.0)
	var sparkles := _burst("sparkle", true, 14, 0.6, 0.18, [Color("ffffff"), Color("d6c2ff"), Color("8a5cff")], 0.5, 1.2, Vector3.ZERO, 0.25)
	sparkles.position = _src + Vector3(0.0, 0.75, 0.0)
	var ball := _glow_ball(Color("ff7a1a"), 0.22)
	ball.visible = false
	_after(0.18, func() -> void: ball.visible = true)
	_trail_flames(ball)
	_fly(ball, _src + Vector3(0.0, 0.82, 0.0), Vector3.ZERO, 0.37, 0.7, 0.18)
	_after(0.55, func() -> void:
		ball.queue_free()
		_fire()
		_burst("sparkle", true, 16, 0.7, 0.2, [Color("ffffff"), Color("d6c2ff"), Color("8a5cff")], 1.5, 3.0, Vector3(0, -2.0, 0), 0.15))


func _earth_shaman() -> void:
	_prop_on_winner("shaman_headdress", [
		PropKit.pt("8a5a2a", ShapeKit.torus(0.2, 0.25, 20, 5), Vector3.ZERO),
		PropKit.pt("e8341c", ShapeKit.cone(0.035, 0.24, 8), Vector3(0.0, 0.14, -0.2), Vector3(-0.3, 0.0, 0.0)),
		PropKit.pt("ffd23f", ShapeKit.cone(0.035, 0.24, 8), Vector3(0.14, 0.14, -0.15), Vector3(-0.25, 0.0, -0.3)),
		PropKit.pt("ffd23f", ShapeKit.cone(0.035, 0.24, 8), Vector3(-0.14, 0.14, -0.15), Vector3(-0.25, 0.0, 0.3)),
		PropKit.pt("27c98f", ShapeKit.cone(0.035, 0.22, 8), Vector3(0.22, 0.12, -0.02), Vector3(0.0, 0.0, -0.45)),
		PropKit.pt("27c98f", ShapeKit.cone(0.035, 0.22, 8), Vector3(-0.22, 0.12, -0.02), Vector3(0.0, 0.0, 0.45)),
	], 0.36, 1.1)
	# A rumble runs along the ground to the loser, then the earth cracks open under it.
	var ground := Vector3(0.0, -position.y + 0.04, 0.0)
	for i in 5:
		var k := (i + 1) / 6.0
		_after(0.05 + k * 0.28, _dust_puff.bind(_src.lerp(Vector3.ZERO, k) + ground, 0.5))
	var crack := _decal("crack", Color(0.18, 0.11, 0.06, 0.95), ground)
	crack.scale = Vector3(0.1, 1.0, 0.1)
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(crack, "scale", Vector3(1.9, 1.0, 1.9), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(crack, "scale", Vector3(0.05, 1.0, 0.05), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_after(0.32, func() -> void:
		var rocks := _burst("square", false, 18, 0.8, 0.12, [Color("8a6a4a"), Color("6a4a2a"), Color("4a3a2a")], 1.5, 3.0, Vector3(0, -9.0, 0), 0.3)
		rocks.position = ground
		_dust_puff(ground, 1.2))


func _airstrike() -> void:
	var across := _toward().cross(Vector3.UP).normalized()
	if across == Vector3.ZERO:
		across = Vector3.RIGHT
	var jet := PropKit.model("toy_jet", [
		PropKit.pt("9aa6b8", ShapeKit.capsule(0.09, 0.6, 14), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("7f8aa0", ShapeKit.prism(PackedVector2Array([Vector2(0.0, 0.12), Vector2(0.42, -0.12), Vector2(-0.42, -0.12)]), 0.025, 0.006), Vector3(0.0, 0.0, 0.02), Vector3(-PI / 2.0, 0.0, 0.0)),
		PropKit.pt("7f8aa0", ShapeKit.prism(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.16), Vector2(-0.12, 0.0)]), 0.02, 0.005), Vector3(0.0, 0.05, 0.25), Vector3(0.0, PI / 2.0, 0.0)),
		PropKit.pt("6fc3ff|g0.3", ShapeKit.sphere(0.06, 0.1, 12), Vector3(0.0, 0.07, -0.12)),
		PropKit.pt("e8341c", ShapeKit.sphere(0.03), Vector3(0.0, 0.0, -0.3), Vector3.ZERO, 0.0),
	])
	jet.scale = Vector3.ONE * 2.0
	add_child(jet)
	var a := -across * 7.0 + Vector3(0.0, 3.4, 0.0)
	var b := across * 7.0 + Vector3(0.0, 3.6, 0.0)
	jet.basis = Basis.looking_at(b - a, Vector3.UP).scaled(Vector3.ONE * 2.0)
	var t := create_tween()
	t.tween_method(_jet_step.bind(jet, a, b), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bomb := PropKit.model("bomb", [
		PropKit.pt("2a2d40", ShapeKit.sphere(0.1, 0.24, 14), Vector3.ZERO),
		PropKit.pt("e8341c", ShapeKit.box(Vector3(0.16, 0.06, 0.01), 0.005, 0.003), Vector3(0.0, 0.13, 0.0)),
		PropKit.pt("e8341c", ShapeKit.box(Vector3(0.01, 0.06, 0.16), 0.005, 0.003), Vector3(0.0, 0.13, 0.0), Vector3(0.0, 0.0, PI / 2.0)),
	])
	add_child(bomb)
	bomb.scale = Vector3.ONE * PROP_SCALE
	bomb.visible = false
	var shadow := _decal("dot", Color(0.0, 0.0, 0.0, 0.35), Vector3(0.0, -position.y + 0.03, 0.0))
	shadow.scale = Vector3(0.1, 1.0, 0.1)
	create_tween().tween_property(shadow, "scale", Vector3(0.9, 1.0, 0.9), 0.75)
	_after(0.4, func() -> void:
		bomb.visible = true
		bomb.position = Vector3(0.0, 3.4, 0.0)
		var drop := create_tween()
		drop.tween_property(bomb, "position", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	_after(0.75, func() -> void:
		bomb.queue_free()
		shadow.queue_free()
		_strength *= 1.3
		_fire()
		_ground_ring(Color("ffb020"), 3.2))


func _jet_step(k: float, jet: Node3D, a: Vector3, b: Vector3) -> void:
	jet.position = a.lerp(b, k) + Vector3(0.0, -1.0 * sin(k * PI), 0.0)


func _ninja_slash() -> void:
	_prop_on_winner("ninja_band", [
		PropKit.pt("e8341c", ShapeKit.torus(0.2, 0.25, 22, 5), Vector3.ZERO),
		PropKit.pt("e8341c", ShapeKit.box(Vector3(0.05, 0.2, 0.02), 0.01, 0.005), Vector3(0.05, -0.06, 0.24), Vector3(0.4, 0.0, 0.3)),
		PropKit.pt("e8341c", ShapeKit.box(Vector3(0.05, 0.2, 0.02), 0.01, 0.005), Vector3(-0.05, -0.08, 0.24), Vector3(0.5, 0.0, -0.2)),
	], 0.22, 0.6)
	# A white dash line from the winner through the loser, then a crossing slash.
	var dash := _streak(_src + Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.1, 0.0) - _src * 0.3, 0.16, Color(1.0, 1.0, 1.0, 0.95))
	dash.visible = false
	_after(0.12, func() -> void: dash.visible = true)
	var across := _toward().cross(Vector3.UP).normalized()
	var slash := _streak(-across * 0.55 + Vector3(0.0, 0.45, 0.0), across * 0.55 + Vector3(0.0, -0.2, 0.0), 0.1, Color("e8f6ff"), 0.5)
	slash.visible = false
	_after(0.28, func() -> void:
		slash.visible = true
		_burst("sparkle", true, 12, 0.4, 0.2, [Color("ffffff"), Color("e8f6ff"), Color("9ccfff")], 2.0, 3.5, Vector3.ZERO, 0.05)
		_flash(Color("e8f6ff"), 2.0))


func _storm_caller() -> void:
	var cloud := FxTextures.particles("puff", false, 14, 1.4, 0.9)
	cloud.local_coords = true
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 0.5
	cloud.position = Vector3(0.0, 2.3, 0.0)
	cloud.gravity = Vector3.ZERO
	cloud.initial_velocity_max = 0.15
	cloud.angle_min = -180.0
	cloud.angle_max = 180.0
	cloud.color_ramp = FxTextures.gradient([Color("4a4f6a", 0.0), Color("3a3f5a", 0.9), Color("2a2d40", 0.8), Color("2a2d40", 0.0)], false)
	cloud.emitting = true
	add_child(cloud)
	_after(0.9, func() -> void: cloud.emitting = false)
	_after(0.55, _lightning)


func _orbital_laser() -> void:
	var reticle := _decal("glow_ring", Color("ff3d5a"), Vector3(0.0, -position.y + 0.05, 0.0))
	reticle.scale = Vector3(2.4, 1.0, 2.4)
	var t := create_tween()
	t.tween_property(reticle, "scale", Vector3(0.7, 1.0, 0.7), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(reticle, "rotation:y", PI, 0.45)
	t.tween_callback(reticle.queue_free)
	_after(0.5, func() -> void:
		var beam := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.75, 9.0)
		beam.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.albedo_texture = FxTextures.texture("beam")
		m.albedo_color = Color(0.6, 1.4, 1.8, 1.0)
		m.render_priority = 3
		beam.material_override = m
		beam.position = Vector3(0.0, 4.0, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		var bt := create_tween()
		bt.tween_property(beam, "scale:x", 1.3, 0.08)
		bt.tween_property(beam, "scale:x", 0.0, 0.35).set_delay(0.15)
		_burst("sparkle", true, 22, 0.5, 0.22, [Color("ffffff"), Color("9cf6ff"), Color("3ad6ff")], 2.0, 4.0, Vector3(0, -5.0, 0), 0.1)
		var scorch := _decal("crack", Color(0.1, 0.08, 0.12, 0.85), Vector3(0.0, -position.y + 0.04, 0.0))
		scorch.scale = Vector3(1.4, 1.0, 1.4)
		_flash(Color("9cf6ff"), 3.0))


func _anvil_drop() -> void:
	var anvil := PropKit.model("anvil", [
		PropKit.pt("4a4f5e", ShapeKit.box(Vector3(0.34, 0.12, 0.24), 0.02, 0.01), Vector3(0.0, -0.12, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("4a4f5e", ShapeKit.box(Vector3(0.16, 0.12, 0.14), 0.02, 0.01), Vector3(0.0, 0.0, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a6070", ShapeKit.box(Vector3(0.5, 0.1, 0.22), 0.02, 0.01), Vector3(0.0, 0.1, 0.0), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a6070", ShapeKit.cone(0.06, 0.22, 10), Vector3(0.34, 0.1, 0.0), Vector3(0.0, 0.0, -PI / 2.0)),
	])
	anvil.scale = Vector3.ONE * 2.0
	add_child(anvil)
	anvil.position = Vector3(0.0, 4.0, 0.0)
	var shadow := _decal("dot", Color(0.0, 0.0, 0.0, 0.4), Vector3(0.0, -position.y + 0.03, 0.0))
	shadow.scale = Vector3(0.1, 1.0, 0.1)
	create_tween().tween_property(shadow, "scale", Vector3(0.9, 1.0, 0.9), 0.45)
	var t := create_tween()
	t.tween_property(anvil, "position", Vector3(0.0, 0.05, 0.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		_dust_puff(Vector3(0.0, -position.y + 0.05, 0.0), 1.4)
		_burst("star", false, 8, 0.9, 0.16, [Color("fff1b0"), Color("ffd24a"), Color("ff9f1c")], 0.8, 1.4, Vector3(0, -1.0, 0), 0.2))
	t.tween_property(anvil, "position:y", 0.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(anvil, "position:y", 0.05, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(0.35)
	t.tween_property(anvil, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(shadow, "scale", Vector3(0.01, 1.0, 0.01), 0.2)


func _pocket_wormhole() -> void:
	var orb := _glow_ball(Color("8a5cff"), 0.16)
	orb.visible = false
	_after(0.08, func() -> void: orb.visible = true)
	_fly(orb, _src + Vector3(0.0, 0.75, 0.0), Vector3.ZERO, 0.3, 0.6, 0.08)
	_after(0.38, func() -> void:
		orb.queue_free()
		_black_hole())


func _freeze_ray() -> void:
	_prop_on_winner("ray_gun", [
		PropKit.pt("27c9b8", ShapeKit.capsule(0.07, 0.24, 12), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("9aa6b8", ShapeKit.cylinder(0.03, 0.03, 0.2, 10), Vector3(0.0, 0.0, -0.2), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("9cf6ff|g0.6", ShapeKit.torus(0.05, 0.09, 14, 5), Vector3(0.0, 0.0, -0.3), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("1d1736", ShapeKit.box(Vector3(0.04, 0.12, 0.05), 0.01, 0.005), Vector3(0.0, -0.1, 0.05)),
	], 0.42, 1.0)
	var ray := _streak(_src + Vector3(0.0, 0.63, 0.0) + _toward() * 0.6, Vector3.ZERO, 0.14, Color(0.6, 1.0, 1.4, 0.9), 0.45)
	ray.visible = false
	_after(0.15, func() -> void: ray.visible = true)
	_after(0.45, func() -> void: ray.queue_free())
	var block := PropKit.model("ice_block", [PropKit.pt("bfefff|a0.55", ShapeKit.box(Vector3(0.62, 0.62, 0.62), 0.08, 0.02), Vector3.ZERO, Vector3.ZERO, 0.0)])
	add_child(block)
	block.scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_interval(0.25)
	t.tween_property(block, "scale", Vector3.ONE * 1.1, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.05)
	t.tween_callback(func() -> void:
		block.queue_free()
		_ice())


func _catapult() -> void:
	var base := _prop_on_winner("catapult", [
		PropKit.pt("8a5a2a", ShapeKit.box(Vector3(0.36, 0.06, 0.22), 0.02, 0.01), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.05, 0.05, 0.03, 12), Vector3(0.15, -0.03, 0.12), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.05, 0.05, 0.03, 12), Vector3(-0.15, -0.03, 0.12), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("8a5a2a", ShapeKit.box(Vector3(0.04, 0.16, 0.04), 0.01, 0.005), Vector3(0.0, 0.1, 0.06)),
	], 0.3, 1.1)
	var arm := PropKit.model("catapult_arm", [
		PropKit.pt("a8783a", ShapeKit.box(Vector3(0.04, 0.4, 0.03), 0.01, 0.005), Vector3(0.0, 0.2, 0.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.07, 0.05, 0.05, 12), Vector3(0.0, 0.4, 0.0)),
	])
	arm.position = Vector3(0.0, 0.16, 0.06)
	arm.rotation.x = 1.2
	base.add_child(arm)
	var t := create_tween()
	t.tween_interval(0.08)
	t.tween_property(arm, "rotation:x", -0.5, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var boulder := PropKit.model("boulder", [
		PropKit.pt("8a8f9e", ShapeKit.sphere(0.12, 0.22, 8), Vector3.ZERO),
		PropKit.pt("6a6f7e", ShapeKit.sphere(0.06, 0.1, 6), Vector3(0.07, 0.04, -0.05)),
	])
	add_child(boulder)
	boulder.scale = Vector3.ONE * PROP_SCALE
	boulder.visible = false
	_after(0.15, func() -> void: boulder.visible = true)
	_fly(boulder, _src + Vector3(0.0, 0.95, 0.0), Vector3(0.0, 0.05, 0.0), 0.45, 1.6, 0.15, true)
	_after(0.6, func() -> void:
		boulder.queue_free()
		_dust_puff(Vector3(0.0, -position.y + 0.05, 0.0), 1.4)
		var chips := _burst("square", false, 16, 0.8, 0.1, [Color("a8adbb"), Color("8a8f9e"), Color("6a6f7e")], 1.5, 3.0, Vector3(0, -9.0, 0), 0.2)
		chips.position.y = -0.2)


func _pirate_cannon() -> void:
	var cannon := _prop_on_winner("pirate_cannon", [
		PropKit.pt("2a2d40", ShapeKit.cylinder(0.09, 0.06, 0.42, 14), Vector3(0.0, 0.06, -0.05), Vector3(PI / 2.0 + 0.15, 0.0, 0.0)),
		PropKit.pt("1d1736", ShapeKit.torus(0.05, 0.08, 14, 5), Vector3(0.0, 0.09, -0.26), Vector3(PI / 2.0 + 0.15, 0.0, 0.0)),
		PropKit.pt("8a5a2a", ShapeKit.box(Vector3(0.18, 0.08, 0.3), 0.02, 0.01), Vector3(0.0, -0.04, 0.02), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.07, 0.07, 0.03, 12), Vector3(0.1, -0.06, 0.08), Vector3(0.0, 0.0, PI / 2.0)),
		PropKit.pt("5a3a24", ShapeKit.cylinder(0.07, 0.07, 0.03, 12), Vector3(-0.1, -0.06, 0.08), Vector3(0.0, 0.0, PI / 2.0)),
	], 0.36, 1.0)
	_recoil(cannon, 0.1)
	_after(0.1, func() -> void:
		var puff := _burst("puff", false, 10, 0.8, 0.35, [Color("f2f2f2", 0.0), Color("e6e6e6", 0.9), Color("c8c8c8", 0.0)], 0.4, 1.0, Vector3(0, 0.6, 0), 0.08)
		puff.position = _src + Vector3(0.0, 0.63, 0.0) + _toward() * 0.6)
	var ball := PropKit.model("cannonball", [PropKit.pt("2a2d40", ShapeKit.sphere(0.08, 0.16, 12), Vector3.ZERO)])
	add_child(ball)
	ball.scale = Vector3.ONE * PROP_SCALE
	ball.visible = false
	_after(0.1, func() -> void: ball.visible = true)
	_fly(ball, _src + Vector3(0.0, 0.68, 0.0) + _toward() * 0.6, Vector3.ZERO, 0.3, 0.35, 0.1)
	_after(0.4, func() -> void:
		ball.queue_free()
		_fire())


func _tornado() -> void:
	var twister := Node3D.new()
	add_child(twister)
	for i in 5:
		var ring := PropKit.model("twister_ring", [PropKit.pt("c9d2de|a0.6", ShapeKit.torus(0.12, 0.2, 18, 5), Vector3.ZERO, Vector3.ZERO, 0.0)])
		ring.position = Vector3(0.0, -0.4 + i * 0.28, 0.0)
		ring.scale = Vector3.ONE * (0.8 + i * 0.45)
		twister.add_child(ring)
	twister.position = _src
	twister.scale = Vector3.ONE * 0.3
	var dust := _burst("puff", false, 12, 1.2, 0.4, [Color("e0d0b0", 0.0), Color("d8c4a0", 0.7), Color("c8b080", 0.0)], 0.3, 0.8, Vector3(0, 0.4, 0), 0.4)
	dust.one_shot = false
	dust.position.y = -0.35
	var t := create_tween().set_parallel(true)
	t.tween_property(twister, "scale", Vector3.ONE * 1.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(twister, "position", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(twister, "rotation:y", TAU * 5.0, 1.4)
	t.chain().tween_property(twister, "position:y", 2.5, 0.7).set_delay(0.3)
	t.parallel().tween_property(twister, "scale", Vector3.ONE * 0.01, 0.4).set_delay(0.6)
	_after(0.8, func() -> void: dust.emitting = false)


func _ufo_abduction() -> void:
	var saucer := PropKit.model("kill_ufo", [
		PropKit.pt("c9d2de", ShapeKit.sphere(0.5, 0.18, 28), Vector3.ZERO),
		PropKit.pt("9aa6b8", ShapeKit.torus(0.42, 0.55, 28, 6), Vector3(0.0, -0.01, 0.0)),
		PropKit.pt("9cf6ff|a0.7", ShapeKit.sphere(0.2, 0.26, 20), Vector3(0.0, 0.09, 0.0)),
		PropKit.pt("4dffb0|g2.0", ShapeKit.sphere(0.04), Vector3(0.38, -0.02, 0.0), Vector3.ZERO, 0.0),
		PropKit.pt("ff5cd6|g2.0", ShapeKit.sphere(0.04), Vector3(-0.38, -0.02, 0.0), Vector3.ZERO, 0.0),
	])
	add_child(saucer)
	saucer.position = Vector3(-2.5, 4.0, 0.0)
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 0.6
	cone.height = 2.4
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
	beam.position = Vector3(0.0, -1.3, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	saucer.add_child(beam)
	create_tween().tween_property(saucer, "rotation:y", TAU * 2.0, 1.5)
	var t := create_tween()
	t.tween_property(saucer, "position", Vector3(0.0, 2.3, 0.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.35, 0.12)
	t.tween_interval(0.75)
	t.tween_property(m, "albedo_color:a", 0.0, 0.1)
	t.tween_property(saucer, "position", Vector3(3.0, 4.5, 0.0), 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _kraken() -> void:
	# 0.00 churning water opens on the loser's square · 0.10 three tentacles rise out of it
	# 0.30 they curl around the chip · 0.45 impact: dragged under with a splash · 1.25 the water closes.
	var ground := Vector3(0.0, -position.y + 0.035, 0.0)
	var water := _water_disc()
	water.position = ground
	water.scale = Vector3(0.05, 1.0, 0.05)
	var wt := create_tween()
	wt.tween_property(water, "scale", Vector3(1.15, 1.0, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wt.tween_interval(1.0)
	wt.tween_property(water, "scale", Vector3(0.01, 1.0, 0.01), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var foam := _decal("ring", Color(0.92, 0.97, 1.0, 0.9), ground + Vector3(0.0, 0.004, 0.0))
	foam.scale = Vector3(0.4, 1.0, 0.4)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(foam, "scale", Vector3(1.5, 1.0, 1.5), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ft.tween_property(foam.material_override, "albedo_color:a", 0.0, 0.4).set_delay(0.2)

	var group := Node3D.new()
	group.position = ground
	add_child(group)
	var arms: Array[Array] = []
	for k in 3:
		var base := Node3D.new()
		var angle := k * TAU / 3.0 + 0.4
		base.position = Vector3(cos(angle), 0.0, sin(angle)) * 0.4 + Vector3(0.0, -1.25, 0.0)
		group.add_child(base)
		base.basis = Basis.looking_at(-Vector3(cos(angle), 0.0, sin(angle)), Vector3.UP).scaled(Vector3.ONE * 1.25)  # -Z faces the chip.
		arms.append(_tentacle(base, k))
	var rise := create_tween()
	rise.tween_interval(0.08)
	for child in group.get_children():
		rise.parallel().tween_property(child, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var curl := create_tween()
	curl.tween_method(_curl_tentacles.bind(arms), 0.0, 1.0, 0.2).set_delay(0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	curl.tween_method(_curl_tentacles.bind(arms), 1.0, 1.15, 0.08)
	var drag := create_tween()
	drag.tween_interval(0.47)
	drag.tween_property(group, "position:y", ground.y - 1.3, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	drag.tween_callback(group.queue_free)

	_after(0.45, func() -> void:
		var splash := _burst("dot", false, 26, 0.75, 0.13, [Color("ffffff"), Color("aee0ff"), Color("3d8bff")], 2.0, 3.6, Vector3(0, -8.5, 0), 0.35)
		splash.position = ground
		var spray := _burst("puff", false, 8, 0.6, 0.4, [Color("ffffff", 0.0), Color("e6f6ff", 0.8), Color("b8e0ff", 0.0)], 0.4, 0.9, Vector3(0, 0.5, 0), 0.3)
		spray.position = ground)
	var bubbles := FxTextures.particles("bubble", false, 18, 0.9, 0.16)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.35
	bubbles.direction = Vector3.UP
	bubbles.spread = 25.0
	bubbles.initial_velocity_min = 0.6
	bubbles.initial_velocity_max = 1.1
	bubbles.gravity = Vector3.ZERO
	bubbles.color_ramp = FxTextures.gradient([Color("ffffff"), Color("cfeeff"), Color("8fcaff")])
	bubbles.position = ground
	bubbles.emitting = false
	add_child(bubbles)
	_after(0.5, func() -> void: bubbles.emitting = true)
	_after(1.15, func() -> void: bubbles.emitting = false)
	_after(1.42, func() -> void:
		var close := _burst("dot", false, 10, 0.4, 0.08, [Color("ffffff"), Color("aee0ff"), Color("3d8bff")], 0.8, 1.4, Vector3(0, -6.0, 0), 0.1)
		close.position = ground)


## One tentacle: a chain of tapering segments (each a child of the last, so bending every joint a
## little curls the whole arm), purple with pale suckers on the side facing the chip.
func _tentacle(base: Node3D, index: int) -> Array:
	var joints: Array = []
	var parent := base
	for i in 8:
		var r := 0.12 - i * 0.011
		var joint := Node3D.new()
		joint.position = Vector3(0.0, 0.0 if i == 0 else 0.15, 0.0)
		parent.add_child(joint)
		var seg := PropKit.model("kraken_seg_%d" % i, [
			PropKit.pt("7a2ca8", ShapeKit.capsule(r, 0.3, 12), Vector3(0.0, 0.08, 0.0)),
			PropKit.pt("f0c8ff", ShapeKit.sphere(r * 0.38, r * 0.5, 8), Vector3(0.0, 0.07, -r * 0.82), Vector3.ZERO, 0.0),
		])
		joint.add_child(seg)
		joints.append(joint)
		parent = joint
	joints[0].set_meta("sway", index * 1.7)
	return joints


## t 0 → 1: from standing straight up to wrapped around the chip (tip curling in over the top).
func _curl_tentacles(t: float, arms: Array[Array]) -> void:
	for joints: Array in arms:
		var sway: float = (joints[0] as Node3D).get_meta("sway", 0.0)
		for i in joints.size():
			var bend := lerpf(0.05, 0.42 + i * 0.03, t) + sin(sway + i * 0.6 + t * 6.0) * 0.06 * (1.0 - t)
			(joints[i] as Node3D).rotation = Vector3(-bend if i > 0 else -0.15 * t, 0.0, 0.0)


## A disc of churning water with swirling foam bands and a white foam rim.
func _water_disc() -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	disc.mesh = plane
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 11.0 - TIME * 9.0);
	vec3 deep = vec3(0.04, 0.16, 0.42);
	vec3 shallow = vec3(0.16, 0.52, 0.92);
	vec3 col = mix(deep, shallow, smoothstep(0.0, 0.9, r));
	float foam = smoothstep(0.6, 0.95, swirl) * smoothstep(0.2, 0.65, r);
	float rim = smoothstep(0.76, 0.88, r) * (1.0 - smoothstep(0.93, 1.0, r));
	col = mix(col, vec3(0.94, 0.98, 1.0), clamp(foam * 0.75 + rim, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.96, 1.0, r);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = 1
	disc.material_override = m
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	return disc


func _boxing_glove() -> void:
	var start := _src + Vector3(0.0, 0.25, 0.0)
	var glove := PropKit.model("boxing_glove", [
		PropKit.pt("e8341c", ShapeKit.sphere(0.15, 0.3, 16), Vector3.ZERO),
		PropKit.pt("e8341c", ShapeKit.sphere(0.06), Vector3(0.12, 0.05, 0.02)),
		PropKit.pt("ffffff", ShapeKit.cylinder(0.09, 0.09, 0.08, 14), Vector3(0.0, 0.0, 0.16), Vector3(PI / 2.0, 0.0, 0.0)),
	])
	add_child(glove)
	glove.scale = Vector3.ONE * PROP_SCALE
	var coils: Array[Node3D] = []
	for i in 6:
		var coil := PropKit.model("spring_coil", [PropKit.pt("c9d2de", ShapeKit.torus(0.04, 0.06, 12, 4), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), 0.008)])
		add_child(coil)
		coils.append(coil)
	var aim := Basis.looking_at(-_src, Vector3.UP)
	glove.basis = aim.scaled(Vector3.ONE * PROP_SCALE)
	for coil in coils:
		coil.basis = aim.scaled(Vector3.ONE * PROP_SCALE)
	var t := create_tween()
	t.tween_method(_spring_step.bind(glove, coils, start, Vector3(0.0, 0.0, 0.0)), 0.0, 1.0, 0.25).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		ClashFX.burst(get_parent(), position, Color("ffd23f"), 0.8))
	t.tween_interval(0.2)
	t.tween_method(_spring_step.bind(glove, coils, start, Vector3(0.0, 0.0, 0.0)), 1.0, 0.0, 0.25)
	t.tween_callback(func() -> void:
		glove.visible = false
		for coil in coils:
			coil.visible = false)


func _spring_step(k: float, glove: Node3D, coils: Array[Node3D], from: Vector3, to: Vector3) -> void:
	var tip := from.lerp(to, k)
	glove.position = tip
	for i in coils.size():
		coils[i].position = from.lerp(tip, (i + 0.5) / coils.size())
		coils[i].visible = k > 0.02


func _dragon_breath() -> void:
	var head := _prop_on_winner("dragon_head", [
		PropKit.pt("27c98f", ShapeKit.box(Vector3(0.26, 0.2, 0.36), 0.06, 0.02), Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("1fa878", ShapeKit.box(Vector3(0.2, 0.12, 0.24), 0.04, 0.015), Vector3(0.0, -0.04, -0.26), Vector3(PI / 2.0, 0.0, 0.0)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.05), Vector3(0.08, 0.1, -0.1)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.05), Vector3(-0.08, 0.1, -0.1)),
		PropKit.pt("1d1736", ShapeKit.sphere(0.022), Vector3(0.09, 0.11, -0.145), Vector3.ZERO, 0.0),
		PropKit.pt("1d1736", ShapeKit.sphere(0.022), Vector3(-0.09, 0.11, -0.145), Vector3.ZERO, 0.0),
		PropKit.pt("fff1b0", ShapeKit.cone(0.035, 0.16, 8), Vector3(0.08, 0.17, 0.08), Vector3(0.5, 0.0, -0.2)),
		PropKit.pt("fff1b0", ShapeKit.cone(0.035, 0.16, 8), Vector3(-0.08, 0.17, 0.08), Vector3(0.5, 0.0, 0.2)),
	], 0.42, 1.05)
	var breath := FxTextures.particles("flame", false, 46, 0.4, 0.3)
	breath.local_coords = false
	breath.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	breath.emission_sphere_radius = 0.05
	breath.direction = Vector3.FORWARD
	breath.spread = 14.0
	var reach := _src.length()
	breath.initial_velocity_min = reach * 2.2
	breath.initial_velocity_max = reach * 2.8
	breath.gravity = Vector3.ZERO
	breath.scale_amount_curve = FxTextures.curve([Vector2(0.0, 0.4), Vector2(0.5, 1.2), Vector2(1.0, 0.6)])
	breath.color_ramp = FxTextures.gradient([Color("fff36b"), Color("ffa21f"), Color("ff3d1f")])
	breath.position = Vector3(0.0, -0.04, -0.4)
	breath.emitting = false
	head.add_child(breath)
	_after(0.15, func() -> void: breath.emitting = true)
	_after(0.65, func() -> void: breath.emitting = false)
	_after(0.5, _fire)


func _bubble_trap() -> void:
	var bubble := PropKit.model("trap_bubble", [PropKit.pt("bfefff|a0.3", ShapeKit.sphere(0.5, 1.0, 24), Vector3.ZERO, Vector3.ZERO, 0.0)])
	add_child(bubble)
	var shine := MeshInstance3D.new()
	shine.mesh = FxTextures.quad(1.05)
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_texture = FxTextures.texture("bubble")
	sm.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	shine.material_override = sm
	bubble.add_child(shine)
	bubble.scale = Vector3.ONE * 0.25
	var t := create_tween()
	t.tween_method(_fly_step.bind(bubble, _src + Vector3(0.0, 0.4, 0.0), Vector3.ZERO, 0.3, false), 0.0, 1.0, 0.35)
	t.parallel().tween_property(bubble, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(bubble, "position:y", 3.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(bubble, "scale", Vector3.ONE * 0.6, 0.9)
	t.tween_callback(func() -> void:
		bubble.visible = false
		var pop := _burst("dot", false, 12, 0.4, 0.1, [Color("ffffff"), Color("bfefff"), Color("ffb3ec")], 1.0, 2.0, Vector3.ZERO, 0.2)
		pop.position = Vector3(0.0, 3.2, 0.0))


func _meteor_call() -> void:
	var from := Vector3(-1.8, 5.0, -1.2)
	var head := _glow_ball(Color("ff8a1f"), 0.3)
	_trail_flames(head)
	_fly(head, from, Vector3.ZERO, 0.6, 0.0, 0.0)
	_after(0.6, func() -> void:
		head.queue_free()
		_strength *= 1.2
		_fire()
		var crater := _decal("crack", Color(0.15, 0.1, 0.08, 0.9), Vector3(0.0, -position.y + 0.04, 0.0))
		crater.scale = Vector3(1.5, 1.0, 1.5))


# --- Holiday action kills --------------------------------------------------------------------------

func _ghost_pop() -> void:
	var ghost := PropKit.model("boo_ghost", [
		PropKit.pt("ffffff|a0.9", ShapeKit.sphere(0.16, 0.26, 18), Vector3(0, 0.05, 0)),
		PropKit.pt("ffffff|a0.9", ShapeKit.cone(0.16, 0.16, 16), Vector3(0, -0.13, 0), Vector3(PI, 0, 0)),
		PropKit.pt("1d1736", ShapeKit.sphere(0.03, 0.04, 8), Vector3(-0.055, 0.08, -0.14), Vector3.ZERO, 0.0),
		PropKit.pt("1d1736", ShapeKit.sphere(0.03, 0.04, 8), Vector3(0.055, 0.08, -0.14), Vector3.ZERO, 0.0),
		PropKit.pt("1d1736", ShapeKit.sphere(0.04, 0.05, 8), Vector3(0, -0.01, -0.15), Vector3.ZERO, 0.0),
	])
	add_child(ghost)
	ghost.scale = Vector3.ONE * 0.05
	ghost.position = _src + Vector3(0.0, 0.3, 0.0)
	ghost.basis = Basis.looking_at(_toward(), Vector3.UP)
	var t := create_tween()
	t.tween_method(_scale_basis.bind(ghost, ghost.basis), 0.05, 1.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fly(ghost, _src + Vector3(0.0, 0.75, 0.0), Vector3(0.0, 0.3, 0.0), 0.3, 0.6, 0.15)
	_after(0.45, func() -> void:
		_burst("dot", true, 18, 0.7, 0.16, [Color("e6ecff"), Color("b8c6ff"), Color("8b5cf6")], 1.2, 2.4, Vector3(0, 0.6, 0), 0.2)
		_ground_ring(Color("8b5cf6"), 2.4)
		_flash(Color("b8c6ff"), 2.0)
		var rise := create_tween()
		rise.tween_property(ghost, "position:y", 2.4, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		rise.parallel().tween_method(_scale_basis.bind(ghost, ghost.basis.orthonormalized()), 1.0, 0.01, 0.9).set_delay(0.3))


func _gift_box() -> void:
	var box := PropKit.model("gift_box", [
		PropKit.pt("d62f3a", ShapeKit.box(Vector3(0.62, 0.5, 0.62), 0.04, 0.02), Vector3.ZERO),
		PropKit.pt("ffcf3f", ShapeKit.box(Vector3(0.1, 0.52, 0.64), 0.02, 0.01), Vector3.ZERO, Vector3.ZERO, 0.0),
		PropKit.pt("ffcf3f", ShapeKit.box(Vector3(0.64, 0.52, 0.1), 0.02, 0.01), Vector3.ZERO, Vector3.ZERO, 0.0),
	])
	var lid := PropKit.model("gift_lid", [
		PropKit.pt("e8443e", ShapeKit.box(Vector3(0.68, 0.68, 0.1), 0.04, 0.02), Vector3.ZERO, Vector3(PI / 2.0, 0, 0)),
		PropKit.pt("ffcf3f", ShapeKit.sphere(0.09, 0.07, 12), Vector3(-0.08, 0.08, 0), Vector3(0, 0, 0.5)),
		PropKit.pt("ffcf3f", ShapeKit.sphere(0.09, 0.07, 12), Vector3(0.08, 0.08, 0), Vector3(0, 0, -0.5)),
	])
	add_child(box)
	box.add_child(lid)
	lid.position = Vector3(0, 0.3, 0)
	box.position = Vector3(0.0, 3.2, 0.0)
	var t := create_tween()
	t.tween_property(box, "position", Vector3(0.0, -0.18, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(box, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(box, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_after(0.38, _dust_puff.bind(Vector3(0.0, -position.y + 0.05, 0.0), 1.2))
	_after(0.5, func() -> void:
		var pop := create_tween().set_parallel(true)
		pop.tween_property(lid, "position", Vector3(0.3, 1.4, 0.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(lid, "rotation", Vector3(1.5, 0.6, 2.4), 0.4)
		var confetti := _burst("square", false, 40, 1.2, 0.12, [Color.WHITE, Color.WHITE, Color.WHITE], 2.5, 4.5, Vector3(0, -4.0, 0), 0.15)
		confetti.color_initial_ramp = FxTextures.rainbow()
		confetti.direction = Vector3.UP
		confetti.spread = 40.0
		confetti.position.y = 0.1
		var ribbons := _burst("streak", false, 10, 0.9, 0.3, [Color("ffcf3f"), Color("ff4f5a"), Color("2f8f4e")], 2.0, 3.5, Vector3(0, -3.0, 0), 0.1)
		ribbons.position.y = 0.1
		_flash(Color("fff1b0"), 2.0))
	var gone := create_tween()
	gone.tween_interval(1.05)
	gone.tween_property(box, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _firecracker() -> void:
	var string := Node3D.new()
	add_child(string)
	for i in 6:
		var cracker := PropKit.model("firecracker", [
			PropKit.pt("e8282e", ShapeKit.cylinder(0.035, 0.035, 0.14, 10), Vector3.ZERO),
			PropKit.pt("ffcf3f", ShapeKit.torus(0.03, 0.04, 10, 4), Vector3(0, 0.05, 0), Vector3.ZERO, 0.0),
			PropKit.pt("8a5a2a", ShapeKit.cylinder(0.006, 0.006, 0.06, 4), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0),
		])
		var a := TAU * i / 6.0
		cracker.position = Vector3(cos(a) * 0.32, -0.3, sin(a) * 0.32)
		cracker.rotation = Vector3(0, 0, PI / 2.0 + randf_range(-0.3, 0.3))
		string.add_child(cracker)
	string.scale = Vector3.ONE * PROP_SCALE * 0.8
	_fly(string, _src + Vector3(0.0, 0.6, 0.0), Vector3.ZERO, 0.3, 0.8, 0.0, true)
	for i in 6:
		var when := 0.32 + i * 0.045
		_after(when, _crack.bind(string.get_child(i)))
	_after(0.55, func() -> void:
		_strength *= 0.9
		_fire()
		var paper := _burst("square", false, 20, 1.0, 0.08, [Color("ff3d3d"), Color("e8282e"), Color("ffcf3f")], 1.5, 3.0, Vector3(0, -3.0, 0), 0.3)
		paper.position.y = -0.2)


func _crack(cracker: Node3D) -> void:
	if not is_instance_valid(cracker):
		return
	var at := cracker.global_position - global_position
	cracker.visible = false
	var spark := _burst("sparkle", true, 8, 0.3, 0.14, [Color("ffffff"), Color("fff1b0"), Color("ffb020")], 1.0, 2.0, Vector3.ZERO, 0.05)
	spark.position = at
	var puff := _burst("puff", false, 4, 0.6, 0.18, [Color("e6e6e6", 0.0), Color("d8d8d8", 0.8), Color("c8c8c8", 0.0)], 0.2, 0.5, Vector3(0, 0.5, 0), 0.05)
	puff.position = at


func _cupid_arrow() -> void:
	var bow := _prop_on_winner("cupid_bow", [
		PropKit.pt("ffcf3f", ShapeKit.torus(0.2, 0.23, 24, 5), Vector3(0, 0, 0.06), Vector3(0, PI / 2.0, 0)),
		PropKit.pt("ffffff", ShapeKit.cylinder(0.004, 0.004, 0.42, 4), Vector3(0, 0, 0.18), Vector3.ZERO, 0.0),
		PropKit.pt("ff7aa0", ShapeKit.sphere(0.035, -1.0, 8), Vector3(0, 0.21, 0.06), Vector3.ZERO, 0.0),
		PropKit.pt("ff7aa0", ShapeKit.sphere(0.035, -1.0, 8), Vector3(0, -0.21, 0.06), Vector3.ZERO, 0.0),
	], 0.42, 0.8)
	_recoil(bow, 0.12)
	var arrow := PropKit.model("cupid_arrow", [
		PropKit.pt("c8956a", ShapeKit.cylinder(0.012, 0.012, 0.42, 6), Vector3.ZERO, Vector3(PI / 2.0, 0, 0)),
		PropKit.pt("ff2f5f", ShapeKit.sphere(0.04, 0.05, 10), Vector3(-0.03, 0.0, -0.22)),
		PropKit.pt("ff2f5f", ShapeKit.sphere(0.04, 0.05, 10), Vector3(0.03, 0.0, -0.22)),
		PropKit.pt("ff2f5f", ShapeKit.cone(0.055, 0.07, 10), Vector3(0, 0.0, -0.27), Vector3(-PI / 2.0, 0, 0)),
		PropKit.pt("ffffff", ShapeKit.box(Vector3(0.08, 0.05, 0.01), 0.01, 0.003), Vector3(0, 0, 0.2), Vector3(0, PI / 2.0, 0), 0.0),
	])
	add_child(arrow)
	arrow.scale = Vector3.ONE * PROP_SCALE
	arrow.visible = false
	_after(0.12, func() -> void: arrow.visible = true)
	_fly(arrow, _src + Vector3(0.0, 0.63, 0.0) + _toward() * 0.4, Vector3(0.0, 0.1, 0.0), 0.23, 0.2, 0.12)
	_after(0.35, func() -> void:
		arrow.queue_free()
		_burst("heart", false, 22, 1.2, 0.26, [Color("ffe3ec"), Color("ff7aa0"), Color("ff2f5f")], 1.0, 2.2, Vector3(0, 0.8, 0), 0.2)
		_ground_ring(Color("ff4f7b"), 2.2)
		_flash(Color("ff9ec0"), 2.2))


func _lion_dance() -> void:
	var lion := PropKit.model("lion_head", [
		PropKit.pt("e8282e", ShapeKit.sphere(0.24, 0.36, 18), Vector3.ZERO),
		PropKit.pt("ffcf3f", ShapeKit.torus(0.2, 0.26, 24, 6), Vector3(0, 0.02, 0.02), Vector3(PI / 2.0, 0, 0)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.07, -1.0, 12), Vector3(-0.09, 0.1, -0.2)),
		PropKit.pt("ffffff", ShapeKit.sphere(0.07, -1.0, 12), Vector3(0.09, 0.1, -0.2)),
		PropKit.pt("1d1736", ShapeKit.sphere(0.035, -1.0, 8), Vector3(-0.09, 0.1, -0.265), Vector3.ZERO, 0.0),
		PropKit.pt("1d1736", ShapeKit.sphere(0.035, -1.0, 8), Vector3(0.09, 0.1, -0.265), Vector3.ZERO, 0.0),
		PropKit.pt("27c98f", ShapeKit.sphere(0.04, -1.0, 8), Vector3(0, 0.27, -0.06)),
		PropKit.pt("ffcf3f", ShapeKit.cone(0.04, 0.12, 8), Vector3(0, 0.3, 0.02)),
		PropKit.pt("ffffff", ShapeKit.box(Vector3(0.24, 0.05, 0.06), 0.02, 0.01), Vector3(0, -0.1, -0.21), Vector3.ZERO, 0.0),
	])
	var jaw := PropKit.model("lion_jaw", [PropKit.pt("ffcf3f", ShapeKit.box(Vector3(0.3, 0.06, 0.22), 0.03, 0.01), Vector3(0, 0, -0.1), Vector3(PI / 2.0, 0, 0))])
	lion.add_child(jaw)
	jaw.position = Vector3(0, -0.17, -0.02)
	var cloth := PropKit.model("lion_cloth", [PropKit.pt("ff3d3d", ShapeKit.capsule(0.16, 0.5, 12), Vector3(0, -0.05, 0.28), Vector3(PI / 2.0, 0, 0))])
	lion.add_child(cloth)
	add_child(lion)
	lion.basis = Basis.looking_at(_toward(), Vector3.UP).scaled(Vector3.ONE * 1.4)
	var hop1 := _src.lerp(Vector3.ZERO, 0.45) + Vector3(0.0, 0.2, 0.0)
	_fly(lion, _src + Vector3(0.0, 0.4, 0.0), hop1, 0.22, 0.5, 0.0)
	_fly(lion, hop1, Vector3(0.0, 0.2, 0.0), 0.22, 0.6, 0.23)
	var chomp := create_tween()
	chomp.tween_interval(0.42)
	chomp.tween_property(jaw, "rotation:x", 0.7, 0.06)
	chomp.tween_property(jaw, "rotation:x", 0.0, 0.08)
	chomp.tween_property(jaw, "rotation:x", 0.7, 0.06)
	chomp.tween_property(jaw, "rotation:x", 0.0, 0.08)
	_after(0.5, func() -> void:
		_burst("coin", false, 18, 1.0, 0.2, [Color("fff1b0"), Color("ffcf3f"), Color("d4a017")], 1.8, 3.2, Vector3(0, -6.0, 0), 0.2)
		_burst("sparkle", true, 14, 0.5, 0.18, [Color("ffffff"), Color("fff1b0"), Color("ff3d3d")], 1.5, 3.0, Vector3.ZERO, 0.1)
		_flash(Color("ffcf3f"), 2.2))
	var leave := create_tween()
	leave.tween_interval(1.1)
	leave.tween_property(lion, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# --- Action building blocks ---------------------------------------------------------------------

## Horizontal unit vector from the winner toward the loser.
func _toward() -> Vector3:
	var flat := Vector3(-_src.x, 0.0, -_src.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD


## A prop that pops up above the winner (`height` in prop units), aimed at the loser, and pops
## away after `stay`.
func _prop_on_winner(key: String, parts: Array, height: float, stay: float) -> Node3D:
	var prop := PropKit.model(key, parts)
	add_child(prop)
	prop.position = _src + Vector3(0.0, height * LIFT, 0.0)
	prop.basis = Basis.looking_at(_toward(), Vector3.UP)
	var aim := prop.basis
	prop.scale = Vector3.ONE * 0.01
	var t := create_tween()
	t.tween_method(_scale_basis.bind(prop, aim), 0.01, 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(stay)
	t.tween_method(_scale_basis.bind(prop, aim), 1.0, 0.01, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(prop.hide)
	return prop


func _scale_basis(s: float, node: Node3D, aim: Basis) -> void:
	node.basis = aim.scaled(Vector3.ONE * maxf(s, 0.01) * PROP_SCALE)


## Kicks a prop backwards (away from the loser) at `when`, then settles.
func _recoil(prop: Node3D, when: float) -> void:
	var home := prop.position
	var t := create_tween()
	t.tween_interval(when)
	t.tween_property(prop, "position", home - _toward() * 0.12, 0.05)
	t.tween_property(prop, "position", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Moves `node` from `a` to `b` along an arc of height `arc`, nose first, starting after `delay`.
func _fly(node: Node3D, a: Vector3, b: Vector3, duration: float, arc: float, delay := 0.0, tumble := false) -> void:
	node.position = a
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(_fly_step.bind(node, a, b, arc, not tumble), 0.0, 1.0, duration)
	if tumble:
		create_tween().tween_property(node, "rotation", Vector3(TAU * 1.5, TAU, 0.0), duration + delay)


func _fly_step(k: float, node: Node3D, a: Vector3, b: Vector3, arc: float, face: bool) -> void:
	node.position = a.lerp(b, k) + Vector3.UP * arc * 4.0 * k * (1.0 - k)
	if face:
		var tangent := (b - a) + Vector3.UP * arc * 4.0 * (1.0 - 2.0 * k)
		if tangent.length() > 0.001 and absf(tangent.normalized().dot(Vector3.UP)) < 0.98:
			node.basis = Basis.looking_at(tangent.normalized(), Vector3.UP).scaled(node.basis.get_scale())


## A small glowing ball (fireballs, wormhole orbs, meteors).
func _glow_ball(color: Color, radius: float) -> MeshInstance3D:
	var ball := _sphere(color, radius)
	ball.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	ball.material_override.albedo_color = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8)
	return ball


func _trail_flames(node: Node3D) -> void:
	var trail := FxTextures.particles("flame", false, 30, 0.4, 0.3)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.05
	trail.spread = 180.0
	trail.initial_velocity_max = 0.2
	trail.gravity = Vector3(0.0, 0.8, 0.0)
	trail.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	trail.color_ramp = FxTextures.gradient([Color("fff36b"), Color("ff8a1f"), Color("c8341c")])
	trail.emitting = true
	node.add_child(trail)


func _trail_puffs(node: Node3D, color: Color, delay: float) -> void:
	var trail := FxTextures.particles("puff", false, 24, 0.6, 0.24)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.04
	trail.spread = 180.0
	trail.initial_velocity_max = 0.1
	trail.gravity = Vector3(0.0, 0.3, 0.0)
	trail.color_ramp = FxTextures.gradient([Color(color, 0.9), Color(color, 0.6)])
	trail.emitting = false
	node.add_child(trail)
	_after(delay, func() -> void: trail.emitting = true)


## A flat decal on the board under the effect (cracks, rings, shadows). `at` is effect-local.
func _decal(shape: String, color: Color, at: Vector3) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	d.mesh = plane
	d.material_override = FxTextures.decal_material(shape, color, false)
	d.position = at
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(d)
	return d


func _dust_puff(at: Vector3, size: float) -> void:
	var p := _burst("puff", false, 8, 0.7, 0.35 * size, [Color("e8dcc8", 0.0), Color("d8c8a8", 0.85), Color("c8b088", 0.0)], 0.4, 0.9, Vector3(0, 0.3, 0), 0.1)
	p.position = at


## A bright line from `a` to `b` (dashes, slashes, rays), fading out quickly once shown.
func _streak(a: Vector3, b: Vector3, width: float, color: Color, hold := 0.3) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	var q := QuadMesh.new()
	var length := (b - a).length()
	q.size = Vector2(width, maxf(length, 0.01))
	line.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = FxTextures.texture("streak")
	m.albedo_color = color
	m.render_priority = 3
	line.material_override = m
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	# Lay the quad's long (Y) axis along a→b, facing up so it reads from the play camera.
	var axis := (b - a).normalized() if length > 0.001 else Vector3.FORWARD
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var normal := side.cross(axis).normalized()
	line.basis = Basis(side, axis, normal)
	line.position = (a + b) * 0.5
	var t := create_tween()
	t.tween_interval(hold)
	t.tween_property(m, "albedo_color:a", 0.0, 0.2)
	return line


func _after(seconds: float, callback: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(callback)


# --- Building blocks --------------------------------------------------------------------------

## One-shot omnidirectional burst.
func _burst(shape: String, additive: bool, amount: int, lifetime: float, size: float, colors: Array,
		speed_min: float, speed_max: float, gravity: Vector3, radius := 0.1) -> CPUParticles3D:
	var p := FxTextures.particles(shape, additive, int(amount * clampf(_strength, 0.6, 1.4)), lifetime, size)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed_min * _strength
	p.initial_velocity_max = speed_max * _strength
	p.gravity = gravity
	FxTextures.random_angle(p, shape)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FxTextures.curve([Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.0)])
	p.color_ramp = FxTextures.gradient(colors)
	p.emitting = true
	add_child(p)
	return p


func _sphere(color: Color, radius: float, glow := true) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	s.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * (1.6 if glow else 1.0), color.g * (1.6 if glow else 1.0), color.b * (1.6 if glow else 1.0), 0.95)
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


## Expanding decal ring on the board under the effect. Alpha-blended, so it keeps its colour on
## light boards instead of washing out to white.
func _ground_ring(color: Color, reach: float, shape := "glow_ring", additive := false) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	ring.mesh = plane
	ring.material_override = FxTextures.decal_material(shape, Color(color, 0.95), additive)
	ring.position.y = -position.y + 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(reach, 1.0, reach) * _strength, 0.5).from(Vector3(0.2, 1.0, 0.2)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6).set_delay(0.3)
	return ring


func _flash(color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy * _strength
	light.omni_range = 3.2
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _stop_emitting(id: int) -> void:
	var p := instance_from_id(id) as CPUParticles3D
	if p != null:
		p.emitting = false
