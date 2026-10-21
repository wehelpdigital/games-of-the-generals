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
const TILE_GAP := 0.12        ## Wide gaps read as chunky inlaid grid lines.
const SLAB_MARGIN := 0.5
const SLAB_HEIGHT := 0.36
const OUTLINE_WIDTH := 0.05
const FRAME_TOP := -0.07
## Where the board's underside rests (board-local y). Arenas put their ground at or below this.
const GROUND_Y := FRAME_TOP - SLAB_HEIGHT - 0.06
const NO_CELL := Vector2i(-1, -1)
const MARKER_COLORS := {
	"move": Color("4dffb0", 0.9),
	"attack": Color("ff4d6d", 0.95),
	"setup": Color("6fc3ff", 0.7),
	"hover": Color("ffffff", 0.95),
	"last": Color("ffd45c", 0.65),
}
const CLASH_COLORS := {
	"attacker": Color("ffb020"),
	"defender": Color("4fc3ff"),
	"both": Color("ff6fd8"),
}

@export var camera: Camera3D
@export var drag_threshold_px := 10.0

## Optional coroutine awaited at the moment of each clash (the UI's battle clip). Receives
## {attacker: {side, rank}, defender: {side, rank}, outcome}.
var clash_presenter: Callable

var mode := Mode.SPECTATE
var my_side := Ranks.WHITE
var can_act := false
var pieces: Dictionary = {}  # piece_id -> Piece3D
var board_theme := CosmeticLibrary.DEFAULT_BOARD
## Per-side cosmetics; they also apply to pieces spawned later.
var piece_skins := {Ranks.WHITE: CosmeticLibrary.DEFAULT_PIECES, Ranks.BLACK: CosmeticLibrary.DEFAULT_PIECES}
var territories := {Ranks.WHITE: CosmeticLibrary.DEFAULT_TERRITORY, Ranks.BLACK: CosmeticLibrary.DEFAULT_TERRITORY}
var icon_packs := {Ranks.WHITE: "classic", Ranks.BLACK: "classic"}
var auras := {Ranks.WHITE: AuraFX.NONE, Ranks.BLACK: AuraFX.NONE}
var trails := {Ranks.WHITE: TrailFX.NONE, Ranks.BLACK: TrailFX.NONE}
var kill_effects := {Ranks.WHITE: "classic", Ranks.BLACK: "classic"}
var board_glows := {Ranks.WHITE: BoardGlowFX.NONE, Ranks.BLACK: BoardGlowFX.NONE}
var chip_shapes := {Ranks.WHITE: ChipShapes.DEFAULT, Ranks.BLACK: ChipShapes.DEFAULT}
var ambiences := {Ranks.WHITE: AmbienceFX.NONE, Ranks.BLACK: AmbienceFX.NONE}
var _glow_nodes: Dictionary = {}  # side -> Node3D
var _ambience_nodes: Dictionary = {}  # side -> AmbienceFX
var _toppers: Dictionary = {}     # side -> Toppers3D

var _cells: Dictionary = {}    # Vector2i -> Piece3D
## Merged tile meshes keyed "<side>/<part>": each half (white rows 0–3, black rows 4–7) has a light
## (tile_a) and a dark (tile_b) set, so each half can wear its own territory.
var _tile_sets: Dictionary = {}
var _markers: Dictionary = {}  # Vector2i -> MeshInstance3D
var _marker_materials: Dictionary = {}
var _frame: MeshInstance3D
var _frame_hull: MeshInstance3D
var _bed: MeshInstance3D
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


## The board itself (frame, grid lines, centre line and any half left on "default" territory).
## The world around the board (sky, light, ground) belongs to the arena, not the board.
func set_board_theme(slug: String) -> void:
	board_theme = slug
	_frame.material_override = CosmeticLibrary.board_material(slug, "frame")
	_frame_hull.material_override = CosmeticLibrary.board_material(slug, "outline")
	_bed.material_override = CosmeticLibrary.board_material(slug, "bed")
	_divider.material_override = CosmeticLibrary.board_material(slug, "divider")
	_apply_tiles()
	for node: Toppers3D in _toppers.values():
		if is_instance_valid(node):
			node.set_board_theme(slug)


func set_piece_skin(side: String, slug: String) -> void:
	piece_skins[side] = slug
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_skin(slug)


## How `side`'s half of the board looks (CosmeticLibrary.TERRITORIES; "default" = board theme).
func set_territory(side: String, slug: String) -> void:
	territories[side] = slug
	_apply_tiles()


## The geometry of `side`'s pieces (ChipShapes.STYLES).
func set_chip_shape(side: String, slug: String) -> void:
	chip_shapes[side] = ChipShapes.slug_or_default(slug)
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_shape(chip_shapes[side])


## Decorations beside `side`'s half of the board (Toppers3D; config is the loadout's `toppers`).
## `local_images` lets flags show pictures that only exist on this device (the player's own side).
func set_toppers(side: String, config: Variant, guild_logo_url := "", local_images := false) -> void:
	var node: Toppers3D = _toppers.get(side)
	if node == null or not is_instance_valid(node):
		node = Toppers3D.new()
		node.name = "Toppers_" + side
		add_child(node)
		_toppers[side] = node
	node.configure(side, config if config is Dictionary else {}, guild_logo_url, local_images, board_theme)


## Which icon pack draws the rank symbols on `side`'s pieces.
func set_icon_pack(side: String, pack: String) -> void:
	icon_packs[side] = pack
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_icon_pack(pack)


## Persistent effect around every piece of `side` (AuraFX.STYLES).
func set_aura(side: String, slug: String) -> void:
	auras[side] = slug
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_aura(slug)


## Particles left behind when `side`'s pieces slide (TrailFX.STYLES).
func set_trail(side: String, slug: String) -> void:
	trails[side] = slug
	for piece: Piece3D in pieces.values():
		if piece.side == side:
			piece.set_trail(slug)


## What plays where a piece falls when `side` wins a clash (KillFX.STYLES).
func set_kill_effect(side: String, slug: String) -> void:
	kill_effects[side] = slug


## Glow along the frame edge of `side`'s half of the board (BoardGlowFX.STYLES).
func set_board_glow(side: String, slug: String) -> void:
	board_glows[side] = slug
	var old: Node3D = _glow_nodes.get(side)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_glow_nodes.erase(side)
	var glow := BoardGlowFX.create(side, slug, FRAME_TOP)
	if glow != null:
		add_child(glow)
		_glow_nodes[side] = glow


## Animated scenery over `side`'s half of the board (AmbienceFX.STYLES).
func set_ambience(side: String, slug: String) -> void:
	if ambiences.get(side) == slug and is_instance_valid(_ambience_nodes.get(side)):
		return
	ambiences[side] = slug
	var old: Node3D = _ambience_nodes.get(side)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_ambience_nodes.erase(side)
	var fx := AmbienceFX.create(side, slug)
	if fx != null:
		add_child(fx)
		_ambience_nodes[side] = fx


## Rebuilds both sides' ambience (after the device's "reduce ambience" setting changes).
func rebuild_ambience() -> void:
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		var slug: String = ambiences.get(side, AmbienceFX.NONE)
		ambiences[side] = ""
		set_ambience(side, slug)


## Shop preview: one of `side`'s pieces hops to a neighbouring free tile and back, showing its trail.
func preview_trail(side: String) -> void:
	if _busy:
		return
	for piece: Piece3D in pieces.values():
		if piece.side != side:
			continue
		for cell in Ranks.neighbors(piece.cell):
			if not _cells.has(cell):
				var home := cell_to_local(piece.cell)
				var t := piece.slide_to(cell_to_local(cell))
				t.finished.connect(_slide_back.bind(piece, home), CONNECT_ONE_SHOT)
				return


## Shop preview: plays `side`'s kill effect in the middle of the board.
func preview_kill(side: String) -> void:
	KillFX.play(self, Vector3(0.0, 0.45, 0.0), kill_effects.get(side, "classic"), CLASH_COLORS["attacker"], 1.0)
	clash_impact.emit(0.5)


func _slide_back(piece: Piece3D, home: Vector3) -> void:
	if is_instance_valid(piece) and not _busy:
		piece.slide_to(home)


func _apply_tiles() -> void:
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		for part: String in ["tile_a", "tile_b"]:
			var m := CosmeticLibrary.territory_material(territories.get(side, CosmeticLibrary.DEFAULT_TERRITORY), part)
			if m == null:
				m = CosmeticLibrary.board_material(board_theme, part)
			var tiles: MeshInstance3D = _tile_sets["%s/%s" % [side, part]]
			tiles.material_override = m


func piece_at(cell: Vector2i) -> Piece3D:
	return _cells.get(cell)


## True while queued moves, clashes or resyncs are still playing out.
func is_animating() -> bool:
	return _busy


## True while the pointer is down on a selected piece (about to drag it), so the camera leaves
## that finger alone.
func is_holding_piece() -> bool:
	return _pressing and _selected != null


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
			piece = Piece3D.new()
			piece.icon_pack = icon_packs.get(side, "classic")
			piece.aura_style = auras.get(side, AuraFX.NONE)
			piece.trail_style = trails.get(side, TrailFX.NONE)
			piece.shape = chip_shapes.get(side, ChipShapes.DEFAULT)
			piece.setup(id, side, rank, side == my_side, piece_skins[side])
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
	var defender: Piece3D = pieces.get(str(clash.get("defender_id", "")), _cells.get(to))
	await _wait(mover.lunge_to(from_pos.lerp(to_pos, 0.42)))
	if clash_presenter.is_valid():
		# Ranks here are only what this client knows: enemy pieces carry "" during play.
		await clash_presenter.call({
			"attacker": {"side": mover.side, "rank": mover.rank},
			"defender": {"side": defender.side if defender else Ranks.opponent(mover.side), "rank": defender.rank if defender else ""},
			"outcome": outcome,
		})
	# The winning side's kill effect plays where the loser falls; a tie uses the attacker's style.
	var winner_side := mover.side
	var fall_at := from_pos.lerp(to_pos, 0.7)
	match outcome:
		"attacker":
			fall_at = to_pos
		"defender":
			winner_side = defender.side if defender else Ranks.opponent(mover.side)
			fall_at = Vector3(mover.position.x, 0.0, mover.position.z)
	var style: String = kill_effects.get(winner_side, "classic")
	var death := ""
	var away := Vector3.ZERO
	if outcome != "both" and KillFX.is_action(style):
		# Action kill: the winning chip performs it, so it starts where the winner stands and the
		# loser only goes down at the moment of impact.
		var winner_at: Vector3 = mover.position if outcome == "attacker" else (defender.position if defender else to_pos)
		winner_at = Vector3(winner_at.x, 0.0, winner_at.z)
		away = fall_at - winner_at
		death = KillFX.death_of(style)
		await _delay(KillFX.play_action(self, winner_at + Vector3(0.0, 0.45, 0.0), fall_at + Vector3(0.0, 0.45, 0.0), style))
	else:
		KillFX.play(self, fall_at + Vector3(0.0, 0.45, 0.0), style, CLASH_COLORS.get(outcome, Color.WHITE), 1.25 if outcome == "both" else 1.0)
	clash_impact.emit(0.9 if outcome == "both" else 0.6)
	for id: Variant in clash.get("eliminated", []):
		var victim: Piece3D = pieces.get(str(id))
		if victim != null:
			_remove(victim)
			victim.eliminate(death, away)
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
		# GameSession.step_rules(): Haste dashes, Roadblock squares, Ceasefire (MoveRules on the server).
		var rules := GameSession.step_rules()
		var blocked: Array = rules["blocked"]
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for steps in (2 if rules["haste"] else 1):
				var cell := piece.cell + dir * (steps + 1)
				if not Ranks.in_bounds(cell) or blocked.has(cell):
					continue
				if steps == 1 and (_cells.has(piece.cell + dir) or blocked.has(piece.cell + dir)):
					continue  # A dash can't jump over a piece or a roadblock.
				var occupant: Piece3D = _cells.get(cell)
				if occupant != null and (occupant.side == piece.side or rules["ceasefire"]):
					continue
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


## Web warm-up (Game3D): shows one move marker of each kind and selects a piece for a frame, so
## their shaders compile behind the loader instead of on the first move. Call with false after.
func show_warmup_markers(on: bool) -> void:
	var cells: Array = _markers.keys()
	var i := 0
	for kind: String in _marker_materials:
		if i < cells.size():
			if on:
				_show_marker(cells[i], kind)
			i += 1
	var mine: Array = pieces.values().filter(func(p: Piece3D) -> bool: return p.side == my_side)
	if not mine.is_empty():
		(mine[0] as Piece3D).set_highlight(Piece3D.Highlight.SELECTED if on else Piece3D.Highlight.NONE)
	if not on:
		_refresh_markers()


func _show_marker(cell: Vector2i, kind: String) -> void:
	var marker: MeshInstance3D = _markers.get(cell)
	if marker != null:
		marker.material_override = _marker_materials[kind]
		marker.visible = true




# --- Construction -----------------------------------------------------------------------------

## A layered toy board: outlined platform, a grid-coloured bed, beveled tiles on top and a bright
## centre line. The ground, sky and lighting around it come from the arena.
func _build_board() -> void:
	var width := Ranks.COLS * TILE
	var depth := Ranks.ROWS * TILE
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)  # Slab outlines lie on XZ; thickness points up.

	var frame_size := Vector3(width + SLAB_MARGIN * 2.0, depth + SLAB_MARGIN * 2.0, SLAB_HEIGHT)
	var frame_at := Vector3(0.0, FRAME_TOP - SLAB_HEIGHT * 0.5, 0.0)
	_frame = _mesh_instance(InsigniaFactory.get_slab_mesh(frame_size, 0.5, 0.09), frame_at, flat)
	_frame_hull = _mesh_instance(InsigniaFactory.get_slab_mesh(frame_size, 0.5, 0.09, OUTLINE_WIDTH), frame_at, flat)
	_frame_hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var bed_size := Vector3(width + TILE_GAP * 1.5, depth + TILE_GAP * 1.5, 0.06)
	_bed = _mesh_instance(InsigniaFactory.get_slab_mesh(bed_size, 0.18, 0.02), Vector3(0.0, -0.035 - bed_size.z * 0.5, 0.0), flat)

	# Tiles are static, so they're merged per half and colour: 4 draw calls for 72 tiles, and each
	# half can carry its own territory.
	var tile := InsigniaFactory.get_slab_mesh(Vector3(TILE - TILE_GAP, TILE - TILE_GAP, 0.07), 0.13, 0.03)
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		for parity in 2:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for y in Ranks.ROWS:
				var half := Ranks.WHITE if y * 2 < Ranks.ROWS else Ranks.BLACK
				if half != side:
					continue
				for x in Ranks.COLS:
					if (x + y) % 2 == parity:
						st.append_from(tile, 0, Transform3D(flat, cell_to_local(Vector2i(x, y)) + Vector3(0.0, -0.035, 0.0)))
			var tiles := _mesh_instance(st.commit(), Vector3.ZERO)
			tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tile_sets["%s/%s" % [side, "tile_a" if parity == 0 else "tile_b"]] = tiles

	var divider_size := Vector3(width + 0.2, TILE_GAP * 1.5, 0.06)
	_divider = _mesh_instance(InsigniaFactory.get_slab_mesh(divider_size, divider_size.y * 0.45, 0.015), Vector3(0.0, -0.01, 0.0), flat)
	_divider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var marker_mesh := _plane(Vector2(TILE - TILE_GAP + 0.02, TILE - TILE_GAP + 0.02))
	for y in Ranks.ROWS:
		for x in Ranks.COLS:
			var cell := Vector2i(x, y)
			var marker := _mesh_instance(marker_mesh, cell_to_local(cell) + Vector3(0.0, 0.01, 0.0))
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.visible = false
			_markers[cell] = marker

	var marker_texture := _marker_texture()
	for kind: String in MARKER_COLORS:
		_marker_materials[kind] = _marker_material(MARKER_COLORS[kind], marker_texture)


func _mesh_instance(mesh: Mesh, at: Vector3, orientation := Basis.IDENTITY) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = Transform3D(orientation, at)
	add_child(instance)
	return instance


func _plane(size: Vector2) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = size
	return plane


func _marker_material(color: Color, texture: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = texture
	m.albedo_color = color
	m.render_priority = 1
	return m


## Rounded-square highlight: a bold bright rim around a lightly tinted fill.
static func _marker_texture() -> ImageTexture:
	const SIZE := 128
	const RADIUS := 26.0
	const INSET := 3.0
	const RIM := 11.0
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE * 0.5
	var box := half - INSET - RADIUS
	for y in SIZE:
		for x in SIZE:
			var q := Vector2(absf(x + 0.5 - half) - box, absf(y + 0.5 - half) - box)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - RADIUS
			var alpha := lerpf(0.3, 1.0, smoothstep(-RIM - 2.0, -RIM + 1.0, d))
			alpha *= 1.0 - smoothstep(-1.5, 0.5, d)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
