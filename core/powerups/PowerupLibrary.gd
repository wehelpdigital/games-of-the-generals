class_name PowerupLibrary
extends RefCounted
## Every powerup a player can bring into a match: 41 cards, all open to every player. Before each
## game the players choose powerups off, Select (their own 5 picks) or Random (5 dealt from the
## whole library); each is usable once per match, on their own turn.
## Mirrors config/powerups.php on the server, which referees online matches; LocalArbiter applies
## the same rules offline. Cards show a type (category) and rarity (PowerupCard draws them, with
## art from assets/powerups/art). Small icons are composed at runtime around game-icons.net glyphs
## (CC BY 3.0, see core/powerups/CREDITS.md).

## What the player picks on the board after tapping a powerup (the server's `target` field):
const TARGET_NONE := "none"
const TARGET_OWN_PIECE := "own_piece"
const TARGET_ENEMY_PIECE := "enemy_piece"
const TARGET_TWO_OWN := "two_own_pieces"
const TARGET_EMPTY_OWN_CELL := "empty_own_cell"
const TARGET_OWN_PIECE_AND_HOME_CELL := "own_piece_and_home_cell"
const TARGET_EMPTY_BACK_CELL := "empty_back_cell"
const TARGET_EMPTY_CELL := "empty_cell"
const TARGET_ANY_CELL := "any_cell"

const MAX_SLOTS := 5
const MAX_PER_TURN := 2
const DEFAULT_LOADOUT: Array[String] = ["time_extension", "spy_card", "insight", "intel_leak", "quick_step"]

## Powerup modes, chosen before every game (MatchView `powerup_mode`).
const MODE_OFF := "off"
const MODE_SELECT := "select"
const MODE_RANDOM := "random"
const MODES := [MODE_OFF, MODE_SELECT, MODE_RANDOM]

## Tunables shared with LocalArbiter (config/powerups.php `tuning` on the server).
const TIME_BONUS := 20          ## time_extension: seconds added to each of your next 3 turns.
const TIME_PENALTY := 15        ## time_squeeze: seconds removed from the opponent's next 3 turns.
const MIN_TURN_SECONDS := 10
const BUFF_TURNS := 3
const JAM_SECONDS := 120
const FREEZE_TURNS := 2
const FORTIFY_TURNS := 6
const MINE_TURNS := 10
const SABOTAGE_TURNS := 3
const SCOUT_COUNT := 3
const TRENCH_TURNS := 6
const ROADBLOCK_TURNS := 3
const QUICKSAND_TURNS := 10
const QUICKSAND_STUCK_TURNS := 2
const BLITZ_TURNS := 2
const STEAL_SECONDS := 10
const STEAL_TURNS := 2
const RETREAT_SQUARES := 2
const CEASEFIRE_TURNS := 1

## `pick` is what the targeting UI asks for, in order: "own_piece", "enemy_piece", "home_cell"
## (empty, your 3 home rows), "half_cell" (empty, your half of the board), "back_cell" (empty,
## your back row), "empty_cell" (any empty square), "any_cell" (any square). `kind` is the card
## type: clock, intel, tactics, trap or support. `rarity`: common, rare, epic, legendary.
const POWERUPS := {
	# Clock
	"time_extension": {"name": "Time Extension", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "clock", "rarity": "common",
		"desc": "Your next 3 turns get +20 seconds on the clock."},
	"time_squeeze": {"name": "Time Squeeze", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "clock", "rarity": "common",
		"desc": "Your opponent's next 3 turns are 15 seconds shorter (never under 10 s)."},
	"quick_step": {"name": "Quick Step", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "clock", "rarity": "rare",
		"desc": "No clock on your next turn. Take all the time you need."},
	"blitz": {"name": "Blitz", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "clock", "rarity": "rare",
		"desc": "Lightning round! Both players' next 2 turns get half the time."},
	"time_steal": {"name": "Time Thief", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "clock", "rarity": "epic",
		"desc": "Steal 10 seconds from each of your opponent's next 2 turns and add them to yours."},
	# Intel
	"spy_card": {"name": "Spy Card", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "common",
		"desc": "Reveals the rank of one random enemy piece you haven't identified. Only you see it."},
	"insight": {"name": "Insight", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "common",
		"desc": "Tells you how many enemy officers (Sergeant up to 5-star General) are still alive."},
	"intel_leak": {"name": "Intel Leak", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "common",
		"desc": "Reveals the rank of the enemy piece that moved last."},
	"sonar_ping": {"name": "Sonar Ping", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "common",
		"desc": "Ping! Learn how many enemy pieces have crossed onto your half of the board."},
	"spy_alarm": {"name": "Spy Alarm", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "common",
		"desc": "Learn whether an enemy Spy is standing right next to one of your pieces."},
	"recon_drone": {"name": "Recon Drone", "target": TARGET_ENEMY_PIECE, "consumes_turn": false, "pick": ["enemy_piece"], "kind": "intel", "rarity": "rare",
		"desc": "Fly over one enemy piece: is it their Flag?"},
	"scout_report": {"name": "Scout Report", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "rare",
		"desc": "Learn the rank group (General, Officer, Enlisted, Spy or Flag) of 3 random enemy pieces."},
	"radar_sweep": {"name": "Radar Sweep", "target": TARGET_ANY_CELL, "consumes_turn": false, "pick": ["any_cell"], "kind": "intel", "rarity": "rare",
		"desc": "Sweep the 3x3 area around any square: is an enemy General hiding there?"},
	"code_breaker": {"name": "Code Breaker", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "rare",
		"desc": "Crack their codes: see every powerup card your opponent hasn't played yet."},
	"interrogation": {"name": "Interrogation", "target": TARGET_ENEMY_PIECE, "consumes_turn": false, "pick": ["enemy_piece"], "kind": "intel", "rarity": "epic",
		"desc": "Reveals the rank of an enemy piece standing next to one of yours. Only you see it."},
	"flag_hunter": {"name": "Flag Hunter", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel", "rarity": "legendary",
		"desc": "Learn which column the enemy Flag stands in."},
	# Tactics
	"retreat": {"name": "Tactical Retreat", "target": TARGET_OWN_PIECE, "consumes_turn": true, "pick": ["own_piece"], "kind": "tactics", "rarity": "common",
		"desc": "One of your pieces falls back up to 2 squares toward your back row. Uses your turn."},
	"swap": {"name": "Swap", "target": TARGET_TWO_OWN, "consumes_turn": true, "pick": ["own_piece", "own_piece"], "kind": "tactics", "rarity": "rare",
		"desc": "Two of your pieces trade places. Uses your turn."},
	"rally_cry": {"name": "Rally Cry", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "tactics", "rarity": "rare",
		"desc": "Your next clash that would end in a tie is a win for you instead."},
	"haste": {"name": "Haste", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "tactics", "rarity": "epic",
		"desc": "This turn one of your pieces may dash 2 squares in a straight line (no jumping over pieces)."},
	"smoke_screen": {"name": "Smoke Screen", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "tactics", "rarity": "epic",
		"desc": "Your next move is hidden: your opponent sees your army as it stood, under smoke, until their turn ends."},
	"double_march": {"name": "Double March", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "tactics", "rarity": "epic",
		"desc": "Move two different pieces this turn. The second move can't be an attack."},
	"teleport": {"name": "Teleport", "target": TARGET_OWN_PIECE_AND_HOME_CELL, "consumes_turn": true, "pick": ["own_piece", "home_cell"], "kind": "tactics", "rarity": "epic",
		"desc": "Beam one of your pieces to any empty square in your 3 home rows. Uses your turn."},
	# Traps
	"jammer": {"name": "Jammer", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trap", "rarity": "common",
		"desc": "Your opponent can't chat or taunt for 2 minutes."},
	"roadblock": {"name": "Roadblock", "target": TARGET_EMPTY_CELL, "consumes_turn": false, "pick": ["empty_cell"], "kind": "trap", "rarity": "common",
		"desc": "Barricade an empty square: no piece can enter it until your opponent's next 3 turns have passed."},
	"freeze": {"name": "Freeze", "target": TARGET_ENEMY_PIECE, "consumes_turn": false, "pick": ["enemy_piece"], "kind": "trap", "rarity": "rare",
		"desc": "Freeze one enemy piece in ice: it can't move for its owner's next 2 turns."},
	"quicksand": {"name": "Quicksand", "target": TARGET_EMPTY_OWN_CELL, "consumes_turn": false, "pick": ["half_cell"], "kind": "trap", "rarity": "rare",
		"desc": "Hide quicksand on an empty square of your half. The first enemy piece to step in is stuck for 2 turns."},
	"chaos_order": {"name": "Chaos Order", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trap", "rarity": "epic",
		"desc": "Your opponent's next move is picked at random and played the moment their turn starts."},
	"sabotage": {"name": "Sabotage", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trap", "rarity": "epic",
		"desc": "Your opponent can't use powerups during their next 3 turns."},
	"mine_field": {"name": "Mine Field", "target": TARGET_EMPTY_OWN_CELL, "consumes_turn": false, "pick": ["half_cell"], "kind": "trap", "rarity": "epic",
		"desc": "Bury a hidden mine on an empty square of your half. The first enemy piece to step on it is out. Lasts 10 of your turns."},
	"counterspell": {"name": "Counterspell", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trap", "rarity": "legendary",
		"desc": "Set a secret counter: the next powerup your opponent plays fizzles and is lost."},
	# Support
	"fortify": {"name": "Fortify", "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "support", "rarity": "rare",
		"desc": "A hidden shield on one of your pieces. The next attack on it bounces off. Lasts 6 of your turns."},
	"trench": {"name": "Trench", "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "support", "rarity": "rare",
		"desc": "Dig one of your pieces in: the next tie it suffers while defending is a win instead."},
	"decoy": {"name": "Decoy", "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "support", "rarity": "rare",
		"desc": "Disguise one of your pieces: enemy spies, leaks, drones and scouts get a convincing fake answer."},
	"ceasefire": {"name": "Ceasefire", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "support", "rarity": "rare",
		"desc": "White flags up! Your opponent can't attack on their next turn."},
	"reinforcement": {"name": "Reinforcement", "target": TARGET_EMPTY_BACK_CELL, "consumes_turn": true, "pick": ["back_cell"], "kind": "support", "rarity": "rare",
		"desc": "Bring back one of your fallen Privates on an empty square of your back row. Uses your turn. The enemy knows it's a Private."},
	"second_chance": {"name": "Second Chance", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "support", "rarity": "epic",
		"desc": "The next time one of your pieces would be eliminated (clash or mine), it survives instead."},
	"shuffle": {"name": "Shuffle", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "support", "rarity": "epic",
		"desc": "Two of your pieces the enemy hasn't identified secretly trade ranks, wiping what they knew about them."},
	"counter_intel": {"name": "Counter-Intel", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "support", "rarity": "epic",
		"desc": "Burn the files! The enemy forgets every rank and scan they learned about your pieces."},
	"promotion": {"name": "Field Promotion", "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "support", "rarity": "legendary",
		"desc": "Secretly promote one of your Privates to Sergeant. The enemy forgets anything they knew about it."},
	"recall": {"name": "Recall", "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "support", "rarity": "legendary",
		"desc": "Take back the last powerup you played: it returns to your hand, ready to use again."},
}

## Card types: [light, dark] frame colours, the label, and an emblem glyph for icons without their own.
const KIND_COLORS := {
	"clock": [Color("2ee6a8"), Color("0f8a63")],
	"intel": [Color("5aa8ff"), Color("2453c4")],
	"tactics": [Color("b18cff"), Color("6237d0")],
	"trap": [Color("ff6f93"), Color("c8204f")],
	"support": [Color("ffd04a"), Color("d8800f")],
}
const KIND_LABELS := {"clock": "Clock", "intel": "Intel", "tactics": "Tactics", "trap": "Trap", "support": "Support"}
const KINDS := ["clock", "intel", "tactics", "trap", "support"]
const KIND_FALLBACK_GLYPH := {"clock": "time_extension", "intel": "insight", "tactics": "double_march", "trap": "mine_field", "support": "fortify"}

const RARITIES := ["common", "rare", "epic", "legendary"]
const RARITY_LABELS := {"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legendary"}
const RARITY_COLORS := {"common": Color("c9ced9"), "rare": Color("4fb3ff"), "epic": Color("b56cff"), "legendary": Color("ffbf2e")}

## Rank groups reported by Scout Report.
const GROUPS := {
	"general": ["G5", "G4", "G3", "G2", "G1"],
	"officer": ["COL", "LTC", "MAJ", "CPT", "1LT", "2LT"],
	"enlisted": ["SGT", "PVT"],
	"spy": ["SPY"],
	"flag": ["FLG"],
}
const GROUP_NAMES := {"general": "General", "officer": "Officer", "enlisted": "Enlisted", "spy": "Spy", "flag": "Flag"}
## Insight counts these (Sergeant up to General of the Army).
const OFFICER_RANKS := ["G5", "G4", "G3", "G2", "G1", "COL", "LTC", "MAJ", "CPT", "1LT", "2LT", "SGT"]

const ICON_SIZE := 192.0

static var _glyphs: Dictionary = {}
static var _icons: Dictionary = {}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in POWERUPS:
		list.append(id)
	return list


static func has(id: String) -> bool:
	return POWERUPS.has(id)


static func info(id: String) -> Dictionary:
	return POWERUPS.get(id, {})


static func display_name(id: String) -> String:
	return str(POWERUPS[id]["name"]) if POWERUPS.has(id) else id.capitalize()


static func consumes_turn(id: String) -> bool:
	return bool(POWERUPS.get(id, {}).get("consumes_turn", false))


static func picks(id: String) -> Array:
	return POWERUPS.get(id, {}).get("pick", [])


static func kind(id: String) -> String:
	return str(POWERUPS.get(id, {}).get("kind", "intel"))


static func rarity(id: String) -> String:
	return str(POWERUPS.get(id, {}).get("rarity", "common"))


static func color(id: String) -> Color:
	return KIND_COLORS[kind(id)][0]


static func dark_color(id: String) -> Color:
	return KIND_COLORS[kind(id)][1]


## A hand of MAX_SLOTS distinct powerups dealt at random from the whole library (Random mode; the
## server deals online hands the same way).
static func deal(rng: RandomNumberGenerator = null) -> Array[String]:
	var pool := ids()
	var hand: Array[String] = []
	while not pool.is_empty() and hand.size() < MAX_SLOTS:
		var i := rng.randi_range(0, pool.size() - 1) if rng else randi_range(0, pool.size() - 1)
		hand.append(pool[i])
		pool.remove_at(i)
	return hand


## "Off" / "Select" / "Random" for a mode id.
static func mode_name(mode: String) -> String:
	return {"off": "Powerups off", "select": "Select", "random": "Random"}.get(mode, "Select")


static func group_of(rank: String) -> String:
	for group: String in GROUPS:
		if rank in GROUPS[group]:
			return group
	return ""


## Keeps up to MAX_SLOTS distinct known ids, in order.
static func sanitize(slots: Array) -> Array[String]:
	var clean: Array[String] = []
	for id: Variant in slots:
		if id is String and POWERUPS.has(id) and not clean.has(id) and clean.size() < MAX_SLOTS:
			clean.append(id)
	return clean


## The powerup's small icon: a candy tile in its type's colour with the white glyph and ink outline
## (toasts, banners). Cards use PowerupCard with the full art.
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = _rasterise(_icon_svg(id))
	return _icons[id]


static func _icon_svg(id: String) -> String:
	if _glyphs.is_empty():
		var res: Variant = load("res://core/powerups/powerup_glyphs.json")
		_glyphs = res.data if res is JSON and res.data is Dictionary else {}
	var colors: Array = KIND_COLORS[kind(id)]
	var glyph: Dictionary = _glyphs.get(id, _glyphs.get(KIND_FALLBACK_GLYPH[kind(id)], {}))
	var paths: Array = glyph.get("paths", [])
	var outline := ""
	var shade := ""
	var fill := ""
	for d: String in paths:
		outline += '<path d="%s" fill="#1d1736" stroke="#1d1736" stroke-width="44" stroke-linejoin="round"/>' % d
		shade += '<path d="%s" fill="#1d1736" fill-opacity="0.28"/>' % d
		fill += '<path d="%s" fill="#ffffff"/>' % d
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
		+ '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
		+ '<stop offset="0" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs>' % [colors[0].to_html(false), colors[1].to_html(false)]
		+ '<rect x="5" y="9" width="118" height="116" rx="30" fill="#1d1736"/>'
		+ '<rect x="5" y="4" width="118" height="114" rx="30" fill="url(#g)" stroke="#1d1736" stroke-width="6"/>'
		+ '<path d="M18 30 Q18 13 35 13 L93 13 Q110 13 110 30 L110 34 Q64 52 18 34 Z" fill="#ffffff" fill-opacity="0.22"/>'
		+ '<g transform="translate(23 22) scale(0.16)">' + outline + '</g>'
		+ '<g transform="translate(23 26) scale(0.16)">' + shade + '</g>'
		+ '<g transform="translate(23 22) scale(0.16)">' + fill + '</g>'
		+ '</svg>')


static func _rasterise(svg: String) -> ImageTexture:
	var image := Image.new()
	if image.load_svg_from_string(svg, ICON_SIZE / 128.0) != OK:
		image = Image.create_empty(int(ICON_SIZE), int(ICON_SIZE), false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
