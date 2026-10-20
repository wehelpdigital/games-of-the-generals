extends Screen
## Log in or create an account. Afterwards it continues to `args.next` (default: title).

var _card: PanelContainer
var _mode := "login"
var _next := "title"
var _tabs: Array[Button] = []
var _username: LineEdit
var _email: LineEdit
var _password: LineEdit
var _confirm: LineEdit
var _error: Label
var _submit: Button


func _ready() -> void:
	_card = AppTheme.card()
	var box := AppTheme.vbox(12)
	_card.add_child(box)

	var tabs := AppTheme.hbox(8)
	for mode: String in ["login", "register"]:
		var tab := AppTheme.button("Log in" if mode == "login" else "Sign up", "Ghost", func() -> void: _set_mode(mode), 48)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.append(tab)
		tabs.add_child(tab)
	box.add_child(tabs)

	_username = AppTheme.field("Username or email")
	_email = AppTheme.field("Email")
	_password = AppTheme.field("Password (8+ characters)", true)
	_confirm = AppTheme.field("Confirm password", true)
	for f: LineEdit in [_username, _email, _password, _confirm]:
		f.text_submitted.connect(func(_t: String) -> void: _submit_form())
		box.add_child(f)

	_error = AppTheme.label("", "", 17, AppTheme.RED)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)
	_submit = AppTheme.button("Log in", "Primary", _submit_form, 60)
	box.add_child(_submit)
	box.add_child(AppTheme.button("Back", "Ghost", func() -> void: ui.show_screen("title"), 48))
	add_child(AppTheme.centered(_card, 440))
	_set_mode("login")


func open(args: Dictionary) -> void:
	_next = args.get("next", "title")
	_show_error("")
	_password.text = ""
	_confirm.text = ""
	AppTheme.pop_in(_card)


func _set_mode(mode: String) -> void:
	_mode = mode
	var register := mode == "register"
	_username.placeholder_text = "Username (3–20 letters, numbers, - or _)" if register else "Username or email"
	_email.visible = register
	_confirm.visible = register
	_submit.text = "Create account" if register else "Log in"
	_show_error("")
	for i in _tabs.size():
		_tabs[i].theme_type_variation = ("AccentButton" if (i == 0) == (mode == "login") else "GhostButton")


func _submit_form() -> void:
	if _submit.disabled:
		return
	var name_text := _username.text.strip_edges()
	if name_text == "" or _password.text == "":
		_show_error("Fill in your username and password.")
		return
	if _mode == "register" and _password.text != _confirm.text:
		_show_error("The passwords don't match.")
		return
	_submit.disabled = true
	_show_error("")
	var res: Dictionary
	if _mode == "register":
		res = await ApiManager.register(name_text, _email.text.strip_edges(), _password.text, _confirm.text)
	else:
		res = await ApiManager.login(name_text, _password.text)
	_submit.disabled = false
	if not res.ok:
		_show_error(res.error)
		return
	ui.toast("Welcome, %s!" % ApiManager.user.get("username", "General"), AppTheme.MINT)
	ui.show_screen(_next)


func _show_error(text: String) -> void:
	_error.text = text
	_error.visible = text != ""
