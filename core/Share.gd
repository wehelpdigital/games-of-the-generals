class_name Share
extends RefCounted
## Sharing the game to social apps: Facebook, X, Messenger, WhatsApp, copy link, and the
## browser's own share sheet (Web Share API) when the device has one. Opening a share page counts
## toward rank tasks (Profile.record_share); the server trusts the player on that.

const URL := "https://games-of-the-generals-web-production-6zraos.laravel.cloud/"

const PLATFORMS := [
	{"key": "facebook", "label": "Facebook", "color": Color("1877f2")},
	{"key": "messenger", "label": "Messenger", "color": Color("a033ff")},
	{"key": "x", "label": "X", "color": Color("15141a")},
	{"key": "whatsapp", "label": "WhatsApp", "color": Color("25d366")},
	{"key": "copy_link", "label": "Copy link", "color": Color("ffcf3f")},
]

static var _js_done: JavaScriptObject  # Kept alive while the browser share sheet is open.


## The brag line for the player's current rank.
static func message(profile: Dictionary) -> String:
	var tier := PlayerRanks.clamp_tier(profile.get("rank_tier", 0))
	if tier == 0:
		return "I'm playing Salpakan Tactics! - 3D Salpakan online, free in your browser. Think you can beat me?"
	return "I just ranked up to %s in Salpakan Tactics! Think you can beat me?" % PlayerRanks.name_of(tier)


static func url_for(platform: String, text: String, link := URL) -> String:
	match platform:
		"facebook":
			return "https://www.facebook.com/sharer/sharer.php?u=%s&quote=%s" % [link.uri_encode(), text.uri_encode()]
		"messenger":
			if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
				return "fb-messenger://share/?link=%s" % link.uri_encode()
			return "https://www.facebook.com/sharer/sharer.php?u=%s" % link.uri_encode()
		"x":
			return "https://twitter.com/intent/tweet?text=%s&url=%s" % [text.uri_encode(), link.uri_encode()]
		"whatsapp":
			return "https://wa.me/?text=%s" % (text + " " + link).uri_encode()
	return link


## Opens the share page (or copies the link). Returns false if nothing could be opened.
static func send(platform: String, text: String, link := URL) -> bool:
	if platform == "copy_link":
		DisplayServer.clipboard_set(text + " " + link)
		return true
	return OS.shell_open(url_for(platform, text, link)) == OK


static func can_web_share() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("!!(navigator.share)", true))


## The device's own share sheet (phones, some desktop browsers). `on_done(shared: bool)`.
static func web_share(text: String, on_done: Callable, link := URL) -> void:
	if not can_web_share():
		on_done.call(false)
		return
	_js_done = JavaScriptBridge.create_callback(func(args: Array) -> void:
		on_done.call(args.size() > 0 and bool(args[0])))
	var window := JavaScriptBridge.get_interface("window")
	window.__gotgShareDone = _js_done
	JavaScriptBridge.eval("""
		navigator.share({title: 'Salpakan Tactics!', text: %s, url: %s})
			.then(function () { window.__gotgShareDone(true); })
			.catch(function () { window.__gotgShareDone(false); });
	""" % [JSON.stringify(text), JSON.stringify(link)], true)
