class_name Graphics
extends RefCounted
## Graphics quality: "auto", "low" or "high", kept in UIRoot's settings file (key "graphics").
##
## Browsers compile every new shader while the page waits (WebGL on Windows translates each one to
## Direct3D, about 0.1–0.6 s apiece), and phones have weak GPUs and very high pixel densities. So
## "auto" means High in the desktop app, Medium in a desktop browser and Low on phones and tablets:
##   high:   everything on.
##   medium: high, but the title-screen showcase doesn't swap cosmetics on the 3D board (every swap
##           compiles new shaders and freezes the page for a moment).
##   low:    medium, plus no MSAA, no dynamic shadows, no glow, lighter ambience and a lower 3D
##           resolution on high-density screens.

signal changed

const SETTING := "graphics"
const LEVELS := ["auto", "low", "high"]
const SETTINGS_FILE := "user://settings.cfg"

static var choice := "auto"
static var _auto := ""  # What "auto" resolves to on this device (worked out once).
static var _loaded := false
static var _signals: Graphics


static func signals() -> Graphics:
	if _signals == null:
		_signals = Graphics.new()
	return _signals


## The player's choice ("auto", "low", "high"), read once from the settings file.
static func get_choice() -> String:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_FILE) == OK:
			var saved := str(cfg.get_value("ui", SETTING, "auto"))
			choice = saved if saved in LEVELS else "auto"
	return choice


static func set_choice(level: String) -> void:
	choice = level if level in LEVELS else "auto"
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ui", SETTING, choice)
	cfg.save(SETTINGS_FILE)
	signals().changed.emit()


## "high", "medium" or "low": the choice with "auto" resolved for this device.
static func effective() -> String:
	var level := get_choice()
	if level != "auto":
		return level
	if _auto == "":
		if is_handheld():
			_auto = "low"
		elif OS.has_feature("web"):
			_auto = "medium"
		else:
			_auto = "high"
	return _auto


static func is_low() -> bool:
	return effective() == "low"


## Whether the title-screen showcase may re-dress the 3D armies (see the class notes).
static func live_showcase() -> bool:
	return effective() == "high"


## Phones and tablets: native mobile, or a browser on Android/iOS or with a coarse pointer.
static func is_handheld() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var coarse: Variant = JavaScriptBridge.eval("(window.matchMedia && matchMedia('(pointer: coarse)').matches && !matchMedia('(pointer: fine)').matches) ? 1 : 0", true)
		return (coarse is int or coarse is float) and int(coarse) == 1
	return false


## Device pixels per CSS pixel (1 on most desktops, 2–3 on phones and retina laptops).
static func pixel_ratio() -> float:
	if OS.has_feature("web"):
		var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		return float(ratio) if ratio is float or ratio is int else 1.0
	return DisplayServer.screen_get_scale()


## Applies the quality to the 3D scene: MSAA and render scale on the viewport, shadows on the key
## light, glow on the environment, and lighter ambience particles.
static func apply(viewport: Viewport, key_light: DirectionalLight3D, env: Environment) -> void:
	var level := effective()
	var low := level == "low"
	viewport.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var ratio := pixel_ratio()
	viewport.scaling_3d_scale = clampf(1.5 / ratio, 0.5, 1.0) if low and ratio > 1.5 else 1.0
	key_light.shadow_enabled = not low
	env.glow_enabled = not low
	var cfg := ConfigFile.new()
	var reduce_ambience := cfg.load(SETTINGS_FILE) == OK and bool(cfg.get_value("ui", "reduce_ambience", false))
	AmbienceFX.reduced = low or reduce_ambience
