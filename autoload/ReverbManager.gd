extends Node
## Laravel Reverb client. Reverb speaks the Pusher Channels protocol (v7) over a WebSocket, so this
## implements the parts the game needs: connection handshake, private-channel auth through
## /api/broadcasting/auth (Sanctum), ping/pong keep-alive, and reconnect with backoff that
## re-subscribes to every channel.
##
##     ReverbManager.connect_to_server({"key": "...", "host": "...", "port": 443, "scheme": "https"})
##     ReverbManager.subscribe("private-game.12")
##     ReverbManager.event_received.connect(func(channel, event, data): ...)

signal connected(socket_id: String)
signal disconnected
signal subscribed(channel: String)
signal subscription_failed(channel: String, message: String)
signal event_received(channel: String, event: String, data: Dictionary)

enum State { DISCONNECTED, CONNECTING, CONNECTED }

const PROTOCOL_VERSION := 7
const CONNECT_TIMEOUT := 10.0  ## A socket can sit in CONNECTING forever (e.g. an unanswered IPv6 route).
const PONG_TIMEOUT := 30.0
const RECONNECT_DELAYS: Array[float] = [1.0, 2.0, 4.0, 8.0, 15.0, 30.0]

var state := State.DISCONNECTED
var socket_id := ""

var _ws := WebSocketPeer.new()
var _config: Dictionary = {}
var _wanted: Dictionary = {}       # channel -> true: everything we should be subscribed to
var _subscribed: Dictionary = {}   # channel -> true: confirmed by the server
var _activity_timeout := 30.0
var _connecting_for := 0.0
var _idle := 0.0
var _awaiting_pong := false
var _pong_wait := 0.0
var _reconnect_attempt := 0
var _reconnect_in := -1.0
var _should_reconnect := false


func _ready() -> void:
	set_process(false)


func is_connected_to_server() -> bool:
	return state == State.CONNECTED


func is_subscribed(channel: String) -> bool:
	return _subscribed.has(channel)


## config comes from GET /api/realtime-config: {key, host, port, scheme}.
func connect_to_server(config: Dictionary) -> void:
	if config.get("key") == null or str(config.get("key", "")) == "":
		push_warning("Reverb: no app key configured; realtime disabled.")
		return
	if state != State.DISCONNECTED and config == _config:
		return
	_config = config
	_should_reconnect = true
	_reconnect_attempt = 0
	_open()


func disconnect_from_server() -> void:
	_should_reconnect = false
	_reconnect_in = -1.0
	_wanted.clear()
	if state != State.DISCONNECTED:
		_ws.close(1000, "Client closed")
	_mark_closed()
	set_process(false)


func subscribe(channel: String) -> void:
	_wanted[channel] = true
	if state == State.CONNECTED and not _subscribed.has(channel):
		_subscribe_now(channel)


func unsubscribe(channel: String) -> void:
	_wanted.erase(channel)
	if _subscribed.has(channel):
		_subscribed.erase(channel)
		_send("pusher:unsubscribe", {"channel": channel})


func _open() -> void:
	var secure := str(_config.get("scheme", "https")) == "https"
	var port := int(_config.get("port", 443 if secure else 80))
	var url := "%s://%s:%d/app/%s?protocol=%d&client=godot&version=1.0&flash=false" % [
		"wss" if secure else "ws", _config.get("host", ""), port, _config.get("key", ""), PROTOCOL_VERSION,
	]
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("Reverb: could not open %s (error %d)" % [url, err])
		_schedule_reconnect()
		return
	state = State.CONNECTING
	_connecting_for = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _reconnect_in >= 0.0:
		_reconnect_in -= delta
		if _reconnect_in < 0.0:
			_open()
		return

	if state == State.CONNECTING:
		_connecting_for += delta
		if _connecting_for > CONNECT_TIMEOUT:
			push_warning("Reverb: no handshake from %s within %d s, retrying." % [_config.get("host", ""), CONNECT_TIMEOUT])
			_ws.close()
			_mark_closed()
			_schedule_reconnect()
			return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				_handle_message(_ws.get_packet().get_string_from_utf8())
			_keep_alive(delta)
		WebSocketPeer.STATE_CLOSED:
			if state != State.DISCONNECTED:
				push_warning("Reverb: connection closed (%d %s)" % [_ws.get_close_code(), _ws.get_close_reason()])
				_mark_closed()
				_schedule_reconnect()


func _keep_alive(delta: float) -> void:
	if state != State.CONNECTED:
		return
	_idle += delta
	if _awaiting_pong:
		_pong_wait += delta
		if _pong_wait > PONG_TIMEOUT:
			push_warning("Reverb: ping timed out, reconnecting.")
			_ws.close(4201, "Pong timeout")
	elif _idle > _activity_timeout:
		_send("pusher:ping", {})
		_awaiting_pong = true
		_pong_wait = 0.0


func _handle_message(text: String) -> void:
	_idle = 0.0
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	var event: String = message.get("event", "")
	var channel: String = message.get("channel", "")
	var data := _decode_data(message.get("data"))

	match event:
		"pusher:connection_established":
			socket_id = str(data.get("socket_id", ""))
			_activity_timeout = maxf(5.0, float(data.get("activity_timeout", 30)) - 5.0)
			state = State.CONNECTED
			_reconnect_attempt = 0
			connected.emit(socket_id)
			for wanted_channel: String in _wanted.keys():
				_subscribe_now(wanted_channel)
		"pusher:ping":
			_send("pusher:pong", {})
		"pusher:pong":
			_awaiting_pong = false
		"pusher:error":
			_handle_error(data)
		"pusher_internal:subscription_succeeded":
			_subscribed[channel] = true
			subscribed.emit(channel)
		"pusher:subscription_error":
			subscription_failed.emit(channel, str(data.get("error", data)))
		_:
			if not event.begins_with("pusher"):
				event_received.emit(channel, event, data)


## Pusher error codes: 4000–4099 fatal, 4100–4199 retry later, 4200–4299 retry now.
func _handle_error(data: Dictionary) -> void:
	var code := int(data.get("code", 0))
	push_warning("Reverb error %d: %s" % [code, data.get("message", "")])
	if code >= 4000 and code < 4100:
		_should_reconnect = false


func _subscribe_now(channel: String) -> void:
	var auth := ""
	if channel.begins_with("private-") or channel.begins_with("presence-"):
		var for_socket := socket_id
		var res: Dictionary = await ApiManager.broadcasting_auth(for_socket, channel)
		if socket_id != for_socket or state != State.CONNECTED:
			return  # Reconnected while authorizing; the new connection re-subscribes.
		if not res.ok:
			subscription_failed.emit(channel, res.error)
			return
		auth = str(res.data.get("auth", ""))
	_send("pusher:subscribe", {"channel": channel, "auth": auth})


func _send(event: String, data: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"event": event, "data": data}))


func _mark_closed() -> void:
	var was_connected := state == State.CONNECTED
	state = State.DISCONNECTED
	socket_id = ""
	_subscribed.clear()
	_awaiting_pong = false
	_idle = 0.0
	if was_connected:
		disconnected.emit()


func _schedule_reconnect() -> void:
	if not _should_reconnect:
		set_process(false)
		return
	_reconnect_in = RECONNECT_DELAYS[mini(_reconnect_attempt, RECONNECT_DELAYS.size() - 1)]
	_reconnect_attempt += 1
	set_process(true)


## Pusher sends `data` as a JSON-encoded string; protocol messages sometimes send an object.
func _decode_data(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw
	if raw is String and raw != "":
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			return parsed
	return {}
