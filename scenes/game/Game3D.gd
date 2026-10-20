class_name Game3D
extends Node3D
## Scene controller for the 3D match. Wires GameSession (server truth) to Board3D (presentation),
## the camera rig and the environment. Holds no game rules.

@onready var board: Board3D = $Board3D
@onready var rig: CameraRig = $CameraRig
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight

var _formation_match := -1  # Match the local setup formation belongs to.


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
	ApiManager.user_updated.connect(_on_user_updated)
	show_attract()


## Menu backdrop: both armies on display (enemy ranks hidden) and a slow orbiting camera.
func show_attract() -> void:
	_formation_match = -1
	board.set_mode(Board3D.Mode.SPECTATE, Ranks.WHITE, false)
	rig.set_side(Ranks.WHITE)
	rig.attract = true
	_on_user_updated(ApiManager.user)
	board.set_piece_skin(Ranks.BLACK, CosmeticLibrary.DEFAULT_PIECES)
	_show_attract_board()


## New random formation during setup.
func shuffle_formation() -> void:
	if GameSession.status() in ["waiting", "setup"]:
		board.load_formation(Ranks.random_formation(GameSession.my_side()))


func preview_piece_skin(slug: String) -> void:
	board.set_piece_skin(board.my_side, slug)


func _on_match_loaded(view: Dictionary) -> void:
	var side := GameSession.my_side()
	board.set_mode(Board3D.Mode.SPECTATE, side, false)
	rig.attract = false
	rig.set_side(side)
	_apply_player_skins(view)

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


func _on_user_updated(user: Dictionary) -> void:
	var equipped: Variant = user.get("equipped")
	if not equipped is Dictionary:
		equipped = {}
	var theme: Variant = equipped.get("board_theme")
	board.set_board_theme(theme if theme is String else CosmeticLibrary.DEFAULT_BOARD)
	var skin: Variant = equipped.get("piece_skin")
	board.set_piece_skin(board.my_side, skin if skin is String else CosmeticLibrary.DEFAULT_PIECES)


## Each side wears its owner's equipped piece skin.
func _apply_player_skins(view: Dictionary) -> void:
	var players: Variant = view.get("players")
	for side: String in [Ranks.WHITE, Ranks.BLACK]:
		var skin := CosmeticLibrary.DEFAULT_PIECES
		if players is Dictionary and players.get(side) is Dictionary:
			var equipped: Variant = players[side].get("piece_skin")
			if equipped is String:
				skin = equipped
		board.set_piece_skin(side, skin)


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
