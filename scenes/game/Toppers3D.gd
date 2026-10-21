class_name Toppers3D
extends Node3D
## Table toppers beside one player's half of the board (filled in below).

var side := Ranks.WHITE


func configure(for_side: String, _config: Dictionary, _guild_logo_url: String, _local_images: bool, _theme: String) -> void:
	side = for_side


func set_board_theme(_slug: String) -> void:
	pass
