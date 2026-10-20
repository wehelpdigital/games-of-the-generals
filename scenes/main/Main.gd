extends Node
## App entry point: validates the saved login and wires the developer HUD to the session and the
## 3D scene.

@onready var game: Game3D = $Game3D
@onready var hud: DevHUD = $DevHUD


func _ready() -> void:
	hud.ready_pressed.connect(_on_ready_pressed)
	hud.shuffle_pressed.connect(game.shuffle_formation)
	hud.board_theme_selected.connect(game.board.set_board_theme)
	hud.piece_skin_selected.connect(game.preview_piece_skin)
	game.board.hover_changed.connect(hud.show_piece_hint)
	if ApiManager.is_logged_in():
		ApiManager.fetch_user()  # Refreshes the profile; a revoked token logs out (401).


func _on_ready_pressed() -> void:
	GameSession.submit_setup(game.board.get_setup_placements())
