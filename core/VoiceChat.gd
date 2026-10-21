class_name VoiceChat
extends Node
## Voice chat between the two players of an online match: a WebRTC call run by the browser
## (JavaScriptBridge), with offers/answers/ICE relayed through POST /api/games/{id}/voice and the
## `VoiceSignal` event on private-game.{id}. Only the web build can do this; native builds
## report `supported() == false`.
##
## Nothing is captured until the player presses "Join voice". Handshake: each side announces
## itself with `mute_state {joined: true, muted}` (the other answers with `ack: true`); white makes
## the offer once both have joined. ICE candidates go in small batches (`ice {candidates: [...]}`,
## a single `{candidate, ...}` is accepted too) to stay well under the signalling rate limit.
## Leaving sends `mute_state {joined: false}` + `hangup`.

signal state_changed(state: String)      ## idle | starting | waiting | connecting | live | error
signal levels_changed(mine: float, theirs: float)
signal peer_changed(joined: bool, muted: bool)

const STUN_SERVERS := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]
const LEVEL_POLL := 0.12

var state := "idle"
var error_text := ""
var match_id := 0
var my_side := ""
var mic_muted := false
var remote_muted := false
var peer_joined := false
var peer_muted := false

var _js_ready := false
var _on_js_signal: JavaScriptObject
var _on_js_state: JavaScriptObject
var _poll := 0.0


static func supported() -> bool:
	return OS.has_feature("web")


func is_active() -> bool:
	return state != "idle" and state != "error"


func _process(delta: float) -> void:
	if state == "idle":
		return
	# The match ended or the player left it: hang up.
	if GameSession.kind != GameSession.Kind.ONLINE or GameSession.match_id() != match_id:
		leave()
		return
	_poll -= delta
	if _poll <= 0.0 and _js_ready and state in ["waiting", "connecting", "live"]:
		_poll = LEVEL_POLL
		var levels: Variant = JavaScriptBridge.eval("window.__gotgVoice ? window.__gotgVoice.levels() : '0,0'", true)
		var parts := str(levels).split(",")
		if parts.size() == 2:
			levels_changed.emit(parts[0].to_float(), parts[1].to_float())


## Asks for the microphone and joins the call for the current online match.
func join() -> void:
	if not supported():
		_set_state("error", "Voice chat is available in the browser version.")
		return
	if GameSession.kind != GameSession.Kind.ONLINE or GameSession.match_id() == 0:
		return
	if is_active():
		return
	match_id = GameSession.match_id()
	my_side = GameSession.my_side()
	_ensure_js()
	_set_state("starting")
	var ice: Variant = ServerConfig.get_value("ice_servers", null)
	var servers: Array = ice if ice is Array and not ice.is_empty() else STUN_SERVERS
	JavaScriptBridge.eval("window.__gotgVoice.start(%s, %s)" % [
		"true" if _is_offerer() else "false", JSON.stringify(JSON.stringify(servers))], true)


func leave() -> void:
	if state == "idle":
		return
	var was_joined := state in ["waiting", "connecting", "live"]
	var id := match_id
	if _js_ready:
		JavaScriptBridge.eval("window.__gotgVoice.stop()", true)
	_set_state("idle")
	peer_joined = false
	match_id = 0
	if was_joined and id > 0 and GameSession.match_id() == id:
		_send_to(id, "mute_state", {"joined": false, "muted": mic_muted})
		_send_to(id, "hangup", {})


func set_mic_muted(muted: bool) -> void:
	mic_muted = muted
	if _js_ready:
		JavaScriptBridge.eval("window.__gotgVoice.setMic(%s)" % ("true" if muted else "false"), true)
	if state in ["waiting", "connecting", "live"]:
		_send("mute_state", {"joined": true, "muted": muted, "ack": true})


func set_remote_muted(muted: bool) -> void:
	remote_muted = muted
	if _js_ready:
		JavaScriptBridge.eval("window.__gotgVoice.setRemote(%s)" % ("true" if muted else "false"), true)


## A VoiceSignal from private-game.{id}: {match_id, from_side, type, data}.
func handle_signal(id: int, payload: Dictionary) -> void:
	var from := str(payload.get("from_side", ""))
	if from == "" or from == GameSession.my_side() or GameSession.match_id() != id:
		return  # Our own echo, or another match.
	var type := str(payload.get("type", ""))
	var data: Dictionary = payload.get("data") if payload.get("data") is Dictionary else {}
	match type:
		"mute_state":
			var joined: bool = data.get("joined", true)
			peer_muted = bool(data.get("muted", false))
			var was_joined := peer_joined
			peer_joined = joined
			peer_changed.emit(peer_joined, peer_muted)
			if not joined:
				_close_call()
				return
			if not (state in ["waiting", "connecting", "live"]):
				return
			if not data.get("ack", false):
				_send("mute_state", {"joined": true, "muted": mic_muted, "ack": true})
			if _is_offerer() and (not was_joined or not data.get("ack", false) or state == "waiting"):
				_offer()
		"hangup":
			peer_joined = false
			peer_changed.emit(false, peer_muted)
			_close_call()
		"offer", "answer", "ice":
			if not (state in ["waiting", "connecting", "live"]):
				return
			if type == "offer":
				peer_joined = true
				_set_state("connecting")
			JavaScriptBridge.eval("window.__gotgVoice.signal(%s, %s)" % [JSON.stringify(type), JSON.stringify(JSON.stringify(data))], true)


func _is_offerer() -> bool:
	return my_side == Ranks.WHITE


func _offer() -> void:
	_set_state("connecting")
	JavaScriptBridge.eval("window.__gotgVoice.offer()", true)


func _close_call() -> void:
	if _js_ready:
		JavaScriptBridge.eval("window.__gotgVoice.closePc()", true)
	if state in ["connecting", "live"]:
		_set_state("waiting")


func _send(type: String, data: Dictionary) -> void:
	_send_to(match_id, type, data)


func _send_to(id: int, type: String, data: Dictionary) -> void:
	if id <= 0:
		return
	ApiManager.request(HTTPClient.METHOD_POST, "/api/games/%d/voice" % id, {"type": type, "data": data})


func _set_state(new_state: String, detail := "") -> void:
	error_text = detail if new_state == "error" else ""
	if new_state == state and detail == "":
		return
	state = new_state
	state_changed.emit(state)


# --- Browser side -----------------------------------------------------------------------------

func _on_signal_from_js(args: Array) -> void:
	if args.size() < 2:
		return
	var parsed: Variant = JSON.parse_string(str(args[1]))
	_send(str(args[0]), parsed if parsed is Dictionary else {})


func _on_state_from_js(args: Array) -> void:
	var what := str(args[0]) if args.size() > 0 else ""
	var detail := str(args[1]) if args.size() > 1 else ""
	match what:
		"mic_ready":
			_set_state("waiting")
			if mic_muted:
				set_mic_muted(true)
			_send("mute_state", {"joined": true, "muted": mic_muted, "ack": false})
			if _is_offerer() and peer_joined:
				_offer()
		"error":
			if detail == "denied":
				_set_state("error", "Microphone blocked. Allow it in the browser to talk.")
			elif detail == "unsupported":
				_set_state("error", "This browser can't do voice chat.")
			else:
				_set_state("error", "Voice chat hit a snag (%s)." % detail)
			JavaScriptBridge.eval("window.__gotgVoice.stop()", true)
		"pc":
			match detail:
				"connected":
					_set_state("live")
				"connecting", "new":
					if state != "live":
						_set_state("connecting")
				"disconnected":
					_set_state("connecting")
				"failed":
					# Usually strict NATs that need a TURN relay. Stay joined so a re-offer can retry.
					_set_state("waiting")
					if _is_offerer() and peer_joined:
						_offer()


func _ensure_js() -> void:
	if _js_ready:
		return
	_on_js_signal = JavaScriptBridge.create_callback(_on_signal_from_js)
	_on_js_state = JavaScriptBridge.create_callback(_on_state_from_js)
	var window := JavaScriptBridge.get_interface("window")
	window.__gotgVoiceOnSignal = _on_js_signal
	window.__gotgVoiceOnState = _on_js_state
	JavaScriptBridge.eval(JS, true)
	_js_ready = true


const JS := """
(function () {
	if (window.__gotgVoice) return;
	var V = {pc: null, local: null, audio: null, ice: [], pending: [], outIce: [], flush: null,
		ctx: null, localAn: null, remoteAn: null, micMuted: false, remoteMuted: false};
	function send(type, data) { try { window.__gotgVoiceOnSignal(type, JSON.stringify(data || {})); } catch (e) {} }
	function state(s, d) { try { window.__gotgVoiceOnState(s, d || ''); } catch (e) {} }
	function analyser(stream) {
		try {
			if (!V.ctx) V.ctx = new (window.AudioContext || window.webkitAudioContext)();
			if (V.ctx.state === 'suspended') V.ctx.resume();
			var an = V.ctx.createAnalyser();
			an.fftSize = 512;
			V.ctx.createMediaStreamSource(stream).connect(an);
			return an;
		} catch (e) { return null; }
	}
	function level(an) {
		if (!an) return 0;
		var buf = new Uint8Array(an.fftSize);
		an.getByteTimeDomainData(buf);
		var sum = 0;
		for (var i = 0; i < buf.length; i++) { var v = (buf[i] - 128) / 128; sum += v * v; }
		return Math.sqrt(sum / buf.length);
	}
	V.start = function (offerer, iceJson) {
		try { V.ice = JSON.parse(iceJson || '[]'); } catch (e) { V.ice = []; }
		if (!window.RTCPeerConnection || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) { state('error', 'unsupported'); return; }
		navigator.mediaDevices.getUserMedia({audio: {echoCancellation: true, noiseSuppression: true, autoGainControl: true}, video: false})
			.then(function (stream) { V.local = stream; V.applyMic(); V.localAn = analyser(stream); state('mic_ready'); })
			.catch(function (err) { state('error', err && (err.name === 'NotAllowedError' || err.name === 'SecurityError') ? 'denied' : String(err && err.name || err)); });
	};
	V.makePc = function () {
		V.closePc();
		var pc = new RTCPeerConnection({iceServers: V.ice});
		V.pc = pc;
		if (V.local) V.local.getTracks().forEach(function (t) { pc.addTrack(t, V.local); });
		pc.onicecandidate = function (e) {
			if (!e.candidate) return;
			V.outIce.push(e.candidate.toJSON());
			if (V.outIce.length >= 8) V.flushIce();
			else if (!V.flush) V.flush = setTimeout(V.flushIce, 250);
		};
		pc.ontrack = function (e) {
			var stream = e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]);
			if (!V.audio) { V.audio = document.createElement('audio'); V.audio.autoplay = true; V.audio.setAttribute('playsinline', ''); document.body.appendChild(V.audio); }
			V.audio.srcObject = stream;
			V.audio.muted = V.remoteMuted;
			var p = V.audio.play(); if (p && p.catch) p.catch(function () {});
			V.remoteAn = analyser(stream);
		};
		pc.onconnectionstatechange = function () { if (V.pc === pc) state('pc', pc.connectionState); };
		return pc;
	};
	V.flushIce = function () {
		if (V.flush) { clearTimeout(V.flush); }
		V.flush = null;
		if (!V.outIce.length) return;
		var list = V.outIce; V.outIce = [];
		send('ice', {candidates: list});
	};
	V.offer = function () {
		var pc = V.makePc();
		pc.createOffer().then(function (o) { return pc.setLocalDescription(o); })
			.then(function () { send('offer', {type: pc.localDescription.type, sdp: pc.localDescription.sdp}); })
			.catch(function (e) { state('error', 'offer ' + e); });
	};
	V.signal = function (type, json) {
		var d = {}; try { d = JSON.parse(json || '{}'); } catch (e) {}
		if (type === 'offer') {
			var pc = V.makePc();
			pc.setRemoteDescription({type: 'offer', sdp: d.sdp}).then(function () { V.drain(); return pc.createAnswer(); })
				.then(function (a) { return pc.setLocalDescription(a); })
				.then(function () { send('answer', {type: pc.localDescription.type, sdp: pc.localDescription.sdp}); })
				.catch(function (e) { state('error', 'answer ' + e); });
		} else if (type === 'answer') {
			if (V.pc && V.pc.signalingState === 'have-local-offer') V.pc.setRemoteDescription({type: 'answer', sdp: d.sdp}).then(V.drain).catch(function () {});
		} else if (type === 'ice') {
			(d.candidates || (d.candidate ? [d] : [])).forEach(function (c) {
				if (V.pc && V.pc.remoteDescription) V.pc.addIceCandidate(c).catch(function () {});
				else V.pending.push(c);
			});
		}
	};
	V.drain = function () {
		var list = V.pending; V.pending = [];
		list.forEach(function (c) { if (V.pc) V.pc.addIceCandidate(c).catch(function () {}); });
	};
	V.applyMic = function () { if (V.local) V.local.getAudioTracks().forEach(function (t) { t.enabled = !V.micMuted; }); };
	V.setMic = function (m) { V.micMuted = !!m; V.applyMic(); };
	V.setRemote = function (m) { V.remoteMuted = !!m; if (V.audio) V.audio.muted = V.remoteMuted; };
	V.closePc = function () {
		if (V.pc) { try { V.pc.close(); } catch (e) {} V.pc = null; }
		V.remoteAn = null;
		if (V.audio) V.audio.srcObject = null;
	};
	V.stop = function () {
		V.closePc();
		if (V.local) { V.local.getTracks().forEach(function (t) { t.stop(); }); V.local = null; }
		V.localAn = null; V.pending = []; V.outIce = [];
		if (V.flush) { clearTimeout(V.flush); V.flush = null; }
		if (V.audio) { V.audio.remove(); V.audio = null; }
	};
	V.levels = function () { return (V.micMuted ? 0 : level(V.localAn)).toFixed(3) + ',' + level(V.remoteAn).toFixed(3); };
	window.__gotgVoice = V;
})();
"""
