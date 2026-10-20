class_name Piece3D
extends Node3D
## One Salpakan piece: an upright plaque on a base with raised rank insignia on its face.
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
const BASE_SIZE := Vector3(0.84, 0.44, 0.07)   ## Outline x/z, thickness.
const PLAQUE_SIZE := Vector3(0.74, 0.62, 0.12)
const PLAQUE_TILT := -0.28  ## Radians; leans the face back toward the owner's camera.

var piece_id := ""
var side := Ranks.WHITE
var rank := ""
var cell := Vector2i(-1, -1)
var is_mine := false

var _skin := CosmeticLibrary.DEFAULT_PIECES
var _rig: Node3D
var _base: MeshInstance3D
var _plaque: MeshInstance3D
var _face: Node3D
var _emblem: MeshInstance3D
var _shadow: MeshInstance3D
var _body: StaticBody3D
var _tween: Tween
var _highlight := Highlight.NONE

static var _overlays: Dictionary = {}


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
	_base.material_override = CosmeticLibrary.piece_material(_skin, side, "base")
	_plaque.material_override = CosmeticLibrary.piece_material(_skin, side, "body")
	_emblem.material_override = CosmeticLibrary.piece_material(_skin, side, "emblem")
	_rebuild_face()


func set_highlight(value: Highlight) -> void:
	if value == _highlight:
		return
	_highlight = value
	var overlay := _overlay_material(value)
	_plaque.material_overlay = overlay
	_base.material_overlay = overlay


func set_pickable(enabled: bool) -> void:
	_body.collision_layer = PICK_LAYER if enabled else 0


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
	shadow_mesh.size = Vector2(1.05, 0.7)
	_shadow.mesh = shadow_mesh
	_shadow.material_override = CosmeticLibrary.contact_shadow_material()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position.y = 0.006
	add_child(_shadow)

	_rig = Node3D.new()
	add_child(_rig)

	_base = MeshInstance3D.new()
	_base.mesh = InsigniaFactory.get_slab_mesh(BASE_SIZE, 0.08)
	_base.rotation.x = -PI / 2.0  # Outline lies on the board; thickness points up.
	_base.position.y = BASE_SIZE.z * 0.5
	_rig.add_child(_base)

	var pivot := Node3D.new()
	pivot.position.y = BASE_SIZE.z * 0.6
	pivot.rotation.x = PLAQUE_TILT
	_rig.add_child(pivot)

	_plaque = MeshInstance3D.new()
	_plaque.mesh = InsigniaFactory.get_slab_mesh(PLAQUE_SIZE, 0.1)
	_plaque.position.y = PLAQUE_SIZE.y * 0.5
	pivot.add_child(_plaque)

	_face = Node3D.new()
	_face.position = Vector3(0.0, PLAQUE_SIZE.y * 0.5, PLAQUE_SIZE.z * 0.5)
	pivot.add_child(_face)

	# Every back is identical, so the opponent learns nothing from it.
	_emblem = MeshInstance3D.new()
	_emblem.mesh = InsigniaFactory.get_mesh("sun")
	_emblem.scale = Vector3.ONE * 0.26
	_emblem.position = Vector3(0.0, PLAQUE_SIZE.y * 0.52, -PLAQUE_SIZE.z * 0.5)
	_emblem.rotation.y = PI
	_emblem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(_emblem)

	_body = StaticBody3D.new()
	_body.collision_mask = 0
	_body.set_meta("piece", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.86, 0.8, 0.52)
	shape.shape = box
	shape.position.y = 0.4
	_body.add_child(shape)
	_rig.add_child(_body)
	set_pickable(true)

	set_skin(_skin)


func _rebuild_face() -> void:
	if _face == null:
		return
	for child in _face.get_children():
		child.queue_free()
	if rank == "" or not Ranks.INFO.has(rank):
		return

	var data := Ranks.info(rank)
	var shape: String = data["insignia"]
	var marks: int = data["marks"]
	var material := CosmeticLibrary.piece_material(_skin, side, "insignia")
	var single := shape == "eye" or shape == "flag"
	var size := 0.3 if single else (0.13 if marks >= 4 else 0.16)
	var gap := size * 1.12
	for i in marks:
		var mark := MeshInstance3D.new()
		mark.mesh = InsigniaFactory.get_mesh(shape)
		mark.material_override = material
		mark.scale = Vector3.ONE * size
		mark.position = Vector3((i - (marks - 1) / 2.0) * gap, 0.07, 0.0)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_face.add_child(mark)

	var text := TextMesh.new()
	text.text = data["label"]
	text.font_size = 14
	text.pixel_size = 0.0055
	text.depth = 0.012
	var label := MeshInstance3D.new()
	label.mesh = text
	label.material_override = material
	label.position = Vector3(0.0, -0.19, 0.004)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(label)


static func _overlay_material(value: Highlight) -> Material:
	if value == Highlight.NONE:
		return null
	if not _overlays.has(value):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		match value:
			Highlight.HOVER:
				m.albedo_color = Color(1.0, 1.0, 1.0, 0.14)
			Highlight.SELECTED:
				m.albedo_color = Color(1.0, 0.82, 0.35, 0.32)
			Highlight.PENDING:
				m.albedo_color = Color(0.4, 0.8, 1.0, 0.28)
		_overlays[value] = m
	return _overlays[value]
