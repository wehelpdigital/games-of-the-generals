class_name Ranks
extends RefCounted
## Salpakan rules shared by the client: board size, the 21-piece set, insignia layout, and the clash
## rules. Online matches are always arbitrated by the server; the client only uses resolve_clash()
## for offline practice.

const COLS := 9
const ROWS := 8
const HOME_DEPTH := 3

const WHITE := "white"
const BLACK := "black"

## Strongest to weakest. "power" is only meaningful for ordinary ranks; SPY and FLG are special-cased.
const INFO := {
	"G5": {"name": "General of the Army", "label": "GEN", "insignia": "star", "marks": 5, "power": 13, "count": 1},
	"G4": {"name": "General", "label": "GEN", "insignia": "star", "marks": 4, "power": 12, "count": 1},
	"G3": {"name": "Lieutenant General", "label": "LT GEN", "insignia": "star", "marks": 3, "power": 11, "count": 1},
	"G2": {"name": "Major General", "label": "MAJ GEN", "insignia": "star", "marks": 2, "power": 10, "count": 1},
	"G1": {"name": "Brigadier General", "label": "BRIG GEN", "insignia": "star", "marks": 1, "power": 9, "count": 1},
	"COL": {"name": "Colonel", "label": "COL", "insignia": "sun", "marks": 3, "power": 8, "count": 1},
	"LTC": {"name": "Lieutenant Colonel", "label": "LT COL", "insignia": "sun", "marks": 2, "power": 7, "count": 1},
	"MAJ": {"name": "Major", "label": "MAJ", "insignia": "sun", "marks": 1, "power": 6, "count": 1},
	"CPT": {"name": "Captain", "label": "CPT", "insignia": "triangle", "marks": 3, "power": 5, "count": 1},
	"1LT": {"name": "First Lieutenant", "label": "1LT", "insignia": "triangle", "marks": 2, "power": 4, "count": 1},
	"2LT": {"name": "Second Lieutenant", "label": "2LT", "insignia": "triangle", "marks": 1, "power": 3, "count": 1},
	"SGT": {"name": "Sergeant", "label": "SGT", "insignia": "chevron", "marks": 3, "power": 2, "count": 1},
	"PVT": {"name": "Private", "label": "PVT", "insignia": "chevron", "marks": 1, "power": 1, "count": 6},
	"SPY": {"name": "Spy", "label": "SPY", "insignia": "eye", "marks": 1, "power": 0, "count": 2},
	"FLG": {"name": "Flag", "label": "FLAG", "insignia": "flag", "marks": 1, "power": 0, "count": 1},
}


static func info(rank: String) -> Dictionary:
	return INFO.get(rank, {})


static func display_name(rank: String) -> String:
	return INFO[rank]["name"] if INFO.has(rank) else "Unknown piece"


## The 21 rank codes a side fields, strongest first.
static func full_set() -> Array[String]:
	var ranks: Array[String] = []
	for rank: String in INFO:
		for i in int(INFO[rank]["count"]):
			ranks.append(rank)
	return ranks


static func opponent(side: String) -> String:
	return BLACK if side == WHITE else WHITE


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


static func is_home_cell(side: String, cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return cell.y < HOME_DEPTH if side == WHITE else cell.y >= ROWS - HOME_DEPTH


## The row a side's flag must reach to win.
static func goal_row(side: String) -> int:
	return ROWS - 1 if side == WHITE else 0


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next := cell + step
		if in_bounds(next):
			result.append(next)
	return result


## Who survives when `attacker` moves onto `defender`: "attacker", "defender" or "both".
static func resolve_clash(attacker: String, defender: String) -> String:
	if defender == "FLG":
		return "attacker"
	if attacker == "FLG":
		return "defender"
	if attacker == "SPY" and defender == "SPY":
		return "both"
	if attacker == "SPY":
		return "defender" if defender == "PVT" else "attacker"
	if defender == "SPY":
		return "attacker" if attacker == "PVT" else "defender"
	var a: int = INFO[attacker]["power"]
	var d: int = INFO[defender]["power"]
	if a == d:
		return "both"
	return "attacker" if a > d else "defender"


## A random legal formation for `side`: [{rank, x, y}] covering 21 of the 27 home squares.
static func random_formation(side: String) -> Array[Dictionary]:
	var cells: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			if is_home_cell(side, Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	cells.shuffle()
	var formation: Array[Dictionary] = []
	var ranks := full_set()
	for i in ranks.size():
		formation.append({"rank": ranks[i], "x": cells[i].x, "y": cells[i].y})
	return formation
