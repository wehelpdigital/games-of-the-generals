class_name Game3D
extends Node3D
## Scene controller for the 3D match. Wires GameSession (server truth) to Board3D (presentation),
## the camera rig and the environment. Holds no game rules.

@onready var board: Board3D = $Board3D
@onready var rig: CameraRig = $CameraRig
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var arena: Arena3D = $Arena3D

var _formation_match := -1  # Match the local setup formation belongs to.
var _opponent_loadout: Dictionary = {}  # Cosmetics shown on the other side of the board.


func _ready() -> void:
	_apply_render_quality()
	board.camera = rig.camera
	board.move_requested.connect(GameSession.request_move)
	board.clash_impact.connect(rig.shake)
	board.desync_detected.connect(GameSession.refresh)
	board.animations_idle.connect(_refresh_mode)
	GameSession.match_loaded.connect(_on_match_loaded)
	GameSession.move_result.connect(board.apply_move_result)
	GameSession.move_rejected.connect(_on_move_rejected)
	GameSession.turn_changed.connect(_refresh_mode)
	GameSession.game_over.connect(_on_game_over)
	Loadout.changed.connect(_on_loadout_changed)
	show_attract()


## Menu backdrop: both armies on display (enemy ranks hidden) and a slow orbiting camera.
func show_attract() -> void:
	_formation_match = -1
	board.set_mode(Board3D.Mode.SPECTATE, Ranks.WHITE, false)
	rig.set_side(Ranks.WHITE)
	rig.attract = true
	_opponent_loadout = Loadout.random_loadout()  # A random "rival" so menus show combos.
	refresh_cosmetics()
	_show_attract_board()


## Applies every equipped cosmetic: the player's loadout on their side (plus the arena and board,
## which only the viewer sees), and the opponent's loadout on the other side.
func refresh_cosmetics() -> void:
	var mine := Loadout.complete(Loadout.items)
	var theirs := Loadout.complete(_opponent_loadout)
	board.set_board_theme(mine["board"])
	arena.set_arena(mine["arena"])  # After the board theme: the arena owns sky, light and ground.
	_apply_side(board.my_side, mine)
	_apply_side(Ranks.opponent(board.my_side), theirs)
	_apply_toppers(board.my_side, mine, true)
	_apply_toppers(Ranks.opponent(board.my_side), theirs, false)


func _apply_side(side: String, loadout: Dictionary) -> void:
	board.set_chip_shape(side, loadout["shape"])
	board.set_piece_skin(side, loadout["chip"])
	board.set_territory(side, loadout["territory"])
	board.set_icon_pack(side, loadout["icons"])
	board.set_aura(side, loadout["aura"])
	board.set_board_glow(side, loadout["glow"])
	board.set_trail(side, loadout["trail"])
	board.set_kill_effect(side, loadout["kill"])


## Toppers beside `side`'s half. Only the player's own flags may use pictures kept on this device;
## guild-logo flags use the owner's guild logo.
func _apply_toppers(side: String, loadout: Dictionary, mine: bool) -> void:
	var logo := _my_guild_logo() if mine else str(_opponent_loadout.get("guild_logo_url", ""))
	board.set_toppers(side, loadout["toppers"], logo, mine)


func _my_guild_logo() -> String:
	var guild: Variant = ApiManager.user.get("guild")
	return str(guild.get("logo_url", "")) if guild is Dictionary and guild.get("logo_url") != null else ""


## Editing toppers (e.g. in the flag editor) only rebuilds the toppers, not the whole look.
func _on_loadout_changed(category: String, _slug: String) -> void:
	if category == "toppers":
		_apply_toppers(board.my_side, Loadout.complete(Loadout.items), true)
	else:
		refresh_cosmetics()


## Shop preview for effects that only show during play: a demo move (trail) or a demo knockout
## (kill effect) by one of the player's pieces on the menu board.
func preview_effect(category: String) -> void:
	if board.is_animating() or GameSession.has_match():
		return
	var mine: Array = board.pieces.values().filter(func(p: Piece3D) -> bool: return p.side == board.my_side)
	var theirs: Array = board.pieces.values().filter(func(p: Piece3D) -> bool: return p.side != board.my_side)
	if mine.is_empty():
		return
	var forward := Vector2i(0, 1) if board.my_side == Ranks.WHITE else Vector2i(0, -1)
	if category == "kill" and not theirs.is_empty():
		var hero: Piece3D = mine.pick_random()
		var victim: Piece3D = theirs.pick_random()
		board.apply_move_result({"piece_id": hero.piece_id, "from": _cell(hero.cell), "to": _cell(victim.cell),
			"clash": {"defender_id": victim.piece_id, "outcome": "attacker", "eliminated": [victim.piece_id]}})
		await board.animations_idle
		await get_tree().create_timer(1.2).timeout
		if not GameSession.has_match():
			_show_attract_board()
		return
	# Trail: step forward onto a free tile, then back.
	for piece: Piece3D in mine:
		var to := piece.cell + forward
		if Ranks.in_bounds(to) and board.piece_at(to) == null:
			var from := piece.cell
			board.apply_move_result({"piece_id": piece.piece_id, "from": _cell(from), "to": _cell(to), "clash": null})
			board.apply_move_result({"piece_id": piece.piece_id, "from": _cell(to), "to": _cell(from), "clash": null})
			return


## Throws a taunt from `from_side` at the other half of the board (shop preview or in-match).
func throw_taunt(from_side: String, slug: String) -> void:
	TauntFX.throw(board, from_side, slug)


func _cell(cell: Vector2i) -> Dictionary:
	return {"x": cell.x, "y": cell.y}


## New random formation during setup.
func shuffle_formation() -> void:
	if GameSession.status() in ["waiting", "setup"]:
		board.load_formation(Ranks.random_formation(GameSession.my_side()))


func _on_match_loaded(view: Dictionary) -> void:
	var side := GameSession.my_side()
	board.set_mode(Board3D.Mode.SPECTATE, side, false)
	rig.attract = false
	rig.set_side(side)
	var players: Variant = view.get("players")
	var rival: Variant = players.get(Ranks.opponent(side)) if players is Dictionary else null
	_opponent_loadout = (rival["loadout"] as Dictionary).duplicate(true) if rival is Dictionary and rival.get("loadout") is Dictionary else {}
	if rival is Dictionary and rival.get("guild") is Dictionary and rival["guild"].get("logo_url") != null:
		_opponent_loadout["guild_logo_url"] = str(rival["guild"]["logo_url"])
	refresh_cosmetics()

	var pieces: Array = view.get("pieces", [])
	var own := pieces.filter(func(p: Dictionary) -> bool: return p.get("side") == side)
	var match_key := int(view.get("id", 0))
	if str(view.get("status")) in ["waiting", "setup"] and own.is_empty():
		# Nothing submitted yet: keep the formation the player is arranging, or deal a new one.
		if _formation_match != match_key or not board.has_own_pieces():
			board.load_formation(Ranks.random_formation(side))
		_formation_match = match_key
	else:
		board.sync_pieces(pieces)
	_refresh_mode()


func _refresh_mode() -> void:
	if not GameSession.has_match():
		return
	var side := GameSession.my_side()
	match GameSession.status():
		"waiting", "setup":
			board.set_mode(Board3D.Mode.SETUP, side, true)
		"active":
			board.set_mode(Board3D.Mode.PLAY, side, GameSession.is_my_turn())
		_:
			board.set_mode(Board3D.Mode.SPECTATE, side, false)


func _on_move_rejected(_piece_id: String, _message: String) -> void:
	board.cancel_pending()


func _on_game_over(info: Dictionary) -> void:
	board.reveal_ranks(info.get("pieces", []))
	rig.shake(0.35)
	_refresh_mode()


## Before any match: a dressed board with hidden enemy pieces, purely decorative.
func _show_attract_board() -> void:
	var pieces: Array = []
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		var formation := Ranks.random_formation(side)
		for i in formation.size():
			var f: Dictionary = formation[i]
			pieces.append({"id": "%s_%d" % [side, i], "side": side, "x": f["x"], "y": f["y"],
				"rank": f["rank"] if side == Ranks.WHITE else null})
	board.sync_pieces(pieces)


## The look is flat cel shading (toon materials, ink outlines, tinted ambient shadows), so SSAO and
## SSR stay off on every renderer: they would muddy the clean colour bands. That keeps web, Android,
## iOS and desktop looking identical on the Compatibility renderer.
func _apply_render_quality() -> void:
	var env := world_env.environment
	env.ssao_enabled = false
	env.ssr_enabled = false
	if OS.has_feature("web") or OS.has_feature("mobile"):
		key_light.directional_shadow_max_distance = 18.0
