class_name Board3D
extends Node3D
## The 9×8 Salpakan board. Builds its own meshes, owns the Piece3D nodes, turns mouse/touch input
## into selection and drag-and-drop through 3D raycasts, and plays results back as animations.
##
## The board never decides outcomes. In PLAY mode it emits `move_requested` and holds the piece in
## the air until the session answers with apply_move_result() (or cancel_pending() when the arbiter
## refuses). All server-driven changes go through one queue so animations never overlap.
##
## Coordinates: cell (x 0–8, y 0–7) → board-local position via cell_to_local(). White's home rows
## (y 0–2) sit at +Z, nearest white's camera.

signal move_requested(piece_id: String, from: Vector2i, to: Vector2i)
signal setup_changed
signal hover_changed(piece: Piece3D)
signal clash_impact(strength: float)
signal desync_detected
signal animations_idle
signal _wait_done(token: int)

enum Mode { SPECTATE, SETUP, PLAY }

const TILE := 1.0
const TILE_GAP := 0.06
const SLAB_MARGIN := 0.45
const SLAB_HEIGHT := 0.3
const NO_CELL := Vector2i(-1, -1)
const MARKER_COLORS := {
	"move": Color(0.35, 1.0, 0.6, 0.6),
	"attack": Color(1.0, 0.32, 0.25, 0.7),
	"setup": Color(0.4, 0.75, 1.0, 0.4),
	"hover": Color(1.0, 1.0, 1.0, 0.7),
	"last": Color(1.0, 0.75, 0.3, 0.35),
}
const CLASH_COLORS := {
	"attacker": Color(1.0, 0.62, 0.25),
	"defender": Color(0.45, 0.7, 1.0),
	"both": Color(1.0, 0.95, 0.85),
}

@export var camera: Camera3D
@export var drag_threshold_px := 10.0

var mode := Mode.SPECTATE
var my_side := Ranks.WHITE
var can_act := false
var pieces: Dictionary = {}  # piece_id -> Piece3D
var board_theme := CosmeticLibrary.DEFAULT_BOARD
var piece_skins := {Ranks.WHITE: CosmeticLibrary.DEFAULT_PIECES, Ranks.BLACK: CosmeticLibrary.DEFAULT_PIECES}

var _cells: Dictionary = {}    # Vector2i -> Piece3D
var _tiles: Dictionary = {}    # Vector2i -> MeshInstance3D
var _markers: Dictionary = {}  # Vector2i -> MeshInstance3D
var _marker_materials: Dictionary = {}
var _lines: Array[MeshInstance3D] = []
var _slab: MeshInstance3D
var _table: MeshInstance3D
var _divider: MeshInstance3D
var _pieces_root: Node3D

var _selected: Piece3D
var _targets: Array[Vector2i] = []
var _hover_piece: Piece3D
var _hover_cell := NO_CELL
var _last_move: Array[Vector2i] = []
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _pending: Dictionary = {}  # {piece, from, to} while waiting for the arbiter
var _queue: Array[Dictionary] = []
var _busy := false
var _wait_token := 0
var _time := 0.0


func _ready() -> void:
	_build_board()
	_pieces_root = Node3D.new()
	_pieces_root.name = "Pieces"
	add_child(_pieces_root)
	set_board_theme(board_theme)


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.75 + 0.25 * sin(_time * 4.0)
	for kind: String in ["move", "attack", "setup"]:
		var m: StandardMaterial3D = _marker_materials[kind]
		m.albedo_color.a = MARKER_COLORS[kind].a * pulse


# --- Coordinates ------------------------------------------------------------------------------

static func cell_to_local(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (Ranks.COLS - 1) * 0.5) * TILE, 0.0, ((Ranks.ROWS - 1) * 0.5 - cell.y) * TILE)


static func local_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / TILE + Ranks.COLS * 0.5), floori(Ranks.ROWS * 0.5 - point.z / TILE))


# --- Public API -------------------------------------------------------------------------------

## SETUP: rearrange your own pieces inside your home rows. PLAY: move one square per turn.
func set_mode(new_mode: Mode, side: String, active: bool) -> void:
	mode = new_mode
	can_act = active
	if side != my_side:
		my_side = side
		for piece: Piece3D in pieces.values():
			piece.is_mine = piece.side == my_side
	if not _can_interact():
		_clear_selection()
	_refresh_markers()


## Replace the board contents with a MatchView `pieces` list (queued behind running animations).
func sync_pieces(list: Array) -> void:
	_enqueue({"kind": "sync", "pieces": list})


## Lay out a local formation ([{rank, x, y}]) for the setup phase.
func load_formation(formation: Array) -> void:
	var list: Array = []
	for i in formation.size():
		var f: Dictionary = formation[i]
		list.append({"id": "setup_%d" % i, "side": my_side, "rank": f["rank"], "x": f["x"], "y": f["y"]})
	sync_pieces(list)


func get_setup_placements() -> Array:
	var placements: Array = []
	for piece: Piece3D in pieces.values():
		if piece.side == my_side and piece.rank != "":
			placements.append({"rank": piece.rank, "x": piece.cell.x, "y": piece.cell.y})
	return placements


func has_own_pieces() -> bool:
	for piece: Piece3D in pieces.values():
		if piece.side == my_side:
			return true
	return false


## Animate a MoveResult from the arbiter (PieceMoved / ClashResolved payload).
func apply_move_result(result: Dictionary) -> void:
	_enqueue({"kind": "result", "result": result})


## Show ranks (end of match) and turn enemy faces toward the player.
func reveal_ranks(list: Array) -> void:
	_enqueue({"kind": "reveal", "pieces": list})


## The arbiter refused the pending move: put the piece back.
func cancel_pending() -> void:
	if _pending.is_empty():
		return
	var piece: Piece3D = _pending["piece"]
	_pending = {}
	if is_instance_valid(piece):
		piece.set_highlight(Piece3D.Highlight.NONE)
		piece.slide_to(cell_to_local(piece.cell))
	_refresh_markers()


func set_board_theme(slug: String) -> void:
	board_theme = slug
	for cell: Vector2i in _tiles:
		var part := "tile_a" if (cell.x + cell.y) % 2 == 0 else "tile_b"
		_tiles[cell].material_override = CosmeticLibrary.board_material(slug, part)
	_slab.material_override = CosmeticLibrary.board_material(slug, "slab")
	_table.material_override = CosmeticLibrary.board_material(slug, "table")
	_divider.material_override = CosmeticLibrary.board_material(slug, "divider")
	for line in _lines:
		line.material_override = CosmeticLibrary.board_material(slug, "line")


func set_piece_skin(side: String, slug: String) -> void:
	piece_skins[side] = slug
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_skin(slug)


func piece_at(cell: Vector2i) -> Piece3D:
	return _cells.get(cell)


# --- Animation queue --------------------------------------------------------------------------

func _enqueue(job: Dictionary) -> void:
	_queue.append(job)
	if not _busy:
		_drain()


func _drain() -> void:
	_busy = true
	_clear_selection()
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		match job["kind"]:
			"result":
				await _play_result(job["result"])
			"sync":
				_sync_now(job["pieces"])
			"reveal":
				_reveal_now(job["pieces"])
	_busy = false
	_refresh_markers()
	animations_idle.emit()


func _sync_now(list: Array) -> void:
	_pending = {}
	var keep: Dictionary = {}
	for data: Dictionary in list:
		var id := str(data["id"])
		var side := str(data["side"])
		var rank: String = data["rank"] if data.get("rank") is String else ""
		var cell := Vector2i(int(data["x"]), int(data["y"]))
		keep[id] = true
		var piece: Piece3D = pieces.get(id)
		if piece == null:
			piece = Piece3D.new().setup(id, side, rank, side == my_side, piece_skins[side])
			_pieces_root.add_child(piece)
			pieces[id] = piece
		elif piece.rank != rank:
			piece.set_rank(rank)
		piece.set_highlight(Piece3D.Highlight.NONE)
		piece.cell = cell
		piece.snap_to(cell_to_local(cell))
	for id: String in pieces.keys():
		if not keep.has(id):
			pieces[id].queue_free()
			pieces.erase(id)
	_cells.clear()
	for piece: Piece3D in pieces.values():
		_cells[piece.cell] = piece


func _reveal_now(list: Array) -> void:
	for data: Dictionary in list:
		var piece: Piece3D = pieces.get(str(data.get("id", "")))
		if piece == null or not data.get("rank") is String:
			continue
		piece.set_rank(data["rank"])
		if piece.side != my_side:
			piece.face_toward(my_side)


func _play_result(result: Dictionary) -> void:
	var from := _cell_of(result.get("from"))
	var to := _cell_of(result.get("to"))
	var mover: Piece3D = pieces.get(str(result.get("piece_id", "")), _cells.get(from))
	if not _pending.is_empty() and _pending["piece"] == mover:
		_pending = {}
	if mover == null or not Ranks.in_bounds(to):
		push_warning("Board out of sync with move %s" % result)
		desync_detected.emit()
		return
	mover.set_highlight(Piece3D.Highlight.NONE)
	_last_move = [from, to]
	_refresh_markers()
	if _cells.get(from) == mover:
		_cells.erase(from)

	var to_pos := cell_to_local(to)
	var clash: Variant = result.get("clash")
	if not clash is Dictionary:
		_place(mover, to)
		await _wait(mover.slide_to(to_pos))
		return

	var outcome := str(clash.get("outcome", "both"))
	var from_pos := cell_to_local(from)
	await _wait(mover.lunge_to(from_pos.lerp(to_pos, 0.42)))
	ClashFX.burst(self, from_pos.lerp(to_pos, 0.7) + Vector3(0.0, 0.45, 0.0), CLASH_COLORS.get(outcome, Color.WHITE),
		1.25 if outcome == "both" else 1.0)
	clash_impact.emit(0.9 if outcome == "both" else 0.6)
	for id: Variant in clash.get("eliminated", []):
		var victim: Piece3D = pieces.get(str(id))
		if victim != null:
			_remove(victim)
			victim.eliminate()
	if outcome == "attacker":
		_place(mover, to)
		await _delay(0.1)
		await _wait(mover.slide_to(to_pos))
	else:
		await _delay(0.45)


func _place(piece: Piece3D, cell: Vector2i) -> void:
	if _cells.get(piece.cell) == piece:
		_cells.erase(piece.cell)
	piece.cell = cell
	_cells[cell] = piece


func _remove(piece: Piece3D) -> void:
	pieces.erase(piece.piece_id)
	if _cells.get(piece.cell) == piece:
		_cells.erase(piece.cell)
	if _hover_piece == piece:
		_hover_piece = null


## Waits for a tween, but never longer than `timeout` (a killed tween never emits `finished`).
func _wait(tween: Tween, timeout := 2.0) -> void:
	if tween == null or not tween.is_valid():
		return
	_wait_token += 1
	var token := _wait_token
	tween.finished.connect(func() -> void: _wait_done.emit(token), CONNECT_ONE_SHOT)
	get_tree().create_timer(timeout).timeout.connect(func() -> void: _wait_done.emit(token), CONNECT_ONE_SHOT)
	while (await _wait_done) != token:
		pass


func _delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _cell_of(value: Variant) -> Vector2i:
	if value is Dictionary:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return NO_CELL


# --- Input ------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(event.position)
		else:
			_pointer_up(event.position)
	elif event is InputEventMouseMotion:
		_pointer_move(event.position)


func _pointer_down(screen_pos: Vector2) -> void:
	_press_pos = screen_pos
	_pressing = false
	_dragging = false
	if not _can_interact():
		return
	if _selected != null and _cell_under(screen_pos) in _targets:
		_commit(_cell_under(screen_pos))  # Tap-to-move (or tap-to-swap during setup).
		_consume()
		return
	var piece := _piece_under(screen_pos)
	if piece != null and _is_selectable(piece):
		if piece != _selected:
			_select(piece)
		_pressing = true
		_consume()
		return
	if _selected != null:
		_clear_selection()  # Not consumed: the camera may orbit from here.


func _pointer_move(screen_pos: Vector2) -> void:
	if _pressing and _selected != null:
		if not _dragging and screen_pos.distance_to(_press_pos) > drag_threshold_px:
			_dragging = true
		if _dragging:
			var point: Variant = _point_on_plane(screen_pos, Piece3D.LIFT_HEIGHT)
			if point != null:
				_selected.position = Vector3(point.x, 0.0, point.z)
			_set_hover_cell(_cell_under(screen_pos))
			_consume()
			return
	_update_hover(screen_pos)


func _pointer_up(screen_pos: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if not _dragging:
		return  # A tap: keep the selection for tap-to-move.
	_dragging = false
	var cell := _cell_under(screen_pos)
	if cell in _targets:
		_commit(cell)
	elif _selected != null:
		_selected.hover_to(cell_to_local(_selected.cell))
	_consume()


func _select(piece: Piece3D) -> void:
	_clear_selection()
	_selected = piece
	piece.set_highlight(Piece3D.Highlight.SELECTED)
	piece.lift()
	_targets = _targets_for(piece)
	_refresh_markers()


func _clear_selection() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.set_highlight(Piece3D.Highlight.NONE)
		if _pending.get("piece") != _selected:
			_selected.slide_to(cell_to_local(_selected.cell))
	_selected = null
	_targets.clear()
	_pressing = false
	_dragging = false
	_refresh_markers()


func _commit(cell: Vector2i) -> void:
	var piece := _selected
	var from := piece.cell
	_selected = null
	_targets.clear()
	piece.set_highlight(Piece3D.Highlight.NONE)

	if mode == Mode.SETUP:
		var other: Piece3D = _cells.get(cell)
		_place(piece, cell)
		piece.slide_to(cell_to_local(cell))
		if other != null:
			_place(other, from)
			other.slide_to(cell_to_local(from))
		_refresh_markers()
		setup_changed.emit()
		return

	# PLAY: hold the piece over its destination (or leaning at an enemy) until the arbiter rules.
	_pending = {"piece": piece, "from": from, "to": cell}
	piece.set_highlight(Piece3D.Highlight.PENDING)
	var target := cell_to_local(cell)
	piece.hover_to(cell_to_local(from).lerp(target, 0.3) if _cells.has(cell) else target)
	_refresh_markers()
	move_requested.emit(piece.piece_id, from, cell)


func _targets_for(piece: Piece3D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if mode == Mode.SETUP:
		for y in Ranks.ROWS:
			for x in Ranks.COLS:
				var cell := Vector2i(x, y)
				if cell != piece.cell and Ranks.is_home_cell(my_side, cell):
					result.append(cell)
	elif mode == Mode.PLAY:
		for cell in Ranks.neighbors(piece.cell):
			var occupant: Piece3D = _cells.get(cell)
			if occupant == null or occupant.side != piece.side:
				result.append(cell)
	return result


func _update_hover(screen_pos: Vector2) -> void:
	var piece := _piece_under(screen_pos)
	if piece != _hover_piece:
		if _hover_piece != null and is_instance_valid(_hover_piece) and _hover_piece != _selected \
				and _pending.get("piece") != _hover_piece:
			_hover_piece.set_highlight(Piece3D.Highlight.NONE)
		_hover_piece = piece
		if piece != null and piece != _selected and _is_selectable(piece) and _can_interact():
			piece.set_highlight(Piece3D.Highlight.HOVER)
		hover_changed.emit(piece)
	_set_hover_cell(_cell_under(screen_pos))


func _set_hover_cell(cell: Vector2i) -> void:
	if cell != _hover_cell:
		_hover_cell = cell
		_refresh_markers()


func _can_interact() -> bool:
	return can_act and mode != Mode.SPECTATE and not _busy and _pending.is_empty()


func _is_selectable(piece: Piece3D) -> bool:
	return is_instance_valid(piece) and piece.side == my_side and pieces.has(piece.piece_id)


func _consume() -> void:
	get_viewport().set_input_as_handled()


# --- Raycasting -------------------------------------------------------------------------------

func _get_camera() -> Camera3D:
	return camera if camera != null else get_viewport().get_camera_3d()


## Physics raycast against piece colliders (layer 2), falling back to the piece standing on the
## tile under the pointer, which is forgiving for fingers.
func _piece_under(screen_pos: Vector2) -> Piece3D:
	var cam := _get_camera()
	if cam == null:
		return null
	var from := cam.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 200.0, Piece3D.PICK_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider != null and collider.has_meta("piece"):
			var piece: Piece3D = collider.get_meta("piece")
			if is_instance_valid(piece) and pieces.has(piece.piece_id):
				return piece
	return _cells.get(_cell_under(screen_pos))


func _cell_under(screen_pos: Vector2) -> Vector2i:
	var point: Variant = _point_on_plane(screen_pos, 0.0)
	if point == null:
		return NO_CELL
	var cell := local_to_cell(point)
	return cell if Ranks.in_bounds(cell) else NO_CELL


## Where the pointer ray crosses the horizontal plane at `height` (board-local), or null.
func _point_on_plane(screen_pos: Vector2, height: float) -> Variant:
	var cam := _get_camera()
	if cam == null:
		return null
	var inverse := global_transform.affine_inverse()
	var origin := inverse * cam.project_ray_origin(screen_pos)
	var direction := (inverse.basis * cam.project_ray_normal(screen_pos)).normalized()
	return Plane(Vector3.UP, height).intersects_ray(origin, direction)


# --- Markers ----------------------------------------------------------------------------------

func _refresh_markers() -> void:
	if _markers.is_empty():
		return
	for marker: MeshInstance3D in _markers.values():
		marker.visible = false
	for cell in _last_move:
		_show_marker(cell, "last")
	for cell in _targets:
		var occupant: Piece3D = _cells.get(cell)
		if mode == Mode.SETUP:
			_show_marker(cell, "setup")
		else:
			_show_marker(cell, "attack" if occupant != null and occupant.side != my_side else "move")
	if not _pending.is_empty():
		_show_marker(_pending["to"], "move")
	if _hover_cell in _targets:
		_show_marker(_hover_cell, "hover")


func _show_marker(cell: Vector2i, kind: String) -> void:
	var marker: MeshInstance3D = _markers.get(cell)
	if marker != null:
		marker.material_override = _marker_materials[kind]
		marker.visible = true


# --- Construction -----------------------------------------------------------------------------

func _build_board() -> void:
	var width := Ranks.COLS * TILE
	var depth := Ranks.ROWS * TILE

	_table = _mesh_instance(_plane(Vector2(60.0, 60.0)), Vector3(0.0, -SLAB_HEIGHT - 0.02, 0.0))
	_table.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var slab := BoxMesh.new()
	slab.size = Vector3(width + SLAB_MARGIN * 2.0, SLAB_HEIGHT, depth + SLAB_MARGIN * 2.0)
	_slab = _mesh_instance(slab, Vector3(0.0, -SLAB_HEIGHT * 0.5 - 0.02, 0.0))

	var tile := BoxMesh.new()
	tile.size = Vector3(TILE - TILE_GAP, 0.04, TILE - TILE_GAP)
	var marker_mesh := _plane(Vector2(TILE - TILE_GAP - 0.04, TILE - TILE_GAP - 0.04))
	for y in Ranks.ROWS:
		for x in Ranks.COLS:
			var cell := Vector2i(x, y)
			var center := cell_to_local(cell)
			var tile_instance := _mesh_instance(tile, center + Vector3(0.0, -0.02, 0.0))
			tile_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tiles[cell] = tile_instance
			var marker := _mesh_instance(marker_mesh, center + Vector3(0.0, 0.004, 0.0))
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.visible = false
			_markers[cell] = marker

	# Inlaid grid lines in the gaps between tiles.
	var line_z := BoxMesh.new()
	line_z.size = Vector3(TILE_GAP, 0.02, depth + TILE_GAP)
	for x in Ranks.COLS + 1:
		_lines.append(_mesh_instance(line_z, Vector3((x - Ranks.COLS * 0.5) * TILE, -0.015, 0.0)))
	var line_x := BoxMesh.new()
	line_x.size = Vector3(width + TILE_GAP, 0.02, TILE_GAP)
	for y in Ranks.ROWS + 1:
		if y * 2 == Ranks.ROWS:
			continue
		_lines.append(_mesh_instance(line_x, Vector3(0.0, -0.015, (Ranks.ROWS * 0.5 - y) * TILE)))

	# The centre line between the two armies.
	var divider := BoxMesh.new()
	divider.size = Vector3(width + TILE_GAP, 0.026, TILE_GAP * 1.4)
	_divider = _mesh_instance(divider, Vector3(0.0, -0.012, 0.0))

	for kind: String in MARKER_COLORS:
		_marker_materials[kind] = _marker_material(MARKER_COLORS[kind])


func _mesh_instance(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


func _plane(size: Vector2) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = size
	return plane


## Glowing rounded-square outline: transparent centre fading to a bright edge.
func _marker_material(color: Color) -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.3), Color(1, 1, 1, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_SQUARE
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = color
	return m
