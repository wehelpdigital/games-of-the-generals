class_name PowerupLoadout
extends Node
## The 5 powerups the player brings into Select-mode matches. Every powerup is open to every
## player, so this is only the player's choice: synced with GET/PUT /api/powerups/loadout when
## logged in, and kept in user://powerups.cfg so offline practice works too.
## Lives on GameSession as `GameSession.powerups`.

signal changed

const SAVE_FILE := "user://powerups.cfg"

var slots: Array[String] = PowerupLibrary.DEFAULT_LOADOUT.duplicate()
var _fetching := false
var _fetch_again := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_FILE) == OK:
		var saved := PowerupLibrary.sanitize(cfg.get_value("powerups", "slots", []))
		if not saved.is_empty():
			slots = saved
	ApiManager.auth_changed.connect(_on_auth_changed)
	fetch()


## Every powerup is open to every player (kept for callers from the rank-unlock days).
func is_unlocked(id: String) -> bool:
	return PowerupLibrary.has(id)


## How many a Select hand holds.
func hand_size() -> int:
	return PowerupLibrary.MAX_SLOTS


## Every powerup the player may bring: the whole library.
func unlocked_ids() -> Array[String]:
	return PowerupLibrary.ids()


## What a match brings: the chosen slots, topped up from the defaults and then the library.
func active_slots() -> Array[String]:
	var list: Array[String] = []
	for id: String in slots + PowerupLibrary.DEFAULT_LOADOUT + PowerupLibrary.ids():
		if list.size() >= PowerupLibrary.MAX_SLOTS:
			break
		if PowerupLibrary.has(id) and not list.has(id):
			list.append(id)
	return list


## Coroutine: when logged in, loads the saved loadout from the account.
func fetch() -> void:
	if _fetching:
		_fetch_again = true  # The login changed mid-flight: fetch again afterwards.
		return
	_fetching = true
	var loadout := {}
	if ApiManager.is_logged_in():
		loadout = await ApiManager.request(HTTPClient.METHOD_GET, "/api/powerups/loadout")
	if loadout.get("ok", false) and loadout["data"].get("slots") is Array:
		var remote := PowerupLibrary.sanitize(loadout["data"]["slots"])
		if not remote.is_empty():
			slots = remote
			_save_local()
	_fetching = false
	changed.emit()
	if _fetch_again:
		_fetch_again = false
		fetch()


## Coroutine: picks a new loadout. Returns "" when saved, otherwise what's wrong.
func save(new_slots: Array) -> String:
	var clean := PowerupLibrary.sanitize(new_slots)
	if clean.size() != hand_size():
		return "Pick exactly %d powerups." % hand_size()
	slots = clean
	_save_local()
	changed.emit()
	if ApiManager.is_logged_in():
		var res := await ApiManager.request(HTTPClient.METHOD_PUT, "/api/powerups/loadout", {"slots": clean})
		if not res.ok and res.status != 404 and res.status != 0:
			return res.error
	return ""


func _save_local() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("powerups", "slots", Array(slots))
	cfg.save(SAVE_FILE)


func _on_auth_changed(_logged_in: bool) -> void:
	changed.emit()
	fetch()
