class_name RulesFX
extends Node3D
## Board-side visuals for turn timers and powerups, plus the board picking that targeted powerups
## need. Lives under Board3D (see Game3D.rules_fx()) and only reads GameSession, so it never changes
## the rules: intel markers over enemy pieces you identified, your secret Fortify shields, Decoys
## and Mines, ice on frozen pieces, Smoke Screen fog, and pop-ups for bounces, mines, saves, rally
## cries, hidden and forced moves.

signal target_picked(target: Dictionary)
signal targeting_changed(prompt: String)  ## "" when targeting ends.

const MARK_Y := 1.0
const GROUP_COLORS := {"general": Color("ff5a5f"), "officer": Color("ffb703"), "enlisted": Color("27c98f"),
	"spy": Color("8b5cf6"), "flag": Color("ff4f8b")}
const PICK_PROMPTS := {
	"own_piece": "Tap one of your pieces", "enemy_piece": "Tap an enemy piece",
	"home_cell": "Tap an empty square in your 3 home rows", "half_cell": "Tap an empty square on your half",
	"back_cell": "Tap an empty square on your back row", "empty_cell": "Tap any empty square",
	"any_cell": "Tap the centre of the area to sweep",
}

static var _rim: ImageTexture

var board: Board3D

var _fog: FogOverlay
var _mines: Dictionary = {}  # "x,y" -> Node3D (your Mine Fields and Quicksand)
var _roadblocks: Dictionary = {}  # "x,y" -> Node3D (everyone's)
var _targeting: Dictionary = {}  # {id, picks, step, chosen: [...]}
var _valid: Array[Vector2i] = []
var _target_marks: Array[MeshInstance3D] = []
var _target_material: StandardMaterial3D
var _chosen_material: StandardMaterial3D
var _time := 0.0
var _refresh_queued := false


func setup(game_board: Board3D) -> void:
	board = game_board
	_fog = FogOverlay.new()
	add_child(_fog)
	_target_material = _flat_material(Color(1.0, 0.8, 0.2, 0.9))
	_chosen_material = _flat_material(Color(0.3, 1.0, 0.65, 1.0))
	GameSession.rules_changed.connect(queue_refresh)
	GameSession.match_loaded.connect(func(_view: Dictionary) -> void: queue_refresh())
	GameSession.turn_changed.connect(_on_turn_changed)
	GameSession.rule_event.connect(_on_rule_event)
	GameSession.powerup_used.connect(_on_powerup_used)
	GameSession.powerup_result.connect(_on_powerup_result)
	board.animations_idle.connect(queue_refresh)
	queue_refresh()


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	_target_material.albedo_color.a = 0.55 + 0.45 * pulse
	for mark in _target_marks:
		var halo := mark.get_node_or_null("Halo") as Sprite3D
		if halo:
			halo.position.y = 1.0 + 0.08 * sin(_time * 4.0)
			halo.modulate.a = 0.6 + 0.4 * pulse
	for mine: Node3D in _mines.values():
		var light := mine.get_node_or_null("Light") as MeshInstance3D
		if light:
			light.visible = fmod(_time, 1.2) < 0.6


func queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


# --- Persistent markers -----------------------------------------------------------------------

func _refresh() -> void:
	_refresh_queued = false
	if board == null:
		return
	var live := GameSession.has_match() and GameSession.status() == "active"
	_fog.set_fog(live and GameSession.has_fog(), Ranks.opponent(GameSession.my_side()))
	if board.is_animating():
		return  # Pieces are mid-flight; animations_idle brings us back.
	var marks := {}  # piece id -> [{kind, ...}]
	if live:
		for entry: Dictionary in GameSession.revealed():
			_add_mark(marks, str(entry.get("piece_id")), entry)
		var fx := GameSession.effects()
		for list_name: String in ["mine", "opponent"]:
			for e: Variant in fx.get(list_name, []):
				if e is Dictionary and e.get("piece_id") != null and e.get("type") in ["fortify", "decoy", "freeze", "trench"]:
					_add_mark(marks, str(e["piece_id"]), {"effect": e["type"], "turns_left": e.get("turns_left")})
	for piece: Piece3D in board.pieces.values():
		_apply_marks(piece, marks.get(piece.piece_id, []))
	_refresh_mines(GameSession.my_mines() if live else [])
	_refresh_roadblocks(GameSession.step_rules()["blocked"] if live else [])


func _add_mark(marks: Dictionary, piece_id: String, mark: Dictionary) -> void:
	if not marks.has(piece_id):
		marks[piece_id] = []
	marks[piece_id].append(mark)


## Rebuilds a piece's marker node only when what it should show changed.
func _apply_marks(piece: Piece3D, list: Array) -> void:
	var signature := JSON.stringify(list)
	var holder := piece.get_node_or_null("RulesMarks") as Node3D
	if holder != null and holder.get_meta("signature", "") == signature:
		return
	if holder != null:
		holder.free()
	if list.is_empty():
		return
	holder = Node3D.new()
	holder.name = "RulesMarks"
	holder.set_meta("signature", signature)
	piece.add_child(holder)
	var rank := ""
	var group := ""
	var flag_hint: Variant = null
	for mark: Dictionary in list:
		if mark.has("rank"):
			rank = str(mark["rank"])
		elif mark.has("group"):
			group = str(mark["group"])
		elif mark.has("is_flag"):
			flag_hint = bool(mark["is_flag"])
		match mark.get("effect", ""):
			"fortify":
				holder.add_child(_shield())
			"freeze":
				holder.add_child(_ice())
			"decoy":
				holder.add_child(_tag("DECOY", AppTheme.PURPLE, 0.62))
			"trench":
				holder.add_child(_sandbags())
	if rank != "":
		holder.add_child(_badge(rank))
	elif group != "":
		holder.add_child(_tag(PowerupLibrary.GROUP_NAMES.get(group, group).to_upper(), GROUP_COLORS.get(group, AppTheme.BLUE), MARK_Y))
	elif flag_hint != null:
		holder.add_child(_tag("FLAG!" if flag_hint else "NOT FLAG", AppTheme.PINK if flag_hint else AppTheme.MUTED, MARK_Y))


func _refresh_mines(list: Array) -> void:
	var wanted := {}
	for m: Variant in list:
		if m is Dictionary:
			wanted["%d,%d,%s" % [int(m["x"]), int(m["y"]), str(m.get("kind", "mine"))]] = Vector2i(int(m["x"]), int(m["y"]))
	for key: String in _mines.keys():
		if not wanted.has(key):
			_mines[key].queue_free()
			_mines.erase(key)
	for key: String in wanted:
		if not _mines.has(key):
			var trap := _quicksand_model() if key.ends_with("quicksand") else _mine_model()
			trap.position = Board3D.cell_to_local(wanted[key]) + Vector3(0.0, 0.03, 0.0)
			add_child(trap)
			_mines[key] = trap


func _refresh_roadblocks(cells: Array) -> void:
	var wanted := {}
	for cell: Vector2i in cells:
		wanted["%d,%d" % [cell.x, cell.y]] = cell
	for key: String in _roadblocks.keys():
		if not wanted.has(key):
			_roadblocks[key].queue_free()
			_roadblocks.erase(key)
	for key: String in wanted:
		if not _roadblocks.has(key):
			var barricade := _barricade_model()
			barricade.position = Board3D.cell_to_local(wanted[key])
			add_child(barricade)
			_roadblocks[key] = barricade


# --- Targeting --------------------------------------------------------------------------------

func is_targeting() -> bool:
	return not _targeting.is_empty()


## Starts picking the targets powerup `id` needs. target_picked fires with the finished target.
func begin_targeting(id: String) -> void:
	cancel_targeting(false)
	var picks: Array = PowerupLibrary.picks(id)
	if picks.is_empty():
		target_picked.emit({})
		return
	_targeting = {"id": id, "picks": picks, "step": 0, "chosen": []}
	_show_step()


func cancel_targeting(announce := true) -> void:
	_targeting = {}
	_clear_target_marks()
	if announce:
		targeting_changed.emit("")


func _show_step() -> void:
	_clear_target_marks()
	var kind: String = _targeting["picks"][_targeting["step"]]
	_valid = _valid_cells(kind)
	for cell in _valid:
		var mark := _cell_mark(cell, _target_material)
		if kind.ends_with("piece"):
			mark.add_child(_halo())  # Pieces hide most of their square: float a ring above them too.
		_target_marks.append(mark)
	for chosen: Dictionary in _targeting["chosen"]:
		_target_marks.append(_cell_mark(chosen["cell"], _chosen_material))
	var prompt: String = PICK_PROMPTS.get(kind, "Pick a target")
	if _targeting["picks"].size() > 1:
		prompt += " (%d/%d)" % [_targeting["step"] + 1, _targeting["picks"].size()]
	targeting_changed.emit(prompt if not _valid.is_empty() else "Nothing to target right now")


func _valid_cells(kind: String) -> Array[Vector2i]:
	var side := GameSession.my_side()
	var cells: Array[Vector2i] = []
	var frozen := {}
	for e: Variant in GameSession.effects().get("opponent", []):
		if e is Dictionary and e.get("type") == "freeze" and e.get("piece_id") != null:
			frozen[str(e["piece_id"])] = true
	var taken := {}
	for chosen: Dictionary in _targeting.get("chosen", []):
		taken[chosen["cell"]] = true
	var id: String = _targeting.get("id", "")
	var moves_pieces: bool = id in ["swap", "teleport", "retreat"]
	var blocked: Array = GameSession.step_rules()["blocked"]
	match kind:
		"own_piece", "enemy_piece":
			for piece: Piece3D in board.pieces.values():
				var mine := piece.side == side
				if mine != (kind == "own_piece") or taken.has(piece.cell):
					continue
				if moves_pieces and frozen.has(piece.piece_id):
					continue
				if id == "promotion" and piece.rank != "PVT":
					continue  # Only Privates can be promoted.
				if id == "interrogation" and not _touches_mine(piece.cell, side):
					continue  # Only enemies standing next to one of yours.
				cells.append(piece.cell)
		"any_cell":
			for y in Ranks.ROWS:
				for x in Ranks.COLS:
					cells.append(Vector2i(x, y))
		_:
			var mines := {}
			for m: Variant in GameSession.my_mines():
				if m is Dictionary:
					mines[Vector2i(int(m["x"]), int(m["y"]))] = true
			for y in Ranks.ROWS:
				for x in Ranks.COLS:
					var cell := Vector2i(x, y)
					if board.piece_at(cell) != null or taken.has(cell) or blocked.has(cell):
						continue
					var ok := false
					match kind:
						"empty_cell":
							ok = true
						"home_cell":
							ok = Ranks.is_home_cell(side, cell)
						"half_cell":
							ok = LocalArbiter.is_own_half(side, cell) and not mines.has(cell)
						"back_cell":
							ok = y == LocalArbiter.back_row(side)
					if ok:
						cells.append(cell)
	return cells


func _touches_mine(cell: Vector2i, side: String) -> bool:
	for n in Ranks.neighbors(cell):
		var piece := board.piece_at(n)
		if piece != null and piece.side == side:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _targeting.is_empty():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_targeting()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_pick(_cell_under(event.position))


func _pick(cell: Vector2i) -> void:
	if not cell in _valid:
		return
	var piece := board.piece_at(cell)
	_targeting["chosen"].append({"cell": cell, "piece_id": piece.piece_id if piece else ""})
	_targeting["step"] += 1
	if _targeting["step"] < _targeting["picks"].size():
		_show_step()
		return
	var target := {}
	var chosen: Array = _targeting["chosen"]
	match str(_targeting["id"]):
		"swap":
			target = {"piece_ids": [chosen[0]["piece_id"], chosen[1]["piece_id"]]}
		"teleport":
			target = {"piece_id": chosen[0]["piece_id"], "x": chosen[1]["cell"].x, "y": chosen[1]["cell"].y}
		_:
			var last: Dictionary = chosen[0]
			var wants_cell: bool = _targeting["picks"][0].ends_with("cell")
			target = {"x": last["cell"].x, "y": last["cell"].y} if wants_cell or last["piece_id"] == "" else {"piece_id": last["piece_id"]}
	cancel_targeting()
	target_picked.emit(target)


## The board square under the pointer: a piece's plaque first (it stands above its square), then
## the board plane.
func _cell_under(screen_pos: Vector2) -> Vector2i:
	var cam := board.camera if board.camera != null else get_viewport().get_camera_3d()
	if cam == null:
		return Board3D.NO_CELL
	var from := cam.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 200.0, Piece3D.PICK_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] != null and hit["collider"].has_meta("piece"):
		var piece: Piece3D = hit["collider"].get_meta("piece")
		if is_instance_valid(piece) and board.pieces.has(piece.piece_id):
			return piece.cell
	var inverse := board.global_transform.affine_inverse()
	var origin := inverse * from
	var direction := (inverse.basis * cam.project_ray_normal(screen_pos)).normalized()
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point == null:
		return Board3D.NO_CELL
	var cell := Board3D.local_to_cell(point)
	return cell if Ranks.in_bounds(cell) else Board3D.NO_CELL


func _clear_target_marks() -> void:
	for mark in _target_marks:
		mark.queue_free()
	_target_marks.clear()
	_valid.clear()


func _on_turn_changed() -> void:
	if not GameSession.is_my_turn() and is_targeting():
		cancel_targeting()


# --- One-off moments --------------------------------------------------------------------------

func _on_rule_event(event: Dictionary) -> void:
	await _after_board()
	if board == null:
		return
	var cell := _cell_of(event.get("cell"))
	match str(event.get("kind")):
		"bounce":
			_ring_burst(cell, Color(0.4, 0.9, 1.0))
			_pop(Board3D.cell_to_local(cell) + Vector3(0, 1.1, 0), "BLOCKED!", Color("3ad0ff"))
		"mine":
			_explosion(cell)
			_pop(Board3D.cell_to_local(cell) + Vector3(0, 1.2, 0), "SAVED!" if event.get("saved") else "BOOM!", AppTheme.RED)
			board.clash_impact.emit(0.9)
		"saved":
			for id: Variant in event.get("piece_ids", []):
				var piece: Piece3D = board.pieces.get(str(id))
				if piece:
					_ring_burst(piece.cell, Color(1.0, 0.95, 0.5))
					_pop(piece.position + Vector3(0, 1.2, 0), "SECOND CHANCE!", AppTheme.MINT)
		"rally":
			_pop(Board3D.cell_to_local(cell) + Vector3(0, 1.3, 0) if cell != Board3D.NO_CELL else Vector3(0, 1.4, 0), "RALLY CRY!", AppTheme.GOLD)
		"trench":
			_ring_burst(cell, Color("c9a26b"))
			_pop(Board3D.cell_to_local(cell) + Vector3(0, 1.3, 0) if cell != Board3D.NO_CELL else Vector3(0, 1.4, 0), "DUG IN!", Color("e3c08a"))
		"quicksand":
			_ring_burst(cell, Color("d9b26a"))
			_pop(Board3D.cell_to_local(cell) + Vector3(0, 1.2, 0), "STUCK!", Color("f0c674"))
		"hidden":
			_smoke_puff(Ranks.opponent(GameSession.my_side()) if str(event.get("side")) != GameSession.my_side() else GameSession.my_side())
			_pop(Vector3(0, 1.4, 0), "HIDDEN MOVE", AppTheme.PURPLE)
		"auto":
			_pop(Vector3(0, 1.4, 0), "CHAOS!" if event.get("chaos") else "TIME UP!", AppTheme.PURPLE if event.get("chaos") else AppTheme.RED)
		"pass":
			_pop(Vector3(0, 1.4, 0), "TURN PASSED", AppTheme.MUTED)


func _on_powerup_used(event: Dictionary) -> void:
	if board == null:
		return
	var side := str(event.get("side", ""))
	var near := Board3D.cell_to_local(Vector2i(4, 1 if side == Ranks.WHITE else Ranks.ROWS - 2))
	if event.get("countered", false):
		_pop(near + Vector3(0, 1.5, 0), "COUNTERED!", AppTheme.PINK)
	var icon := Sprite3D.new()
	icon.texture = PowerupLibrary.icon(str(event.get("id", "")))
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.render_priority = 10
	icon.pixel_size = 1.1 / PowerupLibrary.ICON_SIZE
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = near + Vector3(0, 0.8, 0)
	icon.scale = Vector3.ONE * 0.2
	add_child(icon)
	var t := icon.create_tween()
	t.tween_property(icon, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(icon, "position:y", near.y + 1.6, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(icon, "modulate:a", 0.0, 0.4)
	t.tween_callback(icon.queue_free)
	# Board-changing powerups land after the board catches up.
	if str(event.get("id")) in ["freeze", "teleport", "swap", "reinforcement", "retreat", "roadblock"]:
		var public: Dictionary = event.get("public", {}) if event.get("public") is Dictionary else {}
		var spot := _cell_of(public.get("to", public.get("piece", public)))
		if spot != Board3D.NO_CELL:
			await _after_board()
			_ring_burst(spot, PowerupLibrary.color(str(event["id"])))


func _on_powerup_result(result: Dictionary) -> void:
	var private: Dictionary = result.get("private", {}) if result.get("private") is Dictionary else {}
	var spots: Array = []
	if private.get("piece_id") != null:
		spots.append(str(private["piece_id"]))
	for entry: Variant in private.get("pieces", []):
		if entry is Dictionary:
			spots.append(str(entry.get("piece_id", entry.get("id", ""))))
	await _after_board()
	if board == null:
		return
	for id: String in spots:
		var piece: Piece3D = board.pieces.get(id)
		if piece:
			_ring_burst(piece.cell, PowerupLibrary.color(str(result.get("id", ""))))
	if private.get("x") != null and str(result.get("id")) == "flag_hunter":
		var x := int(private["x"])
		for y in Ranks.ROWS:
			if not LocalArbiter.is_own_half(GameSession.my_side(), Vector2i(x, y)):
				_ring_burst(Vector2i(x, y), AppTheme.PINK)
	queue_refresh()


func _after_board() -> void:
	await get_tree().process_frame
	if board != null and board.is_animating():
		await board.animations_idle


# --- Little 3D builders -----------------------------------------------------------------------

func _badge(rank: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = PieceIcons.badge_or_mystery(rank)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.render_priority = 6
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 0.5 / float(sprite.texture.get_width()) if sprite.texture else 0.002
	sprite.position.y = MARK_Y
	var bob := sprite.create_tween().set_loops()
	bob.tween_property(sprite, "position:y", MARK_Y + 0.08, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", MARK_Y, 0.9).set_trans(Tween.TRANS_SINE)
	return sprite


func _tag(text: String, color: Color, height: float) -> Label3D:
	var label := _label(text, color, 34)
	label.position.y = height
	return label


func _label(text: String, color: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = AppTheme.heading_font()
	label.font_size = size
	label.outline_size = 12
	label.modulate = color
	label.outline_modulate = AppTheme.INK
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 7
	label.outline_render_priority = 6
	return label


func _shield() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.9
	sphere.radial_segments = 24
	sphere.rings = 12
	var bubble := MeshInstance3D.new()
	bubble.mesh = sphere
	bubble.position.y = 0.3
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.35, 0.85, 1.0, 0.4)
	m.rim_enabled = false
	m.cull_mode = BaseMaterial3D.CULL_BACK
	bubble.material_override = m
	var t := bubble.create_tween().set_loops()
	t.tween_property(m, "albedo_color:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(m, "albedo_color:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	return bubble


func _ice() -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.62, 0.9)
	var ice := MeshInstance3D.new()
	ice.mesh = box
	ice.position.y = 0.3
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.92, 1.0, 0.45)
	ice.material_override = m
	var flakes := _label("ICE", Color(0.85, 0.97, 1.0), 40)
	flakes.position.y = 0.72
	ice.add_child(flakes)
	return ice


func _mine_model() -> Node3D:
	var root := Node3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.24
	disc.height = 0.08
	var body := MeshInstance3D.new()
	body.mesh = disc
	body.position.y = 0.04
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b2840")
	dark.roughness = 0.6
	body.material_override = dark
	root.add_child(body)
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	var light := MeshInstance3D.new()
	light.name = "Light"
	light.mesh = bulb
	light.position.y = 0.1
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.2, 0.25)
	light.material_override = red
	root.add_child(light)
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.8, 0.8)
	ring.mesh = plane
	ring.position.y = 0.012
	ring.material_override = FxTextures.decal_material("glow_ring", Color(0.95, 0.15, 0.2, 0.85), false)
	root.add_child(ring)
	var tag := _label("MINE", AppTheme.RED, 26)
	tag.position.y = 0.45
	root.add_child(tag)
	return root


## Quicksand: a swirl of golden sand only its owner sees.
func _quicksand_model() -> Node3D:
	var root := Node3D.new()
	var pit := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)
	pit.mesh = plane
	pit.position.y = 0.012
	pit.material_override = FxTextures.decal_material("glow_ring", Color(0.95, 0.75, 0.35, 0.9), false)
	root.add_child(pit)
	var sand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.36
	disc.height = 0.02
	sand.mesh = disc
	sand.position.y = 0.02
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d9b26a")
	m.roughness = 1.0
	sand.material_override = m
	root.add_child(sand)
	var spin := sand.create_tween().set_loops()
	spin.tween_property(sand, "rotation:y", TAU, 3.0).from(0.0)
	var tag := _label("SAND", Color("f0c674"), 26)
	tag.position.y = 0.45
	root.add_child(tag)
	return root


## Roadblock: striped barrier planks on two posts; both players see it.
func _barricade_model() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a5a35")
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color("ff5a5f")
	for side_x: float in [-0.32, 0.32]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.08, 0.5, 0.08)
		post.mesh = post_mesh
		post.material_override = wood
		post.position = Vector3(side_x, 0.25, 0.0)
		root.add_child(post)
	for i in 2:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(0.82, 0.1, 0.05)
		plank.mesh = plank_mesh
		plank.material_override = stripe if i == 0 else wood
		plank.position = Vector3(0.0, 0.22 + i * 0.18, 0.0)
		plank.rotation.z = 0.12 if i == 0 else -0.12
		root.add_child(plank)
	for child in root.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Trench: a ring of sandbags around a dug-in piece.
func _sandbags() -> Node3D:
	var ring := Node3D.new()
	var burlap := StandardMaterial3D.new()
	burlap.albedo_color = Color("c9a26b")
	burlap.roughness = 1.0
	for i in 8:
		var bag := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.07
		capsule.height = 0.26
		bag.mesh = capsule
		bag.material_override = burlap
		var angle := TAU * i / 8.0
		bag.position = Vector3(cos(angle) * 0.46, 0.06, sin(angle) * 0.46)
		bag.rotation = Vector3(0.0, -angle, PI / 2.0)
		bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.add_child(bag)
	return ring


func _cell_mark(cell: Vector2i, material: StandardMaterial3D) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Board3D.TILE - Board3D.TILE_GAP + 0.04, Board3D.TILE - Board3D.TILE_GAP + 0.04)
	var mark := MeshInstance3D.new()
	mark.mesh = plane
	mark.material_override = material
	mark.position = Board3D.cell_to_local(cell) + Vector3(0, 0.02, 0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	return mark


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _rim_texture()
	m.albedo_color = color
	m.render_priority = 2
	return m


## Rounded-square highlight like the board's move markers: a bright rim around a light fill.
static func _rim_texture() -> ImageTexture:
	if _rim != null:
		return _rim
	const SIZE := 128
	const RADIUS := 26.0
	const RIM := 12.0
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE * 0.5
	var box := half - 3.0 - RADIUS
	for y in SIZE:
		for x in SIZE:
			var q := Vector2(absf(x + 0.5 - half) - box, absf(y + 0.5 - half) - box)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - RADIUS
			var alpha := lerpf(0.25, 1.0, smoothstep(-RIM - 2.0, -RIM + 1.0, d)) * (1.0 - smoothstep(-1.5, 0.5, d))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	_rim = ImageTexture.create_from_image(image)
	return _rim


func _halo() -> Sprite3D:
	var halo := Sprite3D.new()
	halo.name = "Halo"
	halo.texture = FxTextures.texture("glow_ring")
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.no_depth_test = true
	halo.render_priority = 8
	halo.pixel_size = 0.55 / FxTextures.SIZE
	halo.modulate = Color(1.0, 0.85, 0.2)
	halo.position.y = 1.0
	return halo


func _pop(at: Vector3, text: String, color: Color) -> void:
	var label := _label(text, color, 56)
	label.position = at
	label.scale = Vector3.ONE * 0.3
	add_child(label)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(label, "position:y", at.y + 0.5, 0.45)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	t.tween_callback(label.queue_free)


func _ring_burst(cell: Vector2i, color: Color) -> void:
	if cell == Board3D.NO_CELL:
		return
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	ring.mesh = plane
	ring.material_override = FxTextures.decal_material("glow_ring", Color(color, 0.9))
	ring.position = Board3D.cell_to_local(cell) + Vector3(0, 0.05, 0)
	ring.scale = Vector3.ONE * 0.4
	add_child(ring)
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.6).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6)
	t.tween_callback(ring.queue_free)


func _explosion(cell: Vector2i) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 40
	burst.lifetime = 0.9
	var quad := QuadMesh.new()
	quad.material = FxTextures.particle_material("puff")
	burst.mesh = quad
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3(0, -3.0, 0)
	burst.scale_amount_min = 0.3
	burst.scale_amount_max = 0.7
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3))
	ramp.add_point(0.35, Color(1.0, 0.4, 0.15))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.3, 0.28, 0.35, 0.0))
	burst.color_ramp = ramp
	burst.position = Board3D.cell_to_local(cell) + Vector3(0, 0.3, 0)
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	_ring_burst(cell, Color(1.0, 0.5, 0.2))


func _smoke_puff(side: String) -> void:
	var cloud := CPUParticles3D.new()
	cloud.one_shot = true
	cloud.explosiveness = 0.8
	cloud.amount = 24
	cloud.lifetime = 1.6
	var quad := QuadMesh.new()
	quad.material = FxTextures.particle_material("puff")
	cloud.mesh = quad
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cloud.emission_box_extents = Vector3(Ranks.COLS * 0.45, 0.2, Ranks.ROWS * 0.22)
	cloud.direction = Vector3.UP
	cloud.initial_velocity_min = 0.2
	cloud.initial_velocity_max = 0.6
	cloud.gravity = Vector3.ZERO
	cloud.scale_amount_min = 0.8
	cloud.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(FogOverlay.TINT, 0.0))
	ramp.add_point(0.25, Color(FogOverlay.TINT, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(FogOverlay.TINT, 0.0))
	cloud.color_ramp = ramp
	var row := 1 if side == Ranks.WHITE else Ranks.ROWS - 2
	cloud.position = Board3D.cell_to_local(Vector2i(4, row)) + Vector3(0, 0.6, 0.5 if side == Ranks.WHITE else -0.5)
	add_child(cloud)
	cloud.emitting = true
	cloud.finished.connect(cloud.queue_free)


func _cell_of(value: Variant) -> Vector2i:
	if value is Dictionary and value.get("x") != null and value.get("y") != null:
		return Vector2i(int(value["x"]), int(value["y"]))
	return Board3D.NO_CELL
