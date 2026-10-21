class_name Sfx
extends RefCounted
## Older call sites play sounds through here; they now go to the Audio autoload, which owns
## every sound file (see core/audio/Audio.gd).
##
##     Sfx.play(self, "coins")

const NAMES := {"coins": "coins", "fanfare": "rank_up", "tick": "timer_tick"}


static func play(owner: Node, sound: String, volume_db := 0.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var audio := owner.get_node_or_null("/root/Audio")
	if audio:
		audio.play(NAMES.get(sound, sound), volume_db)
