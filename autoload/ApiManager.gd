extends Node
## REST client for the Laravel API (Sanctum bearer tokens) plus persistent login.
##
## Every call is a coroutine that resolves to a uniform result:
##     var res := await ApiManager.login("aguinaldo", "secret123")
##     if res.ok: print(res.data) else: print(res.status, res.error)
## The token is stored in user://auth.json (IndexedDB on web, app storage on Android/iOS).
## Override the server with a user arg (`godot -- --api-url=http://127.0.0.1:8000`) or the
## GOTG_API_URL environment variable.

signal auth_changed(logged_in: bool)
signal user_updated(user: Dictionary)

const DEFAULT_BASE_URL := "https://games-of-the-generals-web-production-6zraos.laravel.cloud"
const AUTH_FILE := "user://auth.json"
const REQUEST_TIMEOUT := 15.0

var base_url := DEFAULT_BASE_URL
var token := ""
var user: Dictionary = {}


func _ready() -> void:
	var env_url := OS.get_environment("GOTG_API_URL")
	if env_url != "":
		base_url = env_url
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api-url="):
			base_url = arg.trim_prefix("--api-url=")
	base_url = base_url.rstrip("/")
	_load_session()


func is_logged_in() -> bool:
	return token != ""


# --- Auth -------------------------------------------------------------------------------------

func register(username: String, email: String, password: String, password_confirmation: String) -> Dictionary:
	var res := await request(HTTPClient.METHOD_POST, "/api/register", {
		"username": username,
		"email": email,
		"password": password,
		"password_confirmation": password_confirmation,
		"device_name": _device_name(),
	}, false)
	if res.ok:
		_set_session(res.data.get("token", ""), res.data.get("user", {}))
	return res


## `login` accepts an email address or a username.
func login(login_name: String, password: String) -> Dictionary:
	var res := await request(HTTPClient.METHOD_POST, "/api/login", {
		"login": login_name,
		"password": password,
		"device_name": _device_name(),
	}, false)
	if res.ok:
		_set_session(res.data.get("token", ""), res.data.get("user", {}))
	return res


func logout() -> void:
	if is_logged_in():
		await request(HTTPClient.METHOD_POST, "/api/logout")
	_clear_session()


func fetch_user() -> Dictionary:
	var res := await request(HTTPClient.METHOD_GET, "/api/user")
	if res.ok:
		_update_user(res.data.get("user", {}))
	return res


# --- Realtime ---------------------------------------------------------------------------------

func realtime_config() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/api/realtime-config", null, false)


func broadcasting_auth(socket_id: String, channel_name: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/broadcasting/auth", {
		"socket_id": socket_id,
		"channel_name": channel_name,
	})


# --- Leaderboard & shop -----------------------------------------------------------------------

## period: "global" or "monthly"; month: "YYYY-MM" (monthly only, empty = current month).
func leaderboard(period := "global", page := 1, per_page := 20, month := "") -> Dictionary:
	var query := "?period=%s&page=%d&per_page=%d" % [period, page, per_page]
	if month != "":
		query += "&month=" + month
	return await request(HTTPClient.METHOD_GET, "/api/leaderboard" + query, null, false)


func shop_items() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/api/shop/items", null, false)


func inventory() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/api/shop/inventory")


func purchase(slug: String) -> Dictionary:
	var res := await request(HTTPClient.METHOD_POST, "/api/shop/purchase", {"slug": slug})
	if res.ok:
		_merge_user({"credits": res.data.get("credits"), "equipped": res.data.get("equipped")})
	return res


## Stores the equipped cosmetics on the account so opponents see them (test mode: no ownership check).
func save_loadout(loadout: Dictionary) -> Dictionary:
	var res := await request(HTTPClient.METHOD_PUT, "/api/user/loadout", {"loadout": loadout})
	if res.ok and res.data.get("user") is Dictionary:
		_update_user(res.data["user"])
	return res


func equip(slug: String) -> Dictionary:
	var res := await request(HTTPClient.METHOD_POST, "/api/shop/equip", {"slug": slug})
	if res.ok:
		_merge_user({"equipped": res.data.get("equipped")})
	return res


# --- Matches (the server is the arbiter; these only submit intents) ---------------------------

## Resumes your open match, joins a waiting one, or creates a new one. data.match is a MatchView.
func find_match() -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games")


## Open matches hosted by others ({data: [{id, host, created_at}]}) plus your own unfinished match
## (`your_match`, a MatchView or null).
func lobby() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/api/lobby")


## Hosts a new lobby match. 409 with data.match_id when you're already in one.
func create_match() -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/create")


func join_match(match_id: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/%d/join" % match_id)


func get_match(match_id: int) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/api/games/%d" % match_id)


## placements: [{rank, x, y}] × 21, all inside your home rows.
func submit_setup(match_id: int, placements: Array) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/%d/setup" % match_id, {"placements": placements})


func send_move(match_id: int, from: Vector2i, to: Vector2i) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/%d/move" % match_id, {
		"from": {"x": from.x, "y": from.y},
		"to": {"x": to.x, "y": to.y},
	})


## Throws a cosmetic taunt at the opponent's side; broadcast as `Taunt` (not game state).
func taunt(match_id: int, slug: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/%d/taunt" % match_id, {"taunt": slug})


func resign(match_id: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/api/games/%d/resign" % match_id)


# --- Transport --------------------------------------------------------------------------------

## Sends one JSON request. Resolves to {ok, status, data, error}; `error` is a readable message
## (the first validation error when the server returns 422).
func request(method: int, path: String, body: Variant = null, authenticated := true) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	# In the browser, fetch() already un-gzips responses; decompressing again fails the request.
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)

	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if authenticated and token != "":
		headers.append("Authorization: Bearer " + token)

	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _result(false, 0, {}, "Could not send request (error %d)." % err)

	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var status: int = response[1]
	var raw: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return _result(false, 0, {}, "Can't reach the server. Check your connection.")

	var data: Dictionary = {}
	var text := raw.get_string_from_utf8()
	if text != "":
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			data = parsed

	var ok := status >= 200 and status < 300
	if status == 401 and authenticated and token != "":
		_clear_session()
	return _result(ok, status, data, "" if ok else _error_message(status, data))


func _result(ok: bool, status: int, data: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "status": status, "data": data, "error": error}


func _error_message(status: int, data: Dictionary) -> String:
	var errors: Variant = data.get("errors")
	if errors is Dictionary and not errors.is_empty():
		var first: Variant = errors.values()[0]
		if first is Array and not first.is_empty():
			return str(first[0])
	if data.has("message"):
		return str(data["message"])
	return "Request failed (HTTP %d)." % status


func _device_name() -> String:
	return "Godot %s" % OS.get_name()


# --- Session persistence ----------------------------------------------------------------------

func _set_session(new_token: String, new_user: Dictionary) -> void:
	token = new_token
	user = new_user
	_save_session()
	auth_changed.emit(is_logged_in())
	user_updated.emit(user)


func _clear_session() -> void:
	var was_logged_in := is_logged_in()
	token = ""
	user = {}
	if FileAccess.file_exists(AUTH_FILE):
		DirAccess.remove_absolute(AUTH_FILE)
	if was_logged_in:
		auth_changed.emit(false)


func _update_user(new_user: Dictionary) -> void:
	user = new_user
	_save_session()
	user_updated.emit(user)


func _merge_user(fields: Dictionary) -> void:
	for key in fields:
		if fields[key] != null:
			user[key] = fields[key]
	_save_session()
	user_updated.emit(user)


func _save_session() -> void:
	var file := FileAccess.open(AUTH_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s (error %d)" % [AUTH_FILE, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"token": token, "user": user, "base_url": base_url}))


func _load_session() -> void:
	if not FileAccess.file_exists(AUTH_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTH_FILE))
	if not parsed is Dictionary:
		return
	# A token is only valid for the server that issued it.
	if parsed.get("base_url", base_url) != base_url:
		return
	token = parsed.get("token", "")
	user = parsed.get("user", {})
