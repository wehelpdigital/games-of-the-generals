class_name PowerupLibrary
extends RefCounted
## Every powerup a player can bring into a match. Before each game the players choose powerups
## off, Select (their own 5 picks from what their account rank, the PlayerRanks tier, has
## unlocked) or Random (5 dealt from what they have unlocked); each is usable once per match, on
## their own turn.
## Mirrors config/powerups.php on the server, which referees online matches; LocalArbiter applies
## the same rules offline. Icons are composed at runtime around game-icons.net glyphs (CC BY 3.0,
## see core/powerups/CREDITS.md).

## What the player picks on the board after tapping a powerup (the server's `target` field):
const TARGET_NONE := "none"
const TARGET_OWN_PIECE := "own_piece"
const TARGET_ENEMY_PIECE := "enemy_piece"
const TARGET_TWO_OWN := "two_own_pieces"
const TARGET_EMPTY_OWN_CELL := "empty_own_cell"
const TARGET_OWN_PIECE_AND_HOME_CELL := "own_piece_and_home_cell"
const TARGET_EMPTY_BACK_CELL := "empty_back_cell"

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

## `pick` is what the targeting UI asks for, in order: "own_piece", "enemy_piece", "home_cell"
## (empty, your 3 home rows), "half_cell" (empty, your half of the board), "back_cell" (empty,
## your back row). `kind` groups them by colour: time, intel, defense, trick, attack.
const POWERUPS := {
	"time_extension": {"name": "Time Extension", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "time",
		"desc": "Your next 3 turns get +20 seconds on the clock."},
	"spy_card": {"name": "Spy Card", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel",
		"desc": "Reveals the rank of one random enemy piece you haven't identified. Only you see it."},
	"insight": {"name": "Insight", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel",
		"desc": "Tells you how many enemy officers (Sergeant up to 5-star General) are still alive."},
	"quick_step": {"name": "Quick Step", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "time",
		"desc": "No clock on your next turn. Take all the time you need."},
	"time_squeeze": {"name": "Time Squeeze", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "time",
		"desc": "Your opponent's next 3 turns are 15 seconds shorter (never under 10 s)."},
	"intel_leak": {"name": "Intel Leak", "tier": 0, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel",
		"desc": "Reveals the rank of the enemy piece that moved last."},
	"recon_drone": {"name": "Recon Drone", "tier": 2, "target": TARGET_ENEMY_PIECE, "consumes_turn": false, "pick": ["enemy_piece"], "kind": "intel",
		"desc": "Fly over one enemy piece: is it their Flag?"},
	"fortify": {"name": "Fortify", "tier": 2, "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "defense",
		"desc": "A hidden shield on one of your pieces. The next attack on it bounces off. Lasts 6 of your turns."},
	"scout_report": {"name": "Scout Report", "tier": 3, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel",
		"desc": "Learn the rank group (General, Officer, Enlisted, Spy or Flag) of 3 random enemy pieces."},
	"swap": {"name": "Swap", "tier": 3, "target": TARGET_TWO_OWN, "consumes_turn": true, "pick": ["own_piece", "own_piece"], "kind": "trick",
		"desc": "Two of your pieces trade places. Uses your turn."},
	"smoke_screen": {"name": "Smoke Screen", "tier": 4, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trick",
		"desc": "Your next move is hidden: your opponent sees your army as it stood, under smoke, until their turn ends."},
	"jammer": {"name": "Jammer", "tier": 4, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trick",
		"desc": "Your opponent can't chat or taunt for 2 minutes."},
	"freeze": {"name": "Freeze", "tier": 5, "target": TARGET_ENEMY_PIECE, "consumes_turn": false, "pick": ["enemy_piece"], "kind": "attack",
		"desc": "Freeze one enemy piece in ice: it can't move for its owner's next 2 turns."},
	"decoy": {"name": "Decoy", "tier": 5, "target": TARGET_OWN_PIECE, "consumes_turn": false, "pick": ["own_piece"], "kind": "defense",
		"desc": "Disguise one of your pieces: enemy Spy Cards, leaks, drones and scouts get a convincing fake answer."},
	"chaos_order": {"name": "Chaos Order", "tier": 6, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "attack",
		"desc": "Your opponent's next move is picked at random and played the moment their turn starts."},
	"flag_hunter": {"name": "Flag Hunter", "tier": 6, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "intel",
		"desc": "Learn which column the enemy Flag stands in."},
	"double_march": {"name": "Double March", "tier": 7, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "attack",
		"desc": "Move two different pieces this turn. The second move can't be an attack."},
	"second_chance": {"name": "Second Chance", "tier": 7, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "defense",
		"desc": "The next time one of your pieces would be eliminated (clash or mine), it survives instead."},
	"sabotage": {"name": "Sabotage", "tier": 8, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "attack",
		"desc": "Your opponent can't use powerups during their next 3 turns."},
	"teleport": {"name": "Teleport", "tier": 8, "target": TARGET_OWN_PIECE_AND_HOME_CELL, "consumes_turn": true, "pick": ["own_piece", "home_cell"], "kind": "trick",
		"desc": "Beam one of your pieces to any empty square in your 3 home rows. Uses your turn."},
	"mine_field": {"name": "Mine Field", "tier": 9, "target": TARGET_EMPTY_OWN_CELL, "consumes_turn": false, "pick": ["half_cell"], "kind": "attack",
		"desc": "Bury a hidden mine on an empty square of your half. The first enemy piece to step on it is out. Lasts 10 of your turns."},
	"rally_cry": {"name": "Rally Cry", "tier": 9, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "attack",
		"desc": "Your next clash that would end in a tie is a win for you instead."},
	"reinforcement": {"name": "Reinforcement", "tier": 10, "target": TARGET_EMPTY_BACK_CELL, "consumes_turn": true, "pick": ["back_cell"], "kind": "defense",
		"desc": "Bring back one of your fallen Privates on an empty square of your back row. Uses your turn. The enemy knows it's a Private."},
	"shuffle": {"name": "Shuffle", "tier": 10, "target": TARGET_NONE, "consumes_turn": false, "pick": [], "kind": "trick",
		"desc": "Two of your pieces the enemy hasn't identified secretly trade ranks, wiping what they knew about them."},
}

const KIND_COLORS := {
	"time": [Color("2ee6a8"), Color("12946c")],
	"intel": [Color("5aa8ff"), Color("2557c9")],
	"defense": [Color("ffd04a"), Color("e08a12")],
	"trick": [Color("b18cff"), Color("6a3fd6")],
	"attack": [Color("ff6f93"), Color("d12a5a")],
}
const KIND_LABELS := {"time": "Clock", "intel": "Intel", "defense": "Defense", "trick": "Trick", "attack": "Attack"}

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


static func unlock_tier(id: String) -> int:
	return int(POWERUPS[id]["tier"]) if POWERUPS.has(id) else 99


static func consumes_turn(id: String) -> bool:
	return bool(POWERUPS.get(id, {}).get("consumes_turn", false))


static func picks(id: String) -> Array:
	return POWERUPS.get(id, {}).get("pick", [])


static func color(id: String) -> Color:
	return KIND_COLORS[POWERUPS.get(id, {}).get("kind", "intel")][0]


## Powerups unlocked at `tier` (account rank), in library order.
static func unlocked_at(tier: int) -> Array[String]:
	var list: Array[String] = []
	for id: String in POWERUPS:
		if int(POWERUPS[id]["tier"]) <= tier:
			list.append(id)
	return list


## A hand of MAX_SLOTS distinct powerups dealt at random from those unlocked at `tier`
## (Random mode; the server deals online hands the same way).
static func deal(tier: int, rng: RandomNumberGenerator = null) -> Array[String]:
	var pool := unlocked_at(tier)
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


## The powerup's card icon: a candy tile in its kind's colour with the white glyph and ink outline.
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = _rasterise(_icon_svg(id))
	return _icons[id]


static func _icon_svg(id: String) -> String:
	if _glyphs.is_empty():
		var res: Variant = load("res://core/powerups/powerup_glyphs.json")
		_glyphs = res.data if res is JSON and res.data is Dictionary else {}
	var colors: Array = KIND_COLORS[POWERUPS.get(id, {}).get("kind", "intel")]
	var paths: Array = _glyphs.get(id, {}).get("paths", [])
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
