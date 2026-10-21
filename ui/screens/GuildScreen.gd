extends Screen
## One guild: logo, tag, master, totals and members. Players join or leave here; the guild
## master uploads the logo (members can fly it on their table flag), kicks members and hands the
## guild over.

var _page: Dictionary
var _body: VBoxContainer
var _guild_id := 0
var _guild: Dictionary = {}
var _members: Array = []
var _ticket := 0


func _ready() -> void:
	_page = ProfileUi.page(self, "Guild", func() -> void: ui.show_screen("guilds"), 780)
	_body = _page["body"]
	get_viewport().size_changed.connect(_layout)


func open(args: Dictionary) -> void:
	_layout()
	_guild_id = int(args.get("id", _guild_id))
	AppTheme.pop_in(_page["card"])
	_load()


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _load() -> void:
	_ticket += 1
	var ticket := _ticket
	ProfileUi.clear(_body)
	_body.add_child(ProfileUi.note("Loading guild..."))
	var res := await Profile.guild(_guild_id)
	if ticket != _ticket or not is_inside_tree():
		return
	ProfileUi.clear(_body)
	if not res.ok:
		_body.add_child(ProfileUi.note(res.error if res.error != "" else "Couldn't load this guild."))
		return
	var guild: Variant = res.data.get("guild", res.data.get("data", res.data))
	_guild = guild if guild is Dictionary else {}
	var members: Variant = _guild.get("members", res.data.get("members", []))
	_members = members if members is Array else []
	_render()


func _render() -> void:
	ProfileUi.clear(_body)
	var mine := Profile.my_guild()
	var is_member := not mine.is_empty() and int(mine.get("id", -1)) == _guild_id
	var my_id := int(Profile.data.get("id", ApiManager.user.get("id", -1)))
	var master: Dictionary = _guild.get("master", {}) if _guild.get("master") is Dictionary else {}
	var is_master := is_member and (str(mine.get("role", "")) == "master" or int(master.get("id", -2)) == my_id)

	var top := AppTheme.hbox(18)
	var logo_column := AppTheme.vbox(8)
	var logo := ProfileUi.guild_logo(_guild, 120)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_column.add_child(logo)
	if is_master:
		logo_column.add_child(ProfileUi.small_button("Change logo", "Secondary", _pick_logo.bind(logo), 40))
	top.add_child(logo_column)
	var words := AppTheme.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := AppTheme.hbox(10)
	var title := ProfileUi.heading(str(_guild.get("name", "?")), 34)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var tag := AppTheme.pill("[%s]" % str(_guild.get("tag", "?")), AppTheme.MINT, Color.WHITE, 20)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(tag)
	words.add_child(title_row)
	words.add_child(AppTheme.label("Led by %s" % str(master.get("username", "?")), "MutedLabel", 17))
	var stats := AppTheme.hbox(10)
	for spec: Array in [[AppTheme.num(_guild.get("members_count", _members.size())), "Members"],
			[ProfileUi.grouped(_guild.get("xp_total", 0)), "Total XP"], [ProfileUi.grouped(_guild.get("wins_total", 0)), "Wins"]]:
		stats.add_child(ProfileUi.stat_tile(spec[0], spec[1]))
	words.add_child(stats)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	if is_member:
		actions.add_child(ProfileUi.small_button("Leave guild", "Danger", _confirm_leave.bind(is_master), 42))
	elif mine.is_empty() and ApiManager.is_logged_in():
		actions.add_child(ProfileUi.small_button("Join guild", "Success", _join, 42))
	elif not ApiManager.is_logged_in():
		actions.add_child(ProfileUi.small_button("Log in to join", "Ghost", func() -> void: ui.show_screen("auth", {"next": "guilds"}), 42))
	else:
		actions.add_child(AppTheme.label("Leave your guild first to join this one.", "MutedLabel", 15))
	words.add_child(actions)
	top.add_child(words)
	_body.add_child(top)
	if is_member:
		_body.add_child(ProfileUi.wrap("Tip: fly the guild logo on your table flag - Shop, Toppers, then pick \"Guild logo\".", 15, AppTheme.MUTED))

	_body.add_child(ProfileUi.eyebrow("Members"))
	if _members.is_empty():
		_body.add_child(ProfileUi.note("No members listed."))
	var sorted := _members.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_master := a is Dictionary and str(a.get("role", "")) == "master"
		var b_master := b is Dictionary and str(b.get("role", "")) == "master"
		if a_master != b_master:
			return a_master
		return int(a.get("xp", 0)) > int(b.get("xp", 0)) if a is Dictionary and b is Dictionary else false)
	for member: Variant in sorted:
		if not member is Dictionary:
			continue
		var member_id := int(member.get("id", member.get("user_id", 0)))
		var role := str(member.get("role", "member"))
		var extra: Control = null
		if is_master and member_id != my_id:
			var tools := AppTheme.hbox(6)
			tools.add_child(ProfileUi.small_button("Make master", "Accent", _confirm_transfer.bind(member), 36))
			tools.add_child(ProfileUi.small_button("Kick", "Danger", _confirm_kick.bind(member), 36))
			extra = tools
		else:
			extra = AppTheme.pill(role.to_upper(), AppTheme.GOLD if role == "master" else Color(AppTheme.INK, 0.12),
				AppTheme.INK, 13)
		var sub := "%s - %s XP" % [str(member.get("rank_name", PlayerRanks.name_of(member.get("rank_tier", 0)))),
			ProfileUi.grouped(member.get("xp", 0))]
		_body.add_child(ProfileUi.player_row(member, -1, sub, [], member_id == my_id, extra))


func _join() -> void:
	var res := await Profile.join_guild(_guild_id)
	ui.toast("Welcome to the guild!" if res.ok else res.error, AppTheme.MINT if res.ok else AppTheme.RED)
	if res.ok and visible:
		_load()


func _confirm_leave(is_master: bool) -> void:
	var message := "Leave %s?" % str(_guild.get("name", "this guild"))
	if is_master and _members.size() > 1:
		message += " As master, hand the guild to another member first."
	ui.confirm(message, "Leave", func() -> void:
		var res := await Profile.leave_guild()
		ui.toast("You left the guild." if res.ok else res.error, AppTheme.INK if res.ok else AppTheme.RED)
		if res.ok and visible:
			ui.show_screen("guilds"))


func _confirm_kick(member: Dictionary) -> void:
	ui.confirm("Kick %s from the guild?" % str(member.get("username", "?")), "Kick", func() -> void:
		var res := await Profile.kick_member(_guild_id, int(member.get("id", member.get("user_id", 0))))
		ui.toast("%s was kicked." % str(member.get("username", "?")) if res.ok else res.error, AppTheme.INK if res.ok else AppTheme.RED)
		if res.ok and visible:
			_load())


func _confirm_transfer(member: Dictionary) -> void:
	ui.confirm("Make %s the guild master? You'll become a regular member." % str(member.get("username", "?")),
		"Hand over", _transfer.bind(member), false)


func _transfer(member: Dictionary) -> void:
	var res := await Profile.transfer_guild(_guild_id, int(member.get("id", member.get("user_id", 0))))
	ui.toast("%s now leads the guild." % str(member.get("username", "?")) if res.ok else res.error, AppTheme.INK if res.ok else AppTheme.RED)
	if res.ok and visible:
		_load()


func _pick_logo(logo: AvatarView) -> void:
	FilePicker.pick_image(self, _on_logo_picked.bind(logo), 512)


func _on_logo_picked(image: Image, logo: Variant) -> void:
	if image == null:
		return
	if is_instance_valid(logo):
		(logo as AvatarView).set_texture(ImageTexture.create_from_image(image))
	ui.toast("Uploading logo...")
	var res := await Profile.upload_guild_logo(_guild_id, image)
	ui.toast("New banner raised!" if res.ok else res.error, AppTheme.MINT if res.ok else AppTheme.RED)
	if visible:
		_load()
