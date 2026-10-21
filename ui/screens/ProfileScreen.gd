extends Screen
## The player's own profile: photo (upload or remove), rank and XP, hometown for the local
## leaderboards, stats, guild, and sharing.

var _page: Dictionary
var _body: VBoxContainer
var _avatar: AvatarView
var _busy := false


func _ready() -> void:
	_page = ProfileUi.page(self, "Your Profile", func() -> void: ui.home(), 780)
	_body = _page["body"]
	get_viewport().size_changed.connect(_layout)
	Profile.changed.connect(func() -> void:
		if visible and not _busy:
			_render())


func open(_args: Dictionary) -> void:
	_layout()
	_render()
	AppTheme.pop_in(_page["card"])
	Profile.refresh(3.0)


func _layout() -> void:
	ProfileUi.fit_page(_page, get_viewport().get_visible_rect().size)


func _render() -> void:
	ProfileUi.clear(_body)
	if not ApiManager.is_logged_in():
		_body.add_child(ProfileUi.note("Log in to see your profile."))
		_body.add_child(AppTheme.button("Log in", "Primary", func() -> void: ui.show_screen("auth", {"next": "profile"}), 54))
		return
	var data := Profile.data

	# Who you are.
	var top := ProfileUi.flex(18)
	var photo := AppTheme.vbox(8)
	_avatar = AvatarView.new(128)
	_avatar.set_user(data)
	_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	photo.add_child(_avatar)
	var change := ProfileUi.small_button("Change photo", "Secondary", _pick_photo, 42)
	photo.add_child(change)
	if Profile.avatar_url() != "":
		photo.add_child(ProfileUi.small_button("Remove", "Ghost", _remove_photo, 38))
	top.add_child(photo)

	var who := AppTheme.vbox(8)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := ProfileUi.heading(str(data.get("username", "Player")), 36)
	name_label.clip_text = true
	who.add_child(name_label)
	var rank_row := AppTheme.hbox(8)
	rank_row.add_child(RankInsignia.new(Profile.tier(), 34))
	var rank_label := AppTheme.label(str(data.get("rank_name", PlayerRanks.name_of(Profile.tier()))), "", 22)
	rank_label.add_theme_font_override("font", AppTheme.heading_font())
	rank_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(rank_label)
	who.add_child(rank_row)
	var progress := Profile.xp_progress()
	var bar := XpBar.new(28)
	who.add_child(bar)
	if progress["maxed"]:
		bar.set_progress(1, 1, "%s XP - MAX RANK" % ProfileUi.grouped(progress["xp"]))
	else:
		bar.set_progress(float(progress["xp"]) - float(progress["from"]), float(progress["to"]) - float(progress["from"]),
			"%s / %s XP" % [ProfileUi.grouped(progress["xp"]), ProfileUi.grouped(progress["to"])])
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	buttons.add_child(ProfileUi.small_button("Rank ladder", "Accent", func() -> void: ui.show_screen("ranks"), 42))
	if ui.has_screen("achievements"):
		buttons.add_child(ProfileUi.small_button("Achievements & titles", "Secondary", func() -> void: ui.show_screen("achievements"), 42))
	buttons.add_child(ProfileUi.small_button("Share & earn XP", "Primary", func() -> void: ShareSheet.open(ui), 42))
	who.add_child(buttons)
	top.add_child(who)
	_body.add_child(top)

	_body.add_child(_hometown_card())

	# Stats.
	_body.add_child(ProfileUi.eyebrow("Battle record"))
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 10)
	var wins := Profile.stat("wins")
	var losses := Profile.stat("losses")
	var played := maxi(Profile.stat("games_played"), wins + losses)
	var rate := "%d%%" % roundi(100.0 * wins / played) if played > 0 else "-"
	for spec: Array in [[ProfileUi.grouped(wins), "Wins", AppTheme.MINT], [ProfileUi.grouped(losses), "Losses", AppTheme.RED],
			[rate, "Win rate", AppTheme.BLUE], [ProfileUi.grouped(played), "Games", AppTheme.INK],
			[ProfileUi.grouped(Profile.stat("ranked_wins")), "Ranked wins", AppTheme.PURPLE],
			[ProfileUi.grouped(Profile.credits()), "Credits", AppTheme.BRONZE]]:
		stats.add_child(ProfileUi.stat_tile(spec[0], spec[1], spec[2]))
	_body.add_child(stats)

	_body.add_child(_guild_card())


func _hometown_card() -> PanelContainer:
	var card := AppTheme.card("Row")
	var row := AppTheme.hbox(12)
	card.add_child(row)
	var pin := TileIcon.new("pin", Vector2(40, 40))
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pin)
	var words := AppTheme.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(ProfileUi.eyebrow("Hometown"))
	var place := Profile.location_text(true)
	if place == "":
		words.add_child(ProfileUi.wrap("Not set yet. Set it to compete on your town and province leaderboards!", 17))
	else:
		var text := AppTheme.label(place, "", 20)
		text.add_theme_font_override("font", AppTheme.heading_font())
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(text)
	row.add_child(words)
	var action := ProfileUi.small_button("Set hometown" if place == "" else "Change", "Success" if place == "" else "Ghost",
		func() -> void: LocationPicker.open(ui, _render), 42)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	return card


func _guild_card() -> PanelContainer:
	var card := AppTheme.card("Row")
	var row := AppTheme.hbox(12)
	card.add_child(row)
	var guild := Profile.my_guild()
	if guild.is_empty():
		var shield := TileIcon.new("shield", Vector2(40, 40))
		shield.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(shield)
		var words := AppTheme.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(ProfileUi.eyebrow("Guild"))
		words.add_child(ProfileUi.wrap("Not in a guild yet. Team up, fly your guild's logo and climb the guild rankings.", 16))
		row.add_child(words)
		var browse := ProfileUi.small_button("Browse", "Success", func() -> void: ui.show_screen("guilds"), 42)
		browse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(browse)
		return card
	var logo := ProfileUi.guild_logo(guild, 52)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var words := AppTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(ProfileUi.eyebrow("Guild" + (" master" if str(guild.get("role", "")) == "master" else "")))
	var guild_name := AppTheme.label("%s [%s]" % [guild.get("name", "?"), guild.get("tag", "?")], "", 20)
	guild_name.add_theme_font_override("font", AppTheme.heading_font())
	guild_name.clip_text = true
	words.add_child(guild_name)
	row.add_child(words)
	var open_button := ProfileUi.small_button("Open", "Success", func() -> void: ui.show_screen("guild", {"id": int(guild.get("id", 0))}), 42)
	open_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(open_button)
	return card


func _pick_photo() -> void:
	FilePicker.pick_image(self, _on_photo_picked, 512)


func _on_photo_picked(image: Image) -> void:
	if image == null:
		return
	if _avatar and is_instance_valid(_avatar):
		_avatar.set_texture(ImageTexture.create_from_image(image))
	_busy = true
	ui.toast("Uploading photo...")
	var res := await Profile.upload_avatar(image)
	_busy = false
	if res.ok:
		ui.toast("Looking sharp! Photo updated.", AppTheme.MINT)
	else:
		ui.toast(res.error if res.error != "" else "Upload failed.", AppTheme.RED)
	if visible:
		_render()


func _remove_photo() -> void:
	ui.confirm("Remove your profile photo?", "Remove", func() -> void:
		var res := await Profile.remove_avatar()
		ui.toast("Photo removed." if res.ok else res.error, AppTheme.INK if res.ok else AppTheme.RED)
		if visible:
			_render())
