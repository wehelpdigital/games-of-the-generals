class_name PerfProbe
extends Node
## Opt-in performance logger: once a second prints FPS, frame and process time, draw calls,
## objects, primitives, node count and memory, tagged with the current screen. On the web it also
## publishes the numbers as `window.__perf` (and the screen as `window.__screen` the moment it
## changes) so browser tests can read them.
## Enabled by `?perf=1` in the page URL (web) or `--perf` after `--` on the command line.

var ui: UIRoot

var _elapsed := 0.0
var _frames := 0
var _worst := 0.0
var _screen := ""
var _web := false


static var _enabled := -1  # -1 unknown, 0 off, 1 on


## Prints a startup milestone with the engine clock (only when the probe is requested).
static func mark(label: String) -> void:
	if _enabled < 0:
		_enabled = 1 if requested() else 0
	if _enabled == 1:
		print("MARK %s t=%d" % [label, Time.get_ticks_msec()])


static var _query := "?"


## Temporary experiment switches from the page URL (e.g. ?perf=1&noshadow=1).  # PERF-TEMP
static func flag(name: String) -> bool:
	if _query == "?":
		_query = ""
		if OS.has_feature("web"):
			var q: Variant = JavaScriptBridge.eval("window.location.search", true)
			_query = q if q is String else ""
		for arg in OS.get_cmdline_user_args():
			_query += "&" + arg.trim_prefix("--")
	return _query.contains(name + "=1") or _query.contains("&" + name)


static func requested() -> bool:
	if "--perf" in OS.get_cmdline_user_args():
		return true
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		return query is String and (query as String).contains("perf=1")
	return false


func _ready() -> void:
	_web = OS.has_feature("web")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if Engine.get_process_frames() < 12:
		mark("frame %d dt=%dms" % [Engine.get_process_frames(), int(delta * 1000.0)])
	if delta > 0.25 and Engine.get_process_frames() > 2:
		mark("slow frame %dms (screen %s)" % [int(delta * 1000.0), _screen])
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	var screen := ui.current_name if ui else ""
	if screen != _screen:
		_screen = screen
		if _web:
			JavaScriptBridge.eval("window.__screen = %s; window.__screenAt = performance.now();" % JSON.stringify(screen), true)
	if _elapsed < 1.0:
		return
	var stats := {
		"screen": _screen,
		"fps": snappedf(_frames / _elapsed, 0.1),
		"frame_ms": snappedf(1000.0 * _elapsed / _frames, 0.1),
		"worst_ms": snappedf(1000.0 * _worst, 0.1),
		"process_ms": snappedf(1000.0 * Performance.get_monitor(Performance.TIME_PROCESS), 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"window": "%dx%d" % [get_window().size.x, get_window().size.y],
	}
	print("PERF ", JSON.stringify(stats))
	if _web:
		JavaScriptBridge.eval("window.__perf = %s;" % JSON.stringify(stats), true)
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0
