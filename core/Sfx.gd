class_name Sfx
extends RefCounted
## Tiny synthesized sound effects (no audio files): a coin chime for rewards and a fanfare for
## unlocks. Generated once into AudioStreamWAV buffers and played on a throwaway player.
##
##     Sfx.play(self, "coins")

const RATE := 22050

static var _cache: Dictionary = {}


static func play(owner: Node, sound: String, volume_db := -6.0) -> void:
	if owner == null or not owner.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = _stream(sound)
	player.volume_db = volume_db
	owner.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var notes: Array = {
		"coins": [[1318.5, 0.07], [1760.0, 0.07], [2093.0, 0.16]],
		"fanfare": [[523.3, 0.1], [659.3, 0.1], [784.0, 0.1], [1046.5, 0.32]],
		"tick": [[880.0, 0.05]],
	}.get(sound, [[880.0, 0.1]])
	var data := PackedByteArray()
	for note: Array in notes:
		var frequency: float = note[0]
		var length := int(RATE * float(note[1]))
		for i in length:
			var t := float(i) / RATE
			var envelope := minf(1.0, i / 120.0) * exp(-4.5 * t / float(note[1]))
			# A bright bell: fundamental plus a soft octave.
			var sample := (sin(TAU * frequency * t) * 0.7 + sin(TAU * frequency * 2.0 * t) * 0.25) * envelope * 0.55
			var value := clampi(int(sample * 32767.0), -32768, 32767)
			data.append(value & 0xff)
			data.append((value >> 8) & 0xff)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_cache[sound] = wav
	return wav
