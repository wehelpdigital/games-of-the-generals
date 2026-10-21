class_name TutorialMarkers
extends Node3D
## Boot Camp's board marks: a pulsing ring under the piece the coach wants moved, a brighter one on
## the square it should go to, and a flat arrow between them. Lives under Board3D while a lesson
## runs (added by the coach widget). Uses the same unshaded, textured, see-through material kind
## as the board's own move markers, so browsers have its shader compiled already.

const Y := 0.07
const RING_COLOR := Color("ffd23f")
const TARGET_COLOR := Color("4dffb0")
const ARROW_COLOR := Color("fff3c4")

static var _arrow_texture: ImageTexture

var _ring_material: StandardMaterial3D
var _target_material: StandardMaterial3D
var _arrow_material: StandardMaterial3D
var _nodes: Array[Node3D] = []
var _targets: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	_ring_material = _material(RING_COLOR, RulesFX._rim_texture())
	_target_material = _material(TARGET_COLOR, RulesFX._rim_texture())
	_arrow_material = _material(ARROW_COLOR, _arrow())


## Shows {rings: [cells], targets: [cells], arrow: [from, to] or []}; an empty dictionary clears.
func show_marks(marks: Dictionary) -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	_targets.clear()
	for cell: Vector2i in marks.get("rings", []):
		_nodes.append(_tile(cell, _ring_material, 1.0))
	for cell: Vector2i in marks.get("targets", []):
		var tile := _tile(cell, _target_material, 1.06)
		_nodes.append(tile)
		_targets.append(tile)
	var arrow: Array = marks.get("arrow", [])
	if arrow.size() == 2 and arrow[0] != arrow[1]:
		_nodes.append(_arrow_between(arrow[0], arrow[1]))


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	_ring_material.albedo_color.a = 0.55 + 0.4 * pulse
	_target_material.albedo_color.a = 0.6 + 0.4 * pulse
	_arrow_material.albedo_color.a = 0.7 + 0.3 * pulse
	for tile in _targets:
		var s := 1.0 + 0.06 * pulse
		tile.scale = Vector3(s, 1.0, s)


func _tile(cell: Vector2i, material: StandardMaterial3D, size: float) -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * Board3D.TILE * 0.98 * size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Board3D.cell_to_local(cell) + Vector3(0.0, Y, 0.0)
	add_child(node)
	return node


## A flat arrow lying on the board from the centre of `from` to the centre of `to`.
func _arrow_between(from: Vector2i, to: Vector2i) -> MeshInstance3D:
	var a := Board3D.cell_to_local(from)
	var b := Board3D.cell_to_local(to)
	var length := a.distance_to(b)
	var quad := PlaneMesh.new()
	quad.size = Vector2(Board3D.TILE * 0.5, length)  # x: width, y: along the arrow
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = _arrow_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = (a + b) * 0.5 + Vector3(0.0, Y + 0.02, 0.0)
	# PlaneMesh's texture runs from -Z (top of the image) to +Z: point its top (the arrow head) at `to`.
	node.rotation.y = atan2(-(b - a).x, -(b - a).z)
	add_child(node)
	return node


static func _material(color: Color, texture: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = texture
	m.albedo_color = color
	m.render_priority = 3
	return m


## A white arrow pointing up the image: a rounded shaft with a broad head, soft edges.
static func _arrow() -> ImageTexture:
	if _arrow_texture != null:
		return _arrow_texture
	var w := 64
	var h := 128
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var head := 44.0
	for y in h:
		for x in w:
			var cx := absf(x + 0.5 - w * 0.5)
			var alpha := 0.0
			if y < head:
				var half := (y + 0.5) / head * (w * 0.5)  # The head widens from its tip.
				alpha = clampf(half - cx, 0.0, 1.5) / 1.5
			else:
				alpha = clampf(w * 0.17 - cx, 0.0, 1.5) / 1.5
				alpha *= clampf((h - y) / 10.0, 0.0, 1.0)  # Fade the tail.
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	_arrow_texture = ImageTexture.create_from_image(image)
	return _arrow_texture
