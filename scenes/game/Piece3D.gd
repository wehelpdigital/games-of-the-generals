class_name Piece3D
extends Node3D
## One Salpakan piece: by default a chunky toy plaque on a team-coloured stand, with an enamel rank
## badge (PieceIcons) and a label on its face, drawn cel-shaded with an ink outline. The chip shape
## (ChipShapes: orbs, coins, dice...) swaps the geometry; the chip skin decides its materials.
##
## The face points toward the piece's owner (or straight up on flat tokens), so the opponent only
## ever sees the neutral side. During play the server never sends enemy ranks, so enemy pieces are
## built with rank "" (blank face).
##
## The root stays on the board plane and carries the x/z position; `_rig` carries lift, squash and
## the picking collider, so the contact shadow can stay on the board while the piece is in the air.

signal eliminated(piece: Piece3D)

enum Highlight { NONE, HOVER, SELECTED, PENDING }

const PICK_LAYER := 2  ## Physics layer bit used only for pointer raycasts.
const LIFT_HEIGHT := 0.34
const ICON_SIZE := 0.48  ## Side of the rank badge on the face (the classic plaque is 0.74 × 0.62).
const EMBLEM_SCALE := 0.34
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
## Cosmetics. Set them before setup() to build the piece with them, or later through the setters.
var icon_pack := "classic"
var aura_style := AuraFX.NONE
var trail_style := TrailFX.NONE
var shape := ChipShapes.DEFAULT

var _skin := CosmeticLibrary.DEFAULT_PIECES
var _geo: Dictionary = {}        # ChipShapes.geometry(shape)
var _aura: Node3D
var _rig: Node3D
var _model: Node3D               # The shape, its face and emblem; idle animations move this.
var _body_mesh: MeshInstance3D   # One surface per shape role (body, base, accent...).
var _hull: MeshInstance3D        # Inverted-hull ink outline around the shape.
var _face: Node3D
var _emblem: MeshInstance3D
var _shadow: MeshInstance3D
var _pick_body: StaticBody3D
var _pick_shape: CollisionShape3D
var _tween: Tween
var _highlight := Highlight.NONE
var _idle_time := randf() * TAU

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


func _process(delta: float) -> void:
	# Shadow shrinks and fades as the piece rises.
	var h := clampf(_rig.position.y / LIFT_HEIGHT, 0.0, 1.5)
	_shadow.scale = Vector3.ONE * (1.0 - 0.35 * h)
	_shadow.transparency = 0.45 * h
	match _geo.get("idle", ""):
		"wobble":
			_idle_time += delta
			var s := sin(_idle_time * 3.2)
			_model.scale = Vector3(1.0 + 0.035 * s, 1.0 - 0.05 * s, 1.0 + 0.035 * s)
		"sway":
			_idle_time += delta
			_model.rotation.z = 0.05 * sin(_idle_time * 1.7)


# --- Appearance -------------------------------------------------------------------------------

func set_rank(new_rank: String) -> void:
	rank = new_rank
	_rebuild_face()


func set_skin(slug: String) -> void:
	_skin = slug
	var roles: Array = _geo["roles"]
	for i in roles.size():
		_body_mesh.set_surface_override_material(i, ChipShapes.material(roles[i], _skin, side))
	_emblem.set_surface_override_material(0, CosmeticLibrary.piece_material(_skin, side, "emblem"))
	_emblem.set_surface_override_material(1, CosmeticLibrary.piece_material(_skin, side, "outline"))
	_apply_outline()
	_rebuild_face()


## The piece's geometry (ChipShapes.STYLES); the skin, face and effects carry over.
func set_shape(slug: String) -> void:
	slug = ChipShapes.slug_or_default(slug)
	if slug == shape and not _geo.is_empty():
		return
	shape = slug
	if _rig == null:
		return
	_apply_shape()
	set_skin(_skin)


## Which icon pack draws the rank symbol on the face (PieceIcons packs; "classic" by default).
func set_icon_pack(pack: String) -> void:
	if pack == icon_pack:
		return
	icon_pack = pack
	_rebuild_face()


## Persistent effect around the piece (AuraFX style, or "none").
func set_aura(style: String) -> void:
	aura_style = style
	if _rig == null:
		return
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = AuraFX.create(style)
	if _aura != null:
		_rig.add_child(_aura)


## Particles left behind when the piece slides (TrailFX style, or "none").
func set_trail(style: String) -> void:
	trail_style = style


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
	var glide := clampf(0.16 + distance * 0.14, 0.18, 0.5)
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), glide) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_append_landing(t)
	if distance > 0.2:
		_trail(glide + 0.12)
	return t


## Glide while staying in the air (used while waiting for the arbiter's verdict).
func hover_to(target: Vector3) -> Tween:
	var t := _new_tween().set_parallel(true)
	t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.12)
	t.tween_property(_rig, "scale", Vector3.ONE * 1.06, 0.12)
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if Vector2(target.x - position.x, target.z - position.z).length() > 0.2:
		_trail(0.25)
	return t


## A quick airborne dash toward `target`; the clash happens at the end of it.
func lunge_to(target: Vector3) -> Tween:
	var t := _new_tween()
	if not is_lifted():
		t.tween_property(_rig, "position:y", LIFT_HEIGHT, 0.1)
	t.tween_property(self, "position", Vector3(target.x, 0.0, target.z), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_trail(0.32)
	return t


func _trail(duration: float) -> void:
	if trail_style != TrailFX.NONE and _rig != null:
		TrailFX.emit(_rig, trail_style, duration)


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


## Leaves the board. `death` is how (action kill effects pick one, see KillFX.ACTIONS); `away` is
## the board-local direction the blow came from the winner, for knock-backs and slices.
func eliminate(death := "", away := Vector3.ZERO) -> Tween:
	set_pickable(false)
	set_highlight(Highlight.NONE)
	eliminated.emit(self)
	var t := _new_tween()
	match death:
		"burn":
			# Scorched: a shiver, then it crumbles down into the blast.
			for k in 3:
				t.tween_property(_rig, "rotation:z", 0.14 * (1.0 if k % 2 == 0 else -1.0), 0.04)
			t.tween_property(_rig, "scale", Vector3(1.2, 0.05, 1.2), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "rotation:z", 0.0, 0.1)
		"sink":
			t.tween_property(_rig, "rotation:z", 0.3, 0.1)
			t.tween_property(_rig, "position:y", -1.1, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "rotation:x", -0.5, 0.45)
		"lift":
			t.tween_property(_rig, "position:y", 3.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "rotation:y", _rig.rotation.y + TAU * 2.0, 0.9)
			t.parallel().tween_property(_rig, "scale", Vector3.ONE * 0.3, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		"squash":
			t.tween_property(_rig, "scale", Vector3(1.5, 0.08, 1.5), 0.07)
			t.tween_interval(0.45)
			t.tween_property(_rig, "scale", Vector3(0.01, 0.01, 0.01), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		"split":
			_split(away)
			t.tween_interval(0.75)
		"fly":
			var dir := Vector3(away.x, 0.0, away.z).normalized() if Vector2(away.x, away.z).length() > 0.01 else Vector3.FORWARD
			var land := position + dir * 4.5
			t.tween_property(self, "position", Vector3(land.x, 0.0, land.z), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_method(_fly_height, 0.0, 1.0, 0.7)
			t.parallel().tween_property(_rig, "rotation", Vector3(TAU * 2.0, TAU, 0.0), 0.7)
			t.parallel().tween_property(_rig, "scale", Vector3.ONE * 0.2, 0.25).set_delay(0.45)
		"shatter":
			t.tween_interval(0.04)
			t.tween_property(_rig, "scale", Vector3.ONE * 0.01, 0.06)
		"vanish":
			t.tween_property(_rig, "rotation:y", _rig.rotation.y + TAU * 3.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "scale", Vector3.ONE * 0.01, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "position:y", 0.3, 0.55)
		_:
			t.tween_property(_rig, "scale", Vector3.ONE * 1.18, 0.07)
			t.tween_property(_rig, "scale", Vector3.ONE * 0.01, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_rig, "rotation:y", _rig.rotation.y + PI, 0.32)
			t.parallel().tween_property(_rig, "position:y", -0.1, 0.32)
	t.tween_callback(queue_free)
	return t


## Knock-back arc: up and down while the root slides away.
func _fly_height(k: float) -> void:
	_rig.position.y = 1.8 * 4.0 * k * (1.0 - k) - 0.6 * k * k


## Ninja slice: two copies of the model, slimmed into halves, fall apart across the blow.
func _split(away: Vector3) -> void:
	var across := Vector3(away.x, 0.0, away.z).cross(Vector3.UP)
	across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
	var local_across := (basis.inverse() * across).normalized()
	_model.visible = false
	for sign: float in [-1.0, 1.0]:
		var half: Node3D = _model.duplicate()
		half.visible = true
		_rig.add_child(half)
		half.scale = Vector3.ONE - local_across.abs() * 0.45
		var t := half.create_tween().set_parallel(true)
		t.tween_property(half, "position", local_across * sign * 0.35 + Vector3(0.0, -0.15, 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(half, "rotation", Vector3(local_across.z, 0.0, -local_across.x) * sign * 0.9, 0.5)
		t.tween_property(half, "scale", Vector3.ONE * 0.01, 0.25).set_delay(0.45)


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
	_model = Node3D.new()
	_rig.add_child(_model)

	_body_mesh = MeshInstance3D.new()
	_model.add_child(_body_mesh)
	_hull = MeshInstance3D.new()
	_hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_hull)
	_face = Node3D.new()
	_model.add_child(_face)

	# Every neutral side is identical, so the opponent learns nothing from it.
	_emblem = MeshInstance3D.new()
	_emblem.mesh = InsigniaFactory.get_sticker_mesh("sun")
	_emblem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_emblem)

	_pick_body = StaticBody3D.new()
	_pick_body.collision_mask = 0
	_pick_body.set_meta("piece", self)
	_pick_shape = CollisionShape3D.new()
	_pick_shape.shape = BoxShape3D.new()
	_pick_body.add_child(_pick_shape)
	_rig.add_child(_pick_body)
	set_pickable(true)

	_apply_shape()
	set_skin(_skin)
	set_aura(aura_style)


## Swaps in the shared geometry of `shape`: meshes, face and emblem placement, picking box.
func _apply_shape() -> void:
	_geo = ChipShapes.geometry(shape)
	_body_mesh.mesh = _geo["mesh"]
	_hull.mesh = _geo["hull"]
	_hull.visible = _geo["hull"] != null
	_face.transform = _geo["face"]
	_model.transform = Transform3D.IDENTITY
	var pick: Array = _geo["pick"]
	(_pick_shape.shape as BoxShape3D).size = pick[0]
	_pick_shape.position = pick[1]
	_update_emblem()


## The neutral emblem: on the back of standing shapes; on face-up tokens it covers the face while
## the rank is unknown (enemy pieces), so every hidden piece looks the same.
func _update_emblem() -> void:
	if _emblem == null or _geo.is_empty():
		return
	var back: Variant = _geo["back"]
	if not _geo["emblem"]:
		_emblem.visible = false
	elif back is Transform3D:
		_emblem.visible = true
		_emblem.transform = back
	else:
		_emblem.visible = rank == "" or not Ranks.INFO.has(rank)
		_emblem.transform = _geo["face"] * Transform3D(Basis().scaled(Vector3.ONE * EMBLEM_SCALE * 1.3), Vector3(0, 0, 0.004))


func _rebuild_face() -> void:
	if _face == null:
		return
	for child in _face.get_children():
		child.queue_free()
	_update_emblem()
	if rank == "" or not Ranks.INFO.has(rank):
		return

	# Rank badge, stuck on the face like an enamel pin just above the label.
	var badge := MeshInstance3D.new()
	badge.mesh = PieceIcons.quad()
	badge.material_override = _face_material(rank, icon_pack)
	badge.scale = Vector3(ICON_SIZE, ICON_SIZE, 1.0)
	badge.position = Vector3(0.0, 0.074, 0.006)
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(badge)

	var colors := CosmeticLibrary.piece_label_colors(_skin, side)
	var label := Label3D.new()
	label.text = Ranks.info(rank)["label"]
	label.font = CosmeticLibrary.display_font()
	label.font_size = 64
	label.pixel_size = 0.0021
	label.outline_size = 18
	label.modulate = colors["color"]
	label.outline_modulate = colors["outline"]
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.position = Vector3(0.0, -0.212, 0.012)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(label)


## The ink outline brightens to show hover/selection, like an anime UI highlight.
func _apply_outline() -> void:
	if _highlight == Highlight.NONE:
		_hull.material_override = CosmeticLibrary.piece_material(_skin, side, "outline")
	else:
		_hull.material_override = CosmeticLibrary.outline_material(HIGHLIGHT_INK[_highlight])


static func _face_material(for_rank: String, pack: String) -> Material:
	return PieceIcons.face_material(for_rank, pack)


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
