class_name DashboardRegistry
extends RefCounted
## Panels contributed to the dashboard by feature modules (global chat, ranked card, guild card,
## powerup loadout...) without editing the dashboard screen. A panel is a Control script; if it
## defines `setup(dashboard: Screen)` it is called once after the dashboard is built, and
## `refresh()` (if defined) whenever the dashboard opens.
##
## Slots: "banner" (strip under the header), "main" (cards column), "side" (right column; below
## the cards on narrow screens). Lower `order` comes first.
##
##     DashboardRegistry.register(preload("res://ui/widgets/GlobalChatPanel.gd"), "side")

const SLOTS := ["banner", "main", "side"]

static var panels: Array[Dictionary] = []  # {script, slot, order}


static func register(script: Script, slot: String, order := 0) -> void:
	assert(slot in SLOTS, "Unknown dashboard slot %s" % slot)
	panels.append({"script": script, "slot": slot, "order": order})


static func in_slot(slot: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in panels:
		if entry["slot"] == slot:
			found.append(entry)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["order"] < b["order"])
	return found
