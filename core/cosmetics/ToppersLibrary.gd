class_name ToppersLibrary
extends RefCounted
## Table toppers: little toys, plants and flags a player puts beside their half of the board (up to
## three, see Toppers3D). The opponent sees them too. Every toy is built from primitives (ShapeKit)
## in flat toon colours with an ink outline, baked once and shared; moving parts are separate nodes
## tagged with an "anim" meta that Toppers3D plays (sway, spin, bob, wave...).
##
## Flag items are poles; the cloth is the player's own design (FlagFactory) stored in the loadout.

const STYLES := {
	"topper_flag_wood": {"name": "Field Flag", "rarity": "common", "kind": "flag", "desc": "A wooden pole for a flag you design yourself: shape, colours, emblem or your own picture.",
		"swatch": [Color("b77a45"), Color("e8344e"), Color("ffd23f")]},
	"topper_flag_steel": {"name": "Steel Standard", "rarity": "rare", "kind": "flag", "desc": "A polished steel standard with a spear tip. Fly your own design.",
		"swatch": [Color("c7d0db"), Color("3d8bff"), Color("1d1736")]},
	"topper_flag_gold": {"name": "Golden Banner", "rarity": "epic", "kind": "flag", "desc": "A gold pole crowned with a star, for a flag worth saluting.",
		"swatch": [Color("ffd54a"), Color("e0a520"), Color("8b5cf6")]},
	"topper_cactus": {"name": "Potted Cactus", "rarity": "common", "kind": "object", "desc": "A prickly little buddy with a pink flower.",
		"swatch": [Color("5fbf5a"), Color("e07a4a"), Color("ff8fbf")]},
	"topper_succulent": {"name": "Succulent", "rarity": "common", "kind": "object", "desc": "A chubby rosette in a pastel pot. Low maintenance, high vibes.",
		"swatch": [Color("8fd8a8"), Color("bfe9ff"), Color("ff9ec7")]},
	"topper_bonsai": {"name": "Bonsai", "rarity": "rare", "kind": "object", "desc": "A patient little tree for a patient strategist.",
		"swatch": [Color("4fae58"), Color("7a4a2a"), Color("2f5d9e")]},
	"topper_sunflower": {"name": "Sunflower", "rarity": "common", "kind": "object", "desc": "Always faces the sunny side of the board.",
		"swatch": [Color("ffd23f"), Color("6b3e22"), Color("5fbf5a")]},
	"topper_rubber_duck": {"name": "Rubber Duck", "rarity": "common", "kind": "object", "desc": "Your loyal debugging partner, now a battle advisor.",
		"swatch": [Color("ffd23f"), Color("ff8a1f"), Color("1d1736")]},
	"topper_toy_robot": {"name": "Toy Robot", "rarity": "rare", "kind": "object", "desc": "Beep boop. Scans the board with glowing eyes.",
		"swatch": [Color("7fd6ff"), Color("c7d0db"), Color("ff5a5f")]},
	"topper_teddy": {"name": "Teddy Bear", "rarity": "rare", "kind": "object", "desc": "A soft general with a dapper bow tie.",
		"swatch": [Color("b77a45"), Color("f3d7a6"), Color("e8344e")]},
	"topper_toy_tank": {"name": "Toy Tank", "rarity": "rare", "kind": "object", "desc": "A wind-up tank whose turret keeps watch.",
		"swatch": [Color("6f8f4e"), Color("3c4a2e"), Color("ffd23f")]},
	"topper_rocket": {"name": "Toy Rocket", "rarity": "epic", "kind": "object", "desc": "Hovers on a flickering flame, ready for lift-off.",
		"swatch": [Color("ffffff"), Color("e8344e"), Color("3d8bff"), Color("ffb020")]},
	"topper_dino": {"name": "Dino Buddy", "rarity": "epic", "kind": "object", "desc": "A tiny dinosaur nodding along to your every move.",
		"swatch": [Color("6fd06a"), Color("ffd23f"), Color("2c7a3a")]},
	"topper_trophy": {"name": "Champion Trophy", "rarity": "epic", "kind": "object", "desc": "A slowly spinning gold cup. Remind them who won last time.",
		"swatch": [Color("ffd54a"), Color("e0a520"), Color("4a2a1a")]},
	"topper_lucky_cat": {"name": "Lucky Cat", "rarity": "rare", "kind": "object", "desc": "Waves its paw to beckon good fortune your way.",
		"swatch": [Color("ffffff"), Color("e8344e"), Color("ffd54a")]},
	"topper_snow_globe": {"name": "Snow Globe", "rarity": "epic", "kind": "object", "desc": "A tiny winter forest with snow that never stops falling.",
		"swatch": [Color("dff4ff"), Color("2f8f4a"), Color("c8342d")]},
	"topper_lava_lamp": {"name": "Lava Lamp", "rarity": "epic", "kind": "object", "desc": "Groovy blobs drift up and down. Very chill. Very strategic.",
		"swatch": [Color("ff6a1a"), Color("8b5cf6"), Color("c7d0db")]},
	"topper_coffee_mug": {"name": "Coffee Mug", "rarity": "common", "kind": "object", "desc": "Steaming hot fuel for long matches.",
		"swatch": [Color("27c98f"), Color("6b3e22"), Color("ffffff")]},
	"topper_mini_fan": {"name": "Mini Fan", "rarity": "rare", "kind": "object", "desc": "Keeps your cool when the game heats up.",
		"swatch": [Color("7fd6ff"), Color("ffffff"), Color("1d1736")]},
	"topper_piggy_bank": {"name": "Piggy Bank", "rarity": "common", "kind": "object", "desc": "Saving up credits for the next legendary.",
		"swatch": [Color("ff9ec7"), Color("ff6f9f"), Color("1d1736")]},
	"topper_crystal_ball": {"name": "Crystal Ball", "rarity": "legendary", "kind": "object", "desc": "Swirling with visions of your opponent's next move (probably).",
		"swatch": [Color("b05cff"), Color("2ef6ff"), Color("1b1440")]},
}

const MAX_SLOTS := 3
const OUTLINE := 0.022
const INK := Color("1d1736")

static var _baked: Dictionary = {}     # "slug/index" -> ShapeKit.bake result
static var _materials: Dictionary = {}


static func exists(slug: String) -> bool:
	return STYLES.has(slug)


static func kind_of(slug: String) -> String:
	return str(STYLES.get(slug, {}).get("kind", "object"))


static func flag_slugs() -> Array:
	return STYLES.keys().filter(func(s: String) -> bool: return kind_of(s) == "flag")


static func object_slugs() -> Array:
	return STYLES.keys().filter(func(s: String) -> bool: return kind_of(s) == "object")


## A valid `toppers` loadout value: {slots: [{kind, slug, flag?}]} with at most three known items
## (flag designs normalised).
static func sanitize(config: Variant) -> Dictionary:
	var slots: Array = []
	var raw_slots: Variant = config.get("slots") if config is Dictionary else null
	if raw_slots is Array:
		for raw: Variant in raw_slots:
			if slots.size() >= MAX_SLOTS:
				break
			if not raw is Dictionary or not STYLES.has(str(raw.get("slug", ""))):
				continue
			var slug := str(raw["slug"])
			var slot := {"kind": kind_of(slug), "slug": slug}
			if slot["kind"] == "flag":
				slot["flag"] = FlagFactory.normalize(raw.get("flag", {}))
			slots.append(slot)
	return {"slots": slots}


## One to three random toppers (practice opponents, Randomize).
static func random_config() -> Dictionary:
	var slots: Array = []
	for i in randi_range(1, MAX_SLOTS):
		if randf() < 0.35:
			slots.append({"kind": "flag", "slug": flag_slugs().pick_random(), "flag": FlagFactory.random_design()})
		else:
			slots.append({"kind": "object", "slug": object_slugs().pick_random()})
	return {"slots": slots}


## A ready-to-place toy (for flags: the pole only; Toppers3D adds the cloth). The node's local
## +Z faces its owner; it stands on y = 0. Moving parts carry meta "anim".
static func create(slug: String) -> Node3D:
	var root := Node3D.new()
	root.name = slug
	var spec := _spec(slug)
	_add_baked(root, "%s/0" % slug, spec["parts"])
	var anims: Array = spec.get("anims", [])
	for i in anims.size():
		var a: Dictionary = anims[i]
		var node := Node3D.new()
		node.position = a.get("at", Vector3.ZERO)
		if a.has("parts"):
			_add_baked(node, "%s/%d" % [slug, i + 1], a["parts"])
		if a.has("mesh"):
			var raw := MeshInstance3D.new()
			raw.mesh = a["mesh"]
			raw.material_override = a["material"]
			raw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(raw)
		node.set_meta("anim", a["anim"])
		root.add_child(node)
	if spec.has("anim"):
		root.set_meta("anim", spec["anim"])
	return root


## Where a flag's cloth hangs from (top of the pole), in the topper's local space.
static func flag_mount(_slug: String) -> Vector3:
	return Vector3(0.02, 1.22, 0.0)


static func _add_baked(node: Node3D, key: String, parts: Array) -> void:
	if parts.is_empty():
		return
	if not _baked.has(key):
		_baked[key] = ShapeKit.bake(parts)
	var baked: Dictionary = _baked[key]
	var mesh := MeshInstance3D.new()
	mesh.mesh = baked["mesh"]
	var roles: Array = baked["roles"]
	for i in roles.size():
		mesh.set_surface_override_material(i, _material(roles[i]))
	node.add_child(mesh)
	if baked["hull"] != null:
		var hull := MeshInstance3D.new()
		hull.mesh = baked["hull"]
		hull.material_override = CosmeticLibrary.outline_material(INK)
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(hull)


## Part helpers: colour, maker, position, optional basis, outline width.
static func _p(color: Variant, maker: Callable, pos: Vector3, basis := Basis.IDENTITY, hull := OUTLINE) -> Dictionary:
	var role: Dictionary = color if color is Dictionary else {"color": Color(str(color)), "shine": 0.25, "glow": 0.0, "alpha": 1.0}
	return ShapeKit.part(role, maker, Transform3D(basis, pos), hull)


static func _c(hex: String, shine := 0.25, glow := 0.0, alpha := 1.0) -> Dictionary:
	return {"color": Color(hex), "shine": shine, "glow": glow, "alpha": alpha}


static func _material(role: Variant) -> Material:
	var key := str(role)
	if _materials.has(key):
		return _materials[key]
	var r: Dictionary = role
	var m := CosmeticLibrary.toon(r["color"], r["shine"])
	if r["glow"] > 0.0:
		m.emission_enabled = true
		m.emission = r["color"]
		m.emission_energy_multiplier = r["glow"]
	if r["alpha"] < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = r["alpha"]
		m.rim_enabled = true
		m.rim = 0.6
	_materials[key] = m
	return m


static func _tilt(axis: Vector3, angle: float) -> Basis:
	return Basis(axis.normalized(), angle)


## A terracotta-style pot: [parts], top of the soil at y = height.
static func _pot(color: String, radius := 0.2, height := 0.26, soil := "5a3a24") -> Array:
	var r := radius
	var profile := PackedVector2Array([Vector2(r * 0.75, 0), Vector2(r * 0.95, height * 0.78),
		Vector2(r * 0.95, height * 0.78), Vector2(r * 1.12, height * 0.78), Vector2(r * 1.12, height), Vector2(r * 0.98, height)])
	return [
		_p(color, ShapeKit.lathe(profile, 24), Vector3.ZERO),
		_p(soil, ShapeKit.cylinder(r * 0.95, r * 0.95, 0.02, 20), Vector3(0, height - 0.012, 0), Basis.IDENTITY, 0.0),
	]


# --- Toys ----------------------------------------------------------------------------------------

static func _spec(slug: String) -> Dictionary:
	match slug:
		"topper_flag_wood", "topper_flag_steel", "topper_flag_gold":
			return _flag_pole(slug)
		"topper_cactus":
			return _cactus()
		"topper_succulent":
			return _succulent()
		"topper_bonsai":
			return _bonsai()
		"topper_sunflower":
			return _sunflower()
		"topper_rubber_duck":
			return _duck()
		"topper_toy_robot":
			return _robot()
		"topper_teddy":
			return _teddy()
		"topper_toy_tank":
			return _tank()
		"topper_rocket":
			return _rocket()
		"topper_dino":
			return _dino()
		"topper_trophy":
			return _trophy()
		"topper_lucky_cat":
			return _lucky_cat()
		"topper_snow_globe":
			return _snow_globe()
		"topper_lava_lamp":
			return _lava_lamp()
		"topper_coffee_mug":
			return _mug()
		"topper_mini_fan":
			return _fan()
		"topper_piggy_bank":
			return _piggy()
		"topper_crystal_ball":
			return _crystal_ball()
	return _cactus()


static func _flag_pole(slug: String) -> Dictionary:
	var pole := {"topper_flag_wood": _c("b77a45", 0.2), "topper_flag_steel": _c("c7d0db", 0.9), "topper_flag_gold": _c("ffcf3f", 0.9)}[slug] as Dictionary
	var base := {"topper_flag_wood": "6b3e22", "topper_flag_steel": "4f5a74", "topper_flag_gold": "8a2245"}[slug] as String
	var parts := [
		_p(base, ShapeKit.cylinder(0.13, 0.16, 0.08, 20), Vector3(0, 0.04, 0)),
		_p(pole, ShapeKit.cylinder(0.025, 0.03, 1.25, 12), Vector3(0, 0.66, 0)),
	]
	match slug:
		"topper_flag_wood":
			parts.append(_p(_c("ffd23f", 0.5), ShapeKit.sphere(0.05, -1.0, 14), Vector3(0, 1.31, 0)))
		"topper_flag_steel":
			parts.append(_p(pole, ShapeKit.cone(0.05, 0.14, 12), Vector3(0, 1.35, 0)))
		"topper_flag_gold":
			var star := ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.25, 0.05)
			parts.append(_p(pole, star, Vector3(0, 1.38, 0), Basis().scaled(Vector3.ONE * 0.16)))
	return {"parts": parts}


static func _cactus() -> Dictionary:
	var green := _c("5fbf5a", 0.3)
	var plant := [
		_p(green, ShapeKit.capsule(0.095, 0.46, 16), Vector3(0, 0.2, 0)),
		_p(green, ShapeKit.capsule(0.055, 0.2, 12), Vector3(0.15, 0.24, 0)),
		_p(green, ShapeKit.capsule(0.05, 0.13, 12), Vector3(0.09, 0.15, 0), _tilt(Vector3.BACK, PI / 2.0)),
		_p(green, ShapeKit.capsule(0.05, 0.17, 12), Vector3(-0.14, 0.16, 0)),
		_p(green, ShapeKit.capsule(0.045, 0.12, 12), Vector3(-0.085, 0.09, 0), _tilt(Vector3.BACK, PI / 2.0)),
		_p("ff8fbf", ShapeKit.sphere(0.06, 0.05, 12), Vector3(0, 0.45, 0)),
		_p("ffd23f", ShapeKit.sphere(0.025, -1.0, 8), Vector3(0, 0.475, 0), Basis.IDENTITY, 0.0),
	]
	for p: Vector3 in [Vector3(0.04, 0.3, 0.09), Vector3(-0.05, 0.12, 0.09), Vector3(0.06, 0.05, 0.08), Vector3(-0.03, 0.36, 0.09)]:
		plant.append(_p("f6ffe8", ShapeKit.sphere(0.012, -1.0, 6), p, Basis.IDENTITY, 0.0))
	return {"parts": _pot("e07a4a"), "anims": [{"at": Vector3(0, 0.25, 0), "parts": plant, "anim": {"kind": "sway", "amount": 0.06, "speed": 1.6}}]}


static func _succulent() -> Dictionary:
	var leaves: Array = []
	for ring in 3:
		var count := 7 - ring
		var tilt := 1.1 - ring * 0.35
		for i in count:
			var a := TAU * (i + ring * 0.5) / count
			var dir := Vector3(cos(a), 0, sin(a))
			var basis := Basis(dir.cross(Vector3.UP).normalized(), -tilt) * Basis(Vector3.UP, -a)
			var color := _c("8fd8a8" if ring < 2 else "b4ecc4", 0.35)
			leaves.append(_p(color, ShapeKit.sphere(0.06, 0.2, 12), dir * (0.08 - ring * 0.025) + Vector3(0, 0.05 + ring * 0.035, 0), basis, 0.015))
	leaves.append(_p("ff9ec7", ShapeKit.sphere(0.035, -1.0, 10), Vector3(0, 0.16, 0), Basis.IDENTITY, 0.012))
	return {"parts": _pot("bfe9ff", 0.19, 0.22), "anims": [{"at": Vector3(0, 0.22, 0), "parts": leaves, "anim": {"kind": "pulse", "amount": 0.03, "speed": 1.4}}]}


static func _bonsai() -> Dictionary:
	var tray := [
		_p("2f5d9e", ShapeKit.box(Vector3(0.62, 0.36, 0.1), 0.08, 0.025), Vector3(0, 0.05, 0), ShapeKit.FLAT),
		_p("5a3a24", ShapeKit.box(Vector3(0.54, 0.28, 0.02), 0.06, 0.005), Vector3(0, 0.1, 0), ShapeKit.FLAT, 0.0),
	]
	var bark := _c("7a4a2a", 0.15)
	var leaf := _c("4fae58", 0.3)
	var tree := [
		_p(bark, ShapeKit.capsule(0.045, 0.3, 10), Vector3(0.03, 0.12, 0), _tilt(Vector3.BACK, -0.35)),
		_p(bark, ShapeKit.capsule(0.035, 0.28, 10), Vector3(-0.04, 0.32, 0), _tilt(Vector3.BACK, 0.6)),
		_p(bark, ShapeKit.capsule(0.03, 0.2, 10), Vector3(0.1, 0.3, 0), _tilt(Vector3.BACK, -0.9)),
		_p(leaf, ShapeKit.sphere(0.16, 0.13, 16), Vector3(-0.12, 0.44, 0)),
		_p(leaf, ShapeKit.sphere(0.13, 0.11, 16), Vector3(0.18, 0.37, 0.02)),
		_p(_c("6cc96e", 0.3), ShapeKit.sphere(0.12, 0.1, 16), Vector3(0.02, 0.52, -0.03)),
	]
	return {"parts": tray, "anims": [{"at": Vector3(0, 0.1, 0), "parts": tree, "anim": {"kind": "sway", "amount": 0.035, "speed": 1.1}}]}


static func _sunflower() -> Dictionary:
	var stem := _c("4fae58", 0.25)
	var plant := [
		_p(stem, ShapeKit.cylinder(0.022, 0.026, 0.5, 8), Vector3(0, 0.25, 0)),
		_p(stem, ShapeKit.sphere(0.07, 0.025, 10), Vector3(0.07, 0.2, 0), _tilt(Vector3.BACK, 0.5)),
		_p(stem, ShapeKit.sphere(0.06, 0.022, 10), Vector3(-0.06, 0.32, 0), _tilt(Vector3.BACK, -0.5)),
	]
	var head := [_p("6b3e22", ShapeKit.cylinder(0.085, 0.085, 0.04, 20), Vector3.ZERO, _tilt(Vector3.RIGHT, PI / 2.0))]
	for i in 12:
		var a := TAU * i / 12.0
		var dir := Vector3(cos(a), sin(a), 0)
		head.append(_p(_c("ffd23f", 0.35), ShapeKit.sphere(0.04, 0.13, 10), dir * 0.13, Basis(Vector3.BACK, a - PI / 2.0), 0.012))
	return {"parts": _pot("e07a4a", 0.17, 0.22), "anims": [
		{"at": Vector3(0, 0.22, 0), "parts": plant, "anim": {"kind": "sway", "amount": 0.05, "speed": 1.3}},
		{"at": Vector3(0, 0.74, 0.02), "parts": head, "anim": {"kind": "turn", "amount": 0.35, "speed": 0.6}},
	]}


static func _duck() -> Dictionary:
	var yellow := _c("ffd23f", 0.45)
	var duck := [
		_p(yellow, ShapeKit.sphere(0.21, 0.3, 20), Vector3(0, 0.15, -0.02)),
		_p(yellow, ShapeKit.sphere(0.06, 0.12, 10), Vector3(0, 0.25, -0.2), _tilt(Vector3.RIGHT, -0.8)),
		_p(yellow, ShapeKit.sphere(0.13, -1.0, 18), Vector3(0, 0.38, 0.08)),
		_p(_c("ff8a1f", 0.4), ShapeKit.sphere(0.07, 0.04, 12), Vector3(0, 0.36, 0.21)),
		_p("1d1736", ShapeKit.sphere(0.02, -1.0, 8), Vector3(0.06, 0.42, 0.18), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.02, -1.0, 8), Vector3(-0.06, 0.42, 0.18), Basis.IDENTITY, 0.0),
		_p(_c("ffc21f", 0.4), ShapeKit.sphere(0.09, 0.05, 12), Vector3(0.18, 0.17, 0.0), _tilt(Vector3.BACK, 0.4)),
		_p(_c("ffc21f", 0.4), ShapeKit.sphere(0.09, 0.05, 12), Vector3(-0.18, 0.17, 0.0), _tilt(Vector3.BACK, -0.4)),
	]
	return {"parts": [], "anims": [{"parts": duck, "anim": {"kind": "rock", "amount": 0.08, "speed": 1.8}}]}


static func _robot() -> Dictionary:
	var shell := _c("7fd6ff", 0.6)
	var metal := _c("c7d0db", 0.8)
	var body := [
		_p(metal, ShapeKit.box(Vector3(0.09, 0.14, 0.1), 0.02, 0.01), Vector3(0.07, 0.07, 0)),
		_p(metal, ShapeKit.box(Vector3(0.09, 0.14, 0.1), 0.02, 0.01), Vector3(-0.07, 0.07, 0)),
		_p(shell, ShapeKit.box(Vector3(0.3, 0.26, 0.2), 0.05, 0.02), Vector3(0, 0.27, 0)),
		_p(_c("ffd23f", 0.4, 0.6), ShapeKit.cylinder(0.04, 0.04, 0.02, 12), Vector3(0, 0.29, 0.105), _tilt(Vector3.RIGHT, PI / 2.0), 0.0),
		_p(metal, ShapeKit.capsule(0.035, 0.2, 10), Vector3(0.19, 0.25, 0), _tilt(Vector3.BACK, 0.25)),
		_p(metal, ShapeKit.capsule(0.035, 0.2, 10), Vector3(-0.19, 0.25, 0), _tilt(Vector3.BACK, -0.25)),
	]
	var head := [
		_p(metal, ShapeKit.box(Vector3(0.26, 0.18, 0.2), 0.05, 0.02), Vector3(0, 0.09, 0)),
		_p(_c("22f2ff", 0.5, 1.6), ShapeKit.sphere(0.03, -1.0, 10), Vector3(0.06, 0.1, 0.1), Basis.IDENTITY, 0.01),
		_p(_c("22f2ff", 0.5, 1.6), ShapeKit.sphere(0.03, -1.0, 10), Vector3(-0.06, 0.1, 0.1), Basis.IDENTITY, 0.01),
		_p(metal, ShapeKit.cylinder(0.01, 0.01, 0.12, 6), Vector3(0, 0.24, 0), Basis.IDENTITY, 0.008),
		_p(_c("ff5a5f", 0.5, 1.2), ShapeKit.sphere(0.035, -1.0, 10), Vector3(0, 0.31, 0), Basis.IDENTITY, 0.012),
	]
	return {"parts": body, "anims": [{"at": Vector3(0, 0.4, 0), "parts": head, "anim": {"kind": "turn", "amount": 0.5, "speed": 0.9}}]}


static func _teddy() -> Dictionary:
	var fur := _c("b77a45", 0.15)
	var light := _c("f3d7a6", 0.15)
	var bear := [
		_p(fur, ShapeKit.sphere(0.17, 0.26, 18), Vector3(0, 0.15, 0)),
		_p(light, ShapeKit.sphere(0.1, 0.14, 14), Vector3(0, 0.15, 0.1)),
		_p(fur, ShapeKit.sphere(0.065, -1.0, 12), Vector3(0.11, 0.04, 0.09)),
		_p(fur, ShapeKit.sphere(0.065, -1.0, 12), Vector3(-0.11, 0.04, 0.09)),
		_p(fur, ShapeKit.capsule(0.05, 0.16, 10), Vector3(0.16, 0.18, 0.03), _tilt(Vector3.BACK, 0.7)),
		_p(fur, ShapeKit.capsule(0.05, 0.16, 10), Vector3(-0.16, 0.18, 0.03), _tilt(Vector3.BACK, -0.7)),
		_p(fur, ShapeKit.sphere(0.14, -1.0, 18), Vector3(0, 0.38, 0)),
		_p(fur, ShapeKit.sphere(0.05, -1.0, 10), Vector3(0.1, 0.5, -0.01)),
		_p(fur, ShapeKit.sphere(0.05, -1.0, 10), Vector3(-0.1, 0.5, -0.01)),
		_p(light, ShapeKit.sphere(0.06, 0.05, 12), Vector3(0, 0.35, 0.12)),
		_p("1d1736", ShapeKit.sphere(0.022, -1.0, 8), Vector3(0, 0.37, 0.175), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.017, -1.0, 8), Vector3(0.05, 0.42, 0.12), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.017, -1.0, 8), Vector3(-0.05, 0.42, 0.12), Basis.IDENTITY, 0.0),
		_p("e8344e", ShapeKit.prism(PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0.04), Vector2(0.07, -0.04)]), 0.03, 0.008), Vector3(0.0, 0.26, 0.12)),
		_p("e8344e", ShapeKit.prism(PackedVector2Array([Vector2(0, 0), Vector2(-0.07, -0.04), Vector2(-0.07, 0.04)]), 0.03, 0.008), Vector3(0.0, 0.26, 0.12)),
	]
	return {"parts": [], "anims": [{"parts": bear, "anim": {"kind": "rock", "amount": 0.05, "speed": 1.1}}]}


static func _tank() -> Dictionary:
	var olive := _c("6f8f4e", 0.25)
	var dark := _c("3c4a2e", 0.2)
	var hull := [
		_p(dark, ShapeKit.capsule(0.06, 0.46, 12), Vector3(0.14, 0.06, 0), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p(dark, ShapeKit.capsule(0.06, 0.46, 12), Vector3(-0.14, 0.06, 0), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p(olive, ShapeKit.box(Vector3(0.3, 0.4, 0.1), 0.05, 0.025), Vector3(0, 0.12, 0), ShapeKit.FLAT),
		_p("ffd23f", ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.1, 0.02), Vector3(0, 0.176, 0.12), ShapeKit.FLAT.scaled(Vector3.ONE * 0.09), 0.0),
	]
	var turret := [
		_p(olive, ShapeKit.sphere(0.12, 0.12, 16), Vector3.ZERO),
		_p(olive, ShapeKit.cylinder(0.022, 0.026, 0.26, 10), Vector3(0, 0.01, 0.16), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p(dark, ShapeKit.cylinder(0.035, 0.035, 0.02, 10), Vector3(0, 0.06, -0.02), Basis.IDENTITY, 0.01),
	]
	return {"parts": hull, "anims": [{"at": Vector3(0, 0.19, -0.02), "parts": turret, "anim": {"kind": "turn", "amount": 0.7, "speed": 0.5}}]}


static func _rocket() -> Dictionary:
	var white := _c("ffffff", 0.5)
	var red := _c("e8344e", 0.45)
	var body := PackedVector2Array([Vector2(0.07, 0), Vector2(0.1, 0.08), Vector2(0.11, 0.25), Vector2(0.1, 0.4)])
	var rocket := [
		_p(white, ShapeKit.lathe(body, 20), Vector3.ZERO),
		_p(red, ShapeKit.cone(0.1, 0.18, 20), Vector3(0, 0.49, 0)),
		_p(_c("3d8bff", 0.8), ShapeKit.cylinder(0.045, 0.045, 0.02, 14), Vector3(0, 0.27, 0.105), _tilt(Vector3.RIGHT, PI / 2.0), 0.012),
	]
	for i in 3:
		var a := TAU * i / 3.0 + PI / 2.0
		var fin := PackedVector2Array([Vector2(0, 0), Vector2(0.12, -0.02), Vector2(0, 0.16)])
		rocket.append(_p(red, ShapeKit.prism(fin, 0.025, 0.006), Vector3(cos(a) * 0.08, 0.02, sin(a) * 0.08), Basis(Vector3.UP, -a)))
	var flame := [_p(_c("ffb020", 0.2, 2.2), ShapeKit.cone(0.06, 0.16, 12), Vector3.ZERO, _tilt(Vector3.RIGHT, PI), 0.0)]
	return {"parts": [_p("4f5a74", ShapeKit.cylinder(0.12, 0.14, 0.04, 16), Vector3(0, 0.02, 0))],
		"anims": [
			{"at": Vector3(0, 0.16, 0), "parts": rocket, "anim": {"kind": "bob", "amount": 0.03, "speed": 2.0}},
			{"at": Vector3(0, 0.1, 0), "parts": flame, "anim": {"kind": "flicker", "amount": 0.3, "speed": 9.0}},
		]}


static func _dino() -> Dictionary:
	var green := _c("6fd06a", 0.3)
	var belly := _c("d9f7a8", 0.2)
	var body := [
		_p(green, ShapeKit.sphere(0.16, 0.24, 18), Vector3(0, 0.2, -0.02), _tilt(Vector3.RIGHT, 0.3)),
		_p(belly, ShapeKit.sphere(0.1, 0.16, 14), Vector3(0, 0.2, 0.08)),
		_p(green, ShapeKit.cone(0.1, 0.3, 14), Vector3(0, 0.12, -0.22), _tilt(Vector3.RIGHT, -1.9)),
		_p(green, ShapeKit.capsule(0.05, 0.14, 10), Vector3(0.09, 0.06, 0.02)),
		_p(green, ShapeKit.capsule(0.05, 0.14, 10), Vector3(-0.09, 0.06, 0.02)),
	]
	for i in 4:
		body.append(_p("ffd23f", ShapeKit.cone(0.035, 0.07, 8), Vector3(0, 0.33 - i * 0.06, -0.08 - i * 0.06), _tilt(Vector3.RIGHT, -0.5 - i * 0.25), 0.012))
	var head := [
		_p(green, ShapeKit.capsule(0.055, 0.2, 10), Vector3(0, 0.06, 0)),
		_p(green, ShapeKit.sphere(0.1, 0.09, 14), Vector3(0, 0.16, 0.05)),
		_p("1d1736", ShapeKit.sphere(0.018, -1.0, 8), Vector3(0.05, 0.19, 0.12), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.018, -1.0, 8), Vector3(-0.05, 0.19, 0.12), Basis.IDENTITY, 0.0),
	]
	return {"parts": body, "anims": [{"at": Vector3(0, 0.28, 0.06), "parts": head, "anim": {"kind": "nod", "amount": 0.18, "speed": 2.2}}]}


static func _trophy() -> Dictionary:
	var gold := _c("ffcf3f", 0.95)
	var cup := PackedVector2Array([Vector2(0.02, 0), Vector2(0.03, 0.12), Vector2(0.06, 0.16), Vector2(0.15, 0.26), Vector2(0.17, 0.36)])
	var trophy := [
		_p(gold, ShapeKit.lathe(cup, 24), Vector3.ZERO),
		_p(gold, ShapeKit.cylinder(0.08, 0.1, 0.03, 18), Vector3(0, 0.015, 0)),
		_p(gold, ShapeKit.torus(0.05, 0.075, 16, 6), Vector3(0.17, 0.26, 0), _tilt(Vector3.RIGHT, PI / 2.0), 0.012),
		_p(gold, ShapeKit.torus(0.05, 0.075, 16, 6), Vector3(-0.17, 0.26, 0), _tilt(Vector3.RIGHT, PI / 2.0), 0.012),
		_p(_c("e8344e", 0.6), ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.15, 0.03), Vector3(0, 0.22, 0.11), Basis().scaled(Vector3.ONE * 0.12), 0.012),
	]
	return {"parts": [_p("4a2a1a", ShapeKit.box(Vector3(0.3, 0.3, 0.12), 0.04, 0.02), Vector3(0, 0.06, 0), ShapeKit.FLAT)],
		"anims": [{"at": Vector3(0, 0.12, 0), "parts": trophy, "anim": {"kind": "spin", "speed": 0.6}}]}


static func _lucky_cat() -> Dictionary:
	var white := _c("ffffff", 0.35)
	var cat := [
		_p(white, ShapeKit.sphere(0.16, 0.26, 18), Vector3(0, 0.14, 0)),
		_p(white, ShapeKit.sphere(0.15, 0.14 * 2.0, 18), Vector3(0, 0.38, 0)),
		_p(white, ShapeKit.cone(0.05, 0.08, 8), Vector3(0.09, 0.5, -0.01), _tilt(Vector3.BACK, -0.35)),
		_p(white, ShapeKit.cone(0.05, 0.08, 8), Vector3(-0.09, 0.5, -0.01), _tilt(Vector3.BACK, 0.35)),
		_p("1d1736", ShapeKit.capsule(0.012, 0.05, 6), Vector3(0.055, 0.4, 0.135), _tilt(Vector3.BACK, PI / 2.0), 0.0),
		_p("1d1736", ShapeKit.capsule(0.012, 0.05, 6), Vector3(-0.055, 0.4, 0.135), _tilt(Vector3.BACK, PI / 2.0), 0.0),
		_p("ff8fbf", ShapeKit.sphere(0.018, -1.0, 8), Vector3(0, 0.36, 0.15), Basis.IDENTITY, 0.0),
		_p(_c("e8344e", 0.4), ShapeKit.torus(0.1, 0.13, 20, 6), Vector3(0, 0.26, 0.01)),
		_p(_c("ffcf3f", 0.9), ShapeKit.sphere(0.035, -1.0, 10), Vector3(0, 0.23, 0.13), Basis.IDENTITY, 0.012),
		_p(white, ShapeKit.capsule(0.045, 0.12, 10), Vector3(-0.11, 0.16, 0.1), _tilt(Vector3.RIGHT, 0.6)),
		_p(_c("ffcf3f", 0.9), ShapeKit.cylinder(0.05, 0.05, 0.015, 14), Vector3(-0.1, 0.12, 0.14), _tilt(Vector3.RIGHT, 1.1), 0.01),
	]
	var paw := [_p(white, ShapeKit.capsule(0.045, 0.16, 10), Vector3(0, 0.07, 0)), _p("ff8fbf", ShapeKit.sphere(0.02, -1.0, 8), Vector3(0, 0.13, 0.035), Basis.IDENTITY, 0.0)]
	return {"parts": cat, "anims": [{"at": Vector3(0.13, 0.28, 0.06), "parts": paw, "anim": {"kind": "wave", "amount": 0.55, "speed": 3.5}}]}


static func _snow_globe() -> Dictionary:
	var base := PackedVector2Array([Vector2(0.18, 0), Vector2(0.2, 0.06), Vector2(0.16, 0.12)])
	var parts := [
		_p("c8342d", ShapeKit.lathe(base, 24), Vector3.ZERO),
		_p("ffffff", ShapeKit.sphere(0.14, 0.05, 18), Vector3(0, 0.13, 0), Basis.IDENTITY, 0.0),
		_p("2f8f4a", ShapeKit.cone(0.07, 0.16, 10), Vector3(0, 0.22, 0), Basis.IDENTITY, 0.0),
		_p("2f8f4a", ShapeKit.cone(0.05, 0.1, 10), Vector3(0, 0.29, 0), Basis.IDENTITY, 0.0),
		_p(_c("dff4ff", 0.9, 0.0, 0.3), ShapeKit.sphere(0.19, -1.0, 28), Vector3(0, 0.29, 0), Basis.IDENTITY, 0.0),
	]
	var flakes: Array = []
	for i in 9:
		var a := TAU * i / 9.0
		flakes.append(_p(_c("ffffff", 0.2, 0.4), ShapeKit.sphere(0.012, -1.0, 6), Vector3(cos(a) * (0.06 + (i % 3) * 0.035), (i % 4) * 0.05 - 0.07, sin(a) * 0.1), Basis.IDENTITY, 0.0))
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.29, 0), "parts": flakes, "anim": {"kind": "spin", "speed": 0.8}}]}


static func _lava_lamp() -> Dictionary:
	var metal := _c("c7d0db", 0.85)
	var base := PackedVector2Array([Vector2(0.15, 0), Vector2(0.09, 0.16)])
	var glass := PackedVector2Array([Vector2(0.085, 0.16), Vector2(0.11, 0.3), Vector2(0.075, 0.56)])
	var parts := [
		_p(metal, ShapeKit.lathe(base, 20), Vector3.ZERO),
		_p(_c("8b5cf6", 0.6, 0.35, 0.55), ShapeKit.lathe(glass, 20), Vector3.ZERO, Basis.IDENTITY, 0.0),
		_p(metal, ShapeKit.cone(0.075, 0.12, 20), Vector3(0, 0.62, 0)),
	]
	var anims: Array = []
	for i in 3:
		anims.append({"at": Vector3(0.01 * (i - 1), 0.3, 0), "parts": [_p(_c("ff6a1a", 0.3, 1.4), ShapeKit.sphere(0.045 - i * 0.008, 0.06 - i * 0.01, 12), Vector3.ZERO, Basis.IDENTITY, 0.0)],
			"anim": {"kind": "float", "amount": 0.12, "speed": 0.5 + i * 0.17, "phase": i * 2.1}})
	return {"parts": parts, "anims": anims}


static func _mug() -> Dictionary:
	var mug := PackedVector2Array([Vector2(0, 0), Vector2(0.13, 0), Vector2(0.13, 0), Vector2(0.135, 0.24), Vector2(0.135, 0.24), Vector2(0.11, 0.24)])
	var parts := [
		_p(_c("27c98f", 0.45), ShapeKit.lathe(mug, 24), Vector3.ZERO),
		_p(_c("6b3e22", 0.6), ShapeKit.cylinder(0.11, 0.11, 0.01, 20), Vector3(0, 0.215, 0), Basis.IDENTITY, 0.0),
		_p(_c("27c98f", 0.45), ShapeKit.torus(0.05, 0.075, 16, 8), Vector3(0.14, 0.12, 0), _tilt(Vector3.RIGHT, PI / 2.0), 0.015),
		_p("ffffff", ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.05, 0.01), Vector3(0, 0.13, 0.13), Basis().scaled(Vector3.ONE * 0.09), 0.0),
	]
	var steam: Array = []
	for i in 3:
		steam.append({"at": Vector3(0.02 * (i - 1), 0.25, 0), "parts": [_p(_c("ffffff", 0.0, 0.3, 0.7), ShapeKit.sphere(0.04, -1.0, 10), Vector3.ZERO, Basis.IDENTITY, 0.0)],
			"anim": {"kind": "steam", "speed": 0.45, "phase": i / 3.0, "amount": 0.28}})
	return {"parts": parts, "anims": steam}


static func _fan() -> Dictionary:
	var light := _c("7fd6ff", 0.5)
	var parts := [
		_p(light, ShapeKit.cylinder(0.12, 0.15, 0.05, 20), Vector3(0, 0.025, 0)),
		_p("ffffff", ShapeKit.cylinder(0.02, 0.025, 0.36, 8), Vector3(0, 0.2, 0)),
		_p(light, ShapeKit.sphere(0.06, 0.08, 12), Vector3(0, 0.42, -0.04), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p("ffffff", ShapeKit.torus(0.17, 0.19, 32, 6), Vector3(0, 0.42, 0.03), _tilt(Vector3.RIGHT, PI / 2.0), 0.012),
	]
	var blades: Array = [_p("1d1736", ShapeKit.sphere(0.03, -1.0, 10), Vector3.ZERO, Basis.IDENTITY, 0.0)]
	for i in 3:
		var a := TAU * i / 3.0
		blades.append(_p(_c("ffffff", 0.4, 0.0, 0.9), ShapeKit.sphere(0.055, 0.28, 10), Vector3(cos(a), sin(a), 0) * 0.09, Basis(Vector3.BACK, a - PI / 2.0) * Basis(Vector3.UP, 0.4), 0.0))
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.42, 0.03), "parts": blades, "anim": {"kind": "spin_z", "speed": 14.0}}]}


static func _piggy() -> Dictionary:
	var pink := _c("ff9ec7", 0.4)
	var pig := [
		_p(pink, ShapeKit.sphere(0.18, 0.26, 20), Vector3(0, 0.19, 0), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p(_c("ff6f9f", 0.4), ShapeKit.cylinder(0.06, 0.065, 0.06, 14), Vector3(0, 0.19, 0.2), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(0.022, 0.19, 0.232), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(-0.022, 0.19, 0.232), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.018, -1.0, 8), Vector3(0.07, 0.26, 0.13), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.018, -1.0, 8), Vector3(-0.07, 0.26, 0.13), Basis.IDENTITY, 0.0),
		_p(pink, ShapeKit.cone(0.05, 0.08, 8), Vector3(0.09, 0.34, 0.05), _tilt(Vector3(1, 0, 1), -0.4)),
		_p(pink, ShapeKit.cone(0.05, 0.08, 8), Vector3(-0.09, 0.34, 0.05), _tilt(Vector3(-1, 0, 1), 0.4)),
		_p("1d1736", ShapeKit.box(Vector3(0.1, 0.02, 0.03), 0.008, 0.004), Vector3(0, 0.375, -0.02), ShapeKit.FLAT, 0.0),
		_p(_c("ffcf3f", 0.9), ShapeKit.cylinder(0.04, 0.04, 0.012, 14), Vector3(0, 0.39, -0.02), _tilt(Vector3.RIGHT, PI / 2.0), 0.008),
	]
	for x: float in [0.1, -0.1]:
		for z: float in [0.09, -0.09]:
			pig.append(_p(pink, ShapeKit.cylinder(0.04, 0.04, 0.08, 10), Vector3(x, 0.04, z)))
	return {"parts": [], "anims": [{"parts": pig, "anim": {"kind": "rock", "amount": 0.04, "speed": 1.4}}]}


static func _crystal_ball() -> Dictionary:
	var stand := PackedVector2Array([Vector2(0.16, 0), Vector2(0.17, 0.04), Vector2(0.1, 0.08), Vector2(0.12, 0.13)])
	var parts := [
		_p(_c("ffcf3f", 0.9), ShapeKit.lathe(stand, 24), Vector3.ZERO),
		_p(_c("1b1440", 0.4), ShapeKit.torus(0.1, 0.135, 24, 6), Vector3(0, 0.13, 0), Basis.IDENTITY, 0.012),
	]
	var ball := SphereMesh.new()
	ball.radius = 0.17
	ball.height = 0.34
	ball.radial_segments = 32
	ball.rings = 16
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.29, 0), "mesh": ball, "material": _crystal_material(), "anim": {"kind": "pulse", "amount": 0.02, "speed": 2.0}}]}


static func _crystal_material() -> ShaderMaterial:
	if _materials.has("crystal"):
		return _materials["crystal"]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 p = UV * vec2(6.2832, 3.1416);
	float swirl = sin(p.x * 2.0 + TIME * 1.4 + sin(p.y * 3.0 - TIME * 0.9) * 2.0) * 0.5 + 0.5;
	vec3 col = mix(vec3(0.42, 0.18, 0.85), vec3(0.18, 0.95, 1.0), swirl * 0.8);
	col = mix(col, vec3(1.0), pow(1.0 - rim, 5.0) * 0.55);
	col = mix(col, vec3(0.11, 0.09, 0.21), smoothstep(0.72, 0.8, rim));
	ALBEDO = col;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	_materials["crystal"] = m
	return m
