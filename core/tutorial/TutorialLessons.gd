class_name TutorialLessons
extends RefCounted
## Boot Camp's lessons as data: each lesson is one or more stages (a small scripted battle on the
## real board), and each stage a list of steps the coach walks the player through.
##
## Pieces: [rank, x, y, tags]. White sits on rows 0-2 (nearest the player), black on 5-7. Tags:
## "r" shows that enemy piece's rank to the player (lessons before Fog of War), "i" marks the drill
## opponent's only moving piece (it paces back and forth; every other enemy piece stays put).
##
## Steps ("do"):
##   note    text only; the coach shows a Next button
##   move    move a piece to the square `to` (also attacks; `after` keys: move, attacker,
##           defender, both). `piece` names it by the square the stage put it on, even if it has
##           moved since
##   any     any move of the player's (after: move)
##   clock   any move, or let the clock run out (after: move, auto)
##   swap    swap two pieces during setup
##   ready   press Ready with the Flag on the back row
##   powerup play the card `id` (after: done)
##   win     win the game (the graduation game)

const GRADUATION_ID := "graduation"

const LESSONS: Array[Dictionary] = [
	{
		"id": "goal", "title": "Win the War", "icon": "FLG",
		"blurb": "Capture the enemy Flag, or march your own Flag home.",
		"stages": [
			{
				"white": [["CPT", 4, 3], ["FLG", 4, 0], ["PVT", 2, 1]],
				"black": [["FLG", 4, 4, "r"], ["PVT", 0, 7, "i"], ["SGT", 8, 6]],
				"steps": [
					{"do": "move", "piece": [4, 3], "to": [4, 4],
						"say": "Welcome to Boot Camp, soldier! Your mission: capture the enemy Flag. It's right in front of your Captain. Tap the Captain, then tap the Flag to attack!",
						"after": {"attacker": "Flag captured! Taking the enemy Flag wins the battle on the spot."}},
				],
			},
			{
				"white": [["FLG", 3, 6], ["PVT", 6, 1]],
				"black": [["PVT", 8, 1, "i"], ["SGT", 0, 2]],
				"steps": [
					{"do": "move", "piece": [3, 6], "to": [3, 7],
						"say": "The other way to win: march your own Flag onto the enemy's back row. Your Flag is one step away. Go!",
						"after": {"move": "Your Flag made it! (If an enemy stands right beside it, it must survive one more turn first.)"}},
				],
			},
		],
	},
	{
		"id": "moving", "title": "Marching Orders", "icon": "PVT",
		"blurb": "One square at a time: forward, back or sideways.",
		"stages": [
			{
				"white": [["PVT", 4, 1], ["SGT", 2, 1], ["FLG", 4, 0]],
				"black": [["PVT", 8, 7, "i"], ["FLG", 0, 7]],
				"steps": [
					{"do": "move", "piece": [4, 1], "to": [4, 2],
						"say": "Pieces move one square at a time. Tap your Private, then tap the glowing square to step forward.",
						"after": {"move": "Nice step!"}},
					{"do": "move", "piece": [4, 1], "to": [5, 2],
						"say": "Sideways works too (and so does backward). Move the Private one square to the right.",
						"after": {"move": "Sideways march, done."}},
					{"do": "any",
						"say": "No diagonal moves and no jumping over pieces. After you move, your opponent moves. Make any move you like.",
						"after": {"move": "That's the rhythm: one move each, back and forth."}},
				],
			},
		],
	},
	{
		"id": "ranks", "title": "Rank & Clash", "icon": "CPT",
		"blurb": "Higher rank wins. Equal ranks knock each other out.",
		"stages": [
			{
				"white": [["CPT", 3, 3], ["SGT", 5, 3], ["FLG", 4, 0]],
				"black": [["1LT", 3, 4, "r"], ["SGT", 5, 4, "r"], ["PVT", 8, 7, "i"], ["FLG", 0, 7]],
				"steps": [
					{"do": "note",
						"say": "When two pieces meet, the higher rank wins and the loser leaves the board. Stars (Generals) beat suns (Colonels and Majors), suns beat triangles (Captains and Lieutenants), and triangles beat chevrons (Sergeant and Private)."},
					{"do": "move", "piece": [3, 3], "to": [3, 4],
						"say": "Your Captain (3 triangles) outranks their First Lieutenant (2 triangles). Attack!",
						"after": {"attacker": "Higher rank wins. Their Lieutenant is out!"}},
					{"do": "move", "piece": [5, 3], "to": [5, 4],
						"say": "Equal ranks knock each other out. Send your Sergeant into theirs.",
						"after": {"both": "Both Sergeants are gone. Equal ranks always trade."}},
					{"do": "note",
						"say": "In a match, tap Rules at the top of the screen to see the whole rank ladder any time."},
				],
			},
		],
	},
	{
		"id": "spy", "title": "The Spy", "icon": "SPY",
		"blurb": "Takes down Generals, but a Private catches it.",
		"stages": [
			{
				"white": [["SPY", 2, 3], ["PVT", 6, 3], ["FLG", 4, 0]],
				"black": [["G5", 2, 4, "r"], ["SPY", 6, 4, "r"], ["PVT", 8, 7, "i"], ["FLG", 0, 7]],
				"steps": [
					{"do": "move", "piece": [2, 3], "to": [2, 4],
						"say": "Meet the Spy: it beats every officer, even the 5-star General! Attack their General with your Spy.",
						"after": {"attacker": "Down goes the General! Spies are your answer to big ranks."}},
					{"do": "move", "piece": [6, 3], "to": [6, 4],
						"say": "The Spy's weakness: Privates. A Private beats a Spy. Attack their Spy with your Private.",
						"after": {"attacker": "Caught! Only a Private can stop a Spy."}},
					{"do": "note",
						"say": "Keep your Spies away from Privates, and keep a Private near your Generals to guard them from enemy Spies."},
				],
			},
		],
	},
	{
		"id": "fog", "title": "Fog of War", "icon": "UNKNOWN",
		"blurb": "Enemy ranks are hidden. Learn them from clashes.",
		"stages": [
			{
				"white": [["G1", 4, 3], ["PVT", 2, 2], ["FLG", 4, 0]],
				"black": [["LTC", 4, 4], ["PVT", 3, 5], ["FLG", 5, 6], ["PVT", 8, 7, "i"]],
				"steps": [
					{"do": "note",
						"say": "Real battles have fog of war: you can't see enemy ranks. Every enemy piece looks the same until you learn more."},
					{"do": "move", "piece": [4, 3], "to": [4, 4],
						"say": "You learn from clashes. Attack the piece in front of your Brigadier General and see what happens.",
						"after": {"attacker": "You won, so that piece was weaker than a Brigadier General. Remember what you learn!",
							"defender": "You lost, so that piece outranks a Brigadier General. Now you know where a big gun is!",
							"both": "A trade: it was another Brigadier General."}},
					{"do": "note",
						"say": "Clues to watch: a piece that never moves might be the Flag, and a piece that beat your officer could be a General or a Spy. Guess, bluff and remember!"},
				],
			},
		],
	},
	{
		"id": "setup", "title": "Battle Formation", "icon": "COL",
		"blurb": "Arrange your army and hide your Flag.",
		"stages": [
			{
				"setup": true,
				"steps": [
					{"do": "swap",
						"say": "Before every battle you arrange your army in your 3 home rows. Tap one of your pieces, then another, to swap them.",
						"after": {"done": "Swapped! Shuffle deals a whole new random layout if you want one."}},
					{"do": "ready",
						"say": "Hide your Flag in your back row (the one nearest you), ideally with strong pieces beside it. Then press Ready!",
						"after": {"done": "Formation locked in. Good thinking, commander!"}},
				],
			},
		],
	},
	{
		"id": "powerups", "title": "Powerup Cards", "icon": "MAJ",
		"blurb": "Play cards for intel and tricks.",
		"stages": [
			{
				"powerups": ["spy_card", "freeze"],
				"white": [["CPT", 4, 2], ["PVT", 3, 2], ["FLG", 4, 0]],
				"black": [["COL", 3, 5], ["PVT", 5, 5], ["MAJ", 4, 6], ["FLG", 4, 7], ["PVT", 8, 7, "i"]],
				"steps": [
					{"do": "powerup", "id": "spy_card",
						"say": "Powerups are cards you play on your turn. Tap the Spy Card in your hand, then tap it again (or press Play).",
						"after": {"done": "It showed you one enemy rank, and only you can see it!"}},
					{"do": "powerup", "id": "freeze",
						"say": "Some cards need a target. Play Freeze, then tap an enemy piece to freeze it.",
						"after": {"done": "Frozen solid! That piece can't move for its next 2 turns."}},
					{"do": "note",
						"say": "Each card works once per match, up to 2 per turn. Before each game you pick 5 cards, or get 5 at random. Browse them all in the Powerups binder."},
				],
			},
		],
	},
	{
		"id": "clock", "title": "Beat the Clock", "icon": "SGT",
		"blurb": "Every turn is timed. Don't let it run out.",
		"stages": [
			{
				"turn_seconds": 20,
				"white": [["PVT", 4, 1], ["SGT", 2, 1], ["FLG", 4, 0]],
				"black": [["PVT", 8, 7, "i"], ["FLG", 0, 7]],
				"steps": [
					{"do": "clock",
						"say": "Every turn has a clock, shown at the top. If it runs out, a random move is played for you, and 3 timeouts in a row lose the game. Make a move before it hits zero!",
						"after": {"move": "Quick thinking!", "auto": "Too slow! The clock picked a move for you."}},
					{"do": "note",
						"say": "Cards like Time Extension add seconds and Time Squeeze takes them from your rival. You're ready for the final exam!"},
				],
			},
		],
	},
]

const GRADUATION := {
	"id": GRADUATION_ID, "title": "Graduation", "icon": "G2", "ai": true,
	"blurb": "A short battle against the Rookie AI.",
	"stages": [
		{
			"turn_seconds": 60,
			"white": [["FLG", 4, 0], ["PVT", 3, 0], ["PVT", 5, 0], ["SGT", 2, 1], ["MAJ", 4, 1], ["CPT", 6, 1],
				["SPY", 1, 2], ["COL", 3, 2], ["G2", 5, 2], ["PVT", 7, 2]],
			"black": [["FLG", 4, 7], ["PVT", 3, 7], ["PVT", 5, 7], ["SGT", 6, 6], ["MAJ", 4, 6], ["CPT", 2, 6],
				["SPY", 7, 5], ["COL", 5, 5], ["G2", 3, 5], ["PVT", 1, 5]],
			"steps": [
				{"do": "win",
					"say": "Final exam! Beat the Rookie AI with a small army: capture its Flag or march yours home. Enemy ranks are hidden, just like a real game. Good luck, soldier!"},
			],
		},
	],
}


## Every Boot Camp entry in order: the drills, then the graduation game.
static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = LESSONS.duplicate()
	list.append(GRADUATION)
	return list


static func get_lesson(lesson_id: String) -> Dictionary:
	for lesson: Dictionary in all():
		if lesson["id"] == lesson_id:
			return lesson
	return {}


## Position in all() (0-based), or -1.
static func index_of(lesson_id: String) -> int:
	var list := all()
	for i in list.size():
		if list[i]["id"] == lesson_id:
			return i
	return -1


## The entry after `lesson_id`, or "" after the graduation game.
static func next_id(lesson_id: String) -> String:
	var list := all()
	var i := index_of(lesson_id)
	return list[i + 1]["id"] if i >= 0 and i + 1 < list.size() else ""


## A stage's piece list as a formation for LocalArbiter.deploy: [{rank, x, y}].
static func formation(entries: Array) -> Array:
	var list: Array = []
	for e: Array in entries:
		list.append({"rank": e[0], "x": e[1], "y": e[2]})
	return list


## The formation drill's starting layout: a random one with the Flag up front, so there's
## something to fix.
static func drill_formation() -> Array[Dictionary]:
	var layout := Ranks.random_formation(Ranks.WHITE)
	var flag := -1
	var front := -1
	for i in layout.size():
		if layout[i]["rank"] == "FLG":
			flag = i
		elif front < 0 and int(layout[i]["y"]) == Ranks.HOME_DEPTH - 1:
			front = i
	if flag >= 0 and front >= 0 and int(layout[flag]["y"]) != Ranks.HOME_DEPTH - 1:
		var spot := Vector2i(int(layout[flag]["x"]), int(layout[flag]["y"]))
		layout[flag]["x"] = layout[front]["x"]
		layout[flag]["y"] = layout[front]["y"]
		layout[front]["x"] = spot.x
		layout[front]["y"] = spot.y
	return layout


## How many steps a lesson has across its stages (for the coach's progress dots).
static func step_count(lesson: Dictionary) -> int:
	var count := 0
	for stage: Dictionary in lesson["stages"]:
		count += (stage["steps"] as Array).size()
	return count
