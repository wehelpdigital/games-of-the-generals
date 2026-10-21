class_name AvatarView
extends Control
## Round profile photo with an optional rank-coloured ring. Players without a photo get one of the
## cute cartoon avatars in assets/avatars, picked from their username so the same player looks the
## same on every screen and device (set_user). Other round pictures (guild logos via set_avatar)
## fall back to initials.
##
##     var avatar := AvatarView.new(48)
##     avatar.set_user({"username": "maria", "avatar_url": "https://...", "rank_tier": 3})

const FALLBACK_COLORS := [AppTheme.PINK, AppTheme.BLUE, AppTheme.PURPLE, AppTheme.MINT, AppTheme.BRONZE, AppTheme.GOLD]
## The cartoon avatars (assets/avatars/<name>.webp, drawn by tools/avatars/generate_avatars.js).
## Append new ones at the end only: a player's pick is their hash modulo this list.
const DEFAULTS := [
	"rookie_helmet", "officer_cap", "red_beret", "general_mustache", "ninja", "pirate",
	"samurai", "spy", "pilot", "knight", "medic", "engineer",
	"cat_trooper", "dog_scout", "bear_captain", "panda_ninja", "fox_pilot", "owl_general",
	"frog_ranger", "carabao", "tarsier", "eagle_ace", "penguin_sailor", "bunny_scout",
]
const DEFAULT_DIR := "res://assets/avatars/"

static var _defaults: Dictionary = {}  # name -> Texture2D

var display_name := ""
var ring_color := Color(0, 0, 0, 0)  # Transparent = no ring.

var _texture: Texture2D
var _cartoon: Texture2D  # Shown while there's no photo (players only).
var _url := ""


func _init(diameter := 48.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # Big pictures stay crisp when small.


## Takes any user-ish dictionary: {username, avatar_url?, rank_tier?}.
func set_user(user: Dictionary) -> void:
	ring_color = PlayerRanks.color_of(user["rank_tier"]) if user.get("rank_tier") != null else Color(0, 0, 0, 0)
	var url: Variant = user.get("avatar_url")
	set_avatar(str(url) if url != null else "", str(user.get("username", "")), default_for(user))


## `cartoon` shows while there's no photo (or while it downloads); without one, initials do.
func set_avatar(url: String, name_text: String, cartoon: Texture2D = null) -> void:
	display_name = name_text
	_url = url
	_cartoon = cartoon
	_texture = RemoteImage.cached(url) if url != "" else null
	queue_redraw()
	if url != "" and _texture == null:
		RemoteImage.fetch(url, _on_texture.bind(url))


## Shows a local picture right away (e.g. the photo just picked, before the upload finishes).
func set_texture(texture: Texture2D) -> void:
	_texture = texture
	queue_redraw()


func _on_texture(texture: Texture2D, url: String) -> void:
	if url == _url:
		_texture = texture
		queue_redraw()


## The cartoon avatar for a player without a photo: the same one for the same username
## everywhere (falls back to the id when a payload has no name). Null for an empty user.
static func default_for(user: Variant) -> Texture2D:
	var key := ""
	if user is Dictionary:
		key = str(user.get("username", "")).strip_edges().to_lower()
		if key == "":
			var id: Variant = user.get("id", user.get("user_id"))
			key = "#%s" % str(id) if id != null and str(id) != "" else ""
	elif user != null:
		key = str(user).strip_edges().to_lower()
	if key == "":
		return null
	var avatar_name: String = DEFAULTS[_stable_hash(key) % DEFAULTS.size()]
	if not _defaults.has(avatar_name):
		var path := DEFAULT_DIR + avatar_name + ".webp"
		_defaults[avatar_name] = load(path) if ResourceLoader.exists(path) else null
	return _defaults[avatar_name]


## FNV-1a over the UTF-8 bytes: the same on every platform and engine version, unlike hash().
static func _stable_hash(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h


func _draw() -> void:
	var diameter := minf(size.x, size.y)
	var center := size / 2.0
	var radius := diameter / 2.0
	var inner := radius
	if ring_color.a > 0.0:
		draw_circle(center, radius, ring_color)
		inner = radius - maxf(2.0, diameter * 0.07)
	var picture := _texture if _texture else _cartoon
	if picture:
		var tex_size := picture.get_size()
		var side := minf(tex_size.x, tex_size.y)
		var uv_origin := (tex_size - Vector2(side, side)) / 2.0 / tex_size
		var uv_scale := Vector2(side, side) / tex_size
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var unit := Vector2.from_angle(TAU * i / 48.0)
			points.append(center + unit * inner)
			uvs.append(uv_origin + (unit * 0.5 + Vector2(0.5, 0.5)) * uv_scale)
		draw_colored_polygon(points, Color.WHITE, uvs, picture)
		return
	draw_circle(center, inner, FALLBACK_COLORS[absi(display_name.hash()) % FALLBACK_COLORS.size()])
	var font := AppTheme.heading_font()
	var font_size := maxi(8, int(inner * 0.85))
	var text := _initials()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(font, Vector2(center.x - width / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _initials() -> String:
	var clean := display_name.strip_edges()
	if clean == "":
		return "?"
	var parts := clean.replace("_", " ").replace(".", " ").split(" ", false)
	if parts.size() >= 2:
		return (parts[0].left(1) + parts[1].left(1)).to_upper()
	return clean.left(2).to_upper()
