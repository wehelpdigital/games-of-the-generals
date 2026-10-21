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
	"topper_tombstone": {"name": "Tombstone", "rarity": "rare", "kind": "object", "season": "halloween", "desc": "A mossy old grave with a shy little ghost floating above.",
		"swatch": [Color("9a94b0"), Color("5fa85a"), Color("ffffff")]},
	"topper_jack_o_lantern": {"name": "Jack-o'-Lantern", "rarity": "epic", "kind": "object", "season": "halloween", "desc": "A carved pumpkin with a flickering, glowing grin.",
		"swatch": [Color("ff8a1f"), Color("ffcf3f"), Color("4a6b2a")]},
	"topper_cauldron": {"name": "Witch's Cauldron", "rarity": "epic", "kind": "object", "season": "halloween", "desc": "Bubbling green brew over a little fire. Double, double...",
		"swatch": [Color("2a2d40"), Color("7dff5a"), Color("ff8a1f")]},
	"topper_parol": {"name": "Parol", "rarity": "epic", "kind": "object", "season": "christmas", "desc": "A glowing Filipino star lantern with ribbon tails, swaying on its stand.",
		"swatch": [Color("ffcf3f"), Color("e8344e"), Color("3d8bff")]},
	"topper_christmas_tree": {"name": "Christmas Tree", "rarity": "rare", "kind": "object", "season": "christmas", "desc": "A little pine with glowing baubles and a turning star.",
		"swatch": [Color("2f8f4e"), Color("ff4f5a"), Color("ffcf3f")]},
	"topper_twelve_fruits": {"name": "Twelve Round Fruits", "rarity": "rare", "kind": "object", "season": "new_year", "desc": "Twelve round fruits for twelve lucky months.",
		"swatch": [Color("ff9a1f"), Color("e8344e"), Color("8bd14a"), Color("8b5cf6")]},
	"topper_rose_bouquet": {"name": "Rose Bouquet", "rarity": "rare", "kind": "object", "season": "valentines", "desc": "Red roses in a glass vase, for your favourite opponent.",
		"swatch": [Color("e8344e"), Color("5fbf5a"), Color("bfe9ff")]},
	"topper_red_lantern": {"name": "Red Lantern", "rarity": "rare", "kind": "object", "season": "lunar_new_year", "desc": "A glowing red lantern with gold caps and a tassel.",
		"swatch": [Color("e8282e"), Color("ffcf3f"), Color("7a0f0f")]},
	"topper_turkey": {"name": "Proud Turkey", "rarity": "rare", "kind": "object", "season": "thanksgiving", "desc": "Fans its tail and nods along to every move.",
		"swatch": [Color("8a5a2a"), Color("e8a33a"), Color("e8344e")]},
	"topper_cornucopia": {"name": "Cornucopia", "rarity": "epic", "kind": "object", "season": "thanksgiving", "desc": "A horn of plenty spilling over with the harvest.",
		"swatch": [Color("c8944a"), Color("e8344e"), Color("ff9a1f"), Color("6a2a8a")]},
	"topper_sandcastle": {"name": "Sandcastle", "rarity": "common", "kind": "object", "season": "summer", "desc": "Four towers, a keep and a flag. And a bucket, of course.",
		"swatch": [Color("eccf8a"), Color("3d8bff"), Color("ff4f5a")]},
	"topper_bunny": {"name": "Egg Bunny", "rarity": "rare", "kind": "object", "season": "summer", "desc": "A fluffy bunny hugging a painted egg. Its ears never stop twitching.",
		"swatch": [Color("fff6f8"), Color("ffb3d1"), Color("8fd8ff")]},
	"topper_sun_standard": {"name": "Sun & Stars Standard", "rarity": "epic", "kind": "object", "season": "kalayaan", "desc": "A golden sun with three stars turning above blue, red and white ribbons.",
		"swatch": [Color("0038a8"), Color("ce1126"), Color("fcd116"), Color("fffdf5")]},
	"topper_lechon": {"name": "Lechon", "rarity": "epic", "kind": "object", "season": "fiesta", "desc": "The star of every fiesta: crispy, shiny, apple in its mouth.",
		"swatch": [Color("c8641e"), Color("e8344e"), Color("5fbf5a")]},
	"topper_jeepney": {"name": "Jeepney", "rarity": "legendary", "kind": "object", "season": "fiesta", "desc": "A chrome-horsed, rainbow-striped jeepney idling by your side.",
		"swatch": [Color("ff3d7f"), Color("ffd23f"), Color("27c98f"), Color("c7d0db")]},
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
		"topper_tombstone":
			return _tombstone()
		"topper_jack_o_lantern":
			return _jack_o_lantern()
		"topper_cauldron":
			return _cauldron()
		"topper_parol":
			return _parol()
		"topper_christmas_tree":
			return _christmas_tree()
		"topper_twelve_fruits":
			return _twelve_fruits()
		"topper_rose_bouquet":
			return _rose_bouquet()
		"topper_red_lantern":
			return _red_lantern()
		"topper_turkey":
			return _turkey()
		"topper_cornucopia":
			return _cornucopia()
		"topper_sandcastle":
			return _sandcastle()
		"topper_bunny":
			return _bunny()
		"topper_sun_standard":
			return _sun_standard()
		"topper_lechon":
			return _lechon()
		"topper_jeepney":
			return _jeepney()
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

# --- Holiday toppers -----------------------------------------------------------------------------

static func _tombstone() -> Dictionary:
	var stone := _c("9a94b0", 0.1)
	var parts := [
		_p("5fa85a", ShapeKit.sphere(0.26, 0.1, 18), Vector3(0, 0.02, 0)),
		_p(stone, ShapeKit.box(Vector3(0.36, 0.4, 0.12), 0.03, 0.02), Vector3(0, 0.25, 0)),
		_p(stone, ShapeKit.cylinder(0.18, 0.18, 0.12, 20), Vector3(0, 0.45, 0), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p("5a5470", ShapeKit.box(Vector3(0.03, 0.17, 0.02), 0.008, 0.004), Vector3(0, 0.34, 0.062), Basis.IDENTITY, 0.0),
		_p("5a5470", ShapeKit.box(Vector3(0.11, 0.03, 0.02), 0.008, 0.004), Vector3(0, 0.38, 0.062), Basis.IDENTITY, 0.0),
		_p("6aa86a", ShapeKit.sphere(0.04, 0.03, 8), Vector3(-0.13, 0.12, 0.07), Basis.IDENTITY, 0.0),
		_p("6aa86a", ShapeKit.sphere(0.03, 0.025, 8), Vector3(0.12, 0.2, 0.065), Basis.IDENTITY, 0.0),
	]
	var ghost := [
		_p(_c("ffffff", 0.2, 0.3, 0.85), ShapeKit.sphere(0.08, 0.14, 14), Vector3.ZERO),
		_p(_c("ffffff", 0.2, 0.3, 0.85), ShapeKit.cone(0.07, 0.1, 10), Vector3(0, -0.09, 0), _tilt(Vector3.RIGHT, PI)),
		_p("1d1736", ShapeKit.sphere(0.014, -1.0, 6), Vector3(-0.025, 0.02, 0.07), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.014, -1.0, 6), Vector3(0.025, 0.02, 0.07), Basis.IDENTITY, 0.0),
	]
	return {"parts": parts, "anims": [{"at": Vector3(0.12, 0.72, 0.02), "parts": ghost, "anim": {"kind": "bob", "amount": 0.05, "speed": 2.0}}]}


static func _jack_o_lantern() -> Dictionary:
	var orange := _c("ff8a1f", 0.3)
	var center := Vector3(0, 0.2, 0)
	var parts := [_p(orange, ShapeKit.sphere(0.21, 0.33, 22), center)]
	for i in 8:
		var a := TAU * i / 8.0
		parts.append(_p(orange, ShapeKit.sphere(0.12, 0.32, 14), center + Vector3(cos(a), 0, sin(a)) * 0.11, Basis.IDENTITY, 0.015))
	parts.append(_p("4a6b2a", ShapeKit.cylinder(0.025, 0.035, 0.1, 8), Vector3(0.01, 0.4, 0), _tilt(Vector3.BACK, -0.25)))
	parts.append(_p("5fbf5a", ShapeKit.sphere(0.05, 0.015, 8), Vector3(0.07, 0.38, 0.02), _tilt(Vector3.BACK, 0.4)))
	var lit := _c("ffcf3f", 0.0, 2.2)
	var tri := PackedVector2Array([Vector2(-0.04, -0.03), Vector2(0.04, -0.03), Vector2(0.0, 0.04)])
	var mouth := PackedVector2Array([Vector2(-0.11, 0.02), Vector2(-0.06, -0.01), Vector2(-0.03, 0.02), Vector2(0.0, -0.01),
		Vector2(0.03, 0.02), Vector2(0.06, -0.01), Vector2(0.11, 0.02), Vector2(0.07, -0.06), Vector2(-0.07, -0.06)])
	var face := [
		_p(lit, ShapeKit.prism(tri, 0.02, 0.004), Vector3(-0.075, 0.05, 0.0), Basis.IDENTITY, 0.0),
		_p(lit, ShapeKit.prism(tri, 0.02, 0.004), Vector3(0.075, 0.05, 0.0), Basis.IDENTITY, 0.0),
		_p(lit, ShapeKit.prism(mouth, 0.02, 0.004), Vector3(0.0, -0.05, 0.0), Basis.IDENTITY, 0.0),
	]
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.22, 0.205), "parts": face, "anim": {"kind": "pulse", "amount": 0.06, "speed": 9.0}}]}


static func _cauldron() -> Dictionary:
	var iron := _c("2a2d40", 0.5)
	var parts := [
		_p(iron, ShapeKit.sphere(0.2, 0.3, 20), Vector3(0, 0.19, 0)),
		_p(iron, ShapeKit.torus(0.15, 0.2, 22, 6), Vector3(0, 0.31, 0)),
		_p(_c("7dff5a", 0.2, 1.4), ShapeKit.cylinder(0.155, 0.155, 0.02, 20), Vector3(0, 0.305, 0), Basis.IDENTITY, 0.0),
		_p("ff8a1f", ShapeKit.cone(0.06, 0.12, 8), Vector3(-0.06, 0.04, 0.05), Basis.IDENTITY, 0.0),
		_p("ffcf3f", ShapeKit.cone(0.045, 0.1, 8), Vector3(0.05, 0.035, 0.06), Basis.IDENTITY, 0.0),
	]
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		parts.append(_p(iron, ShapeKit.cylinder(0.02, 0.025, 0.1, 6), Vector3(cos(a) * 0.13, 0.04, sin(a) * 0.13)))
	var anims: Array = []
	for i in 3:
		var a := TAU * i / 3.0
		anims.append({"at": Vector3(cos(a) * 0.07, 0.33, sin(a) * 0.07),
			"parts": [_p(_c("b8ff8a", 0.6, 0.6, 0.85), ShapeKit.sphere(0.035, -1.0, 10), Vector3.ZERO, Basis.IDENTITY, 0.0)],
			"anim": {"kind": "steam", "amount": 0.18, "speed": 0.9, "phase": i * 0.33}})
	anims.append({"at": Vector3(0, 0.42, 0), "parts": [_p(_c("9cff7a", 0.0, 0.4, 0.45), ShapeKit.sphere(0.08, 0.1, 12), Vector3.ZERO, Basis.IDENTITY, 0.0)],
		"anim": {"kind": "steam", "amount": 0.3, "speed": 0.5}})
	return {"parts": parts, "anims": anims}


static func _hanging_stand(base_color: String, pole_color: String, reach: float) -> Array:
	return [
		_p(base_color, ShapeKit.cylinder(0.12, 0.15, 0.06, 18), Vector3(0, 0.03, 0)),
		_p(pole_color, ShapeKit.cylinder(0.022, 0.026, 1.02, 10), Vector3(0, 0.54, 0)),
		_p(pole_color, ShapeKit.cylinder(0.016, 0.016, reach, 8), Vector3(reach * 0.5, 1.04, 0), _tilt(Vector3.BACK, PI / 2.0)),
		_p(pole_color, ShapeKit.sphere(0.03, -1.0, 10), Vector3(0, 1.06, 0)),
	]


static func _parol() -> Dictionary:
	var star := InsigniaFactory.star_polygon(5, 0.5, 0.24)
	var lantern := [
		_p("c8c0b0", ShapeKit.cylinder(0.005, 0.005, 0.12, 4), Vector3(0, -0.06, 0), Basis.IDENTITY, 0.0),
		_p(_c("ffcf3f", 0.2, 1.2), ShapeKit.prism(star, 0.32, 0.06), Vector3(0, -0.3, 0), Basis().scaled(Vector3.ONE * 0.38)),
		_p(_c("e8344e", 0.2, 1.4), ShapeKit.prism(star, 0.25, 0.04), Vector3(0, -0.3, 0.055), Basis().scaled(Vector3.ONE * 0.2), 0.0),
		_p(_c("ffffff", 0.0, 1.6), ShapeKit.sphere(0.03, -1.0, 8), Vector3(0, -0.3, 0.075), Basis.IDENTITY, 0.0),
		_p("e8344e", ShapeKit.box(Vector3(0.025, 0.26, 0.012), 0.008, 0.003), Vector3(-0.05, -0.6, 0), _tilt(Vector3.BACK, 0.12)),
		_p("ffffff", ShapeKit.box(Vector3(0.025, 0.24, 0.012), 0.008, 0.003), Vector3(0.0, -0.6, 0)),
		_p("3d8bff", ShapeKit.box(Vector3(0.025, 0.26, 0.012), 0.008, 0.003), Vector3(0.05, -0.6, 0), _tilt(Vector3.BACK, -0.12)),
	]
	return {"parts": _hanging_stand("8a2245", "b77a45", 0.3), "anims": [{"at": Vector3(0.28, 1.03, 0), "parts": lantern, "anim": {"kind": "sway", "amount": 0.08, "speed": 1.4}}]}


static func _christmas_tree() -> Dictionary:
	var green := _c("2f8f4e", 0.2)
	var parts := [
		_p("c8342d", ShapeKit.cylinder(0.12, 0.1, 0.12, 16), Vector3(0, 0.06, 0)),
		_p("6b3e22", ShapeKit.cylinder(0.04, 0.04, 0.1, 8), Vector3(0, 0.16, 0)),
	]
	var tiers := [[0.26, 0.28, 0.24], [0.2, 0.25, 0.38], [0.14, 0.22, 0.5]]
	for tier: Array in tiers:
		parts.append(_p(green, ShapeKit.cone(tier[0], tier[1], 18), Vector3(0, tier[2], 0)))
	var baubles := ["ff4f5a", "ffcf3f", "5fa8ff", "ff8ec0", "ffffff"]
	for i in 9:
		var tier: Array = tiers[i % 3]
		var a := TAU * i / 9.0 + 0.3
		var r: float = tier[0] * 0.62
		parts.append(_p(_c(baubles[i % baubles.size()], 0.6, 0.8), ShapeKit.sphere(0.032, -1.0, 10),
			Vector3(cos(a) * r, float(tier[2]) - 0.05, sin(a) * r), Basis.IDENTITY, 0.01))
	var star := [_p(_c("ffcf3f", 0.3, 1.4), ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.3, 0.06), Vector3.ZERO, Basis().scaled(Vector3.ONE * 0.16))]
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.66, 0), "parts": star, "anim": {"kind": "turn", "amount": 0.6, "speed": 1.2}}]}


static func _twelve_fruits() -> Dictionary:
	var parts := [
		_p("fff6e8", ShapeKit.cylinder(0.25, 0.15, 0.12, 22), Vector3(0, 0.06, 0)),
		_p(_c("ffcf3f", 0.8), ShapeKit.torus(0.235, 0.26, 26, 5), Vector3(0, 0.12, 0)),
	]
	var fruit := [["ff9a1f", 0.075], ["e8344e", 0.07], ["ffd23f", 0.065], ["8bd14a", 0.06], ["8b5cf6", 0.055], ["ff8ec0", 0.06],
		["ff9a1f", 0.07], ["e8344e", 0.065], ["c8e05a", 0.06], ["ffb020", 0.065], ["6a2a8a", 0.05], ["f4f0a0", 0.06]]
	for i in 12:
		var ring := 0 if i < 7 else (1 if i < 11 else 2)
		var in_ring: int = [7, 4, 1][ring]
		var k: int = i - int([0, 7, 11][ring])
		var a := TAU * k / in_ring + ring * 0.6
		var r: float = [0.15, 0.08, 0.0][ring]
		var info: Array = fruit[i]
		parts.append(_p(_c(info[0], 0.5), ShapeKit.sphere(info[1], -1.0, 12), Vector3(cos(a) * r, 0.17 + ring * 0.08, sin(a) * r), Basis.IDENTITY, 0.012))
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.42, 0), "parts": [_p(_c("fff1b0", 0.0, 1.4), ShapeKit.prism(InsigniaFactory.star_polygon(4, 0.5, 0.15), 0.1, 0.02), Vector3.ZERO, Basis().scaled(Vector3.ONE * 0.12), 0.0)],
		"anim": {"kind": "pulse", "amount": 0.4, "speed": 4.0}}]}


static func _rose_bouquet() -> Dictionary:
	var parts := [
		_p(_c("bfe9ff", 0.8, 0.0, 0.7), ShapeKit.cylinder(0.1, 0.075, 0.26, 18), Vector3(0, 0.13, 0)),
		_p("ff9ec7", ShapeKit.torus(0.095, 0.115, 18, 5), Vector3(0, 0.2, 0)),
	]
	var flowers: Array = []
	var stem := _c("3f9a4a", 0.2)
	for i in 5:
		var a := TAU * i / 5.0
		var top := Vector3(cos(a) * 0.08, 0.27 + (0.04 if i % 2 == 0 else 0.0), sin(a) * 0.08)
		flowers.append(_p(stem, ShapeKit.cylinder(0.008, 0.008, 0.26, 5), top * Vector3(0.5, 1.0, 0.5) - Vector3(0, 0.13, 0), _tilt(Vector3(sin(a), 0, -cos(a)), 0.25), 0.0))
		flowers.append(_p(_c("e8344e", 0.4), ShapeKit.sphere(0.06, 0.08, 14), top))
		flowers.append(_p(_c("b81f3a", 0.4), ShapeKit.sphere(0.035, 0.05, 10), top + Vector3(0, 0.03, 0), Basis.IDENTITY, 0.0))
		flowers.append(_p(_c("5fbf5a", 0.3), ShapeKit.sphere(0.045, 0.015, 8), top * Vector3(1.4, 0.8, 1.4) + Vector3(0, -0.02, 0), _tilt(Vector3(sin(a), 0, -cos(a)), 0.6), 0.0))
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.12, 0), "parts": flowers, "anim": {"kind": "sway", "amount": 0.05, "speed": 1.3}}]}


static func _turkey() -> Dictionary:
	var brown := _c("8a5a2a", 0.3)
	var parts := [
		_p(brown, ShapeKit.sphere(0.17, 0.26, 18), Vector3(0, 0.2, 0)),
		_p("ff9a1f", ShapeKit.cylinder(0.015, 0.015, 0.1, 6), Vector3(-0.05, 0.05, 0.02)),
		_p("ff9a1f", ShapeKit.cylinder(0.015, 0.015, 0.1, 6), Vector3(0.05, 0.05, 0.02)),
	]
	var tail: Array = []
	var feathers := ["c8641e", "e8a33a", "8a4a1e", "ffd23f", "c8641e", "e8a33a", "8a4a1e"]
	for i in 7:
		var a := lerpf(-1.25, 1.25, i / 6.0)
		var dir := Vector3(sin(a), cos(a), 0)
		tail.append(_p(_c(feathers[i], 0.3), ShapeKit.sphere(0.07, 0.3, 12), dir * 0.17, Basis(Vector3.BACK, -a), 0.015))
	var head := [
		_p(_c("c8956a", 0.3), ShapeKit.capsule(0.045, 0.16, 10), Vector3(0, 0.05, 0)),
		_p("ff9a1f", ShapeKit.cone(0.02, 0.05, 8), Vector3(0, 0.1, 0.05), _tilt(Vector3.RIGHT, PI / 2.0)),
		_p("e8344e", ShapeKit.sphere(0.022, 0.05, 8), Vector3(0, 0.06, 0.05), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(-0.025, 0.12, 0.035), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(0.025, 0.12, 0.035), Basis.IDENTITY, 0.0),
	]
	return {"parts": parts, "anims": [
		{"at": Vector3(0, 0.24, -0.1), "parts": tail, "anim": {"kind": "pulse", "amount": 0.05, "speed": 2.2}},
		{"at": Vector3(0, 0.3, 0.12), "parts": head, "anim": {"kind": "nod", "amount": 0.25, "speed": 3.0}},
	]}


static func _cornucopia() -> Dictionary:
	var wicker := _c("c8944a", 0.2)
	var parts: Array = []
	var points: Array[Vector3] = []
	for i in 7:
		var t := i / 6.0
		points.append(Vector3(lerpf(0.16, -0.22, t), 0.16 + 0.12 * t * t + 0.02 * sin(t * PI), lerpf(0.04, -0.06, t)))
	for i in 6:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var axis := (b - a).normalized()
		var r_a := lerpf(0.15, 0.025, i / 6.0)
		var r_b := lerpf(0.15, 0.025, (i + 1) / 6.0)
		parts.append(_p(wicker, ShapeKit.cylinder(r_b, r_a, (b - a).length() + 0.02, 16), (a + b) * 0.5, Basis(Quaternion(Vector3.UP, axis))))
	parts.append(_p(_c("a8783a", 0.2), ShapeKit.torus(0.13, 0.16, 20, 5), points[0] + Vector3(0.01, 0, 0), _tilt(Vector3.BACK, PI / 2.0 + 0.2)))
	var spill := [["e8344e", Vector3(0.24, 0.07, 0.05), 0.06], ["ff9a1f", Vector3(0.3, 0.06, -0.06), 0.065], ["ffd23f", Vector3(0.2, 0.06, 0.13), 0.05],
		["6a2a8a", Vector3(0.33, 0.05, 0.08), 0.035], ["6a2a8a", Vector3(0.35, 0.05, 0.04), 0.035], ["6a2a8a", Vector3(0.36, 0.08, 0.07), 0.035],
		["8bd14a", Vector3(0.16, 0.12, -0.02), 0.05], ["ff8a1f", Vector3(0.13, 0.2, 0.06), 0.06]]
	for f: Array in spill:
		parts.append(_p(_c(f[0], 0.4), ShapeKit.sphere(f[2], -1.0, 12), f[1], Basis.IDENTITY, 0.012))
	parts.append(_p(_c("ffd23f", 0.3), ShapeKit.capsule(0.03, 0.16, 10), Vector3(0.24, 0.045, -0.12), _tilt(Vector3.BACK, PI / 2.0 - 0.3)))
	return {"parts": parts}


static func _sandcastle() -> Dictionary:
	var sand := _c("eccf8a", 0.1)
	var parts := [_p(sand, ShapeKit.box(Vector3(0.48, 0.4, 0.12), 0.05, 0.02), Vector3(0, 0.06, 0), ShapeKit.FLAT)]
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var at := Vector3(cos(a) * 0.19, 0, sin(a) * 0.16)
		parts.append(_p(sand, ShapeKit.cylinder(0.06, 0.07, 0.24, 12), at + Vector3(0, 0.24, 0)))
		parts.append(_p(_c("e0b86a", 0.1), ShapeKit.cone(0.07, 0.1, 12), at + Vector3(0, 0.41, 0)))
	parts.append(_p(sand, ShapeKit.cylinder(0.1, 0.11, 0.3, 14), Vector3(0, 0.27, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		parts.append(_p(sand, ShapeKit.box(Vector3(0.04, 0.05, 0.04), 0.01, 0.005), Vector3(cos(a) * 0.085, 0.445, sin(a) * 0.085), Basis.IDENTITY, 0.012))
	parts.append(_p("3d8bff", ShapeKit.cylinder(0.06, 0.05, 0.1, 14), Vector3(0.3, 0.05, 0.12)))
	parts.append(_p("3d8bff", ShapeKit.torus(0.05, 0.06, 14, 4), Vector3(0.3, 0.11, 0.12), _tilt(Vector3.RIGHT, PI / 2.0), 0.0))
	var flag := [
		_p("fff6e8", ShapeKit.cylinder(0.006, 0.006, 0.18, 5), Vector3(0, 0.09, 0), Basis.IDENTITY, 0.0),
		_p("ff4f5a", ShapeKit.prism(PackedVector2Array([Vector2(0, 0.04), Vector2(0.1, 0.0), Vector2(0, -0.04)]), 0.01, 0.002), Vector3(0, 0.15, 0), Basis.IDENTITY, 0.008),
	]
	return {"parts": parts, "anims": [{"at": Vector3(0, 0.45, 0), "parts": flag, "anim": {"kind": "turn", "amount": 0.4, "speed": 2.0}}]}


static func _bunny() -> Dictionary:
	var fur := _c("fff6f8", 0.2)
	var parts := [
		_p(fur, ShapeKit.sphere(0.15, 0.24, 18), Vector3(0, 0.15, 0)),
		_p(fur, ShapeKit.sphere(0.11, -1.0, 16), Vector3(0, 0.34, 0.04)),
		_p(fur, ShapeKit.sphere(0.05, -1.0, 10), Vector3(0, 0.1, -0.15), Basis.IDENTITY, 0.012),
		_p("1d1736", ShapeKit.sphere(0.015, -1.0, 6), Vector3(-0.04, 0.37, 0.13), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.015, -1.0, 6), Vector3(0.04, 0.37, 0.13), Basis.IDENTITY, 0.0),
		_p("ff8ec0", ShapeKit.sphere(0.018, -1.0, 6), Vector3(0, 0.33, 0.145), Basis.IDENTITY, 0.0),
		_p(_c("8fd8ff", 0.4), ShapeKit.sphere(0.055, 0.14, 12), Vector3(0, 0.15, 0.15), Basis.IDENTITY, 0.012),
		_p(_c("ff8ec0", 0.4), ShapeKit.torus(0.05, 0.058, 14, 4), Vector3(0, 0.15, 0.15), Basis.IDENTITY, 0.0),
	]
	var ear := func(x: float) -> Array:
		return [_p(fur, ShapeKit.capsule(0.035, 0.22, 10), Vector3(0, 0.1, 0)),
			_p("ffb3d1", ShapeKit.capsule(0.018, 0.15, 8), Vector3(0, 0.1, 0.022), Basis.IDENTITY, 0.0)]
	return {"parts": parts, "anims": [
		{"at": Vector3(-0.05, 0.42, 0.02), "parts": ear.call(-0.05), "anim": {"kind": "sway", "amount": 0.18, "speed": 2.0}},
		{"at": Vector3(0.05, 0.42, 0.02), "parts": ear.call(0.05), "anim": {"kind": "sway", "amount": 0.18, "speed": 2.0, "phase": 1.7}},
	]}


static func _lechon() -> Dictionary:
	var skin := _c("c8641e", 0.8)
	var parts := [
		_p("5fbf5a", ShapeKit.sphere(0.36, 0.03, 20), Vector3(0, 0.015, 0), Basis().scaled(Vector3(1.0, 1.0, 0.7)), 0.0),
		_p(skin, ShapeKit.capsule(0.12, 0.46, 16), Vector3(-0.02, 0.13, 0), _tilt(Vector3.BACK, PI / 2.0)),
		_p(skin, ShapeKit.sphere(0.1, -1.0, 14), Vector3(0.24, 0.15, 0)),
		_p(skin, ShapeKit.cylinder(0.045, 0.055, 0.08, 12), Vector3(0.33, 0.14, 0), _tilt(Vector3.BACK, PI / 2.0)),
		_p(_c("e8344e", 0.6), ShapeKit.sphere(0.045, -1.0, 12), Vector3(0.39, 0.13, 0)),
		_p(skin, ShapeKit.cone(0.035, 0.07, 8), Vector3(0.22, 0.25, 0.05), _tilt(Vector3.RIGHT, 0.3)),
		_p(skin, ShapeKit.cone(0.035, 0.07, 8), Vector3(0.22, 0.25, -0.05), _tilt(Vector3.RIGHT, -0.3)),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(0.3, 0.19, 0.06), Basis.IDENTITY, 0.0),
		_p("1d1736", ShapeKit.sphere(0.012, -1.0, 6), Vector3(0.3, 0.19, -0.06), Basis.IDENTITY, 0.0),
	]
	for leg: Vector3 in [Vector3(0.12, 0.05, 0.08), Vector3(0.12, 0.05, -0.08), Vector3(-0.16, 0.05, 0.08), Vector3(-0.16, 0.05, -0.08)]:
		parts.append(_p(skin, ShapeKit.capsule(0.03, 0.1, 8), leg, _tilt(Vector3.BACK, PI / 2.0), 0.012))
	var steam: Array = []
	for i in 2:
		steam.append({"at": Vector3(-0.06 + i * 0.12, 0.28, 0),
			"parts": [_p(_c("ffffff", 0.0, 0.0, 0.55), ShapeKit.sphere(0.04, -1.0, 10), Vector3.ZERO, Basis.IDENTITY, 0.0)],
			"anim": {"kind": "steam", "amount": 0.22, "speed": 0.7, "phase": i * 0.5}})
	return {"parts": parts, "anims": steam}


static func _jeepney() -> Dictionary:
	var body := [
		_p("ff3d7f", ShapeKit.box(Vector3(0.5, 0.22, 0.26), 0.04, 0.015), Vector3(-0.04, 0.17, 0)),
		_p("ff3d7f", ShapeKit.box(Vector3(0.18, 0.14, 0.24), 0.03, 0.012), Vector3(0.28, 0.13, 0)),
		_p("ffffff", ShapeKit.box(Vector3(0.56, 0.035, 0.29), 0.012, 0.006), Vector3(-0.03, 0.3, 0)),
		_p("ffd23f", ShapeKit.box(Vector3(0.5, 0.03, 0.27), 0.01, 0.005), Vector3(-0.04, 0.12, 0), Basis.IDENTITY, 0.0),
		_p("27c98f", ShapeKit.box(Vector3(0.5, 0.02, 0.27), 0.008, 0.004), Vector3(-0.04, 0.095, 0), Basis.IDENTITY, 0.0),
		_p("3a3f5a", ShapeKit.box(Vector3(0.36, 0.08, 0.265), 0.015, 0.006), Vector3(-0.08, 0.23, 0), Basis.IDENTITY, 0.0),
		_p("3a3f5a", ShapeKit.box(Vector3(0.02, 0.08, 0.2), 0.008, 0.004), Vector3(0.19, 0.23, 0), Basis.IDENTITY, 0.0),
		_p(_c("c7d0db", 0.9), ShapeKit.box(Vector3(0.02, 0.08, 0.2), 0.008, 0.004), Vector3(0.375, 0.12, 0), Basis.IDENTITY, 0.0),
		_p(_c("fff1b0", 0.0, 1.6), ShapeKit.sphere(0.022, -1.0, 8), Vector3(0.375, 0.16, 0.08), Basis.IDENTITY, 0.0),
		_p(_c("fff1b0", 0.0, 1.6), ShapeKit.sphere(0.022, -1.0, 8), Vector3(0.375, 0.16, -0.08), Basis.IDENTITY, 0.0),
		_p(_c("c7d0db", 0.9), ShapeKit.cone(0.02, 0.07, 6), Vector3(0.3, 0.23, 0.05), Basis.IDENTITY, 0.008),
		_p(_c("c7d0db", 0.9), ShapeKit.cone(0.02, 0.07, 6), Vector3(0.3, 0.23, -0.05), Basis.IDENTITY, 0.008),
		_p("8b5cf6", ShapeKit.box(Vector3(0.14, 0.05, 0.02), 0.01, 0.004), Vector3(0.18, 0.345, 0), Basis.IDENTITY, 0.008),
	]
	for wheel: Vector3 in [Vector3(0.22, 0.05, 0.13), Vector3(0.22, 0.05, -0.13), Vector3(-0.19, 0.05, 0.13), Vector3(-0.19, 0.05, -0.13)]:
		body.append(_p("1d1736", ShapeKit.cylinder(0.05, 0.05, 0.035, 14), wheel, _tilt(Vector3.RIGHT, PI / 2.0)))
	return {"parts": [], "anims": [{"at": Vector3.ZERO, "parts": body, "anim": {"kind": "bob", "amount": 0.006, "speed": 14.0}}]}


static func _red_lantern() -> Dictionary:
	var lantern := [
		_p("c8c0b0", ShapeKit.cylinder(0.005, 0.005, 0.1, 4), Vector3(0, -0.05, 0), Basis.IDENTITY, 0.0),
		_p(_c("ffcf3f", 0.7), ShapeKit.cylinder(0.07, 0.08, 0.04, 14), Vector3(0, -0.12, 0)),
		_p(_c("e8282e", 0.3, 0.7), ShapeKit.sphere(0.15, 0.26, 18), Vector3(0, -0.27, 0)),
		_p(_c("ffcf3f", 0.7), ShapeKit.cylinder(0.08, 0.07, 0.04, 14), Vector3(0, -0.42, 0)),
		_p(_c("ffcf3f", 0.6), ShapeKit.cylinder(0.008, 0.008, 0.08, 5), Vector3(0, -0.48, 0), Basis.IDENTITY, 0.0),
		_p("e8282e", ShapeKit.cone(0.035, 0.12, 8), Vector3(0, -0.57, 0), _tilt(Vector3.RIGHT, PI)),
	]
	for i in 4:
		var a := TAU * i / 4.0
		lantern.append(_p(_c("ffcf3f", 0.6), ShapeKit.torus(0.145, 0.155, 18, 3), Vector3(0, -0.27, 0), Basis(Vector3.UP, a) * _tilt(Vector3.RIGHT, PI / 2.0), 0.0))
	return {"parts": _hanging_stand("7a0f0f", "b77a45", 0.3), "anims": [{"at": Vector3(0.28, 1.03, 0), "parts": lantern, "anim": {"kind": "sway", "amount": 0.07, "speed": 1.2}}]}


static func _sun_standard() -> Dictionary:
	var parts := [
		_p("0038a8", ShapeKit.cylinder(0.13, 0.16, 0.08, 20), Vector3(0, 0.04, 0)),
		_p(_c("ffcf3f", 0.8), ShapeKit.cylinder(0.022, 0.026, 1.0, 10), Vector3(0, 0.56, 0)),
	]
	var ribbons := [
		_p("0038a8", ShapeKit.box(Vector3(0.04, 0.34, 0.012), 0.012, 0.004), Vector3(-0.03, -0.17, 0), _tilt(Vector3.BACK, 0.1)),
		_p("ce1126", ShapeKit.box(Vector3(0.04, 0.3, 0.012), 0.012, 0.004), Vector3(0.03, -0.15, 0), _tilt(Vector3.BACK, -0.1)),
		_p("fffdf5", ShapeKit.box(Vector3(0.03, 0.24, 0.012), 0.01, 0.004), Vector3(0.0, -0.12, 0.004)),
	]
	var sun := [_p(_c("fcd116", 0.5, 0.8), ShapeKit.cylinder(0.075, 0.075, 0.035, 20), Vector3.ZERO, _tilt(Vector3.RIGHT, PI / 2.0))]
	for i in 8:
		var a := TAU * i / 8.0
		sun.append(_p(_c("fcd116", 0.5, 0.8), ShapeKit.prism(PackedVector2Array([Vector2(-0.025, 0.0), Vector2(0.025, 0.0), Vector2(0.0, 0.08)]), 0.03, 0.006),
			Vector3(cos(a + PI / 2.0), sin(a + PI / 2.0), 0) * 0.08, Basis(Vector3.BACK, a), 0.01))
	for i in 3:
		var a := PI / 2.0 + TAU * i / 3.0
		sun.append(_p(_c("fcd116", 0.5, 0.8), ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.25, 0.05), Vector3(cos(a), sin(a), 0) * 0.2, Basis().scaled(Vector3.ONE * 0.09), 0.01))
	return {"parts": parts, "anims": [
		{"at": Vector3(0, 1.08, 0), "parts": sun, "anim": {"kind": "spin_z", "speed": 0.4}},
		{"at": Vector3(0, 0.98, 0.03), "parts": ribbons, "anim": {"kind": "sway", "amount": 0.12, "speed": 1.6}},
	]}
