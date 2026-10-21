class_name Arena3D
extends Node3D
## Builds the equipped arena around the board: sky, ambient and key light, fog, a procedural ground,
## toon decor and an ambient particle layer. Each arena is personal (only its owner sees it).
##
##     $Arena3D.set_arena("lava_pit")   # unknown slugs fall back to "classic"
##
## Decor is built from primitive meshes merged into one mesh per material (two draw calls with the
## ink outline pass), stays outside the board (radius >= 8) and low near it so the orbiting camera
## always sees the board. Catalogue: core/cosmetics/ArenaLibrary.gd.

const GROUND_Y := Board3D.GROUND_Y  ## The arena ground meets the bottom of the board.
const INK := Color("1d1736")
const GROUND_SHADER := preload("res://materials/arena/arena_ground.gdshader")
const SPACE_SKY_SHADER := preload("res://materials/arena/space_sky.gdshader")

@export var environment_path: NodePath
@export var key_light_path: NodePath

var current := ""

var _env: Environment
var _light: DirectionalLight3D
var _root: Node3D
var _groups: Dictionary = {}  # bucket -> {material, verts, normals, colors, indices}
var _keys: Dictionary = {}    # colour key -> {bucket, color}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var world_env := get_node_or_null(environment_path) as WorldEnvironment
	if world_env != null:
		_env = world_env.environment
	_light = get_node_or_null(key_light_path) as DirectionalLight3D
	set_arena("classic")


func set_arena(slug: String) -> void:
	if not ArenaLibrary.ARENAS.has(slug):
		slug = "classic"
	current = slug
	if _root != null:
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Arena_" + slug
	add_child(_root)
	_groups.clear()
	_keys.clear()
	_rng.seed = hash(slug)

	var arena: Dictionary = ArenaLibrary.ARENAS[slug]
	_apply_environment(arena)
	_build_ground(arena.get("ground", {}))
	var builder := "_decor_" + slug
	if has_method(builder):
		call(builder)
	_commit_decor()
	var preset: String = arena.get("particles", "")
	if preset != "":
		_root.add_child(_particles(preset))


# --- Environment ------------------------------------------------------------------------------

func _apply_environment(arena: Dictionary) -> void:
	if _env != null:
		var sky_spec: Variant = arena.get("sky")
		if _env.sky == null:
			_env.sky = Sky.new()
		_env.background_mode = Environment.BG_SKY
		if sky_spec is String and sky_spec == "space":
			var space := ShaderMaterial.new()
			space.shader = SPACE_SKY_SHADER
			_env.sky.sky_material = space
		else:
			var sky := ProceduralSkyMaterial.new()
			var colors: Array = sky_spec
			sky.sky_top_color = colors[0]
			sky.sky_horizon_color = colors[1]
			sky.ground_horizon_color = colors[1]
			sky.ground_bottom_color = colors[2]
			sky.sky_curve = 0.12
			sky.sun_angle_max = 8.0
			sky.sun_curve = 0.05
			_env.sky.sky_material = sky
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = arena["ambient"]
		_env.ambient_light_energy = arena.get("ambient_energy", 0.62)
		_env.fog_enabled = arena.has("fog")
		if arena.has("fog"):
			var fog_range: Vector2 = arena.get("fog_range", Vector2(18.0, 60.0))
			_env.fog_mode = Environment.FOG_MODE_DEPTH
			_env.fog_light_color = arena["fog"]
			_env.fog_light_energy = 1.0
			_env.fog_density = 1.0
			_env.fog_depth_begin = fog_range.x
			_env.fog_depth_end = fog_range.y
			_env.fog_depth_curve = 1.0
			_env.fog_sky_affect = 0.6
	if _light != null:
		_light.light_color = arena.get("light", Color.WHITE)
		_light.light_energy = arena.get("light_energy", 0.21)


func _build_ground(spec: Dictionary) -> void:
	var pattern: int = spec.get("pattern", 0)
	if pattern < 0:
		return
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(170.0, 170.0)
	ground.mesh = plane
	ground.position.y = GROUND_Y
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("color_a", spec.get("a", Color.WHITE))
	m.set_shader_parameter("color_b", spec.get("b", spec.get("a", Color.WHITE)))
	m.set_shader_parameter("color_c", spec.get("c", Color.WHITE))
	m.set_shader_parameter("glow_color", spec.get("glow", Color(1.0, 0.45, 0.1)))
	m.set_shader_parameter("glow_strength", spec.get("glow_strength", 1.5))
	m.set_shader_parameter("scale", spec.get("scale", 1.0))
	ground.material_override = m
	_root.add_child(ground)


# --- Decor recipes (one per arena; called by name) --------------------------------------------

func _decor_desert_canyon() -> void:
	var layers := [_toon("mesa_a", Color("d9774a"), 0.12), _toon("mesa_b", Color("c8613a"), 0.12), _toon("mesa_c", Color("eb9763"), 0.12)]
	for at in _ring(11, 22.0, 36.0):
		var r := _rng.randf_range(3.5, 7.0)
		var y := GROUND_Y
		for i in 3:
			var h := _rng.randf_range(1.8, 3.2)
			_put(layers[i], _cyl(r * (1.0 - i * 0.16), r * (1.0 - i * 0.12), h, 7), at + Vector3(0, y + h * 0.5, 0), _rng.randf() * TAU)
			y += h
	var cactus := _toon("cactus", Color("4f9f55"))
	for at in _ring(12, 9.0, 14.0):
		var h := _rng.randf_range(1.6, 2.6)
		_put(cactus, _capsule(0.24, h), at + Vector3(0, GROUND_Y + h * 0.5, 0))
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.75:
				var arm_y := GROUND_Y + h * _rng.randf_range(0.45, 0.7)
				var yaw := _rng.randf() * TAU
				var out := Vector3(cos(yaw), 0, sin(yaw)) * side
				_put_along(cactus, _capsule(0.16, 0.7), at + out * 0.42 + Vector3(0, arm_y, 0), out, PI / 2.0)
				_put(cactus, _capsule(0.16, 0.9), at + out * 0.72 + Vector3(0, arm_y + 0.4, 0))
	var rock := _toon("rock", Color("c98a5a"))
	for at in _ring(14, 8.0, 12.0):
		_put(rock, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.1, 0), _rng.randf() * TAU, _vary(0.6, 0.35, 0.5))


func _decor_sakura_garden() -> void:
	var trunk := _toon("trunk", Color("7a4a3a"))
	var bloom := [_toon("bloom_a", Color("ffb3d1"), 0.1), _toon("bloom_b", Color("ff9ac2"), 0.1)]
	for at in _ring(13, 13.0, 23.0):
		var h := _rng.randf_range(2.6, 3.8)
		_put(trunk, _cyl(0.22, 0.38, h, 7), at + Vector3(0, GROUND_Y + h * 0.5, 0))
		for i in 4:
			var off := Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-1.2, 1.2))
			_put(bloom[i % 2], _sphere(1.0), at + Vector3(0, GROUND_Y + h + 0.6, 0) + off, 0.0, Vector3.ONE * _rng.randf_range(1.2, 1.8))
	var stone := _toon("stone", Color("c4c6cc"))
	var lamp := _glow("lamp", Color("ffd38a"), 1.6)
	for at in _ring(6, 8.8, 10.5):
		_put(stone, _box(Vector3(0.8, 0.22, 0.8)), at + Vector3(0, GROUND_Y + 0.11, 0))
		_put(stone, _cyl(0.14, 0.14, 0.75, 6), at + Vector3(0, GROUND_Y + 0.6, 0))
		_put(lamp, _box(Vector3(0.48, 0.4, 0.48)), at + Vector3(0, GROUND_Y + 1.15, 0))
		_put(stone, _cyl(0.0, 0.62, 0.38, 4), at + Vector3(0, GROUND_Y + 1.53, 0), PI / 4.0)
	var bush := _toon("bush", Color("5fae4f"))
	for at in _ring(14, 8.0, 12.0):
		_put(bush, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.15, 0), 0.0, _vary(0.7, 0.45, 0.7))
	var red := _toon("torii", Color("e0453a"))
	var dark := _toon("torii_top", Color("2b1f22"))
	for z: float in [-27.0, 27.0]:
		for x: float in [-3.0, 3.0]:
			_put(red, _cyl(0.32, 0.36, 6.0, 8), Vector3(x, GROUND_Y + 3.0, z))
		_put(dark, _box(Vector3(9.0, 0.5, 0.7)), Vector3(0, GROUND_Y + 6.2, z))
		_put(red, _box(Vector3(7.4, 0.36, 0.45)), Vector3(0, GROUND_Y + 5.1, z))


func _decor_frozen_tundra() -> void:
	var ice := _toon("ice", Color("a8ecff"), 0.05, 0.4)
	for at in _ring(16, 9.0, 13.0):
		for i in 3:
			var h := _rng.randf_range(0.7, 2.0)
			var off := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			_put(ice, _cyl(0.0, _rng.randf_range(0.22, 0.42), h, 6), at + off + Vector3(0, GROUND_Y + h * 0.5, 0), _rng.randf() * TAU,
				Vector3.ONE, Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25)))
	var crystal := _toon("crystal", Color("7fdcff"), 0.1, 0.4)
	for at in _ring(8, 17.0, 25.0):
		var h := _rng.randf_range(4.0, 7.5)
		_put(crystal, _cyl(0.0, _rng.randf_range(0.9, 1.5), h, 6), at + Vector3(0, GROUND_Y + h * 0.5, 0), _rng.randf() * TAU,
			Vector3.ONE, Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15)))
	var pine := _toon("pine", Color("2f6b5a"), 0.08)
	var snow := _toon("snowcap", Color("ffffff"), 0.06)
	for at in _ring(14, 15.0, 27.0):
		var s := _rng.randf_range(0.9, 1.4)
		for i in 3:
			var y := GROUND_Y + (0.9 + i * 1.1) * s
			_put(pine, _cyl(0.0, (1.5 - i * 0.35) * s, 1.6 * s, 8), at + Vector3(0, y, 0))
		_put(snow, _cyl(0.0, 0.45 * s, 0.6 * s, 8), at + Vector3(0, GROUND_Y + 3.9 * s, 0))
	var mound := _toon("mound", Color("f4f9ff"))
	for at in _ring(12, 8.0, 12.0):
		_put(mound, _sphere(1.0), at + Vector3(0, GROUND_Y, 0), 0.0, _vary(1.0, 0.45, 0.9))


func _decor_candy_land() -> void:
	var stick := _toon("stick", Color("fffaf2"))
	var swirl := [_toon("pop_a", Color("ff5a8a"), 0.08, 0.6), _toon("pop_b", Color("5ac8ff"), 0.08, 0.6), _toon("pop_c", Color("ffd23f"), 0.08, 0.6)]
	for at in _ring(10, 14.0, 24.0):
		var h := _rng.randf_range(3.5, 5.5)
		_put(stick, _cyl(0.12, 0.12, h, 8), at + Vector3(0, GROUND_Y + h * 0.5, 0))
		var yaw := _rng.randf() * TAU
		var c := _rng.randi() % 3
		_put(swirl[c], _cyl(1.5, 1.5, 0.32, 20), at + Vector3(0, GROUND_Y + h + 1.2, 0), yaw, Vector3.ONE, Vector3(PI / 2.0, 0, 0))
		_put(swirl[(c + 1) % 3], _torus(0.55, 0.95), at + Vector3(0, GROUND_Y + h + 1.2, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.17, yaw, Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	var cane_red := _toon("cane_red", Color("ff4a5a"), 0.06, 0.4)
	var cane_white := _toon("cane_white", Color("fff6f6"), 0.06, 0.4)
	for at in _ring(8, 12.0, 20.0):
		var bands := 9
		for i in bands:
			_put(cane_red if i % 2 == 0 else cane_white, _cyl(0.22, 0.22, 0.42, 10), at + Vector3(0, GROUND_Y + 0.21 + i * 0.42, 0))
		_put(cane_red, _sphere(0.3), at + Vector3(0, GROUND_Y + bands * 0.42 + 0.1, 0))
	var gum := [_toon("gum_a", Color("7fe0a8"), 0.06, 0.6), _toon("gum_b", Color("c39bff"), 0.06, 0.6), _toon("gum_c", Color("ffa45a"), 0.06, 0.6)]
	for at in _ring(16, 8.0, 12.0):
		_put(gum[_rng.randi() % 3], _sphere(1.0), at + Vector3(0, GROUND_Y + 0.05, 0), 0.0, _vary(0.55, 0.55, 0.55))
	var cup := _toon("cupcake", Color("ff9ec8"))
	var frost := _toon("frosting", Color("fffaf2"), 0.06, 0.5)
	var cherry := _toon("cherry", Color("e8243c"), 0.04, 0.6)
	for at in _ring(6, 9.0, 12.0):
		_put(cup, _cyl(0.6, 0.45, 0.65, 12), at + Vector3(0, GROUND_Y + 0.33, 0))
		_put(frost, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.75, 0), 0.0, Vector3(0.68, 0.5, 0.68))
		_put(cherry, _sphere(0.16), at + Vector3(0, GROUND_Y + 1.28, 0))
	var cone := _toon("cone", Color("e8b06a"), 0.1)
	var scoop := [_toon("scoop_a", Color("fff1d6"), 0.1, 0.4), _toon("scoop_b", Color("ff9ec8"), 0.1, 0.4), _toon("scoop_c", Color("8a5a3a"), 0.1, 0.4)]
	for at in _ring(6, 21.0, 29.0):
		_put(cone, _cyl(1.3, 0.1, 3.6, 10), at + Vector3(0, GROUND_Y + 1.8, 0))
		_put(scoop[_rng.randi() % 3], _sphere(1.35), at + Vector3(0, GROUND_Y + 4.0, 0))
		_put(scoop[_rng.randi() % 3], _sphere(1.1), at + Vector3(0, GROUND_Y + 5.6, 0))


func _decor_ocean_reef() -> void:
	var brain := _toon("brain", Color("ff7a9a"), 0.05)
	var tube := _toon("tube", Color("ff9a3d"), 0.04)
	var fan := _toon("fan", Color("b07aff"), 0.04)
	var anemone := _toon("anemone", Color("ffd23f"), 0.04)
	for at in _ring(16, 8.0, 13.0):
		match _rng.randi() % 4:
			0:
				_put(brain, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.15, 0), 0.0, _vary(0.8, 0.55, 0.8))
			1:
				for i in 4:
					var h := _rng.randf_range(0.7, 1.6)
					_put(tube, _cyl(0.17, 0.13, h, 8), at + Vector3(_rng.randf_range(-0.4, 0.4), GROUND_Y + h * 0.5, _rng.randf_range(-0.4, 0.4)))
			2:
				_put(fan, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.9, 0), _rng.randf() * TAU, Vector3(1.0, 1.1, 0.12))
			_:
				_put(anemone, _cyl(0.35, 0.25, 0.4, 10), at + Vector3(0, GROUND_Y + 0.2, 0))
				for i in 6:
					var a := TAU * i / 6.0
					_put(anemone, _sphere(0.12), at + Vector3(cos(a) * 0.28, GROUND_Y + 0.5, sin(a) * 0.28))
	var kelp := _toon("kelp", Color("3fae6a"), 0.05)
	for at in _ring(12, 13.0, 22.0):
		for i in 3:
			var h := _rng.randf_range(3.5, 7.0)
			_put(kelp, _capsule(0.13, h), at + Vector3(_rng.randf_range(-0.8, 0.8), GROUND_Y + h * 0.5, _rng.randf_range(-0.8, 0.8)), 0.0,
				Vector3.ONE, Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12)))
	var rock := _toon("reef_rock", Color("7c8aa0"))
	for at in _ring(10, 9.0, 14.0):
		_put(rock, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.1, 0), _rng.randf() * TAU, _vary(0.7, 0.4, 0.6))


func _decor_cloud_kingdom() -> void:
	var colors := [Color("ff5a5f"), Color("ffa63d"), Color("ffe066"), Color("5fd67a"), Color("4aa8ff"), Color("9b6bff")]
	for i in colors.size():
		var band := _glow("rainbow_%d" % i, colors[i], 1.05)
		var r := 15.0 - i * 0.62
		_put(band, _torus(r - 0.31, r + 0.31, 48), Vector3(0, GROUND_Y - 0.4, -34.0), 0.0, Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	var grass := _toon("island_grass", Color("8fd96b"), 0.08)
	var dirt := _toon("island_rock", Color("b98a62"), 0.08)
	var leaves := _toon("island_tree", Color("4fb06a"), 0.08)
	for at in _ring(7, 17.0, 26.0):
		var y := _rng.randf_range(2.0, 5.5)
		var r := _rng.randf_range(1.6, 2.6)
		_put(grass, _cyl(r, r, 0.45, 12), at + Vector3(0, y, 0))
		_put(dirt, _cyl(r * 0.95, 0.2, r * 1.4, 10), at + Vector3(0, y - 0.22 - r * 0.7, 0))
		_put(leaves, _sphere(0.8), at + Vector3(_rng.randf_range(-0.5, 0.5), y + 0.95, _rng.randf_range(-0.5, 0.5)))
	var puff := _toon("puff", Color("ffffff"), 0.06)
	for at in _ring(14, 8.5, 13.0):
		for i in 3:
			_put(puff, _sphere(1.0), at + Vector3(_rng.randf_range(-0.7, 0.7), GROUND_Y + 0.15, _rng.randf_range(-0.7, 0.7)), 0.0, _vary(0.75, 0.5, 0.75))


func _decor_jungle_temple() -> void:
	var stone := _toon("temple", Color("8d9478"), 0.12)
	var moss := _toon("temple_moss", Color("5f9445"), 0.12)
	var gem := _glow("gem", Color("5fffb0"), 1.8)
	for z: float in [-29.0, 29.0]:
		for i in 5:
			var s := 12.0 - i * 2.0
			_put(stone if i % 2 == 0 else moss, _box(Vector3(s, 1.6, s)), Vector3(0, GROUND_Y + 0.8 + i * 1.6, z))
		_put(stone, _box(Vector3(2.6, 2.0, 2.6)), Vector3(0, GROUND_Y + 9.0, z))
		_put(gem, _sphere(0.6), Vector3(0, GROUND_Y + 10.6, z))
		_put(stone, _box(Vector3(2.2, 8.0, 3.0)), Vector3(0, GROUND_Y + 3.4, z - signf(z) * 5.6), 0.0, Vector3.ONE, Vector3(signf(z) * -0.85, 0, 0))
	var trunk := _toon("jungle_trunk", Color("6b4a2f"))
	var canopy := [_toon("canopy_a", Color("2f7d3c"), 0.1), _toon("canopy_b", Color("3f9a4a"), 0.1)]
	for at in _ring(14, 15.0, 26.0):
		if absf(at.x) < 8.0 and absf(at.z) > 22.0:
			continue  # Keep the temples clear.
		var h := _rng.randf_range(3.5, 5.5)
		_put(trunk, _cyl(0.28, 0.42, h, 7), at + Vector3(0, GROUND_Y + h * 0.5, 0))
		for i in 3:
			var off := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.2, 0.4), _rng.randf_range(-1.0, 1.0))
			_put(canopy[i % 2], _sphere(1.0), at + Vector3(0, GROUND_Y + h + 0.4, 0) + off, 0.0, Vector3(1.9, 1.1, 1.9))
	var fern := [_toon("fern_a", Color("4f9a3c")), _toon("fern_b", Color("6fbf4a"))]
	for at in _ring(18, 8.0, 12.0):
		_put(fern[_rng.randi() % 2], _sphere(1.0), at + Vector3(0, GROUND_Y + 0.1, 0), 0.0, _vary(0.7, 0.4, 0.7))
	for at in _ring(6, 9.0, 13.0):
		var h := _rng.randf_range(0.8, 2.2)
		_put(stone, _cyl(0.38, 0.42, h, 8), at + Vector3(0, GROUND_Y + h * 0.5, 0))


func _decor_neon_city() -> void:
	var tower := _toon("tower", Color("1d1838"), 0.1)
	var trims := [_glow("neon_cyan", Color("19f0ff"), 2.2), _glow("neon_pink", Color("ff3dd0"), 2.2), _glow("neon_gold", Color("ffd23f"), 2.0)]
	for at in _ring(26, 18.0, 34.0):
		var size := Vector3(_rng.randf_range(2.8, 5.5), _rng.randf_range(6.0, 15.0), _rng.randf_range(2.8, 5.5))
		var yaw := _rng.randf() * TAU
		_put(tower, _box(size), at + Vector3(0, GROUND_Y + size.y * 0.5, 0), yaw)
		var trim: String = trims[_rng.randi() % 3]
		var bands := 2 + _rng.randi() % 3
		for i in bands:
			var y := GROUND_Y + size.y * (i + 1.0) / (bands + 1.0)
			_put(trim, _box(Vector3(size.x + 0.08, 0.18, size.z + 0.08)), at + Vector3(0, y, 0), yaw)
	var barrier := _toon("barrier", Color("2a2550"), 0.05)
	for at in _ring(10, 9.0, 11.5):
		var yaw := atan2(at.x, at.z) + PI / 2.0
		_put(barrier, _box(Vector3(1.8, 0.45, 0.4)), at + Vector3(0, GROUND_Y + 0.22, 0), yaw)
		_put(trims[0], _box(Vector3(1.82, 0.08, 0.42)), at + Vector3(0, GROUND_Y + 0.32, 0), yaw)
	for at in _ring(6, 14.0, 20.0):
		_put(trims[1], _torus(0.9, 1.1, 32), at + Vector3(0, GROUND_Y + _rng.randf_range(3.0, 5.5), 0), atan2(at.x, at.z), Vector3.ONE, Vector3(PI / 2.0, 0, 0))


func _decor_haunted_grove() -> void:
	var bark := _toon("dead_tree", Color("2b2236"), 0.07)
	for at in _ring(14, 13.0, 24.0):
		var h := _rng.randf_range(3.5, 5.5)
		var lean := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
		_put(bark, _cyl(0.12, 0.42, h, 6), at + Vector3(0, GROUND_Y + h * 0.5, 0), 0.0, Vector3.ONE, lean)
		for i in 3:
			var yaw := _rng.randf() * TAU
			var y := GROUND_Y + h * _rng.randf_range(0.55, 0.85)
			var out := Vector3(cos(yaw), 0, sin(yaw))
			_put_along(bark, _cyl(0.04, 0.12, 1.6, 5), at + out * 0.6 + Vector3(0, y + 0.4, 0), out, 0.9)
	var grave := _toon("grave", Color("8d86a6"), 0.05)
	for at in _ring(14, 9.0, 13.0):
		var yaw := atan2(at.x, at.z) + _rng.randf_range(-0.4, 0.4)
		var tilt := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.12, 0.12))
		_put(grave, _box(Vector3(0.8, 1.0, 0.24)), at + Vector3(0, GROUND_Y + 0.45, 0), yaw, Vector3.ONE, tilt)
		_put(grave, _cyl(0.4, 0.4, 0.24, 12), at + Vector3(0, GROUND_Y + 0.95, 0), yaw, Vector3.ONE, Vector3(PI / 2.0, 0, 0) + tilt)
	var pumpkin := _glow("pumpkin", Color("ff8a2a"), 1.3)
	var stalk := _toon("stalk", Color("4a6b2a"), 0.03)
	for at in _ring(8, 8.5, 11.0):
		_put(pumpkin, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.28, 0), 0.0, Vector3(0.45, 0.34, 0.45))
		_put(stalk, _cyl(0.05, 0.07, 0.22, 5), at + Vector3(0, GROUND_Y + 0.68, 0))
	_put(_glow("moon", Color("fff3c4"), 1.4), _sphere(6.0), Vector3(-34.0, 22.0, -48.0))


func _decor_spooky_graveyard() -> void:
	var stone := _toon("tombstone", Color("9a94b0"), 0.05)
	var dark := _toon("tombstone_dark", Color("6f688a"), 0.05)
	for at in _ring(22, 8.5, 15.0):
		var yaw := atan2(at.x, at.z) + _rng.randf_range(-0.35, 0.35)
		var tilt := Vector3(_rng.randf_range(-0.16, 0.16), 0, _rng.randf_range(-0.12, 0.12))
		var key := stone if _rng.randf() < 0.6 else dark
		var h := _rng.randf_range(0.8, 1.3)
		_put(key, _box(Vector3(0.8, h, 0.24)), at + Vector3(0, GROUND_Y + h * 0.5, 0), yaw, Vector3.ONE, tilt)
		_put(key, _cyl(0.4, 0.4, 0.24, 14), at + Vector3(0, GROUND_Y + h, 0), yaw, Vector3.ONE, Vector3(PI / 2.0, 0, 0) + tilt)
	# A crooked iron fence ring.
	var iron := _toon("iron", Color("1d1726"), 0.04)
	for i in 64:
		var a := TAU * i / 64.0
		var at := Vector3(cos(a), 0, sin(a)) * 17.0
		_put(iron, _cyl(0.05, 0.05, 1.5, 5), at + Vector3(0, GROUND_Y + 0.75, 0), 0.0, Vector3.ONE, Vector3(_rng.randf_range(-0.08, 0.08), 0, 0))
		_put(iron, _cyl(0.0, 0.09, 0.22, 4), at + Vector3(0, GROUND_Y + 1.6, 0))
	for y: float in [0.5, 1.2]:
		_put(iron, _torus(16.95, 17.05, 96), Vector3(0, GROUND_Y + y, 0))
	var pumpkin := _glow("lantern_pumpkin", Color("ff8a2a"), 1.6)
	var stalk := _toon("stalk", Color("4a6b2a"), 0.03)
	for at in _ring(12, 7.6, 10.5):
		_put(pumpkin, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.3, 0), 0.0, Vector3(0.5, 0.38, 0.5))
		_put(stalk, _cyl(0.05, 0.07, 0.22, 5), at + Vector3(0, GROUND_Y + 0.74, 0))
	# Undas candles on the graves.
	var wax := _toon("candle", Color("fff6e0"), 0.03)
	var flame := _glow("candle_flame", Color("ffcf5a"), 2.4)
	for at in _ring(26, 8.0, 13.5):
		var h := _rng.randf_range(0.2, 0.4)
		_put(wax, _cyl(0.06, 0.06, h, 8), at + Vector3(0, GROUND_Y + h * 0.5, 0))
		_put(flame, _sphere(1.0), at + Vector3(0, GROUND_Y + h + 0.07, 0), 0.0, Vector3(0.05, 0.1, 0.05))
	var bark := _toon("dead_tree", Color("2b2236"), 0.07)
	for at in _ring(8, 18.0, 26.0):
		var h := _rng.randf_range(4.0, 6.0)
		_put(bark, _cyl(0.14, 0.45, h, 6), at + Vector3(0, GROUND_Y + h * 0.5, 0), 0.0, Vector3.ONE, Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1)))
		for i in 3:
			var yaw := _rng.randf() * TAU
			var out := Vector3(cos(yaw), 0, sin(yaw))
			_put_along(bark, _cyl(0.04, 0.12, 1.8, 5), at + out * 0.6 + Vector3(0, GROUND_Y + h * _rng.randf_range(0.6, 0.85), 0), out, 0.9)
	_put(_glow("big_moon", Color("ffb45a"), 1.5), _sphere(8.0), Vector3(-30.0, 20.0, -50.0))


func _decor_snowy_village() -> void:
	var walls := [_toon("house_red", Color("d9573f"), 0.05), _toon("house_cream", Color("f4e3c4"), 0.05),
		_toon("house_mint", Color("9fd8c2"), 0.05), _toon("house_ginger", Color("c8803f"), 0.05)]
	var roof := _toon("roof", Color("6b3a2a"), 0.05)
	var snow := _toon("snow_cap", Color("ffffff"), 0.04)
	var window := _glow("window", Color("ffd36a"), 1.8)
	for at in _ring(10, 12.0, 18.0):
		var yaw := atan2(at.x, at.z)
		var w := _rng.randf_range(1.6, 2.4)
		var h := _rng.randf_range(1.4, 2.0)
		_put(walls[_rng.randi() % walls.size()], _box(Vector3(w, h, w * 0.85)), at + Vector3(0, GROUND_Y + h * 0.5, 0), yaw)
		_put(roof, _cyl(0.0, w * 0.82, 1.1, 4), at + Vector3(0, GROUND_Y + h + 0.5, 0), yaw + PI / 4.0)
		_put(snow, _cyl(0.0, w * 0.74, 0.7, 4), at + Vector3(0, GROUND_Y + h + 0.75, 0), yaw + PI / 4.0)
		var front := Vector3(-sin(yaw), 0, -cos(yaw))
		_put(window, _box(Vector3(0.36, 0.36, 0.06)), at + front * (w * 0.43) + Vector3(0, GROUND_Y + h * 0.55, 0), yaw)
	var pine := _toon("pine", Color("2f7a4a"), 0.05)
	var trunk := _toon("trunk", Color("6b3e22"), 0.04)
	var bauble_colors := [_glow("bauble_r", Color("ff4f5a"), 1.4), _glow("bauble_y", Color("ffcf3f"), 1.4), _glow("bauble_b", Color("5fa8ff"), 1.4)]
	for at in _ring(16, 9.0, 24.0):
		var s := _rng.randf_range(0.8, 1.4)
		_put(trunk, _cyl(0.15, 0.2, 0.6, 6), at + Vector3(0, GROUND_Y + 0.3 * s, 0), 0.0, Vector3.ONE * s)
		for k in 3:
			_put(pine, _cyl(0.0, (1.1 - k * 0.28) * s, 1.0 * s, 8), at + Vector3(0, GROUND_Y + (0.8 + k * 0.6) * s, 0))
			_put(snow, _cyl(0.0, (0.55 - k * 0.14) * s, 0.4 * s, 8), at + Vector3(0, GROUND_Y + (1.15 + k * 0.6) * s, 0))
		for k in 4:
			var a := _rng.randf() * TAU
			_put(bauble_colors[k % 3], _sphere(0.09 * s), at + Vector3(cos(a) * 0.6 * s, GROUND_Y + (0.9 + k * 0.35) * s, sin(a) * 0.6 * s))
	var post := _toon("lamp_post", Color("2a2d40"), 0.04)
	var lamp := _glow("lamp", Color("fff0b0"), 2.2)
	for at in _ring(8, 8.0, 9.5):
		_put(post, _cyl(0.06, 0.08, 2.2, 6), at + Vector3(0, GROUND_Y + 1.1, 0))
		_put(lamp, _sphere(0.2), at + Vector3(0, GROUND_Y + 2.35, 0))
	# A big parol (star lantern) glowing in the sky.
	_put(_glow("sky_parol", Color("ffcf3f"), 1.8), _cyl(0.0, 3.0, 0.4, 5), Vector3(28.0, 18.0, -45.0), 0.0, Vector3.ONE, Vector3(PI / 2.0, 0, 0))


func _decor_harvest_farm() -> void:
	# A red barn with a white-trimmed door and a hay loft.
	var barn := _toon("barn_red", Color("c8341c"), 0.06)
	var trim := _toon("barn_trim", Color("fff6e8"), 0.04)
	var barn_roof := _toon("barn_roof", Color("5a2a1a"), 0.05)
	var barn_at := Vector3(-14.0, 0.0, -13.0)
	var barn_yaw := atan2(barn_at.x, barn_at.z)
	_put(barn, _box(Vector3(5.0, 3.2, 4.0)), barn_at + Vector3(0, GROUND_Y + 1.6, 0), barn_yaw)
	_put(barn_roof, _cyl(0.0, 3.6, 1.8, 4), barn_at + Vector3(0, GROUND_Y + 4.1, 0), barn_yaw + PI / 4.0, Vector3(1.0, 1.0, 0.8))
	var front := Vector3(-sin(barn_yaw), 0, -cos(barn_yaw))
	_put(trim, _box(Vector3(1.6, 2.0, 0.1)), barn_at + front * 2.02 + Vector3(0, GROUND_Y + 1.0, 0), barn_yaw)
	_put(barn, _box(Vector3(1.3, 1.75, 0.12)), barn_at + front * 2.05 + Vector3(0, GROUND_Y + 0.92, 0), barn_yaw)
	# Round hay bales, corn stalks and a pumpkin patch around the table.
	var hay := _toon("hay", Color("e8c25a"), 0.05)
	for at in _ring(9, 9.0, 13.0):
		var r := _rng.randf_range(0.6, 0.8)
		_put(hay, _cyl(r, r, 0.9, 14), at + Vector3(0, GROUND_Y + r, 0), atan2(at.x, at.z), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	var stalk := _toon("corn_stalk", Color("7aa83a"), 0.03)
	var cob := _toon("corn_cob", Color("ffd23f"), 0.03)
	for at in _ring(26, 15.0, 22.0):
		var h := _rng.randf_range(1.8, 2.6)
		_put(stalk, _cyl(0.05, 0.08, h, 5), at + Vector3(0, GROUND_Y + h * 0.5, 0), 0.0, Vector3.ONE, Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1)))
		_put(stalk, _cyl(0.0, 0.18, 0.9, 4), at + Vector3(0.18, GROUND_Y + h * 0.6, 0), 0.0, Vector3(1.0, 1.0, 0.3), Vector3(0, 0, -0.9))
		_put(cob, _sphere(0.1), at + Vector3(0.07, GROUND_Y + h * 0.7, 0.05), 0.0, Vector3(0.8, 2.2, 0.8))
	var pumpkin := _toon("farm_pumpkin", Color("ff8a1f"), 0.05)
	var vine := _toon("farm_vine", Color("4a6b2a"), 0.03)
	for at in _ring(14, 7.6, 10.0):
		var size := _rng.randf_range(0.35, 0.6)
		_put(pumpkin, _sphere(1.0), at + Vector3(0, GROUND_Y + size * 0.7, 0), 0.0, Vector3(size, size * 0.75, size))
		_put(vine, _cyl(0.04, 0.06, 0.2, 5), at + Vector3(0, GROUND_Y + size * 1.4, 0))
	# A wooden fence.
	var wood := _toon("fence_wood", Color("a8783a"), 0.04)
	for i in 40:
		var a := TAU * i / 40.0
		var at := Vector3(cos(a), 0, sin(a)) * 16.0
		_put(wood, _box(Vector3(0.18, 1.1, 0.18)), at + Vector3(0, GROUND_Y + 0.55, 0))
	for y: float in [0.45, 0.9]:
		_put(wood, _torus(15.95, 16.05, 80), Vector3(0, GROUND_Y + y, 0))
	_put(_glow("harvest_sun", Color("ffcf6a"), 1.4), _sphere(7.0), Vector3(30.0, 14.0, -55.0))


func _decor_sunny_beach() -> void:
	# The sea: a wide band of blue water with a foam line, out beyond the sand toward the horizon.
	var sea := _toon("sea", Color("1fb3d6"), 0.0)
	_put(sea, _box(Vector3(160.0, 0.1, 70.0)), Vector3(0, GROUND_Y + 0.02, -62.0))
	var foam := _toon("foam", Color("ffffff"), 0.0)
	for i in 3:
		_put(foam, _box(Vector3(160.0, 0.06, 0.5)), Vector3(0, GROUND_Y + 0.05, -26.8 - i * 1.4))
	# Palm trees with bending trunks.
	var trunk := _toon("palm_trunk", Color("a8783a"), 0.04)
	var frond := _toon("palm_frond", Color("2fa84a"), 0.04)
	var coconut := _toon("coconut", Color("5a3a24"), 0.03)
	for at in _ring(9, 10.0, 18.0):
		var h := _rng.randf_range(3.2, 4.6)
		var lean := Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
		_put(trunk, _cyl(0.14, 0.24, h, 7), at + Vector3(0, GROUND_Y + h * 0.5, 0), 0.0, Vector3.ONE, lean)
		var top := at + Vector3(lean.z * h * 0.5, GROUND_Y + h, -lean.x * h * 0.5)
		for k in 6:
			var yaw := TAU * k / 6.0
			var out := Vector3(cos(yaw), 0, sin(yaw))
			_put_along(frond, _cyl(0.02, 0.32, 1.9, 4), top + out * 0.6 + Vector3(0, -0.1, 0), out, 1.25)
		_put(coconut, _sphere(0.16), top + Vector3(0.12, -0.15, 0.0))
		_put(coconut, _sphere(0.16), top + Vector3(-0.1, -0.18, 0.08))
	# Striped umbrellas, towels and a little sandcastle.
	var umbrella_colors := [_toon("umbrella_red", Color("ff4f5a"), 0.04), _toon("umbrella_yellow", Color("ffcf3f"), 0.04),
		_toon("umbrella_blue", Color("3d8bff"), 0.04)]
	var pole := _toon("umbrella_pole", Color("fff6e8"), 0.03)
	var towels := [_toon("towel_pink", Color("ff8ec0"), 0.02), _toon("towel_mint", Color("4dd6a8"), 0.02)]
	for at in _ring(7, 8.0, 11.0):
		_put(pole, _cyl(0.04, 0.04, 2.2, 5), at + Vector3(0, GROUND_Y + 1.1, 0))
		_put(umbrella_colors[_rng.randi() % umbrella_colors.size()], _cyl(0.05, 1.3, 0.5, 8), at + Vector3(0, GROUND_Y + 2.3, 0))
		_put(towels[_rng.randi() % towels.size()], _box(Vector3(0.9, 0.03, 1.7)), at + Vector3(0.9, GROUND_Y + 0.02, 0.3), _rng.randf() * TAU)
	var sand := _toon("castle_sand", Color("eccf8a"), 0.04)
	var castle_at := Vector3(9.0, 0.0, 6.0)
	_put(sand, _box(Vector3(1.6, 0.6, 1.6)), castle_at + Vector3(0, GROUND_Y + 0.3, 0))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_put(sand, _cyl(0.3, 0.34, 1.0, 8), castle_at + Vector3(cos(a) * 0.85, GROUND_Y + 0.5, sin(a) * 0.85))
	_put(_glow("beach_sun", Color("fff0a0"), 1.6), _sphere(6.0), Vector3(-26.0, 24.0, -60.0))


func _decor_lava_pit() -> void:
	var rock := _toon("basalt", Color("3a2b2e"), 0.07)
	for at in _ring(16, 8.0, 12.0):
		_put(rock, _sphere(1.0), at + Vector3(0, GROUND_Y + 0.1, 0), _rng.randf() * TAU, _vary(0.85, 0.5, 0.7))
	var spire := _toon("spire", Color("2b1f22"), 0.1)
	var ember := _glow("spire_glow", Color("ff7a2a"), 1.6)
	for at in _ring(14, 15.0, 27.0):
		var h := _rng.randf_range(4.5, 8.5)
		_put(spire, _cyl(0.15, _rng.randf_range(1.0, 1.8), h, 7), at + Vector3(0, GROUND_Y + h * 0.5, 0), _rng.randf() * TAU,
			Vector3.ONE, Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1)))
		_put(ember, _cyl(0.22, 0.26, 0.4, 7), at + Vector3(0, GROUND_Y + 0.2, 0))
	_put(spire, _cyl(4.5, 15.0, 13.0, 12), Vector3(-30.0, GROUND_Y + 6.5, -34.0))
	_put(_glow("crater", Color("ffb04a"), 2.4), _cyl(4.2, 4.2, 0.3, 16), Vector3(-30.0, GROUND_Y + 13.0, -34.0))


func _decor_deep_space() -> void:
	# The board rests on a flat-topped asteroid floating in the void.
	var top := _toon("island_top", Color("8f87b5"), 0.1)
	var under := _toon("island_under", Color("5f5880"), 0.1)
	_put(top, _cyl(7.6, 7.6, 0.6, 24), Vector3(0, GROUND_Y - 0.32, 0))
	_put(under, _cyl(7.4, 1.2, 4.6, 14), Vector3(0, GROUND_Y - 2.9, 0))
	for i in 10:
		var a := TAU * i / 10.0 + _rng.randf_range(-0.2, 0.2)
		_put(under, _sphere(1.0), Vector3(cos(a) * 7.2, GROUND_Y - 0.9, sin(a) * 7.2), _rng.randf() * TAU, _vary(1.2, 0.8, 1.0))
	var rocks := _toon("asteroid", Color("7a7392"), 0.06)
	for at in _ring(22, 10.0, 17.0):
		_put(rocks, _sphere(1.0), at + Vector3(0, _rng.randf_range(-5.0, 1.0), 0), _rng.randf() * TAU, _vary(0.6, 0.45, 0.5))
	_put(_toon("planet_a", Color("ffb36b"), 0.15), _sphere(8.0), Vector3(-28.0, -9.0, -32.0))
	_put(_toon("planet_ring", Color("ffe0a8"), 0.1), _torus(10.5, 13.5, 48), Vector3(-28.0, -9.0, -32.0), 0.3, Vector3(1.0, 0.08, 1.0),
		Vector3(0.35, 0, 0.2))
	_put(_toon("planet_b", Color("6fb6ff"), 0.12), _sphere(5.0), Vector3(24.0, -12.0, -26.0))
	_put(_toon("planet_c", Color("c8c4e8"), 0.1), _sphere(3.2), Vector3(22.0, -6.0, 22.0))


# --- Particles --------------------------------------------------------------------------------

func _particles(preset: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(20.0, 0.5, 20.0)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	var additive := false
	var texture := _dot_texture()
	var colors := Gradient.new()
	match preset:
		"embers":
			p.amount = 130
			p.lifetime = 5.0
			p.position.y = GROUND_Y + 0.2
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.0
			p.gravity = Vector3(0.3, 0.25, 0.0)
			quad.size = Vector2(0.14, 0.14)
			additive = true
			colors.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
			colors.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		"petals":
			p.amount = 110
			p.lifetime = 9.0
			p.position.y = 8.0
			p.direction = Vector3(1.0, -1.0, 0.3)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.1
			p.gravity = Vector3(0.0, -0.25, 0.0)
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
			p.angle_min = 0.0
			p.angle_max = 360.0
			quad.size = Vector2(0.2, 0.12)
			colors.set_color(0, Color("ffc6dd"))
			colors.set_color(1, Color(1.0, 0.7, 0.85, 0.0))
		"snow":
			p.amount = 140
			p.lifetime = 9.0
			p.position.y = 8.5
			p.direction = Vector3(0.2, -1.0, 0.1)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0.0, -0.2, 0.0)
			quad.size = Vector2(0.12, 0.12)
			colors.set_color(0, Color(1, 1, 1, 0.95))
			colors.set_color(1, Color(1, 1, 1, 0.0))
		"sparks":
			p.amount = 100
			p.lifetime = 6.0
			p.position.y = GROUND_Y + 0.5
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.9
			p.spread = 60.0
			quad.size = Vector2(0.1, 0.1)
			additive = true
			colors.set_color(0, Color("19f0ff"))
			colors.set_color(1, Color(1.0, 0.24, 0.82, 0.0))
		"dust":
			p.amount = 70
			p.lifetime = 7.0
			p.position.y = GROUND_Y + 1.2
			p.emission_box_extents = Vector3(20.0, 1.2, 20.0)
			p.direction = Vector3(1.0, 0.1, 0.2)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.4
			quad.size = Vector2(0.16, 0.16)
			colors.set_color(0, Color(0.95, 0.8, 0.55, 0.6))
			colors.set_color(1, Color(0.95, 0.8, 0.55, 0.0))
		"bubbles":
			p.amount = 90
			p.lifetime = 7.0
			p.position.y = GROUND_Y + 0.2
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.3
			p.gravity = Vector3(0.0, 0.15, 0.0)
			quad.size = Vector2(0.2, 0.2)
			texture = _ring_texture()
			colors.set_color(0, Color(1, 1, 1, 0.85))
			colors.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
		"sprinkles":
			p.amount = 110
			p.lifetime = 8.0
			p.position.y = 8.0
			p.direction = Vector3(0.1, -1.0, 0.0)
			p.initial_velocity_min = 0.7
			p.initial_velocity_max = 1.3
			p.gravity = Vector3(0.0, -0.25, 0.0)
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			quad.size = Vector2(0.06, 0.2)
			texture = null
			var palette := Gradient.new()
			palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			palette.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
			palette.colors = PackedColorArray([Color("ff5a8a"), Color("5ac8ff"), Color("ffd23f"), Color("7fe0a8")])
			p.color_initial_ramp = palette
			colors.set_color(0, Color(1, 1, 1, 1))
			colors.set_color(1, Color(1, 1, 1, 0.0))
		"fireflies":
			p.amount = 70
			p.lifetime = 6.0
			p.position.y = GROUND_Y + 1.0
			p.emission_box_extents = Vector3(18.0, 1.0, 18.0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			quad.size = Vector2(0.14, 0.14)
			additive = true
			colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			colors.colors = PackedColorArray([Color(0.8, 1.0, 0.3, 0.0), Color(0.85, 1.0, 0.35, 1.0), Color(0.8, 1.0, 0.3, 0.0)])
		"wisps":
			p.amount = 60
			p.lifetime = 7.0
			p.position.y = GROUND_Y + 0.4
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.spread = 40.0
			quad.size = Vector2(0.28, 0.28)
			additive = true
			colors.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
			colors.colors = PackedColorArray([Color(0.6, 1.0, 0.9, 0.0), Color(0.65, 1.0, 0.92, 0.7), Color(0.7, 0.6, 1.0, 0.0)])
		"sparkles":
			p.amount = 60
			p.lifetime = 4.0
			p.position.y = 2.5
			p.emission_box_extents = Vector3(18.0, 2.5, 18.0)
			p.spread = 180.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
			quad.size = Vector2(0.12, 0.12)
			additive = true
			colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			colors.colors = PackedColorArray([Color(1, 0.95, 0.6, 0.0), Color(1, 0.98, 0.8, 1.0), Color(1, 0.95, 0.6, 0.0)])
		"stardust":
			p.amount = 90
			p.lifetime = 6.0
			p.position.y = 0.0
			p.emission_box_extents = Vector3(22.0, 6.0, 22.0)
			p.spread = 180.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.25
			quad.size = Vector2(0.1, 0.1)
			additive = true
			colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			colors.colors = PackedColorArray([Color(0.8, 0.85, 1.0, 0.0), Color(0.9, 0.9, 1.0, 1.0), Color(0.8, 0.85, 1.0, 0.0)])
	p.color_ramp = colors
	p.preprocess = p.lifetime
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true  # Without it, unspawned particles draw as squares and size curves are ignored.
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if texture != null:
		m.albedo_texture = texture
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- Mesh building helpers --------------------------------------------------------------------

## Registers a toon colour. All toon decor sharing an outline width lands in one vertex-coloured
## mesh (one draw call plus its ink outline pass), however many colours an arena uses.
func _toon(key: String, color: Color, grow := 0.06, _shine := 0.0) -> String:
	var bucket := "toon_%d" % roundi(grow * 100.0)
	if not _groups.has(bucket):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 0.5
		if grow > 0.0:
			var ink := StandardMaterial3D.new()
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink.cull_mode = BaseMaterial3D.CULL_FRONT
			ink.albedo_color = INK
			ink.grow = true
			ink.grow_amount = grow
			m.next_pass = ink
		_groups[bucket] = _new_bucket(m)
	_keys[key] = {"bucket": bucket, "color": color}
	return key


## Registers an unshaded glowing colour; `energy` above 1 blooms with the environment glow.
func _glow(key: String, color: Color, energy := 1.6) -> String:
	var bucket := "glow_%d" % roundi(energy * 10.0)
	if not _groups.has(bucket):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_color = Color(energy, energy, energy)
		_groups[bucket] = _new_bucket(m)
	_keys[key] = {"bucket": bucket, "color": color}
	return key


func _new_bucket(material: Material) -> Dictionary:
	return {"material": material, "verts": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array()}


func _put(key: String, mesh: Mesh, at: Vector3, yaw := 0.0, size := Vector3.ONE, tilt := Vector3.ZERO) -> void:
	var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)) * Basis.from_scale(size)
	_append(key, mesh, Transform3D(basis, at))


## Like _put, but tips the mesh's up axis `angle` radians toward the horizontal direction `out`
## (cactus arms, branches).
func _put_along(key: String, mesh: Mesh, at: Vector3, out: Vector3, angle: float) -> void:
	var axis := Vector3.UP.cross(out).normalized()
	_append(key, mesh, Transform3D(Basis(axis, angle), at))


func _append(key: String, mesh: Mesh, xf: Transform3D) -> void:
	var info: Dictionary = _keys[key]
	var bucket: Dictionary = _groups[info["bucket"]]
	var arrays := mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xf.basis.inverse().transposed()
	var base: int = bucket["verts"].size()
	var verts: PackedVector3Array = bucket["verts"]
	var normals: PackedVector3Array = bucket["normals"]
	var colors: PackedColorArray = bucket["colors"]
	var indices: PackedInt32Array = bucket["indices"]
	var color: Color = info["color"]
	for i in src_verts.size():
		verts.append(xf * src_verts[i])
		normals.append((normal_basis * src_normals[i]).normalized())
		colors.append(color)
	if src_indices.is_empty():
		for i in src_verts.size():
			indices.append(base + i)
	else:
		for index in src_indices:
			indices.append(base + index)
	bucket["verts"] = verts
	bucket["normals"] = normals
	bucket["colors"] = colors
	bucket["indices"] = indices


func _commit_decor() -> void:
	for name_key: String in _groups:
		var bucket: Dictionary = _groups[name_key]
		var verts: PackedVector3Array = bucket["verts"]
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = bucket["normals"]
		arrays[Mesh.ARRAY_COLOR] = bucket["colors"]
		arrays[Mesh.ARRAY_INDEX] = bucket["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = name_key
		instance.mesh = mesh
		instance.material_override = bucket["material"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(instance)
	_groups.clear()
	_keys.clear()


## `count` ground positions spread around a ring between r_min and r_max (deterministic per arena).
func _ring(count: int, r_min: float, r_max: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var offset := _rng.randf() * TAU
	for i in count:
		var a := offset + TAU * (i + _rng.randf_range(-0.3, 0.3)) / count
		var r := _rng.randf_range(r_min, r_max)
		out.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	return out


func _vary(base: float, height: float, depth: float) -> Vector3:
	return Vector3(base * _rng.randf_range(0.7, 1.3), height * _rng.randf_range(0.7, 1.3), depth * _rng.randf_range(0.7, 1.3))


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m


func _cyl(top: float, bottom: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 10
	m.rings = 4
	return m


func _torus(inner: float, outer: float, rings := 24) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = 8
	return m


static var _textures: Dictionary = {}


func _dot_texture() -> Texture2D:
	if not _textures.has("dot"):
		_textures["dot"] = _radial(PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)]), PackedFloat32Array([0.0, 0.45, 1.0]))
	return _textures["dot"]


func _ring_texture() -> Texture2D:
	if not _textures.has("ring"):
		_textures["ring"] = _radial(PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]),
			PackedFloat32Array([0.0, 0.6, 0.82, 1.0]))
	return _textures["ring"]


static func _radial(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex
