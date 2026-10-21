class_name Toppers3D
extends Node3D
## Up to three table toppers beside one player's half of the board, each on a little pedestal
## bolted to the board frame (outside the playing area, so they never cover a cell). Built from the
## loadout's `toppers` value ({slots: [{kind, slug, flag?}]}); both players see both sets. Toy
## parts animate here (ToppersLibrary "anim" metas); flag cloth waves in its shader.

## Pedestal spots in white's frame (+Z is white's side); black's set is turned half a turn.
const SPOTS := [Vector3(-5.62, 0, 3.0), Vector3(5.62, 0, 3.0), Vector3(5.62, 0, 1.25)]
const TOY_SCALE := 1.3

var side := Ranks.WHITE

var _key := ""
var _theme := CosmeticLibrary.DEFAULT_BOARD
var _pedestals: Array[MeshInstance3D] = []
var _anims: Array[Dictionary] = []  # {node, anim, base}
var _time := 0.0

static var _pedestal_geo: Dictionary
static var _cloth: PlaneMesh


## Rebuilds the toppers when anything changed. `local_images`: flags may show pictures saved only
## on this device (the player's own side, before or without an upload).
func configure(for_side: String, config: Dictionary, guild_logo_url: String, local_images: bool, theme: String) -> void:
	_theme = theme
	var key := JSON.stringify([for_side, config, guild_logo_url, local_images])
	if key == _key:
		set_board_theme(theme)
		return
	_key = key
	side = for_side
	rotation.y = 0.0 if side == Ranks.WHITE else PI
	for child in get_children():
		child.queue_free()
	_anims.clear()
	_pedestals.clear()
	var slots: Array = ToppersLibrary.sanitize(config)["slots"]
	for i in slots.size():
		_build_slot(SPOTS[i], slots[i], guild_logo_url, local_images)


func set_board_theme(slug: String) -> void:
	_theme = slug
	for pedestal in _pedestals:
		if is_instance_valid(pedestal):
			pedestal.set_surface_override_material(0, CosmeticLibrary.board_material(_theme, "frame"))


func _process(delta: float) -> void:
	_time += delta
	for entry in _anims:
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.transform = entry["base"] * _pose(entry["anim"])


func _build_slot(spot: Vector3, slot: Dictionary, guild_logo_url: String, local_images: bool) -> void:
	var outward := signf(spot.x)
	var holder := Node3D.new()
	holder.position = Vector3(spot.x, Board3D.FRAME_TOP, spot.z)
	add_child(holder)
	_add_pedestal(holder, outward)

	var slug: String = slot["slug"]
	var toy := ToppersLibrary.create(slug)
	holder.add_child(toy)
	if slot["kind"] == "flag":
		_add_flag(toy, slug, slot.get("flag", {}), outward, guild_logo_url, local_images)
	else:
		toy.rotation.y = -outward * 0.45  # Turn a little toward the board.
		toy.scale = Vector3.ONE * TOY_SCALE
	_collect_anims(toy)


func _add_pedestal(holder: Node3D, outward: float) -> void:
	if _pedestal_geo.is_empty():
		_pedestal_geo = ShapeKit.bake([
			ShapeKit.part("frame", ShapeKit.cylinder(0.44, 0.4, 0.12, 32), ShapeKit.at(Vector3(0, -0.06, 0))),
			ShapeKit.part("frame", ShapeKit.box(Vector3(0.5, 0.3, 0.1), 0.06, 0.02), ShapeKit.at(Vector3(-0.5, -0.06, 0), ShapeKit.FLAT)),
		])
	var base := Node3D.new()
	base.rotation.y = 0.0 if outward > 0.0 else PI  # Bracket toward the board.
	holder.add_child(base)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _pedestal_geo["mesh"]
	mesh.set_surface_override_material(0, CosmeticLibrary.board_material(_theme, "frame"))
	base.add_child(mesh)
	var hull := MeshInstance3D.new()
	hull.mesh = _pedestal_geo["hull"]
	hull.material_override = CosmeticLibrary.outline_material(CosmeticLibrary.INK)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.add_child(hull)
	_pedestals.append(mesh)


## The cloth flies outward, away from the board. Pictures load in the background.
func _add_flag(pole: Node3D, slug: String, design: Dictionary, outward: float, guild_logo_url: String, local_images: bool) -> void:
	if _cloth == null:
		_cloth = FlagFactory.cloth_mesh()
	var cloth := MeshInstance3D.new()
	cloth.mesh = _cloth
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mount := ToppersLibrary.flag_mount(slug)
	cloth.position = mount + Vector3(outward * (FlagFactory.CLOTH_SIZE.x * 0.5 + 0.01), -FlagFactory.CLOTH_SIZE.y * 0.5, 0)
	var mirror := outward < 0.0  # Flying left: the texture is seen reversed, so pictures are pre-flipped.
	var material := FlagFactory.cloth_material(FlagFactory.texture(design, null, "photo", 1.0, "", mirror), mirror)
	cloth.material_override = material
	pole.add_child(cloth)

	var apply := func(image: Image, mode: String, picture_key: String) -> void:
		if image != null and is_instance_valid(cloth):
			material.set_shader_parameter("cloth", FlagFactory.texture(design, image, mode, 1.0, picture_key, mirror))
	if bool(design.get("use_guild_logo", false)) and guild_logo_url != "":
		RemoteImage.fetch(guild_logo_url, func(texture: Texture2D) -> void:
			if texture:
				apply.call(texture.get_image(), "logo", guild_logo_url))
	elif design.get("image_media_id") != null:
		var url := "/api/media/%d" % int(design["image_media_id"])
		RemoteImage.fetch(url, func(texture: Texture2D) -> void:
			if texture:
				apply.call(texture.get_image(), "photo", url))
	elif local_images and str(design.get("local_image", "")) != "":
		var path := str(design["local_image"])
		if FileAccess.file_exists(path):
			apply.call(Image.load_from_file(path), "photo", path + str(FileAccess.get_modified_time(path)))


func _collect_anims(node: Node) -> void:
	if node is Node3D and node.has_meta("anim"):
		_anims.append({"node": node, "anim": node.get_meta("anim"), "base": (node as Node3D).transform})
	for child in node.get_children():
		_collect_anims(child)


## Offset from a moving part's rest transform at the current time.
func _pose(anim: Dictionary) -> Transform3D:
	var speed: float = anim.get("speed", 1.0)
	var amount: float = anim.get("amount", 0.1)
	var phase: float = anim.get("phase", 0.0)
	var t := _time * speed
	match str(anim.get("kind", "")):
		"sway", "rock":
			return Transform3D(Basis(Vector3.BACK, amount * sin(t + phase)), Vector3.ZERO)
		"turn":
			return Transform3D(Basis(Vector3.UP, amount * sin(t + phase)), Vector3.ZERO)
		"nod":
			return Transform3D(Basis(Vector3.RIGHT, amount * sin(t + phase)), Vector3.ZERO)
		"wave":
			return Transform3D(Basis(Vector3.RIGHT, -amount * (0.5 + 0.5 * sin(t + phase))), Vector3.ZERO)
		"spin":
			return Transform3D(Basis(Vector3.UP, t), Vector3.ZERO)
		"spin_z":
			return Transform3D(Basis(Vector3.BACK, t), Vector3.ZERO)
		"bob":
			return Transform3D(Basis.IDENTITY, Vector3(0, amount * sin(t + phase), 0))
		"float":
			return Transform3D(Basis.IDENTITY, Vector3(0, amount * sin(t + phase), 0))
		"pulse":
			return Transform3D(Basis().scaled(Vector3.ONE * (1.0 + amount * sin(t + phase))), Vector3.ZERO)
		"flicker":
			var f := 1.0 + amount * sin(t) * sin(t * 0.37 + 1.0)
			return Transform3D(Basis().scaled(Vector3(2.0 - f, f, 2.0 - f)), Vector3.ZERO)
		"steam":
			var c := fposmod(t + phase, 1.0)
			return Transform3D(Basis().scaled(Vector3.ONE * maxf(0.05, sin(c * PI))), Vector3(0, c * amount, 0))
	return Transform3D.IDENTITY
