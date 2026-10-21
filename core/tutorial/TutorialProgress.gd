class_name TutorialProgress
extends RefCounted
## Boot Camp progress on this device (user://bootcamp.cfg): which drills are done, whether the
## player graduated, and whether they dismissed the "try Boot Camp" nudge. There is no account
## endpoint for it, so it stays local; the graduation game's win is reported like any practice win.

const FILE := "user://bootcamp.cfg"

static var _cfg: ConfigFile


static func is_done(lesson_id: String) -> bool:
	return bool(_store().get_value("done", lesson_id, false))


static func mark_done(lesson_id: String) -> void:
	_store().set_value("done", lesson_id, true)
	_save()


## How many of the drills (not the graduation game) are done.
static func done_count() -> int:
	var count := 0
	for lesson: Dictionary in TutorialLessons.LESSONS:
		if is_done(lesson["id"]):
			count += 1
	return count


static func is_graduate() -> bool:
	return bool(_store().get_value("bootcamp", "graduate", false))


static func graduate() -> void:
	_store().set_value("bootcamp", "graduate", true)
	_save()


## The first drill not done yet, or the graduation game once every drill is done.
static func next_lesson() -> String:
	for lesson: Dictionary in TutorialLessons.LESSONS:
		if not is_done(lesson["id"]):
			return lesson["id"]
	return TutorialLessons.GRADUATION_ID


## Whether to invite this player to Boot Camp (title and dashboard): not after they graduated or
## said no thanks.
static func should_nudge() -> bool:
	return not is_graduate() and not bool(_store().get_value("bootcamp", "nudge_dismissed", false))


static func dismiss_nudge() -> void:
	_store().set_value("bootcamp", "nudge_dismissed", true)
	_save()


## Tests start from a clean slate.
static func reset() -> void:
	_cfg = ConfigFile.new()
	_save()


static func _store() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(FILE)
	return _cfg


static func _save() -> void:
	_store().save(FILE)
