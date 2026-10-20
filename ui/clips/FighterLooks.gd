class_name FighterLooks
extends RefCounted
## How each rank looks and fights in the cartoon battle clips. Every character is an original
## design: uniforms and insignia follow public military conventions, nothing is taken from any
## existing game. UNKNOWN is the shadow soldier used while an enemy's rank is still hidden.
##
## Keys: skin, uniform, trousers, hat (peaked|beret|side_cap|helmet|fedora|bandana|none),
## hat_color, insignia (star|sun|triangle|chevron|""), marks, mustache (""|handlebar|bushy|thin),
## belly (0–1), cape, shades, coat, move (megaphone|saber|baton|punch|rifle|chop|flag), shout.

const SKIN := [Color("f6c9a0"), Color("e0a477"), Color("c58556"), Color("8d5a3b")]
const NAVY := Color("2f3f96")
const OLIVE := Color("6b7d3a")
const SLATE := Color("4d6f93")
const GREEN := Color("4f8a3c")
const SHADOW := Color("2a2440")

const LOOKS := {
	"G5": {"skin": 0, "uniform": NAVY, "hat": "peaked", "hat_color": NAVY, "insignia": "star", "marks": 5,
		"mustache": "bushy", "belly": 1.0, "cape": true, "move": "megaphone", "shout": "CHARGE!!"},
	"G4": {"skin": 1, "uniform": NAVY, "hat": "peaked", "hat_color": NAVY, "insignia": "star", "marks": 4,
		"mustache": "handlebar", "belly": 0.8, "move": "megaphone", "shout": "ATTACK!"},
	"G3": {"skin": 2, "uniform": NAVY, "hat": "peaked", "hat_color": NAVY, "insignia": "star", "marks": 3,
		"mustache": "handlebar", "belly": 0.5, "move": "megaphone", "shout": "ADVANCE!"},
	"G2": {"skin": 0, "uniform": NAVY, "hat": "peaked", "hat_color": NAVY, "insignia": "star", "marks": 2,
		"mustache": "thin", "belly": 0.4, "move": "megaphone", "shout": "FORWARD!"},
	"G1": {"skin": 3, "uniform": NAVY, "hat": "peaked", "hat_color": NAVY, "insignia": "star", "marks": 1,
		"belly": 0.3, "move": "megaphone", "shout": "GO GO GO!"},
	"COL": {"skin": 1, "uniform": OLIVE, "hat": "beret", "hat_color": Color("8f1d33"), "insignia": "sun", "marks": 3,
		"mustache": "thin", "belly": 0.3, "move": "saber"},
	"LTC": {"skin": 2, "uniform": OLIVE, "hat": "beret", "hat_color": Color("8f1d33"), "insignia": "sun", "marks": 2,
		"belly": 0.2, "move": "saber"},
	"MAJ": {"skin": 0, "uniform": OLIVE, "hat": "beret", "hat_color": Color("8f1d33"), "insignia": "sun", "marks": 1,
		"belly": 0.2, "move": "saber"},
	"CPT": {"skin": 3, "uniform": SLATE, "hat": "side_cap", "hat_color": Color("2c4a6b"), "insignia": "triangle", "marks": 3,
		"belly": 0.1, "move": "baton"},
	"1LT": {"skin": 1, "uniform": SLATE, "hat": "side_cap", "hat_color": Color("2c4a6b"), "insignia": "triangle", "marks": 2,
		"move": "baton"},
	"2LT": {"skin": 0, "uniform": SLATE, "hat": "side_cap", "hat_color": Color("2c4a6b"), "insignia": "triangle", "marks": 1,
		"move": "baton"},
	"SGT": {"skin": 2, "uniform": GREEN, "hat": "helmet", "hat_color": Color("51702f"), "insignia": "chevron", "marks": 3,
		"mustache": "thin", "belly": 0.2, "move": "punch"},
	"PVT": {"skin": 1, "uniform": GREEN, "hat": "helmet", "hat_color": Color("51702f"), "insignia": "chevron", "marks": 1,
		"big_helmet": true, "move": "rifle"},
	"SPY": {"skin": 0, "uniform": Color("c9a066"), "trousers": Color("3b3852"), "hat": "fedora", "hat_color": Color("4a4660"),
		"shades": true, "coat": true, "move": "chop"},
	"FLG": {"skin": 2, "uniform": Color("e8475f"), "trousers": Color("f4ecdc"), "hat": "bandana", "hat_color": Color("ffcf3f"),
		"move": "flag"},
	"UNKNOWN": {"skin": -1, "uniform": SHADOW, "trousers": SHADOW, "hat": "helmet", "hat_color": SHADOW,
		"shadow": true, "move": "punch"},
}


static func for_rank(rank: String) -> Dictionary:
	var look: Dictionary = LOOKS.get(rank, LOOKS["UNKNOWN"]).duplicate()
	var skin_index: int = look.get("skin", 0)
	look["skin_color"] = SHADOW if skin_index < 0 else SKIN[skin_index]
	look["trousers"] = look.get("trousers", Color(look["uniform"]).darkened(0.25))
	look["rank"] = rank
	return look


## What the move is called on screen when it lands.
static func impact_word(move: String) -> String:
	return {"megaphone": "BOOM!", "saber": "SWISH!", "baton": "WHACK!", "punch": "POW!", "rifle": "BONK!",
		"chop": "CHOP!", "flag": "THWACK!"}.get(move, "POW!")
