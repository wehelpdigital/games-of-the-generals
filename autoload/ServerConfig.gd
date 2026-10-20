extends Node
## Server-wide settings the admin controls (GET /api/config): dashboard theme, shop test mode,
## turn length, maintenance notice and the running season. Fetched at start-up and whenever the
## login changes; DEFAULTS apply until then (and offline).

signal changed

const DEFAULTS := {
	"dashboard_theme": "classic",
	"shop_test_mode": true,
	"turn_seconds": 45,
	"maintenance_message": "",
	"season": null,
}

var values: Dictionary = DEFAULTS.duplicate()
var loaded := false


func _ready() -> void:
	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void: refresh())
	refresh()


func get_value(key: String, default: Variant = null) -> Variant:
	return values.get(key, DEFAULTS.get(key, default))


func refresh() -> void:
	var res: Dictionary = await ApiManager.request(HTTPClient.METHOD_GET, "/api/config", null, false)
	if not res.ok:
		return
	values = DEFAULTS.duplicate()
	values.merge(res.data, true)
	loaded = true
	changed.emit()
