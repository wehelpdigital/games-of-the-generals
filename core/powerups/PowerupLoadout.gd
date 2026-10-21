class_name PowerupLoadout
extends Node
## The 3 powerups the player brings into matches and which ones their rank has unlocked. Synced
## with GET /api/powerups and GET/PUT /api/powerups/loadout when logged in, and kept in
## user://powerups.cfg so offline practice works too. Logged out, only rank-0 powerups unlock
## (unless the server's "unlock all" setting is on: GET /api/powerups is public).
## Lives on GameSession as `GameSession.powerups`.

signal changed

const SAVE_FILE := "user://powerups.cfg"

var slots: Array[String] = PowerupLibrary.DEFAULT_LOADOUT.duplicate()
var _server_unlocked: Array = []  # ids the server says are unlocked
var _server_loaded := false
var _fetching := false
var _fetch_again := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_FILE) == OK:
		var saved := PowerupLibrary.sanitize(cfg.get_value("powerups", "slots", []))
		if not saved.is_empty():
			slots = saved
	ApiManager.auth_changed.connect(_on_auth_changed)
	ApiManager.user_updated.connect(func(_user: Dictionary) -> void: changed.emit())
	fetch()


## The player's account rank (0 when logged out).
func tier() -> int:
	if not ApiManager.is_logged_in():
		return 0
	var profile := get_node_or_null("/root/Profile")
	var data: Variant = profile.get("data") if profile else null
	if data is Dictionary and data.get("rank_tier") != null:
		return PlayerRanks.clamp_tier(data["rank_tier"])
	return PlayerRanks.clamp_tier(ApiManager.user.get("rank_tier", 0))


func is_unlocked(id: String) -> bool:
	if _server_loaded:
		return _server_unlocked.has(id)
	return PowerupLibrary.unlock_tier(id) <= tier()


## Every powerup this player may bring (the server's unlocks once known, else by rank).
func unlocked_ids() -> Array[String]:
	var list: Array[String] = []
	for id in PowerupLibrary.ids():
		if is_unlocked(id):
			list.append(id)
	return list


## What a match brings: the chosen slots that are unlocked, topped up from the defaults.
func active_slots() -> Array[String]:
	var list: Array[String] = []
	for id in slots:
		if is_unlocked(id):
			list.append(id)
	for id in PowerupLibrary.DEFAULT_LOADOUT + PowerupLibrary.unlocked_at(tier()):
		if list.size() >= PowerupLibrary.MAX_SLOTS:
			break
		if is_unlocked(id) and not list.has(id):
			list.append(id)
	return list


## Coroutine: loads unlocks (guests count as rank 0) and, when logged in, the saved loadout.
func fetch() -> void:
	if _fetching:
		_fetch_again = true  # The login changed mid-flight: fetch again afterwards.
		return
	_fetching = true
	var library := await ApiManager.request(HTTPClient.METHOD_GET, "/api/powerups", null, ApiManager.is_logged_in())
	if library.ok and library.data.get("data") is Array:
		_server_unlocked.clear()
		for entry: Variant in library.data["data"]:
			if entry is Dictionary and entry.get("unlocked", false):
				_server_unlocked.append(str(entry.get("id", "")))
		_server_loaded = true
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
	if clean.size() != PowerupLibrary.MAX_SLOTS:
		return "Pick exactly %d powerups." % PowerupLibrary.MAX_SLOTS
	for id in clean:
		if not is_unlocked(id):
			return "%s unlocks at %s." % [PowerupLibrary.display_name(id), PlayerRanks.name_of(PowerupLibrary.unlock_tier(id))]
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
	_server_loaded = false
	_server_unlocked.clear()
	changed.emit()
	fetch()
