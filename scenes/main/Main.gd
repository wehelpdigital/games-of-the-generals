extends Node
## App entry point: the 3D board (Game3D) runs underneath the UI screens (UIRoot). Starts on the
## title screen with the board orbiting behind it, and refreshes a saved login in the background.

@onready var game: Game3D = $Game3D
@onready var ui: UIRoot = $UI


func _ready() -> void:
	ui.game = game
	ui.home()
	if ApiManager.is_logged_in():
		ApiManager.fetch_user()  # Refreshes the profile; a revoked token logs out (401).
