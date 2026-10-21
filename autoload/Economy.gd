extends Node
## Economy module: the daily login reward, missions, achievements and titles, and the rewards a
## finished game paid (online matches from the server, practice wins reported to it). Registers
## the achievements screen and the dashboard's daily-reward banner and missions card.
## Every call goes through api(), which tests can redirect with `mock`.
##
##     await Economy.refresh_missions()
##     print(Economy.missions.daily.missions)

signal daily_changed
signal missions_changed
signal achievements_changed
signal match_rewards(summary: Dictionary)  ## After a game: {kind, credits, xp, breakdown, missions, achievements...}

const LEVELS := {SalpakanAI.Difficulty.EASY: "easy", SalpakanAI.Difficulty.MEDIUM: "medium", SalpakanAI.Difficulty.HARD: "hard"}

var daily: Dictionary = {}         ## GET /api/rewards/daily
var missions: Dictionary = {}      ## GET /api/missions
var achievements: Dictionary = {}  ## GET /api/achievements
var last_rewards: Dictionary = {}  ## The latest match_rewards summary (with "seq").
var game_seq := 0                  ## Counts finished games, so views can match a summary to its game.

## Tests: func(method: int, path: String, body: Variant) -> Dictionary (an ApiManager result).
var mock: Callable

var _popup_shown_on := ""


func _ready() -> void:
	ScreenRegistry.register("achievements", preload("res://ui/screens/AchievementsScreen.gd"))
	DashboardRegistry.register(preload("res://ui/dashboard/DailyRewardBanner.gd"), "banner", 5)
	DashboardRegistry.register(preload("res://ui/dashboard/MissionsPanel.gd"), "main", 10)
	GameSession.game_over.connect(_on_game_over)
	ApiManager.auth_changed.connect(func(_logged_in: bool) -> void:
		daily = {}
		missions = {}
		achievements = {}
		last_rewards = {})


func api(method: int, path: String, body: Variant = null) -> Dictionary:
	if mock.is_valid():
		return mock.call(method, path, body)
	return await ApiManager.request(method, path, body)


# --- Daily login reward -------------------------------------------------------------------------

func refresh_daily() -> Dictionary:
	if not ApiManager.is_logged_in():
		return {}
	var res := await api(HTTPClient.METHOD_GET, "/api/rewards/daily")
	if res.ok:
		daily = res.data
		daily_changed.emit()
	return res


## Coroutine: claims today's reward. Returns the API result ({reward: {day, credits, item}, ...}).
func claim_daily() -> Dictionary:
	var res := await api(HTTPClient.METHOD_POST, "/api/rewards/daily/claim")
	if res.ok:
		daily = res.data.get("status", daily)
		_after_credits_changed(res.data)
		daily_changed.emit()
	return res


## Whether the dashboard should pop the calendar up (once per day, when unclaimed).
func should_offer_daily() -> bool:
	return ApiManager.is_logged_in() and not daily.is_empty() and not daily.get("claimed_today", true) \
		and _popup_shown_on != _today()


func mark_daily_offered() -> void:
	_popup_shown_on = _today()


# --- Missions -----------------------------------------------------------------------------------

func refresh_missions() -> Dictionary:
	if not ApiManager.is_logged_in():
		return {}
	var res := await api(HTTPClient.METHOD_GET, "/api/missions")
	if res.ok:
		missions = res.data
		missions_changed.emit()
	return res


func claim_mission(id: int) -> Dictionary:
	var res := await api(HTTPClient.METHOD_POST, "/api/missions/%d/claim" % id)
	if res.ok:
		_after_credits_changed(res.data)
		await refresh_missions()
	return res


func reroll_mission(id: int) -> Dictionary:
	var res := await api(HTTPClient.METHOD_POST, "/api/missions/%d/reroll" % id)
	if res.ok and res.data.get("board") is Dictionary:
		missions = res.data["board"]
		missions_changed.emit()
	return res


## Completed missions waiting to be claimed (both boards).
func claimable_count() -> int:
	var count := 0
	for period: String in ["daily", "weekly"]:
		var board: Variant = missions.get(period)
		if board is Dictionary:
			for m: Dictionary in board.get("missions", []):
				if m.get("completed", false) and not m.get("claimed", false):
					count += 1
	return count


# --- Achievements and titles --------------------------------------------------------------------

func refresh_achievements() -> Dictionary:
	if not ApiManager.is_logged_in():
		return {}
	var res := await api(HTTPClient.METHOD_GET, "/api/achievements")
	if res.ok:
		achievements = res.data
		achievements_changed.emit()
	return res


## Wear an unlocked title ("" takes it off).
func set_title(title: String) -> Dictionary:
	var res := await api(HTTPClient.METHOD_PUT, "/api/profile/title", {"title": null if title == "" else title})
	if res.ok:
		achievements["title"] = res.data.get("title")
		Profile.data["title"] = res.data.get("title")
		Profile.changed.emit()
		achievements_changed.emit()
	return res


static func title_of(user: Variant) -> String:
	if user is Dictionary and user.get("title") != null:
		return str(user["title"])
	return ""


# --- After a game -------------------------------------------------------------------------------

func _on_game_over(info: Dictionary) -> void:
	game_seq += 1
	var seq := game_seq
	if not ApiManager.is_logged_in():
		return
	var summary := {}
	if GameSession.kind == GameSession.Kind.PRACTICE:
		summary = await report_practice(LEVELS.get(GameSession.practice_level, "easy"), bool(info.get("you_won", false)),
			int(GameSession.match_view.get("move_number", 0)))
	elif GameSession.kind == GameSession.Kind.ONLINE and GameSession.match_id() > 0:
		summary = await fetch_match_rewards(GameSession.match_id())
	if summary.is_empty():
		summary = {"kind": "none", "failed": true}
	summary["seq"] = seq
	last_rewards = summary
	match_rewards.emit(summary)
	if summary.get("failed", false):
		return
	_announce(summary)
	refresh_missions()


## Coroutine: reports a finished practice game; returns the summary ({} on failure).
func report_practice(level: String, won: bool, moves: int) -> Dictionary:
	var res := await api(HTTPClient.METHOD_POST, "/api/practice/result", {"level": level, "won": won, "moves": moves})
	if not res.ok:
		return {}
	var data: Dictionary = res.data
	_after_credits_changed(data)
	return {"kind": "practice", "counted": data.get("counted", false), "credits": int(data.get("credits_awarded", 0)),
		"xp": 0, "breakdown": {"practice_win": int(data.get("credits_awarded", 0))} if int(data.get("credits_awarded", 0)) > 0 else {},
		"missions": data.get("missions", []), "achievements": data.get("achievements", []), "balance": data.get("credits")}


## Coroutine: the server pays online matches right after they end; waits briefly if it's not ready.
func fetch_match_rewards(match_id: int) -> Dictionary:
	for attempt in 4:
		var res := await api(HTTPClient.METHOD_GET, "/api/rewards/match/%d" % match_id)
		if not res.ok:
			return {}
		if not res.data.get("pending", false):
			var data: Dictionary = res.data
			data["kind"] = "online"
			_after_credits_changed({"credits": data.get("balance")})
			return data
		await get_tree().create_timer(1.0 + attempt).timeout
	return {}


func _after_credits_changed(data: Dictionary) -> void:
	if data.get("credits") != null and ApiManager.is_logged_in():
		ApiManager.user["credits"] = int(data["credits"])
		Profile.data["credits"] = int(data["credits"])
		Profile.changed.emit()
	for unlocked: Dictionary in data.get("achievements", []):
		toast("Achievement unlocked: %s!" % str(unlocked.get("name", "")), AppTheme.PURPLE)
	if not data.get("achievements", []).is_empty():
		Profile.refresh()


func _announce(summary: Dictionary) -> void:
	for m: Dictionary in summary.get("missions", []):
		if m.get("completed", false) and not m.get("claimed", false):
			toast("Mission complete: %s! Claim it on the dashboard." % str(m.get("title", "")), AppTheme.MINT)
	if summary.get("kind") == "online":
		for unlocked: Dictionary in summary.get("achievements", []):
			toast("Achievement unlocked: %s!" % str(unlocked.get("name", "")), AppTheme.PURPLE)


func toast(text: String, color := AppTheme.INK) -> void:
	var scene := get_tree().current_scene
	var ui := scene.get_node_or_null("UI") if scene else null
	if ui and ui.has_method("toast"):
		ui.call("toast", text, color)


func _today() -> String:
	return Time.get_date_string_from_system()
