class_name Piece3D
extends Node3D
## One Salpakan piece: a chunky toy plaque on a team-coloured stand, with sticker-style rank
## insignia and a label on its face, drawn cel-shaded with an ink outline.
##
## The face points toward the piece's owner, so the opponent only ever sees the neutral back. During
## play the server never sends enemy ranks, so enemy pieces are built with rank "" (blank face).
##
## The root stays on the board plane and carries the x/z position; `_rig` carries lift, squash and
## the picking collider, so the contact shadow can stay on the board while the piece is in the air.

signal eliminated(piece: Piece3D)

enum Highlight { NONE, HOVER, SELECTED, PENDING }

const PICK_LAYER := 2  ## Physics layer bit used only for pointer raycasts.
const LIFT_HEIGHT := 0.34
const BASE_SIZE := Vector3(0.86, 0.48, 0.1)    ## Outline x/z, thickness.
const PLAQUE_SIZE := Vector3(0.74, 0.62, 0.16)
const PLAQUE_TILT := -0.28  ## Radians; leans the face back toward the owner's camera.
const OUTLINE_WIDTH := 0.03
const HIGHLIGHT_INK := {
	Highlight.HOVER: Color("ffffff"),
	Highlight.SELECTED: Color("ffd23f"),
	Highlight.PENDING: Color("52e5ff"),
}

var piece_id := ""
var side := Ranks.WHITE
var rank := ""
var cell := Vector2i(-1, -1)
var is_mine := false

var _skin := CosmeticLibrary.DEFAULT_PIECES
var _rig: Node3D
var _body_mesh: MeshInstance3D   # Surface 0: plaque, surface 1: stand.
var _hull: MeshInstance3D        # Inverted-hull ink outline around both.
var _face: Node3D
var _emblem: MeshInstance3D
var _shadow: MeshInstance3D
var _pick_body: StaticBody3D
var _tween: Tween
var _highlight := Highlight.NONE

static var _overlays: Dictionary = {}
static var _shared_body: ArrayMesh
static var _shared_hull: ArrayMesh
static var _badges: Dictionary = {}


func setup(id: String, piece_side: String, piece_rank: String, mine: bool, skin: String) -> Piece3D:
	piece_id = id
	side = piece_side
	is_mine = mine
	_skin = skin
	name = "Piece_%s" % id
	rotation.y = 0.0 if side == Ranks.WHITE else PI
	_build()
	set_rank(piece_rank)
	return self


func _process(_delta: float) -> void:
	# Shadow shrinks and fades as the piece rises.
	var h := clampf(_rig.position.y / LIFT_HEIGHT, 0.0, 1.5)
	_shadow.scale = Vector3.ONE * (1.0 - 0.35 * h)
	_shadow.transparency = 0.45 * h


# --- Appearance -------------------------------------------------------------------------------

func set_rank(new_rank: String) -> void:
	rank = new_rank
	_rebuild_face()


func set_skin(slug: String) -> void:
	_skin = slug
	_body_mesh.set_surface_override_material(0, CosmeticLibrary.piece_material(_skin, side, "body"))
	_body_mesh.set_surface_override_material(1, CosmeticLibrary.piece_material(_skin, side, "base"))
	_emblem.set_surface_override_material(0, CosmeticLibrary.piece_material(_skin, side, "emblem"))
	_emblem.set_surface_override_material(1, CosmeticLibrary.piece_material(_skin, side, "outline"))
	_apply_outline()
	_rebuild_face()


func set_highlight(value: Highlight) -> void:
	if value == _highlight:
		return
	_highlight = value
	_body_mesh.material_overlay = _overlay_material(value)
	_apply_outline()


func set_pickable(enabled: bool) -> void:
	_pick_body.collision_layer = PICK_LAYER if enabled else 0


func is_lifted() -> bool:
	return _rig.position.y > LIFT_HEIGHT * 0.5


# --- Animation (all return the Tween so callers can await `finished`) -------------------------

func lift() -> Tween:
	var t := _new_tween().set_parallel(true)
	t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "scale", Vector3.ONE * 1.06, 0.16)
	return t


func drop() -> Tween:
	var t := _new_tween()
	_append_landing(t)
	return t


## Lift (if needed), glide to `target` (board-local), land with a small squash.
func slide_to(target: Vector3) -> Tween:
	var t := _new_tween()
	if not is_lifted():
		t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var distance := Vector2(target.x - position.x, target.z - position.z).length()
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), clampf(0.16 + distance * 0.14, 0.18, 0.5)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_append_landing(t)
	return t


## Glide while staying in the air (used while waiting for the arbiter's verdict).
func hover_to(target: Vector3) -> Tween:
	var t := _new_tween().set_parallel(true)
	t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.12)
	t.tween_property(_rig, "scale", Vector3.ONE * 1.06, 0.12)
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t


## A quick airborne dash toward `target`; the clash happens at the end of it.
func lunge_to(target: Vector3) -> Tween:
	var t := _new_tween()
	if not is_lifted():
		t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.1)
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return t


## Stop any animation and stand on `target` immediately (used when resyncing from the server).
func snap_to(target: Vector3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	position = Vector3(target.x, 0.0, target.z)
	_rig.position = Vector3.ZERO
	_rig.scale = Vector3.ONE
	_rig.rotation = Vector3.ZERO


## Turn the face toward `viewer_side` (used to reveal enemy ranks when the match ends).
func face_toward(viewer_side: String) -> Tween:
	var t := create_tween()
	t.tween_property(self, "rotation:y", 0.0 if viewer_side == Ranks.WHITE else PI, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


func eliminate() -> Tween:
	set_pickable(false)
	set_highlight(Highlight.NONE)
	eliminated.emit(self)
	var t := _new_tween()
	t.tween_property(_rig, "scale", Vector3.ONE * 1.18, 0.07)
	t.tween_property(_rig, "scale", Vector3.ONE * 0.01, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_rig, "rotation:y", _rig.rotation.y + PI, 0.32)
	t.parallel().tween_property(_rig, "position:y", -0.1, 0.32)
	t.tween_callback(queue_free)
	return t


func _append_landing(t: Tween) -> void:
	t.tween_property(_rig, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_rig, "scale", Vector3(1.07, 0.88, 1.07), 0.05)
	t.tween_property(_rig, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _new_tween() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


# --- Construction -----------------------------------------------------------------------------

func _build() -> void:
	_shadow = MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(1.1, 0.75)
	_shadow.mesh = shadow_mesh
	_shadow.material_override = CosmeticLibrary.contact_shadow_material()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position.y = 0.006
	add_child(_shadow)

	_rig = Node3D.new()
	add_child(_rig)

	_build_shared_meshes()
	_body_mesh = MeshInstance3D.new()
	_body_mesh.mesh = _shared_body
	_rig.add_child(_body_mesh)
	_hull = MeshInstance3D.new()
	_hull.mesh = _shared_hull
	_hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(_hull)

	var pivot := Node3D.new()
	pivot.transform = _plaque_pivot()
	_rig.add_child(pivot)

	_face = Node3D.new()
	_face.position = Vector3(0.0, PLAQUE_SIZE.y * 0.5, PLAQUE_SIZE.z * 0.5)
	pivot.add_child(_face)

	# Every back is identical, so the opponent learns nothing from it.
	_emblem = MeshInstance3D.new()
	_emblem.mesh = InsigniaFactory.get_sticker_mesh("sun")
	_emblem.scale = Vector3.ONE * 0.34
	_emblem.position = Vector3(0.0, PLAQUE_SIZE.y * 0.52, -PLAQUE_SIZE.z * 0.5)
	_emblem.rotation.y = PI
	_emblem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(_emblem)

	_pick_body = StaticBody3D.new()
	_pick_body.collision_mask = 0
	_pick_body.set_meta("piece", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.88, 0.82, 0.54)
	shape.shape = box
	shape.position.y = 0.41
	_pick_body.add_child(shape)
	_rig.add_child(_pick_body)
	set_pickable(true)

	set_skin(_skin)


func _rebuild_face() -> void:
	if _face == null:
		return
	for child in _face.get_children():
		child.queue_free()
	if rank == "" or not Ranks.INFO.has(rank):
		return

	var badge := MeshInstance3D.new()
	badge.mesh = _badge_mesh(rank)
	badge.set_surface_override_material(0, CosmeticLibrary.piece_material(_skin, side, "insignia"))
	badge.set_surface_override_material(1, CosmeticLibrary.piece_material(_skin, side, "outline"))
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(badge)

	var colors := CosmeticLibrary.piece_label_colors(_skin, side)
	var label := Label3D.new()
	label.text = Ranks.info(rank)["label"]
	label.font = CosmeticLibrary.display_font()
	label.font_size = 64
	label.pixel_size = 0.0024
	label.outline_size = 18
	label.modulate = colors["color"]
	label.outline_modulate = colors["outline"]
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.position = Vector3(0.0, -0.19, 0.012)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(label)


## The ink outline brightens to show hover/selection, like an anime UI highlight.
func _apply_outline() -> void:
	if _highlight == Highlight.NONE:
		_hull.material_override = CosmeticLibrary.piece_material(_skin, side, "outline")
	else:
		_hull.material_override = CosmeticLibrary.outline_material(HIGHLIGHT_INK[_highlight])


static func _plaque_pivot() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, PLAQUE_TILT), Vector3(0.0, BASE_SIZE.z * 0.6, 0.0))


## One body mesh (plaque + stand, two surfaces) and one outline hull, shared by every piece.
static func _build_shared_meshes() -> void:
	if _shared_body != null:
		return
	var stand := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, BASE_SIZE.z * 0.5, 0.0))
	var plaque := _plaque_pivot() * Transform3D(Basis(), Vector3(0.0, PLAQUE_SIZE.y * 0.5, 0.0))
	_shared_body = ArrayMesh.new()
	for part: Array in [[PLAQUE_SIZE, 0.14, 0.05, plaque], [BASE_SIZE, 0.13, 0.035, stand]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(InsigniaFactory.get_slab_mesh(part[0], part[1], part[2]), 0, part[3])
		st.commit(_shared_body)
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	hull.append_from(InsigniaFactory.get_slab_mesh(PLAQUE_SIZE, 0.14, 0.05, OUTLINE_WIDTH), 0, plaque)
	hull.append_from(InsigniaFactory.get_slab_mesh(BASE_SIZE, 0.13, 0.035, OUTLINE_WIDTH), 0, stand)
	_shared_hull = hull.commit()


## All insignia marks of a rank merged into one mesh: surface 0 fill, surface 1 ink outline.
## Up to three marks sit in a row; four and five stack into two rows so they stay big and bold.
static func _badge_mesh(code: String) -> ArrayMesh:
	if _badges.has(code):
		return _badges[code]
	var data := Ranks.info(code)
	var shape: String = data["insignia"]
	var marks: int = data["marks"]
	var rows: Array = [marks]
	var size := 0.24
	match marks:
		2:
			size = 0.22
		3:
			size = 0.2
		4:
			rows = [2, 2]
			size = 0.17
		5:
			rows = [3, 2]
			size = 0.17
	if shape == "eye" or shape == "flag":
		size = 0.34
	var sticker := InsigniaFactory.get_sticker_mesh(shape)
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink := SurfaceTool.new()
	ink.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gap := size * 1.12
	var top := 0.08 + (rows.size() - 1) * gap * 0.5
	for r in rows.size():
		var count: int = rows[r]
		for i in count:
			var at := Vector3((i - (count - 1) / 2.0) * gap, top - r * gap, 0.0)
			var xf := Transform3D(Basis().scaled(Vector3.ONE * size), at)
			fill.append_from(sticker, 0, xf)
			ink.append_from(sticker, 1, xf)
	var mesh := fill.commit()
	ink.commit(mesh)
	_badges[code] = mesh
	return mesh



static func _overlay_material(value: Highlight) -> Material:
	if value == Highlight.NONE:
		return null
	if not _overlays.has(value):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var tint: Color = HIGHLIGHT_INK[value]
		m.albedo_color = Color(tint, 0.12 if value == Highlight.HOVER else 0.22)
		_overlays[value] = m
	return _overlays[value]
