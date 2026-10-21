class_name UiScale
extends RefCounted
## Makes menus, text and buttons a comfortable size on every screen. The project stretches a
## 1280x720 canvas to fit the window, so on a 390 px wide phone everything would be drawn at about
## a third of its size. UiScale sets the root window's content_scale_factor (2D only; the 3D board
## keeps rendering at full resolution) so one UI pixel is roughly one CSS pixel on phones and a
## little more on tablets, and leaves desktops as they were. The player's "Text size" setting
## (small / normal / large) multiplies the result.
##
## Device kinds: "phone" (short side < 600 CSS px and a touch screen), "tablet" (touch, larger) and
## "desktop". Tests can pretend to be a device with the user arg --device=phone_portrait,
## phone_landscape, tablet_portrait, tablet_landscape or desktop.

signal changed

const SETTING := "text_size"
const TEXT_SIZES := {"small": 0.88, "normal": 1.0, "large": 1.15}
const SETTINGS_FILE := "user://settings.cfg"
const BASE := Vector2(1280, 720)  # display/window/size of the project.
## CSS pixels per UI pixel we aim for: just under 1 on phones keeps the 1280-wide designs from
## needing too much width; tablets get roomier, slightly larger text.
const PHONE_CSS_PER_UI := 0.92
const TABLET_CSS_PER_UI := 1.1
const DESKTOP_MIN_CSS_PER_UI := 0.75
const TEST_DEVICES := {
	"phone_portrait": Vector2(390, 844),
	"phone_landscape": Vector2(844, 390),
	"tablet_portrait": Vector2(820, 1180),
	"tablet_landscape": Vector2(1180, 820),
	"desktop": Vector2(1280, 720),
}

static var kind := "desktop"
static var factor := 1.0
static var _test_device := ""
static var _text_size := ""
static var _signals: UiScale


static func signals() -> UiScale:
	if _signals == null:
		_signals = UiScale.new()
	return _signals


## Recomputes the scale for the current window and applies it. Safe to call on every resize.
static func apply(tree: SceneTree) -> void:
	var window := tree.root
	var css := css_viewport(window)
	kind = _kind_for(css)
	var fit := minf(css.x / BASE.x, css.y / BASE.y)  # CSS px per UI px before scaling.
	var target := fit
	match kind:
		"phone":
			target = PHONE_CSS_PER_UI
		"tablet":
			target = TABLET_CSS_PER_UI
		_:
			target = maxf(fit, DESKTOP_MIN_CSS_PER_UI)
	var new_factor := maxf(1.0, target / maxf(fit, 0.01)) * text_size_multiplier()
	if is_equal_approx(new_factor, window.content_scale_factor):
		return
	factor = new_factor
	window.content_scale_factor = new_factor
	signals().changed.emit()


## The window size in CSS pixels (on native builds, in device-independent pixels).
static func css_viewport(window: Window) -> Vector2:
	if _test_device == "":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--device="):
				_test_device = arg.trim_prefix("--device=")
		if _test_device == "":
			_test_device = "-"
	if TEST_DEVICES.has(_test_device):
		return TEST_DEVICES[_test_device]
	if OS.has_feature("web"):
		var w: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		var h: Variant = JavaScriptBridge.eval("window.innerHeight", true)
		if (w is int or w is float) and (h is int or h is float) and float(w) > 0.0:
			return Vector2(float(w), float(h))
	var scale := DisplayServer.screen_get_scale() if OS.has_feature("mobile") else 1.0
	return Vector2(window.size) / maxf(scale, 1.0)


static func text_size() -> String:
	if _text_size == "":
		var cfg := ConfigFile.new()
		var saved := "normal"
		if cfg.load(SETTINGS_FILE) == OK:
			saved = str(cfg.get_value("ui", SETTING, "normal"))
		_text_size = saved if TEXT_SIZES.has(saved) else "normal"
	return _text_size


static func set_text_size(tree: SceneTree, size: String) -> void:
	_text_size = size if TEXT_SIZES.has(size) else "normal"
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ui", SETTING, _text_size)
	cfg.save(SETTINGS_FILE)
	apply(tree)


static func text_size_multiplier() -> float:
	return TEXT_SIZES[text_size()]


## True when `node`'s screen is phone-narrow (in UI pixels): rows should stack, wrap or drop
## secondary columns.
static func narrow(node: Node) -> bool:
	return node.is_inside_tree() and node.get_viewport().get_visible_rect().size.x < 520.0


static func is_phone() -> bool:
	return kind == "phone"


static func is_handheld() -> bool:
	return kind != "desktop"


static func _kind_for(css: Vector2) -> String:
	var touch := Graphics.is_handheld() or _test_device.begins_with("phone") or _test_device.begins_with("tablet")
	if _test_device == "desktop":
		touch = false
	if not touch:
		return "desktop"
	return "phone" if minf(css.x, css.y) < 600.0 else "tablet"
