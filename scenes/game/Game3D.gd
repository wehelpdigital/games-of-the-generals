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
var _view_key := ""  # Which match the camera was last set up for (see _on_match_loaded).
var _showcase: Dictionary = {}  # Guest title-screen showcase; replaces the player's own look.


func _ready() -> void:
	_apply_render_quality()
	Graphics.signals().changed.connect(_on_graphics_changed)
	if Graphics.effective() != "high":
		get_tree().node_added.connect(_on_node_added)
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
	if OS.has_feature("web"):
		_warm_up()
	else:
		warmed = true


## Menu backdrop: both armies on display (enemy ranks hidden) and a slow orbiting camera.
func show_attract() -> void:
	_formation_match = -1
	board.set_mode(Board3D.Mode.SPECTATE, Ranks.WHITE, false)
	rig.set_side(Ranks.WHITE)
	rig.attract = true
	_view_key = ""
	# A random "rival" so menus show combos. Not in the browser: every new look compiles shaders
	# with the page frozen (see Graphics), so there the rival wears the default look.
	_opponent_loadout = Loadout.random_loadout() if Graphics.live_showcase() else {}
	refresh_cosmetics()
	_show_attract_board()


## Applies every equipped cosmetic: the player's loadout on their side (plus the arena and board,
## which only the viewer sees), and the opponent's loadout on the other side.
func refresh_cosmetics() -> void:
	var mine := Loadout.complete(_showcase if not _showcase.is_empty() else Loadout.items)
	var theirs := Loadout.complete(_opponent_loadout)
	board.set_board_theme(mine["board"])
	arena.set_arena(mine["arena"])  # After the board theme: the arena owns sky, light and ground.
	_apply_side(board.my_side, mine)
	_apply_side(Ranks.opponent(board.my_side), theirs)
	_apply_toppers(board.my_side, mine, true)
	_apply_toppers(Ranks.opponent(board.my_side), theirs, false)


## Title-screen showcase for guests (FeatureShowcase): dresses the player's side in `mine`
## without touching their saved loadout, and the rival in `rival` if given. `{}` ends it.
func set_showcase(mine: Dictionary, rival := {}) -> void:
	_showcase = mine
	if not rival.is_empty():
		_opponent_loadout = rival
	refresh_cosmetics()


func _apply_side(side: String, loadout: Dictionary) -> void:
	board.set_chip_shape(side, loadout["shape"])
	board.set_piece_skin(side, loadout["chip"])
	board.set_territory(side, loadout["territory"])
	board.set_icon_pack(side, loadout["icons"])
	board.set_aura(side, loadout["aura"])
	board.set_board_glow(side, loadout["glow"])
	board.set_trail(side, loadout["trail"])
	board.set_kill_effect(side, loadout["kill"])
	board.set_ambience(side, loadout["ambience"])


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


## Shop preview: the camera shot that suits each category (CameraRig.frame).
const PREVIEW_SHOTS := {
	"arena": "wide", "board": "wide", "ambience": "sky", "territory": "half", "glow": "half",
	"chip": "close", "shape": "close", "icons": "close", "aura": "close", "topper": "toppers",
	"trail": "half", "kill": "half", "taunt": "half",
}


## Shop preview: the player's look with one item swapped in (nothing is equipped or saved) and a
## camera shot that suits it. end_preview() puts everything back.
func preview_item(category: String, slug: String) -> void:
	var look := Loadout.complete(Loadout.items)
	if category == "topper":
		var slots: Array = (look["toppers"]["slots"] as Array).filter(func(s: Dictionary) -> bool: return s["slug"] != slug)
		var slot := {"kind": ToppersLibrary.kind_of(slug), "slug": slug}
		if slot["kind"] == "flag":
			slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
		slots.push_front(slot)
		look["toppers"] = {"slots": slots.slice(0, ToppersLibrary.MAX_SLOTS)}
	elif look.has(category):
		look[category] = slug
	set_showcase(CosmeticCatalog.dress_with_pair(look, category, slug))
	rig.frame(PREVIEW_SHOTS.get(category, "half"))


func end_preview() -> void:
	set_showcase({})
	rig.attract = true


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
	_showcase = {}  # A real match always shows the player's own look.
	var side := GameSession.my_side()
	board.set_mode(Board3D.Mode.SPECTATE, side, false)
	# Every refresh reloads the match; only a new match (or side) resets the player's view.
	var view_key := "%d:%d:%s" % [GameSession.kind, GameSession.match_id(), side]
	if rig.attract or view_key != _view_key:
		_view_key = view_key
		rig.attract = false
		rig.set_side(side)
		rig.reset_view()
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
	rig.reset_view()  # The final board in the standard view.
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
	Graphics.apply(get_viewport(), key_light, env)


## Below High graphics, glowing effects and particles don't cast shadows: each shadow caster needs
## its own extra shader (more compiling in the browser) and their shadows were barely visible.
func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D and is_ancestor_of(node):
		_trim_shadow.call_deferred(node)  # Materials are often set right after the node is added.


func _trim_shadow(node: GeometryInstance3D) -> void:
	if not is_instance_valid(node) or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return
	if node is CPUParticles3D or node is GPUParticles3D or _all_unlit(node):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _all_unlit(node: GeometryInstance3D) -> bool:
	var mats: Array[Material] = []
	if node.material_override:
		mats.append(node.material_override)
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh:
		for i in (node as MeshInstance3D).mesh.get_surface_count():
			mats.append((node as MeshInstance3D).get_active_material(i))
	if mats.is_empty():
		return false
	for m in mats:
		if m is BaseMaterial3D:
			var b := m as BaseMaterial3D
			if b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				return false
		elif m is ShaderMaterial:
			var shader := (m as ShaderMaterial).shader
			if shader == null or not shader.code.contains("unshaded"):
				return false
		else:
			return false
	return true


func _on_graphics_changed() -> void:
	_apply_render_quality()
	refresh_cosmetics()


# --- Shader warm-up (web) ---------------------------------------------------------------------

signal warmed_up

var warmed := false  ## True once the first scene has been drawn (the web warm-up is over).


## In the browser the first frame would compile every shader on screen at once: tens of seconds
## on Windows (WebGL translates each one to Direct3D), with the page frozen and the loader stuck.
## Instead the scene appears behind the HTML loader one new material per frame (everything whose
## materials are already compiled appears at once), reporting progress to the loader, so the
## compiling happens in small steps and the title is responsive the moment it shows.
func _warm_up() -> void:
	var pending: Array[GeometryInstance3D] = []
	for node in _geometry_under(self):
		if Graphics.effective() != "high":
			_trim_shadow(node)
		if node.visible:
			node.visible = false
			pending.append(node)
	var keys_of := {}
	var all_keys := {}
	for node in pending:
		keys_of[node] = _shader_keys(node)
		for key: String in keys_of[node]:
			all_keys[key] = true
	var seen := {}
	while not pending.is_empty():
		var waiting: Array[GeometryInstance3D] = []
		var revealed_new := false
		for node in pending:
			if not is_instance_valid(node):
				continue
			var fresh: Array = (keys_of[node] as Array).filter(func(k: String) -> bool: return not seen.has(k))
			if fresh.is_empty():
				node.visible = true  # Nothing new to compile.
			elif not revealed_new:
				revealed_new = true
				node.visible = true
				for key: String in fresh:
					seen[key] = true
			else:
				waiting.append(node)
		pending = waiting
		_report_warm_up(seen.size(), all_keys.size() + EFFECT_STEPS)
		await RenderingServer.frame_post_draw
	await _warm_up_effects(all_keys.size(), all_keys.size() + EFFECT_STEPS)
	warmed = true
	warmed_up.emit()


const EFFECT_STEPS := 3  # Warm-up steps for the effects, on top of one per scene material.


## The first move and the first clash of a match use materials the menu board never shows (move
## markers, the selected piece, the clash and kill effects). Run them once behind the loader.
func _warm_up_effects(done: int, total: int) -> void:
	board.show_warmup_markers(true)
	_report_warm_up(done + 1, total)
	await RenderingServer.frame_post_draw
	board.show_warmup_markers(false)
	preview_effect("kill")  # A demo clash: move, elimination and both kill effects.
	_report_warm_up(done + 2, total)
	var until := Time.get_ticks_msec() + 2500
	while board.is_animating() and Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
	for i in 4:  # Leftover particles of the kill effect.
		await RenderingServer.frame_post_draw
	_show_attract_board()
	_report_warm_up(total, total)


func _report_warm_up(done: int, total: int) -> void:
	JavaScriptBridge.eval("window.salpakanWarmup && window.salpakanWarmup(%d, %d)" % [done, total], true)


## What a mesh needs compiled: one key per material shader, per instancing and shadow use. Two
## StandardMaterial3Ds with the same features share a shader, so their key is built from those.
func _shader_keys(node: GeometryInstance3D) -> Array:
	var mats: Array[Material] = []
	if node.material_override:
		mats.append(node.material_override)
	if node.material_overlay:
		mats.append(node.material_overlay)
	if node.material_override == null:
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			for i in (node as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (node as MeshInstance3D).get_active_material(i)
				if m:
					mats.append(m)
		elif node is CPUParticles3D and (node as CPUParticles3D).mesh:
			var pmesh := (node as CPUParticles3D).mesh
			for i in pmesh.get_surface_count():
				if pmesh.surface_get_material(i):
					mats.append(pmesh.surface_get_material(i))
	var suffix := ("|inst" if node is CPUParticles3D or node is MultiMeshInstance3D else "") 		+ ("|shadow" if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else "")
	var keys := []
	for m in mats:
		var chain: Material = m
		while chain:
			keys.append(_material_key(chain) + suffix)
			chain = chain.next_pass
	if keys.is_empty():
		keys.append(node.get_class() + suffix)
	return keys


func _material_key(m: Material) -> String:
	if m is ShaderMaterial:
		var shader := (m as ShaderMaterial).shader
		return "shader:%d" % (shader.get_instance_id() if shader else 0)
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return "base:%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d" % [b.transparency, b.shading_mode, b.diffuse_mode,
			b.specular_mode, b.blend_mode, b.cull_mode, b.depth_draw_mode, b.billboard_mode,
			int(b.vertex_color_use_as_albedo), int(b.albedo_texture != null), int(b.emission_enabled),
			int(b.no_depth_test), int(b.rim_enabled)]
	return m.get_class()


func _geometry_under(node: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for child in node.get_children():
		if child is GeometryInstance3D:
			found.append(child)
		found.append_array(_geometry_under(child))
	return found


# --- Rules visuals (turn timers, powerups) ---------------------------------------------------

var _rules_fx: RulesFX


## Powerup visuals and board picking (intel markers, shields, ice, mines, fog, targeting). Made on
## first use by the HUD's powerup bar, so the scene setup above stays untouched.
func rules_fx() -> RulesFX:
	if _rules_fx == null:
		_rules_fx = RulesFX.new()
		_rules_fx.name = "RulesFX"
		board.add_child(_rules_fx)
		_rules_fx.setup(board)
	return _rules_fx
