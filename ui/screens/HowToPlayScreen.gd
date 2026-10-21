extends Screen
## How to play: the goal, moving, the rank ladder with every insignia, the special rules, fog of
## war, powerups and the clock, plus a short FAQ. Boot Camp is one tap away at the top.

const FAQ := [
	["How long is a game?", "Usually 10 to 20 minutes. Each turn has a clock (45 seconds by default)."],
	["Can I play without an account?", "Yes: Boot Camp and games against the Rookie AI are free and offline. Log in to play online, take on the tougher AIs and earn rewards."],
	["Why can't I see enemy ranks?", "That's fog of war, the heart of Salpakan. Clashes tell you who won; the rest is reading your opponent."],
	["What happens when two pieces of the same rank meet?", "Both leave the board. Two Spies do too."],
	["My Flag reached the far row but the game didn't end?", "An enemy piece was right beside it. It has to survive one more turn, then you win."],
	["Do powerups make the game unfair?", "Everyone gets 5 cards and each works once. Prefer it classic? Turn powerups off before a game."],
]

var _page: Dictionary
var _body: VBoxContainer
var _back_to := ""


func _ready() -> void:
	_page = ProfileUi.page(self, "How to Play", _back, 820)
	_body = _page["body"]
	get_viewport().size_changed.connect(_on_resized)


func open(args: Dictionary) -> void:
	_back_to = str(args.get("back", ""))
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])


func _on_resized() -> void:
	_layout()
	if visible:
		_render()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _back() -> void:
	if _back_to != "" and ui.has_screen(_back_to):
		ui.show_screen(_back_to)
	else:
		ui.home()


func _render() -> void:
	ProfileUi.clear(_body)
	var frame: Control = _page["frame"]
	var wide := not ProfileUi.narrow and frame.size.x >= 720.0
	_body.add_child(_boot_camp_card())
	_section("Goal", "Capture the enemy Flag, or march your own Flag onto the enemy's back row. Each side has 21 pieces: Generals, officers, Sergeant, Privates, two Spies and a Flag.")
	_section("Moving", "On your turn, move one piece one square forward, back or sideways. No diagonals and no jumping. Move onto an enemy piece to attack it.")
	_body.add_child(ProfileUi.eyebrow("RANK LADDER  ·  STRONGEST FIRST"))
	var ladder_card := AppTheme.card("Row")
	ladder_card.add_child(RulesSheet.ladder(2 if wide else 1, 44.0))
	_body.add_child(ladder_card)
	_body.add_child(ProfileUi.eyebrow("CLASH RULES"))
	var rules_card := AppTheme.card("Row")
	rules_card.add_child(RulesSheet.rules(16))
	_body.add_child(rules_card)
	_section("Before the battle", "Arrange your army in your 3 home rows. Hide your Flag at the back with strong pieces nearby, and mix in a Spy or two to surprise attackers.")
	_section("Powerups", "Optional cards: before a game choose 5 (or get 5 at random), or switch them off. Play them on your turn, at most 2 per turn, each once per match. Some need a target: tap the card, then the piece or square.")
	_section("The clock", "Every turn is timed. If time runs out a random move is played for you, and 3 timeouts in a row lose the game.")
	_body.add_child(ProfileUi.eyebrow("FAQ"))
	for entry: Array in FAQ:
		_body.add_child(_faq(entry[0], entry[1]))


func _boot_camp_card() -> Control:
	var card := AppTheme.card("Row")
	card.add_theme_stylebox_override("panel", ProfileUi.highlight_style())
	var line := ProfileUi.flex(14)
	card.add_child(line)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var graduate := TutorialProgress.is_graduate()
	words.add_child(ProfileUi.heading("Boot Camp graduate" if graduate else "Learn by playing", 24))
	words.add_child(ProfileUi.wrap("Eight quick drills on the real board, then a short game against the Rookie AI.", 16, AppTheme.MUTED))
	line.add_child(words)
	var go := ProfileUi.colored_button("Open Boot Camp" if graduate else "Start Boot Camp", AppTheme.PINK, Color.WHITE,
		func() -> void: ui.show_screen("boot_camp", {"back": "how_to_play"}), 54)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(go)
	return card


func _section(title: String, text: String) -> void:
	var card := AppTheme.card("Row")
	var box := AppTheme.vbox(4)
	card.add_child(box)
	box.add_child(ProfileUi.heading(title, 22))
	box.add_child(ProfileUi.wrap(text, 16))
	_body.add_child(card)


func _faq(question: String, answer: String) -> Control:
	var card := AppTheme.card("Row")
	var box := AppTheme.vbox(4)
	card.add_child(box)
	var q := AppTheme.label(question, "", 17)
	q.add_theme_font_override("font", AppTheme.heading_font())
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(q)
	box.add_child(ProfileUi.wrap(answer, 15, AppTheme.MUTED))
	return card
