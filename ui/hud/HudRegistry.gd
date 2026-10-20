class_name HudRegistry
extends RefCounted
## In-match HUD widgets contributed by feature modules (turn timer, powerups, chat, voice...)
## without editing GameHUD. A widget is a Control script; if it defines `setup(hud: Screen)` it is
## called once after the HUD is built (hud.ui gives access to UIRoot and the 3D game).
##
## Slots: "top_left" (top bar, after Clips), "top_center" (under the turn banner), "left" (column
## under the top-left bar), "right" (top of the action column), "bottom_left", "bottom_center".
##
##     HudRegistry.register(preload("res://ui/hud/TurnTimer.gd"), "top_center")

const SLOTS := ["top_left", "top_center", "left", "right", "bottom_left", "bottom_center"]

static var widgets: Array[Dictionary] = []  # {script, slot}


static func register(script: Script, slot: String) -> void:
	assert(slot in SLOTS, "Unknown HUD slot %s" % slot)
	widgets.append({"script": script, "slot": slot})
