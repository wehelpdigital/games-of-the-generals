class_name TauntFX
extends Node3D
## Taunts: cheeky things a player lobs into the opponent's half of the board (a cream pie, a
## rotten tomato, a cartoon poo...). A shop product. Each taunt is built from simple meshes in
## code, flies a lively arc from high behind the thrower's back row, lands on a random tile of the
## other half and splats: a flat cartoon splat on the board, a burst of bits and a comic word. It
## lingers a few seconds, then fades and frees itself. No physics bodies are added, so piece
## picking keeps working, and at most MAX_PER_BOARD taunts exist per board (oldest goes first).
##
##     TauntFX.throw(board, Ranks.WHITE, "cream_pie")

const INK := Color("1d1736")
const MAX_PER_BOARD := 3
const FLIGHT_TIME := 1.0
const LINGER := 3.2
const FADE := 0.6
const DECAL_Y := 0.03
const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

const STYLES := {
	"cream_pie": {"name": "Cream Pie", "rarity": "common", "collection": "toys_fun", "desc": "A classic pie to the face of their army.",
		"swatch": [Color("fff8ec"), Color("d9a25f"), Color("e8243c")]},
	"rotten_tomato": {"name": "Rotten Tomato", "rarity": "common", "collection": "toys_fun", "desc": "Boo! Get off the board!",
		"swatch": [Color("e04a32"), Color("9bb84a"), Color("ffd23f")]},
	"egg": {"name": "Egg Toss", "rarity": "common", "collection": "toys_fun", "desc": "Crack! Yolk all over their side.",
		"swatch": [Color("fffaf0"), Color("ffc21a"), Color("e8d9b8")]},
	"snowball": {"name": "Snowball", "rarity": "common", "collection": "ice_snow", "desc": "A cold, fluffy POOF.",
		"swatch": [Color("f4fbff"), Color("bfe3ff"), Color("6fb6ff")]},
	"water_balloon": {"name": "Water Balloon", "rarity": "common", "collection": "ocean_water", "desc": "Sploosh! Everybody gets wet.",
		"swatch": [Color("4fb8ff"), Color("bfe8ff"), Color("2f7fd8")]},
	"mud_ball": {"name": "Mud Ball", "rarity": "common", "collection": "nature_garden", "desc": "A big, sloppy SPLUT of mud.",
		"swatch": [Color("6b4a2b"), Color("8a6440"), Color("3f2a17")]},
	"banana_peel": {"name": "Banana Peel", "rarity": "common", "collection": "toys_fun", "desc": "Mind your step, General.",
		"swatch": [Color("ffe14d"), Color("c99a2e"), Color("6b4a2b")]},
	"poop": {"name": "Cartoon Poo", "rarity": "rare", "collection": "toys_fun", "desc": "PLOP. It has googly eyes. Flies included.",
		"swatch": [Color("8a5530"), Color("5a3218"), Color("9be15d")]},
	"slime": {"name": "Slime Blob", "rarity": "rare", "collection": "zombie_outbreak", "desc": "A jiggly green blob that stares back.",
		"swatch": [Color("7dff5a"), Color("3fbf2a"), Color("d8ffc8")]},
	"rubber_chicken": {"name": "Rubber Chicken", "rarity": "rare", "collection": "toys_fun", "desc": "SQUAWK! Feathers everywhere.",
		"swatch": [Color("ffd23f"), Color("ff3b3b"), Color("ff9f1c")]},
	"paint_bomb": {"name": "Paint Bomb", "rarity": "rare", "collection": "street_graffiti", "desc": "KA-SPLASH! Three colours of paint.",
		"swatch": [Color("ff4f8b"), Color("3d8bff"), Color("ffd23f"), Color("2d2a44")]},
	"stink_cloud": {"name": "Stink Cloud", "rarity": "rare", "collection": "zombie_outbreak", "desc": "A lingering green PEE-YEW.",
		"swatch": [Color("9be15d"), Color("cfff9a"), Color("5a8a2a")]},
	"kiss": {"name": "Blown Kiss", "rarity": "rare", "collection": "cute_candy", "desc": "MWAH! A lipstick kiss and floating hearts.",
		"swatch": [Color("ff3b6b"), Color("ff9ec7"), Color("e8243c")]},
	"confetti_cannon": {"name": "Confetti Popper", "rarity": "epic", "collection": "toys_fun", "desc": "TA-DA! Celebrate a little too early.",
		"swatch": [Color("ff4f8b"), Color("ffd23f"), Color("3d8bff"), Color("27c98f")]},
	"honk": {"name": "Clown Horn", "rarity": "epic", "collection": "toys_fun", "desc": "HONK! HONK! Right in their ear.",
		"swatch": [Color("ff3b3b"), Color("ffc93c"), Color("1d1736")]},
	"glitter_bomb": {"name": "Glitter Bomb", "rarity": "legendary", "collection": "magical_sparkle", "desc": "A gift box that explodes into glitter. BLING!",
		"swatch": [Color("ff8ec0"), Color("ffd23f"), Color("b05cff"), Color("6fe3ff")]},
	# Holidays.
	"candy_corn": {"name": "Candy Corn", "rarity": "common", "season": "halloween", "desc": "A handful of candy corn rains on their side. CRUNCH!",
		"swatch": [Color("ffffff"), Color("ff8a1f"), Color("ffd23f")]},
	"fruitcake": {"name": "Fruitcake", "rarity": "rare", "season": "christmas", "desc": "Nobody wants it. Now they have it. THUD.",
		"swatch": [Color("8a4a1e"), Color("e8344e"), Color("2f8f4e"), Color("fff6e8")]},
	"torotot": {"name": "Torotot", "rarity": "common", "season": "new_year", "desc": "A New Year party horn that won't stop tooting.",
		"swatch": [Color("ff3d7f"), Color("ffcf3f"), Color("3d8bff")]},
	"love_letter": {"name": "Love Letter", "rarity": "common", "season": "valentines", "desc": "A pink envelope sealed with a heart. XOXO!",
		"swatch": [Color("fff6f8"), Color("ff7aa0"), Color("ff2f5f")]},
	"red_envelope": {"name": "Red Envelope", "rarity": "rare", "season": "lunar_new_year", "desc": "A lucky red envelope that bursts into gold coins.",
		"swatch": [Color("e8282e"), Color("ffcf3f"), Color("7a0f0f")]},
	"pumpkin_pie": {"name": "Pumpkin Pie", "rarity": "common", "season": "thanksgiving", "desc": "A spiced pumpkin pie with a dollop of cream, straight to the face.",
		"swatch": [Color("e8892a"), Color("d9a25f"), Color("fff8ec")]},
	"beach_ball": {"name": "Beach Ball", "rarity": "common", "season": "summer", "desc": "BOING! A big striped beach ball bounces onto their side.",
		"swatch": [Color("ff4f5a"), Color("ffcf3f"), Color("3d8bff"), Color("ffffff")]},
	"palayok": {"name": "Palayok", "rarity": "rare", "season": "fiesta", "desc": "The fiesta clay pot breaks open and sweets spill everywhere.",
		"swatch": [Color("c8643a"), Color("8a3a1e"), Color("ff8ec0"), Color("ffcf3f")]},
	# Themed collections.
	"wave_splash": {"name": "Wave Splash", "rarity": "rare", "collection": "great_wave", "desc": "A curl of sea water crashes down. Foam everywhere!",
		"swatch": [Color("3f6aae"), Color("ffffff"), Color("8fc6ff")]},
	"cannonball": {"name": "Cannonball", "rarity": "epic", "collection": "treasure_seas", "desc": "An iron ball with a lit fuse. KA-THOOM! Scorch marks and smoke.",
		"swatch": [Color("2a2d40"), Color("ffb020"), Color("c9c2b0")]},
	"smoke_bomb": {"name": "Smoke Bomb", "rarity": "rare", "collection": "ninja_clan", "desc": "POOF! A purple cloud swallows the spot and throwing stars scatter.",
		"swatch": [Color("2a2350"), Color("8a7aa8"), Color("c9d2de")]},
}

## What each taunt shouts when it lands: [word, fill colour].
const WORDS := {
	"cream_pie": ["SPLAT!", Color("fff8ec")], "rotten_tomato": ["SPLAT!", Color("ff5a3c")],
	"egg": ["CRACK!", Color("ffd23f")], "snowball": ["POOF!", Color("cfeeff")],
	"water_balloon": ["SPLOOSH!", Color("6fd0ff")], "mud_ball": ["SPLUT!", Color("b07a48")],
	"banana_peel": ["SLIP!", Color("ffe14d")], "poop": ["PLOP!", Color("c08050")],
	"slime": ["SPLORCH!", Color("8dff6a")], "rubber_chicken": ["SQUAWK!", Color("ffd23f")],
	"paint_bomb": ["KA-SPLASH!", Color("ff4f8b")], "stink_cloud": ["PEE-YEW!", Color("b6f06a")],
	"kiss": ["MWAH!", Color("ff6f9f")], "confetti_cannon": ["TA-DA!", Color("ffd23f")],
	"honk": ["HONK!", Color("ffc93c")], "glitter_bomb": ["BLING!", Color("ffe066")],
	"candy_corn": ["CRUNCH!", Color("ff8a1f")], "fruitcake": ["THUD!", Color("c8803f")],
	"torotot": ["TOOOT!", Color("ff3d7f")], "love_letter": ["XOXO!", Color("ff7aa0")],
	"red_envelope": ["LUCKY!", Color("ffcf3f")], "pumpkin_pie": ["SPLAT!", Color("e8892a")],
	"beach_ball": ["BOING!", Color("3d8bff")], "palayok": ["CRASH!", Color("e07a4a")],
	"wave_splash": ["SPLASH!", Color("8fc6ff")], "cannonball": ["KA-THOOM!", Color("ffb020")], "smoke_bomb": ["POOF!", Color("b8a8ff")],
}

const PARTY := [Color("ff4f8b"), Color("ffd23f"), Color("3d8bff"), Color("27c98f"), Color("b05cff"), Color("ff9f1c")]

var target_local := Vector3.ZERO  ## Landing point (board-local); handy for tests and cameras.
var style := ""

var _rng := RandomNumberGenerator.new()
var _start := Vector3.ZERO
var _apex := 2.0
var _spin_axis := Vector3.RIGHT
var _spins := 1.5
var _proj: Node3D
var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _fade_mats: Array[StandardMaterial3D] = []
var _keep: Array[Node3D] = []  # Things left on the board that shrink away at the end.

static var _font: Font
static var _meshes: Dictionary = {}
static var _toons: Dictionary = {}
static var _hull: StandardMaterial3D


## Throws taunt `slug` from `from_side`'s end of the board into the other side's half.
static func throw(board: Node3D, from_side: String, slug: String, rng_seed := -1) -> void:
	if board == null or not is_instance_valid(board) or not board.is_inside_tree():
		return
	var live: Array = board.get_children().filter(func(c: Node) -> bool: return c is TauntFX and not c.is_queued_for_deletion())
	while live.size() >= MAX_PER_BOARD:
		(live.pop_front() as Node).queue_free()
	var fx := TauntFX.new()
	fx.name = "Taunt"
	if rng_seed >= 0:
		fx._rng.seed = rng_seed
	else:
		fx._rng.randomize()
	board.add_child(fx)
	fx._launch(from_side, slug if STYLES.has(slug) else "cream_pie")


# --- Flight -----------------------------------------------------------------------------------

func _launch(from_side: String, slug: String) -> void:
	style = slug
	var white := from_side == Ranks.WHITE
	var cell := _pick_target(white)
	target_local = Board3D.cell_to_local(cell) + Vector3(_rng.randf_range(-0.15, 0.15), 0.0, _rng.randf_range(-0.15, 0.15))
	_start = Vector3(_rng.randf_range(-2.5, 2.5), 3.4, 7.2 if white else -7.2)
	_apex = _rng.randf_range(1.5, 2.3)
	_spin_axis = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.0, 1.0))
	_spin_axis = _spin_axis.normalized() if _spin_axis.length() > 0.1 else Vector3.RIGHT
	_spins = _rng.randf_range(1.0, 2.0)

	_proj = _build_projectile(slug)
	add_child(_proj)
	_shadow_mat = _flat(Color(INK, 0.35), 0)
	_shadow = _mesh_node(_disc_mesh(), _shadow_mat)
	add_child(_shadow)
	_fly(0.0)
	var t := create_tween()
	t.tween_method(_fly, 0.0, 1.0, FLIGHT_TIME)
	t.tween_callback(_land)


## A random tile in the other side's half, preferring empty ones so the splat isn't hidden under
## a piece (uses the board's read-only `piece_at` lookup when it has one).
func _pick_target(thrown_by_white: bool) -> Vector2i:
	var half := int(Ranks.ROWS * 0.5)
	var rows := range(half, Ranks.ROWS) if thrown_by_white else range(0, half)
	var all: Array[Vector2i] = []
	var empty: Array[Vector2i] = []
	var board := get_parent()
	for y: int in rows:
		for x in Ranks.COLS:
			var cell := Vector2i(x, y)
			all.append(cell)
			if not board.has_method("piece_at") or board.call("piece_at", cell) == null:
				empty.append(cell)
	var pool := empty if not empty.is_empty() else all
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _fly(t: float) -> void:
	var p := _start.lerp(target_local + Vector3(0.0, 0.14, 0.0), t)
	p.y += sin(PI * t) * _apex
	_proj.position = p
	var stretch := 1.0 + 0.2 * sin(PI * t)
	var squash := 1.0 / sqrt(stretch)
	_proj.basis = Basis(_spin_axis, t * _spins * TAU) * Basis.from_scale(Vector3(squash, stretch, squash))
	var height := clampf(p.y / 4.0, 0.0, 1.0)
	_shadow.position = Vector3(p.x, 0.02, p.z)
	_shadow.scale = Vector3.ONE * lerpf(1.0, 0.4, height)
	_shadow_mat.albedo_color.a = lerpf(0.4, 0.1, height)


func _land() -> void:
	_shadow.queue_free()
	_word(WORDS[style][0], WORDS[style][1])
	match style:
		"cream_pie": _splat_cream_pie()
		"rotten_tomato": _splat_tomato()
		"egg": _splat_egg()
		"snowball": _splat_snowball()
		"water_balloon": _splat_water()
		"mud_ball": _splat_mud()
		"banana_peel": _splat_banana()
		"poop": _splat_poop()
		"slime": _splat_slime()
		"rubber_chicken": _splat_chicken()
		"paint_bomb": _splat_paint()
		"stink_cloud": _splat_stink()
		"kiss": _splat_kiss()
		"confetti_cannon": _splat_confetti()
		"honk": _splat_honk()
		"glitter_bomb": _splat_glitter()
		"candy_corn": _splat_candy_corn()
		"fruitcake": _splat_fruitcake()
		"torotot": _splat_torotot()
		"love_letter": _splat_love_letter()
		"red_envelope": _splat_red_envelope()
		"pumpkin_pie": _splat_pumpkin_pie()
		"beach_ball": _splat_beach_ball()
		"palayok": _splat_palayok()
		"wave_splash": _splat_wave()
		"cannonball": _splat_cannonball()
		"smoke_bomb": _splat_smoke_bomb()
	var t := create_tween()
	t.tween_interval(LINGER)
	t.tween_callback(_fade_out)


func _fade_out() -> void:
	var t := create_tween().set_parallel(true)
	for m in _fade_mats:
		t.tween_property(m, "albedo_color:a", 0.0, FADE)
	for node in _keep:
		if is_instance_valid(node):
			t.tween_property(node, "scale", Vector3.ONE * 0.01, FADE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)


## The projectile stops flying and rests on the board as an object (peel, chicken, horn...).
func _rest_projectile(rest: Basis, lift := 0.08, size := 1.0) -> void:
	_proj.basis = rest
	_proj.scale = Vector3.ONE * size
	_proj.position = target_local + Vector3(0.0, lift, 0.0)
	_keep.append(_proj)
	var t := create_tween()
	t.tween_property(_proj, "position:y", lift + 0.22, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_proj, "position:y", lift, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _drop_projectile() -> void:
	_proj.queue_free()
	_proj = null


# --- Splats -----------------------------------------------------------------------------------

func _splat_cream_pie() -> void:
	_drop_projectile()
	_decal(Color("fff8ec"), 0.44, 9, 6, 0.18)
	_dots(Color("d9a25f"), 7, 0.36, Vector2(0.025, 0.045))
	var cherry := Node3D.new()
	_part(cherry, _sphere(0.065), Color("e8243c"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.18, 0.8)
	_part(cherry, _cyl(0.008, 0.008, 0.1), Color("5a7a2a"), Vector3(0.02, 0.08, 0.0), Vector3(0.0, 0.0, -0.4), Vector3.ONE, 0.0)
	cherry.position = target_local + Vector3(0.05, 0.09, -0.03)
	add_child(cherry)
	_keep.append(cherry)
	_particles(target_local, 18, _circle_mesh(0.05), [Color("fff8ec"), Color("ffe8c8")], Vector2(1.8, 3.4))


func _splat_tomato() -> void:
	_drop_projectile()
	_decal(Color("e04a32"), 0.42, 8, 7, 0.2)
	_dots(Color("ffd23f"), 9, 0.3, Vector2(0.018, 0.028))
	_dots(Color("9bb84a"), 4, 0.3, Vector2(0.03, 0.05))
	_particles(target_local, 16, _circle_mesh(0.045), [Color("e04a32"), Color("ff6a4a"), Color("9bb84a")], Vector2(1.8, 3.6))


func _splat_egg() -> void:
	_drop_projectile()
	_decal(Color(1.0, 1.0, 0.95, 0.9), 0.4, 5, 3, 0.14)
	_decal(Color("ffc21a"), 0.15, 6, 0, 0.03, Vector3(0.05, 0.004, -0.03), true, true)
	_particles(target_local, 10, _shard_mesh(), [Color("fffaf0"), Color("efe2c4")], Vector2(1.5, 3.2), {"spin": 360.0})


func _splat_snowball() -> void:
	_drop_projectile()
	_decal(Color("f4fbff"), 0.38, 10, 5, 0.16)
	var pile := Node3D.new()
	_part(pile, _sphere(0.16), Color("f7fbff"), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.45, 1.1), 1.08, 0.3)
	_part(pile, _sphere(0.08), Color("f7fbff"), Vector3(0.12, 0.02, 0.06), Vector3.ZERO, Vector3(1.0, 0.6, 1.0), 1.12, 0.3)
	pile.position = target_local + Vector3(0.0, 0.03, 0.0)
	add_child(pile)
	_keep.append(pile)
	_particles(target_local, 20, _circle_mesh(0.04), [Color.WHITE, Color("dff1ff")], Vector2(1.2, 2.6), {"gravity": Vector3(0.0, -4.0, 0.0), "lifetime": 1.2})


func _splat_water() -> void:
	_drop_projectile()
	_decal(Color(0.35, 0.75, 1.0, 0.6), 0.52, 8, 8, 0.2)
	_decal(Color(0.75, 0.92, 1.0, 0.55), 0.2, 5, 0, 0.12, Vector3(-0.08, 0.004, -0.06), false, false)
	_particles(target_local, 24, _circle_mesh(0.04), [Color("6fd0ff"), Color("bfe8ff"), Color("2f9ff0")], Vector2(2.0, 4.2), {"spread": 55.0})
	_particles(target_local, 6, _shard_mesh(), [Color("2f9ff0")], Vector2(1.0, 2.0), {"spin": 360.0})


func _splat_mud() -> void:
	_drop_projectile()
	_decal(Color("6b4a2b"), 0.46, 10, 8, 0.26)
	_dots(Color("3f2a17"), 8, 0.35, Vector2(0.03, 0.06))
	_particles(target_local, 16, _circle_mesh(0.05), [Color("6b4a2b"), Color("8a6440")], Vector2(1.6, 3.2))


func _splat_banana() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU), 0.05, 1.7)
	_particles(target_local + Vector3(0.0, 0.45, 0.0), 5, _star_mesh(0.07), [Color("ffe14d"), Color.WHITE], Vector2(0.4, 0.8),
		{"gravity": Vector3.ZERO, "lifetime": 1.4, "spin": 180.0})


func _splat_poop() -> void:
	_drop_projectile()
	_decal(Color("7a4a28"), 0.36, 6, 5, 0.22)
	var mini := _build_projectile("poop")
	mini.scale = Vector3.ONE * 0.95
	mini.position = target_local + Vector3(0.0, 0.06, 0.0)
	mini.rotation.y = PI if target_local.z < 0.0 else 0.0  # Googly eyes stare at the victim (their camera side).
	add_child(mini)
	_keep.append(mini)
	_flies(target_local + Vector3(0.0, 0.42, 0.0))
	_particles(target_local + Vector3(0.0, 0.2, 0.0), 8, _circle_mesh(0.07), [Color(0.6, 0.88, 0.36, 0.7)], Vector2(0.3, 0.7),
		{"gravity": Vector3(0.0, 0.6, 0.0), "lifetime": 1.8, "explosiveness": 0.3})


func _splat_slime() -> void:
	_drop_projectile()
	_decal(Color(0.49, 1.0, 0.35, 0.75), 0.46, 7, 6, 0.24)
	# A pair of googly eyes left floating in the puddle.
	var eyes := Node3D.new()
	for x in [-0.08, 0.08]:
		_part(eyes, _sphere(0.06), Color.WHITE, Vector3(x, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), 1.12, 0.6)
		_part(eyes, _sphere(0.03), INK, Vector3(x + _rng.randf_range(-0.015, 0.015), 0.025, 0.02), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), 0.0, 0.0)
	eyes.position = target_local + Vector3(0.0, 0.05, 0.0)
	add_child(eyes)
	_keep.append(eyes)
	for i in 3:
		var bubble := _mesh_node(_sphere(0.04), _toon(Color(0.78, 1.0, 0.7, 0.8), 0.8))
		bubble.position = target_local + Vector3(_rng.randf_range(-0.25, 0.25), 0.04, _rng.randf_range(-0.25, 0.25))
		add_child(bubble)
		_keep.append(bubble)
		var t := create_tween().set_loops(4)
		t.tween_property(bubble, "scale", Vector3.ONE * 1.4, 0.35 + i * 0.1)
		t.tween_property(bubble, "scale", Vector3.ONE * 0.8, 0.35 + i * 0.1)
	_particles(target_local, 16, _circle_mesh(0.045), [Color("7dff5a"), Color("3fbf2a")], Vector2(1.6, 3.4))


func _splat_chicken() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5), 0.13, 1.4)
	_decal(Color(0.85, 0.82, 0.75, 0.35), 0.26, 6, 0, 0.12, Vector3.ZERO, false, false)
	_particles(target_local + Vector3(0.0, 0.2, 0.0), 12, _feather_mesh(), [Color.WHITE, Color("ffe066")], Vector2(1.0, 2.2),
		{"gravity": Vector3(0.0, -1.2, 0.0), "lifetime": 1.8, "spin": 240.0, "damping": 1.5})


func _splat_paint() -> void:
	_drop_projectile()
	var colors := [Color("ff4f8b"), Color("3d8bff"), Color("ffd23f")]
	for i in 3:
		var a := TAU * i / 3.0 + _rng.randf() * 0.6
		_decal(colors[i], 0.28, 7, 4, 0.22, Vector3(cos(a) * 0.15, 0.002 * i, sin(a) * 0.15))
	_particles(target_local, 24, _circle_mesh(0.045), colors, Vector2(2.0, 3.8))


func _splat_stink() -> void:
	_drop_projectile()
	_decal(Color(0.6, 0.88, 0.36, 0.35), 0.46, 6, 3, 0.2, Vector3.ZERO, false, false)
	var cloud := Node3D.new()
	for i in 4:
		var a := TAU * i / 4.0
		var puff := _mesh_node(_sphere(0.16 + 0.03 * (i % 2)), _toon(Color(0.62, 0.9, 0.38, 0.55), 0.2))
		puff.position = Vector3(cos(a) * 0.14, 0.2 + 0.05 * (i % 2), sin(a) * 0.14)
		cloud.add_child(puff)
	cloud.position = target_local
	add_child(cloud)
	_keep.append(cloud)
	var wobble := create_tween().set_loops(5)
	wobble.tween_property(cloud, "scale", Vector3(1.1, 0.9, 1.1), 0.35).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(cloud, "scale", Vector3(0.95, 1.08, 0.95), 0.35).set_trans(Tween.TRANS_SINE)
	_flies(target_local + Vector3(0.0, 0.55, 0.0))
	_particles(target_local + Vector3(0.0, 0.3, 0.0), 10, _wave_mesh(), [Color("9be15d"), Color("cfff9a")], Vector2(0.3, 0.6),
		{"gravity": Vector3(0.0, 0.8, 0.0), "lifetime": 2.0, "explosiveness": 0.2, "spread": 40.0})


func _splat_kiss() -> void:
	_drop_projectile()
	# A lipstick mark: cupid's-bow upper lip, fuller lower lip, upright for the victim's camera.
	var up := 1.0 if target_local.z < 0.0 else -1.0
	var lips := _smooth(PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.32, 0.2), Vector2(-0.14, 0.25), Vector2(0.0, 0.13),
		Vector2(0.14, 0.25), Vector2(0.32, 0.2), Vector2(0.5, 0.0), Vector2(0.32, -0.17), Vector2(0.0, -0.26), Vector2(-0.32, -0.17)]), 2)
	var mouth := PackedVector2Array()
	for i in 9:
		var x := -0.44 + 0.88 * i / 8.0
		mouth.append(Vector2(x, 0.015 - 0.04 * (1.0 - pow(x / 0.44, 2.0))))
	for i in range(8, -1, -1):
		var x := -0.44 + 0.88 * i / 8.0
		mouth.append(Vector2(x, -0.015 - 0.04 * (1.0 - pow(x / 0.44, 2.0))))
	var at := target_local + Vector3(0.0, DECAL_Y, 0.0)
	_decal_node(_poly_xz(lips, 0.55, up, 0.035), INK, at + Vector3(0.0, -0.004, 0.0), 1, Vector3.ONE, 0.0)
	_decal_node(_poly_xz(lips, 0.55, up), Color("e8243c"), at, 2, Vector3.ONE, 0.0)
	_decal_node(_poly_xz(mouth, 0.55, up), Color("8f0f26"), at + Vector3(0.0, 0.003, 0.0), 3, Vector3.ONE, 0.0)
	var shine := _smooth(PackedVector2Array([Vector2(-0.12, -0.12), Vector2(0.06, -0.1), Vector2(0.12, -0.15), Vector2(-0.06, -0.17)]), 2)
	_decal_node(_poly_xz(shine, 0.55, up), Color(1.0, 0.7, 0.75, 0.85), at + Vector3(0.0, 0.004, 0.0), 4, Vector3.ONE, 0.0)
	_particles(target_local + Vector3(0.0, 0.15, 0.0), 10, _heart_mesh(0.09), [Color("ff3b6b"), Color("ff9ec7"), Color("ff6f9f")], Vector2(0.6, 1.2),
		{"gravity": Vector3(0.0, 0.7, 0.0), "lifetime": 1.8, "explosiveness": 0.5})


func _splat_confetti() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.42), 0.16, 1.4)
	for i in 3:
		var streamer := _mesh_node(_box(Vector3(0.62, 0.012, 0.07)), _flat(PARTY[i], 2))
		streamer.position = target_local + Vector3(_rng.randf_range(-0.12, 0.12), DECAL_Y + 0.006 * i, _rng.randf_range(-0.2, 0.2))
		streamer.rotation.y = _rng.randf() * TAU
		add_child(streamer)
	_particles(target_local + Vector3(0.0, 0.2, 0.0), 36, _confetti_mesh(), PARTY, Vector2(2.4, 4.4),
		{"gravity": Vector3(0.0, -2.5, 0.0), "lifetime": 2.0, "spin": 540.0, "spread": 35.0, "damping": 1.2})


func _splat_honk() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU), 0.2, 1.5)
	_word("HONK!", WORDS["honk"][1], 0.75, target_local + Vector3(0.35, 0.15, 0.0))
	for delay in [0.0, 0.75]:
		var ring := _mesh_node(_torus(0.2, 0.24), _flat(Color(1.0, 0.86, 0.3, 0.9), 3))
		ring.position = target_local + Vector3(0.0, 0.12, 0.0)
		ring.scale = Vector3.ONE * 0.3
		add_child(ring)
		var mat: StandardMaterial3D = ring.material_override
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
		t.tween_callback(ring.queue_free)
		var squeeze := create_tween()
		squeeze.tween_interval(delay)
		squeeze.tween_property(_proj, "scale", Vector3(1.25, 0.8, 1.25) * 1.5, 0.08)
		squeeze.tween_property(_proj, "scale", Vector3.ONE * 1.5, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _splat_glitter() -> void:
	_drop_projectile()
	_decal(Color(1.0, 0.56, 0.75, 0.45), 0.4, 8, 4, 0.18, Vector3.ZERO, false, false)
	for c in PARTY:
		_dots(c, 4, 0.4, Vector2(0.015, 0.025))
	_particles(target_local + Vector3(0.0, 0.1, 0.0), 36, _star_mesh(0.06), [Color("ffe066"), Color("ff8ec0"), Color("b05cff"), Color("6fe3ff"), Color.WHITE],
		Vector2(1.5, 3.6), {"gravity": Vector3(0.0, -1.5, 0.0), "lifetime": 1.8, "spin": 360.0, "spread": 80.0})


# --- Projectiles ------------------------------------------------------------------------------

func _build_projectile(slug: String) -> Node3D:
	var root := Node3D.new()
	match slug:
		"cream_pie":
			_part(root, _cyl(0.27, 0.21, 0.12), Color("d9a25f"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.07)
			_part(root, _sphere(0.25), Color("fff8ec"), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0), 1.05, 0.3)
			for i in 6:
				var a := TAU * i / 6.0
				_part(root, _sphere(0.06), Color("fff8ec"), Vector3(cos(a) * 0.19, 0.11, sin(a) * 0.19), Vector3.ZERO, Vector3.ONE, 1.15, 0.3)
			_part(root, _sphere(0.06), Color("e8243c"), Vector3(0.0, 0.2, 0.0), Vector3.ZERO, Vector3.ONE, 1.18, 0.8)
		"rotten_tomato":
			_part(root, _sphere(0.2), Color("e04a32"), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.0), 1.07, 0.6)
			for i in 5:
				var a := TAU * i / 5.0
				_part(root, _sphere(0.07), Color("5f7a2a"), Vector3(cos(a) * 0.07, 0.16, sin(a) * 0.07), Vector3(0.0, -a, 0.3),
					Vector3(1.6, 0.3, 0.6), 1.1)
			for d in [Vector3(0.7, 0.3, 0.6), Vector3(-0.6, -0.2, 0.75), Vector3(0.1, -0.5, -0.85)]:
				_part(root, _sphere(0.05), Color("9bb84a"), d.normalized() * 0.18, Vector3.ZERO, Vector3(1.0, 1.0, 0.4), 0.0)
		"egg":
			_part(root, _sphere(0.13), Color("fffaf0"), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.35, 1.0), 1.08, 0.6)
		"snowball":
			_part(root, _sphere(0.17), Color("f7fbff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.07, 0.3)
			_part(root, _sphere(0.08), Color("f7fbff"), Vector3(0.11, 0.08, 0.05), Vector3.ZERO, Vector3.ONE, 1.1, 0.3)
		"water_balloon":
			_part(root, _sphere(0.2), Color(0.31, 0.72, 1.0, 0.82), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.12, 1.0), 1.06, 0.9)
			_part(root, _cyl(0.0, 0.045, 0.07), Color("2f7fd8"), Vector3(0.0, -0.25, 0.0), Vector3(PI, 0.0, 0.0), Vector3.ONE, 1.15)
			_part(root, _sphere(0.028), Color("2f7fd8"), Vector3(0.0, -0.3, 0.0), Vector3.ZERO, Vector3.ONE, 1.15)
		"mud_ball":
			for lump in [[Vector3.ZERO, 0.17], [Vector3(0.1, 0.07, 0.04), 0.1], [Vector3(-0.09, -0.04, 0.08), 0.11], [Vector3(0.02, -0.1, -0.09), 0.09]]:
				_part(root, _sphere(lump[1]), Color("6b4a2b"), lump[0], Vector3.ZERO, Vector3.ONE, 1.08, 0.2)
			_part(root, _sphere(0.06), Color("8a6440"), Vector3(-0.05, 0.12, -0.04), Vector3.ZERO, Vector3.ONE, 1.12, 0.2)
		"banana_peel":
			_part(root, _cyl(0.035, 0.045, 0.09), Color("c99a2e"), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3.ONE, 1.12)
			for i in 3:
				var a := TAU * i / 3.0
				var flap := Node3D.new()
				flap.rotation = Vector3(0.0, a, 0.0)
				root.add_child(flap)
				_part(flap, _capsule(0.06, 0.36), Color("ffe14d"), Vector3(0.16, -0.01, 0.0), Vector3(0.0, 0.0, PI * 0.5 - 0.25),
					Vector3(1.0, 1.0, 0.45), 1.08, 0.5)
				_part(flap, _sphere(0.035), Color("6b4a2b"), Vector3(0.31, -0.05, 0.0), Vector3.ZERO, Vector3.ONE, 0.0)
		"poop":
			_part(root, _cyl(0.17, 0.2, 0.16), Color("8a5530"), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.5)
			_part(root, _torus(0.07, 0.23), Color("8a5530"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.05, 0.5)
			_part(root, _torus(0.055, 0.175), Color("8a5530"), Vector3(0.0, 0.09, 0.0), Vector3.ZERO, Vector3.ONE, 1.06, 0.5)
			_part(root, _torus(0.04, 0.12), Color("8a5530"), Vector3(0.0, 0.17, 0.0), Vector3.ZERO, Vector3.ONE, 1.07, 0.5)
			_part(root, _cyl(0.0, 0.075, 0.13), Color("8a5530"), Vector3(0.02, 0.25, 0.0), Vector3(0.0, 0.0, -0.35), Vector3.ONE, 1.1, 0.5)
			for x in [-0.06, 0.06]:
				_part(root, _sphere(0.055), Color.WHITE, Vector3(x, 0.11, 0.165), Vector3.ZERO, Vector3.ONE, 1.12, 0.6)
				_part(root, _sphere(0.027), INK, Vector3(x * 1.1, 0.105, 0.215), Vector3.ZERO, Vector3.ONE, 0.0, 0.0)
		"slime":
			_part(root, _sphere(0.19), Color(0.49, 1.0, 0.35, 0.8), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.9, 1.0), 1.06, 0.9)
			for x in [-0.07, 0.07]:
				_part(root, _sphere(0.05), Color.WHITE, Vector3(x, 0.05, 0.16), Vector3.ZERO, Vector3.ONE, 1.12, 0.6)
				_part(root, _sphere(0.025), INK, Vector3(x, 0.05, 0.205), Vector3.ZERO, Vector3.ONE, 0.0, 0.0)
			_part(root, _cyl(0.0, 0.05, 0.1), Color(0.49, 1.0, 0.35, 0.8), Vector3(0.05, -0.2, 0.0), Vector3(PI, 0.0, 0.0), Vector3.ONE, 1.1, 0.9)
		"rubber_chicken":
			_part(root, _capsule(0.085, 0.42), Color("ffd23f"), Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Vector3.ONE, 1.07, 0.5)
			_part(root, _sphere(0.075), Color("ffd23f"), Vector3(0.24, 0.08, 0.0), Vector3.ZERO, Vector3.ONE, 1.1, 0.5)
			for i in 3:
				_part(root, _sphere(0.03), Color("ff3b3b"), Vector3(0.21 + i * 0.03, 0.16, 0.0), Vector3.ZERO, Vector3.ONE, 1.15, 0.5)
			_part(root, _cyl(0.0, 0.032, 0.09), Color("ff9f1c"), Vector3(0.34, 0.07, 0.0), Vector3(0.0, 0.0, -PI * 0.5), Vector3.ONE, 1.12)
			for z in [-0.04, 0.04]:
				_part(root, _sphere(0.014), INK, Vector3(0.28, 0.11, z * 1.4), Vector3.ZERO, Vector3.ONE, 0.0, 0.0)
				_part(root, _cyl(0.012, 0.012, 0.14), Color("ff9f1c"), Vector3(-0.02, -0.13, z), Vector3.ZERO, Vector3.ONE, 1.2)
			_part(root, _cyl(0.0, 0.06, 0.12), Color("ffd23f"), Vector3(-0.26, 0.05, 0.0), Vector3(0.0, 0.0, PI * 0.5 + 0.5), Vector3.ONE, 1.1)
		"paint_bomb":
			_part(root, _sphere(0.18), Color("2d2a44"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.07, 0.7)
			_part(root, _torus(0.17, 0.19), Color("ffd23f"), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), Vector3.ONE, 0.0, 0.5)
			var drips := [[Vector3(0.6, 0.5, 0.6), Color("ff4f8b")], [Vector3(-0.7, 0.3, 0.6), Color("3d8bff")], [Vector3(0.1, 0.6, -0.8), Color("ffd23f")]]
			for d in drips:
				_part(root, _sphere(0.055), d[1], (d[0] as Vector3).normalized() * 0.17, Vector3.ZERO, Vector3(1.0, 1.0, 0.5), 0.0, 0.6)
			_part(root, _cyl(0.016, 0.016, 0.14), Color("8a6440"), Vector3(0.03, 0.22, 0.0), Vector3(0.0, 0.0, -0.4), Vector3.ONE, 1.2)
			_part(root, _sphere(0.04), Color(1.6, 1.2, 0.4), Vector3(0.07, 0.3, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		"stink_cloud":
			for i in 5:
				var a := TAU * i / 5.0
				_part(root, _sphere(0.1 + 0.02 * (i % 2)), Color(0.62, 0.9, 0.38, 0.88), Vector3(cos(a) * 0.11, 0.04 * (i % 2), sin(a) * 0.11),
					Vector3.ZERO, Vector3.ONE, 1.08, 0.2)
			_part(root, _sphere(0.13), Color(0.62, 0.9, 0.38, 0.88), Vector3(0.0, 0.06, 0.0), Vector3.ZERO, Vector3.ONE, 1.06, 0.2)
		"kiss":
			_part(root, _sphere(0.115), Color("ff3b6b"), Vector3(-0.085, 0.05, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.6), 1.08, 0.8)
			_part(root, _sphere(0.115), Color("ff3b6b"), Vector3(0.085, 0.05, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.6), 1.08, 0.8)
			_part(root, _cyl(0.185, 0.0, 0.24), Color("ff3b6b"), Vector3(0.0, -0.09, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.6), 1.07, 0.8)
		"confetti_cannon":
			var bands := [Color("ff4f8b"), Color("ffd23f"), Color("3d8bff")]
			for i in 3:
				var r0 := 0.03 + i * 0.04
				_part(root, _cyl(r0 + 0.04, r0, 0.11), bands[i], Vector3(0.0, -0.11 + i * 0.11, 0.0), Vector3.ZERO, Vector3.ONE, 1.07, 0.4)
			for i in 4:
				var a := TAU * i / 4.0
				_part(root, _box(Vector3(0.05, 0.08, 0.012)), PARTY[i + 1], Vector3(cos(a) * 0.07, 0.2, sin(a) * 0.07), Vector3(0.3, a, 0.2), Vector3.ONE, 0.0)
		"honk":
			_part(root, _sphere(0.11), Color("ff3b3b"), Vector3(-0.2, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 1.1, 1.0), 1.08, 0.7)
			_part(root, _cyl(0.03, 0.03, 0.16), Color("ffc93c"), Vector3(-0.06, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Vector3.ONE, 1.15, 0.9)
			_part(root, _cyl(0.14, 0.035, 0.2), Color("ffc93c"), Vector3(0.11, 0.0, 0.0), Vector3(0.0, 0.0, -PI * 0.5), Vector3.ONE, 1.06, 0.9)
		"glitter_bomb":
			_part(root, _box(Vector3(0.28, 0.28, 0.28)), Color("ff8ec0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.06, 0.4)
			_part(root, _box(Vector3(0.295, 0.295, 0.07)), Color("ffd23f"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.7)
			_part(root, _box(Vector3(0.07, 0.295, 0.295)), Color("ffd23f"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.7)
			for s in [-1.0, 1.0]:
				_part(root, _sphere(0.065), Color("ffd23f"), Vector3(0.06 * s, 0.17, 0.0), Vector3(0.0, 0.0, -0.5 * s), Vector3(1.3, 0.75, 0.8), 1.12, 0.7)
		"candy_corn":
			_part(root, _cyl(0.0, 0.07, 0.08), Color("ffffff"), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3.ONE, 1.1, 0.4)
			_part(root, _cyl(0.07, 0.11, 0.08), Color("ff8a1f"), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3.ONE, 1.08, 0.4)
			_part(root, _cyl(0.11, 0.13, 0.07), Color("ffd23f"), Vector3(0.0, -0.06, 0.0), Vector3.ZERO, Vector3.ONE, 1.07, 0.4)
		"fruitcake":
			_part(root, _box(Vector3(0.36, 0.17, 0.2)), Color("8a4a1e"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.06, 0.3)
			_part(root, _box(Vector3(0.37, 0.04, 0.21)), Color("fff6e8"), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.3)
			for bit in [[Vector3(-0.1, 0.02, 0.105), Color("e8344e")], [Vector3(0.06, -0.04, 0.105), Color("2f8f4e")], [Vector3(0.13, 0.03, 0.105), Color("e8344e")],
					[Vector3(-0.04, -0.05, -0.105), Color("2f8f4e")], [Vector3(0.0, 0.13, 0.03), Color("e8344e")]]:
				_part(root, _sphere(0.025), bit[1], bit[0], Vector3.ZERO, Vector3.ONE, 0.0, 0.6)
		"torotot":
			var bands := [Color("ff3d7f"), Color("ffcf3f"), Color("3d8bff"), Color("27c98f")]
			for i in 4:
				var r0 := 0.025 + i * 0.03
				_part(root, _cyl(r0 + 0.03, r0, 0.09), bands[i], Vector3(0.0, -0.13 + i * 0.09, 0.0), Vector3.ZERO, Vector3.ONE, 1.07, 0.5)
			_part(root, _cyl(0.025, 0.025, 0.08), Color("ffffff"), Vector3(0.0, -0.21, 0.0), Vector3.ZERO, Vector3.ONE, 1.12, 0.3)
		"love_letter":
			_part(root, _box(Vector3(0.36, 0.03, 0.24)), Color("fff6f8"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.08, 0.3)
			_part(root, _box(Vector3(0.25, 0.012, 0.25)), Color("ffd6e4"), Vector3(0.0, 0.02, -0.03), Vector3(0.0, PI / 4.0, 0.0), Vector3(1.0, 1.0, 0.6), 0.0, 0.3)
			_part(root, _heart_mesh(0.06), Color("ff2f5f"), Vector3(0.0, 0.03, 0.0), Vector3(-PI / 2.0, 0.0, 0.0), Vector3.ONE, 0.0, 0.6)
		"red_envelope":
			_part(root, _box(Vector3(0.22, 0.03, 0.34)), Color("e8282e"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.08, 0.5)
			_part(root, _box(Vector3(0.23, 0.035, 0.03)), Color("ffcf3f"), Vector3(0.0, 0.0, 0.1), Vector3.ZERO, Vector3.ONE, 0.0, 0.8)
			_part(root, _cyl(0.05, 0.05, 0.02), Color("ffcf3f"), Vector3(0.0, 0.02, -0.03), Vector3.ZERO, Vector3.ONE, 0.0, 0.8)
		"pumpkin_pie":
			_part(root, _cyl(0.27, 0.21, 0.12), Color("d9a25f"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.07)
			_part(root, _cyl(0.24, 0.24, 0.04), Color("e8892a"), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.5)
			_part(root, _sphere(0.08), Color("fff8ec"), Vector3(0.0, 0.11, 0.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0), 1.12, 0.3)
		"beach_ball":
			_part(root, _sphere(0.22), Color("ffffff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.06, 0.6)
			var stripes := [Color("ff4f5a"), Color("ffcf3f"), Color("3d8bff")]
			for i in 3:
				_part(root, _sphere(0.222), stripes[i], Vector3.ZERO, Vector3(0.0, TAU * i / 3.0, 0.0), Vector3(0.35, 1.0, 1.0), 0.0, 0.6)
			_part(root, _sphere(0.05), Color("ffffff"), Vector3(0.0, 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), 0.0, 0.6)
		"palayok":
			_part(root, _sphere(0.2), Color("c8643a"), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.0), 1.06, 0.3)
			_part(root, _torus(0.08, 0.12), Color("8a3a1e"), Vector3(0.0, 0.16, 0.0), Vector3.ZERO, Vector3.ONE, 1.1, 0.3)
			for i in 6:
				var a := TAU * i / 6.0
				_part(root, _box(Vector3(0.05, 0.02, 0.02)), Color("ffffff"), Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2), Vector3(0.0, -a, 0.0), Vector3.ONE, 0.0, 0.2)
		"wave_splash":
			_part(root, _sphere(0.2), Color("3f6aae"), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.9, 1.0), 1.07, 0.8)
			_part(root, _torus(0.12, 0.17), Color("ffffff"), Vector3(0.0, 0.1, 0.0), Vector3(0.3, 0.0, 0.0), Vector3.ONE, 1.1, 0.3)
			for i in 4:
				var a := TAU * i / 4.0
				_part(root, _sphere(0.05), Color("ffffff"), Vector3(cos(a) * 0.15, 0.16, sin(a) * 0.15), Vector3.ZERO, Vector3.ONE, 1.15, 0.3)
		"cannonball":
			_part(root, _sphere(0.18), Color("2a2d40"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.07, 0.8)
			_part(root, _cyl(0.016, 0.016, 0.12), Color("c8a070"), Vector3(0.02, 0.22, 0.0), Vector3(0.0, 0.0, -0.3), Vector3.ONE, 1.2)
			_part(root, _sphere(0.035), Color(1.8, 1.2, 0.3), Vector3(0.04, 0.29, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		"smoke_bomb":
			_part(root, _sphere(0.15), Color("2a2350"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.08, 0.6)
			_part(root, _torus(0.14, 0.16), Color("8a7aa8"), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), Vector3.ONE, 0.0, 0.4)
			_part(root, _cyl(0.014, 0.014, 0.1), Color("c8a070"), Vector3(0.0, 0.18, 0.0), Vector3.ZERO, Vector3.ONE, 1.2)
			_part(root, _sphere(0.03), Color(1.8, 1.2, 0.3), Vector3(0.0, 0.24, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
	return root


# --- Effects helpers --------------------------------------------------------------------------

## A flat cartoon splat on the board around the landing point, with an ink rim and a wet highlight.
func _decal(color: Color, radius: float, lumps: int, drops: int, wobble: float, offset := Vector3.ZERO,
		ink := true, highlight := true, stretch := Vector3.ONE, rot := -1.0) -> void:
	var shape := _splat_shape(radius, lumps, drops, wobble)
	var base := target_local + offset
	var spin := _rng.randf() * TAU if rot < 0.0 else rot
	if ink:
		_decal_node(_splat_mesh(shape, 0.035), Color(INK, color.a), base + Vector3(0.0, DECAL_Y - 0.004, 0.0), 1, stretch, spin)
	_decal_node(_splat_mesh(shape, 0.0), color, base + Vector3(0.0, DECAL_Y, 0.0), 2, stretch, spin)
	if highlight:
		var shine := Color(color.lightened(0.45), color.a * 0.8)
		var node := _decal_node(_splat_mesh(shape, 0.0), shine, base + Vector3(-radius * 0.22, DECAL_Y + 0.003, -radius * 0.2), 3, stretch * 0.38, spin)
		node.scale.y = 1.0


## A sprinkle of tiny flat dots (seeds, crumbs, glitter) inside the splat.
func _dots(color: Color, count: int, spread: float, size_range: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * spread
		_add_circle(st, Vector2(cos(a), sin(a)) * d, _rng.randf_range(size_range.x, size_range.y), 10)
	_decal_node(st.commit(), color, target_local + Vector3(0.0, DECAL_Y + 0.006, 0.0), 4, Vector3.ONE, 0.0)


func _decal_node(mesh: Mesh, color: Color, at: Vector3, priority: int, stretch: Vector3, spin: float) -> MeshInstance3D:
	var node := _mesh_node(mesh, _flat(color, priority))
	node.position = at
	node.rotation.y = spin
	node.scale = Vector3(stretch.x, 1.0, stretch.z)
	add_child(node)
	return node


func _splat_shape(radius: float, lumps: int, drops: int, wobble: float) -> Dictionary:
	var p1 := _rng.randf() * TAU
	var p2 := _rng.randf() * TAU
	var outline := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var r := radius * (1.0 + wobble * sin(lumps * a + p1) + wobble * 0.45 * sin((lumps + 3) * a + p2))
		outline.append(Vector2(cos(a), sin(a)) * r)
	var blobs: Array = []
	for i in drops:
		var a := _rng.randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * radius * _rng.randf_range(1.15, 1.7), radius * _rng.randf_range(0.07, 0.15)])
	return {"outline": outline, "drops": blobs}


func _splat_mesh(shape: Dictionary, grow: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: PackedVector2Array = shape["outline"]
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		_add_tri(st, Vector2.ZERO, a + a.normalized() * grow, b + b.normalized() * grow)
	for drop: Array in shape["drops"]:
		_add_circle(st, drop[0], drop[1] + grow, 12)
	return st.commit()


## A flat polygon on the board (2D y maps to ±Z by `up`), fanned from its centroid; `grow` pushes
## the outline outwards for an ink rim.
func _poly_xz(points: PackedVector2Array, size: float, up: float, grow := 0.0) -> ArrayMesh:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		a = (a + (a - center).normalized() * grow / size) * size
		b = (b + (b - center).normalized() * grow / size) * size
		var c := center * size
		_add_tri(st, Vector2(c.x, c.y * up), Vector2(a.x, a.y * up), Vector2(b.x, b.y * up))
	return st.commit()


## Chaikin corner cutting: rounds a rough outline into a soft cartoon shape.
static func _smooth(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var p := points
	for it in iterations:
		var q := PackedVector2Array()
		for i in p.size():
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


func _add_circle(st: SurfaceTool, center: Vector2, radius: float, segments: int) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		_add_tri(st, center, center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius)


func _add_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	for p in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, 0.0, p.y))


func _particles(at: Vector3, count: int, mesh: Mesh, colors: Array, speed: Vector2, opts := {}) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = opts.get("explosiveness", 0.92)
	p.amount = count
	p.lifetime = opts.get("lifetime", 0.9)
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true  # Without it, unspawned particles draw as squares and size curves are ignored.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 5
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = opts.get("spread", 65.0)
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = opts.get("gravity", Vector3(0.0, -9.0, 0.0))
	p.damping_min = opts.get("damping", 0.0)
	p.damping_max = opts.get("damping", 0.0)
	var spin: float = opts.get("spin", 0.0)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.75, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var ramp_colors := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / colors.size())
		ramp_colors.append(colors[i])
	ramp.offsets = offsets
	ramp.colors = ramp_colors
	p.color_initial_ramp = ramp
	p.position = at
	p.emitting = true
	add_child(p)


## Three cartoon flies circling a spot.
func _flies(at: Vector3) -> void:
	var swarm := Node3D.new()
	swarm.position = at
	add_child(swarm)
	_keep.append(swarm)
	for i in 3:
		var a := TAU * i / 3.0
		var fly := Node3D.new()
		fly.position = Vector3(cos(a) * 0.2, 0.04 * i, sin(a) * 0.2)
		swarm.add_child(fly)
		_part(fly, _sphere(0.022), INK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.0)
		_part(fly, _sphere(0.02), Color(1.0, 1.0, 1.0, 0.85), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3(1.4, 0.4, 0.8), 0.0, 0.0)
	var t := create_tween().set_loops(8)
	t.tween_property(swarm, "rotation:y", TAU, 0.6).from(0.0)
	var bob := create_tween().set_loops(10)
	bob.tween_property(swarm, "position:y", at.y + 0.08, 0.22).set_trans(Tween.TRANS_SINE)
	bob.tween_property(swarm, "position:y", at.y - 0.04, 0.22).set_trans(Tween.TRANS_SINE)


func _word(text: String, color: Color, delay := 0.0, at := Vector3.INF) -> void:
	var spot := target_local if at == Vector3.INF else at
	var l := Label3D.new()
	l.text = text
	if _font == null:
		_font = load(FONT_PATH)
	l.font = _font
	l.font_size = 120
	l.outline_size = 34
	l.pixel_size = 0.0028
	l.modulate = color
	l.outline_modulate = INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position = spot + Vector3(0.0, 0.75, 0.0)
	l.scale = Vector3.ONE * 0.01
	add_child(l)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(l, "scale", Vector3.ONE * 1.18, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector3.ONE, 0.1)
	t.tween_property(l, "position:y", l.position.y + 0.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


# --- Building blocks --------------------------------------------------------------------------

## A toon-shaded part with an optional inverted-hull ink outline (hull = scale factor, 0 = none).
func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3, scl: Vector3, hull := 1.08,
		shine := 0.4, glow := false) -> MeshInstance3D:
	var material: StandardMaterial3D
	if glow:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
	else:
		material = _toon(color, shine)
	var mi := _mesh_node(mesh, material)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	if hull > 0.0:
		var outline := _mesh_node(mesh, _ink_hull())
		outline.scale = Vector3.ONE * hull
		mi.add_child(outline)
	return mi


static func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _toon(color: Color, shine: float) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), shine]
	if not _toons.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		m.roughness = lerpf(0.5, 0.18, shine)
		m.rim_enabled = true
		m.rim = lerpf(0.1, 0.35, shine)
		m.rim_tint = 0.5
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_toons[key] = m
	return _toons[key]


static func _ink_hull() -> StandardMaterial3D:
	if _hull == null:
		_hull = StandardMaterial3D.new()
		_hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hull.cull_mode = BaseMaterial3D.CULL_FRONT
		_hull.albedo_color = INK
	return _hull


## Unshaded, fadeable, double-sided material for flat splats. One per use so it can fade alone.
func _flat(color: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.render_priority = priority
	_fade_mats.append(m)
	return m


static func _sphere(r: float) -> SphereMesh:
	var key := "sphere/%s" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 16
		m.rings = 8
		_meshes[key] = m
	return _meshes[key]


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var key := "cyl/%s/%s/%s" % [top, bottom, height]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = 16
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _torus(inner: float, outer: float) -> TorusMesh:
	var key := "torus/%s/%s" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 10
		_meshes[key] = m
	return _meshes[key]


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var key := "capsule/%s/%s" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 12
		m.rings = 4
		_meshes[key] = m
	return _meshes[key]


static func _box(size: Vector3) -> BoxMesh:
	var key := "box/%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


## Flat shapes in the XY plane for billboard particles.
static func _flat_mesh(key: String, points: PackedVector2Array) -> ArrayMesh:
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center := Vector2.ZERO
		for p in points:
			center += p
		center /= points.size()
		for i in points.size():
			for v in [center, points[i], points[(i + 1) % points.size()]]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(Vector3(v.x, v.y, 0.0))
		_meshes[key] = st.commit()
	return _meshes[key]


static func _circle_mesh(r: float) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0)) * r)
	return _flat_mesh("circle/%s" % r, pts)


static func _star_mesh(r: float) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.28))
	return _flat_mesh("star/%s" % r, pts)


static func _heart_mesh(r: float) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y + 2.0) * (r / 16.0))
	return _flat_mesh("heart/%s" % r, pts)


static func _shard_mesh() -> ArrayMesh:
	return _flat_mesh("shard", PackedVector2Array([Vector2(-0.03, -0.035), Vector2(0.04, -0.02), Vector2(0.015, 0.04)]))


static func _feather_mesh() -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * 0.025, sin(a) * 0.075))
	return _flat_mesh("feather", pts)


static func _confetti_mesh() -> ArrayMesh:
	return _flat_mesh("confetti", PackedVector2Array([Vector2(-0.035, -0.018), Vector2(0.035, -0.018), Vector2(0.035, 0.018), Vector2(-0.035, 0.018)]))


## A little "~" stink wiggle.
static func _wave_mesh() -> ArrayMesh:
	if not _meshes.has("wave"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_top := Vector2.ZERO
		var prev_bottom := Vector2.ZERO
		for i in 13:
			var x := -0.09 + 0.18 * i / 12.0
			var y := sin(i / 12.0 * TAU * 1.5) * 0.025
			var top := Vector2(x, y + 0.01)
			var bottom := Vector2(x, y - 0.01)
			if i > 0:
				for v in [prev_top, prev_bottom, top, top, prev_bottom, bottom]:
					st.set_normal(Vector3.BACK)
					st.add_vertex(Vector3(v.x, v.y, 0.0))
			prev_top = top
			prev_bottom = bottom
		_meshes["wave"] = st.commit()
	return _meshes["wave"]


## Soft round shadow under the projectile, in the XZ plane.
static func _disc_mesh() -> ArrayMesh:
	if not _meshes.has("disc"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 20:
			var a0 := TAU * i / 20.0
			var a1 := TAU * (i + 1) / 20.0
			for p in [Vector2.ZERO, Vector2(cos(a0), sin(a0)) * 0.26, Vector2(cos(a1), sin(a1)) * 0.26]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, 0.0, p.y))
		_meshes["disc"] = st.commit()
	return _meshes["disc"]


# --- Holiday splats -------------------------------------------------------------------------------

func _splat_candy_corn() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), 0.1, 1.3)
	for i in 6:
		var corn := Node3D.new()
		_part(corn, _cyl(0.0, 0.035, 0.04), Color("ffffff"), Vector3(0.0, 0.045, 0.0), Vector3.ZERO, Vector3.ONE, 1.12, 0.4)
		_part(corn, _cyl(0.035, 0.055, 0.045), Color("ff8a1f"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.1, 0.4)
		_part(corn, _cyl(0.055, 0.065, 0.035), Color("ffd23f"), Vector3(0.0, -0.04, 0.0), Vector3.ZERO, Vector3.ONE, 1.1, 0.4)
		var a := TAU * i / 6.0 + _rng.randf() * 0.5
		corn.position = target_local + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.18, 0.36) + Vector3(0.0, 0.04, 0.0)
		corn.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0.0)
		add_child(corn)
		_keep.append(corn)
	_particles(target_local, 16, _cyl(0.0, 0.03, 0.05), [Color("ffffff"), Color("ff8a1f"), Color("ffd23f")], Vector2(1.6, 3.0), {"spin": 360.0})


func _splat_fruitcake() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU), 0.09, 1.25)
	_decal(Color(0.55, 0.36, 0.2, 0.35), 0.34, 6, 0, 0.1, Vector3.ZERO, false, false)
	_dots(Color("8a4a1e"), 8, 0.36, Vector2(0.02, 0.035))
	_dots(Color("e8344e"), 3, 0.3, Vector2(0.015, 0.025))
	_particles(target_local, 14, _circle_mesh(0.035), [Color("8a4a1e"), Color("a8642a")], Vector2(1.0, 2.2))


func _splat_torotot() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), 0.13, 1.5)
	_word("TOOOT!", WORDS["torotot"][1], 0.7, target_local + Vector3(0.35, 0.15, 0.0))
	for delay in [0.0, 0.7]:
		var ring := _mesh_node(_torus(0.2, 0.24), _flat(Color(1.0, 0.4, 0.6, 0.9), 3))
		ring.position = target_local + Vector3(0.0, 0.12, 0.0)
		ring.scale = Vector3.ONE * 0.3
		add_child(ring)
		var mat: StandardMaterial3D = ring.material_override
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
		t.tween_callback(ring.queue_free)
	_particles(target_local + Vector3(0.0, 0.2, 0.0), 24, _confetti_mesh(), PARTY, Vector2(1.6, 3.2),
		{"gravity": Vector3(0.0, -2.5, 0.0), "lifetime": 1.6, "spin": 540.0, "spread": 45.0, "damping": 1.2})


func _splat_love_letter() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)), 0.03, 1.4)
	_particles(target_local + Vector3(0.0, 0.15, 0.0), 14, _heart_mesh(0.09), [Color("ff2f5f"), Color("ff9ec7"), Color("ff6f9f")], Vector2(0.6, 1.3),
		{"gravity": Vector3(0.0, 0.7, 0.0), "lifetime": 1.8, "explosiveness": 0.5})


func _splat_red_envelope() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU), 0.03, 1.4)
	for c in [Color("ffcf3f"), Color("ffe680")]:
		_dots(c, 6, 0.38, Vector2(0.025, 0.04))
	_particles(target_local + Vector3(0.0, 0.1, 0.0), 22, _circle_mesh(0.05), [Color("ffcf3f"), Color("ffe680"), Color("d4a017")], Vector2(1.8, 3.4),
		{"spin": 360.0, "lifetime": 1.2})


func _splat_pumpkin_pie() -> void:
	_drop_projectile()
	_decal(Color("e8892a"), 0.44, 9, 6, 0.18)
	_decal(Color("fff8ec"), 0.14, 6, 0, 0.06, Vector3(0.04, 0.004, -0.03), true, true)
	_dots(Color("d9a25f"), 7, 0.36, Vector2(0.025, 0.045))
	_particles(target_local, 18, _circle_mesh(0.05), [Color("e8892a"), Color("f0a050"), Color("fff8ec")], Vector2(1.8, 3.4))


func _splat_beach_ball() -> void:
	_rest_projectile(Basis(Vector3.UP, _rng.randf() * TAU), 0.22, 1.5)
	var bounce := create_tween()
	for h in [0.55, 0.3, 0.12]:
		bounce.tween_property(_proj, "position:y", 0.22 + h, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bounce.tween_property(_proj, "position:y", 0.22, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_decal(Color(0.95, 0.85, 0.6, 0.4), 0.3, 6, 0, 0.1, Vector3.ZERO, false, false)
	_particles(target_local, 12, _circle_mesh(0.035), [Color("f2d79a"), Color("e6c27f")], Vector2(1.0, 2.0))


func _splat_palayok() -> void:
	_drop_projectile()
	_decal(Color(0.78, 0.39, 0.23, 0.45), 0.36, 7, 3, 0.18, Vector3.ZERO, false, false)
	_particles(target_local, 16, _shard_mesh(), [Color("c8643a"), Color("8a3a1e"), Color("e07a4a")], Vector2(1.6, 3.4), {"spin": 360.0})
	var sweets := [Color("ff8ec0"), Color("ffcf3f"), Color("27c98f"), Color("3d8bff"), Color("ffffff")]
	for i in 9:
		var candy := _mesh_node(_sphere(0.035 + _rng.randf() * 0.015), _toon(sweets[i % sweets.size()], 0.6))
		var a := TAU * i / 9.0 + _rng.randf() * 0.4
		candy.position = target_local + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.08, 0.32) + Vector3(0.0, 0.04, 0.0)
		add_child(candy)
		_keep.append(candy)
	_particles(target_local + Vector3(0.0, 0.1, 0.0), 14, _circle_mesh(0.035), sweets, Vector2(1.5, 3.0))


# --- Themed collections -----------------------------------------------------------------------

func _splat_wave() -> void:
	_drop_projectile()
	_decal(Color(0.25, 0.42, 0.75, 0.75), 0.5, 9, 7, 0.2)
	_decal(Color(1.0, 1.0, 1.0, 0.85), 0.2, 7, 0, 0.16, Vector3(0.1, 0.004, -0.06), false, false)
	_dots(Color("ffffff"), 9, 0.42, Vector2(0.025, 0.045))
	_particles(target_local, 28, _circle_mesh(0.045), [Color("ffffff"), Color("8fc6ff"), Color("3f6aae")], Vector2(2.2, 4.4), {"spread": 50.0})
	_particles(target_local + Vector3(0.0, 0.1, 0.0), 8, _wave_mesh(), [Color("ffffff"), Color("dff3ff")], Vector2(0.6, 1.2),
		{"gravity": Vector3(0.0, -1.0, 0.0), "lifetime": 1.3, "spin": 120.0})


func _splat_cannonball() -> void:
	_rest_projectile(Basis.IDENTITY, 0.18, 1.3)
	_decal(Color(0.12, 0.1, 0.12, 0.7), 0.46, 11, 6, 0.28, Vector3.ZERO, false, false)
	_particles(target_local + Vector3(0.0, 0.15, 0.0), 22, _circle_mesh(0.04), [Color("fff6c8"), Color("ffb020"), Color("ff6a1a")], Vector2(2.0, 4.0),
		{"spread": 80.0, "lifetime": 0.7})
	_particles(target_local + Vector3(0.0, 0.2, 0.0), 12, _circle_mesh(0.12), [Color(0.85, 0.82, 0.78, 0.8), Color(0.6, 0.58, 0.56, 0.7)], Vector2(0.4, 0.9),
		{"gravity": Vector3(0.0, 0.6, 0.0), "lifetime": 1.8, "explosiveness": 0.6, "spread": 70.0})


func _splat_smoke_bomb() -> void:
	_drop_projectile()
	_decal(Color(0.35, 0.3, 0.45, 0.45), 0.44, 8, 3, 0.2, Vector3.ZERO, false, false)
	var smoke := Color(0.55, 0.5, 0.68, 0.6)
	var cloud := Node3D.new()
	for i in 5:
		var a := TAU * i / 5.0
		var puff := _mesh_node(_sphere(0.17 + 0.03 * (i % 2)), _toon(smoke, 0.2))
		puff.position = Vector3(cos(a) * 0.16, 0.18 + 0.06 * (i % 2), sin(a) * 0.16)
		cloud.add_child(puff)
	var top := _mesh_node(_sphere(0.2), _toon(smoke, 0.2))
	top.position = Vector3(0.0, 0.32, 0.0)
	cloud.add_child(top)
	cloud.position = target_local
	cloud.scale = Vector3.ONE * 0.3
	add_child(cloud)
	_keep.append(cloud)
	var t := create_tween()
	t.tween_property(cloud, "scale", Vector3.ONE * 1.15, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cloud, "scale", Vector3.ONE, 0.3)
	_particles(target_local + Vector3(0.0, 0.25, 0.0), 8, _star_mesh(0.07), [Color("c9d2de"), Color("8a94a6")], Vector2(1.5, 2.6),
		{"spin": 720.0, "spread": 80.0, "lifetime": 1.0})
	_particles(target_local + Vector3(0.0, 0.3, 0.0), 14, _circle_mesh(0.1), [Color(0.6, 0.55, 0.75, 0.7), Color(0.45, 0.4, 0.6, 0.6)], Vector2(0.4, 1.0),
		{"gravity": Vector3(0.0, 0.5, 0.0), "lifetime": 1.6, "explosiveness": 0.7, "spread": 90.0})
