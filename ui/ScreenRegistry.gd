class_name ScreenRegistry
extends RefCounted
## Screens contributed by feature modules (autoloads) without editing UIRoot. Register in an
## autoload's _init() or _ready(): autoloads are ready before the main scene builds the UI.
##
##     ScreenRegistry.register("dashboard", preload("res://ui/screens/DashboardScreen.gd"))

static var screens: Dictionary = {}  # name -> Script (extends Screen)


static func register(screen_name: String, script: Script) -> void:
	screens[screen_name] = script
