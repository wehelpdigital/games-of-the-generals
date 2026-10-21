class_name PropKit
extends RefCounted
## Little toon props for effects (bazookas, wizard hats, toy soldiers, saucers...): ShapeKit parts
## baked once per key into one mesh plus an ink outline, with shared toon materials. Roles are
## colour strings "rrggbb", optionally with "|g<glow>" (emission) or "|a<alpha>" (see-through).
##
##     var hat := PropKit.model("wizard_hat", [PropKit.pt("6a3cff", ShapeKit.cone(0.2, 0.4), Vector3(0, 0.2, 0))])

const INK := Color("1d1736")

static var _baked: Dictionary = {}
static var _materials: Dictionary = {}


static func model(key: String, parts: Array) -> Node3D:
	if not _baked.has(key):
		_baked[key] = ShapeKit.bake(parts)
	var baked: Dictionary = _baked[key]
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = baked["mesh"]
	var roles: Array = baked["roles"]
	for i in roles.size():
		mesh.set_surface_override_material(i, material(str(roles[i])))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	if baked["hull"] != null:
		var hull := MeshInstance3D.new()
		hull.mesh = baked["hull"]
		hull.material_override = CosmeticLibrary.outline_material(INK)
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hull)
	return root


static func material(role: String) -> Material:
	if _materials.has(role):
		return _materials[role]
	var bits := role.split("|")
	var m := CosmeticLibrary.toon(Color(bits[0]), 0.2)
	for extra: String in bits.slice(1):
		if extra.begins_with("g"):
			m.emission_enabled = true
			m.emission = Color(bits[0])
			m.emission_energy_multiplier = float(extra.substr(1))
		elif extra.begins_with("a"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = float(extra.substr(1))
	_materials[role] = m
	return m


## One part: colour role, mesh maker, position, rotation (Euler), outline width (0 = none).
static func pt(role: String, maker: Callable, pos: Vector3, rot := Vector3.ZERO, hull := 0.018) -> Dictionary:
	return ShapeKit.part(role, maker, Transform3D(Basis.from_euler(rot), pos), hull)
