class_name FlagFactory
extends RefCounted
## Custom flags for table toppers. A flag design is a small dictionary (the loadout's
## `toppers.slots[i].flag`):
##   {shape, color, color2, pattern, emblem, image_media_id, use_guild_logo, local_image?}
## Designs are drawn as SVG (shape clip, pattern, emblem, ink border) and rasterised by ThorVG, so
## they stay crisp; an uploaded picture or a guild logo is composited into the shape. The cloth is a
## subdivided plane waved by a vertex shader and readable from both sides.

const INK := "#1d1736"
const VIEW_W := 168.0  ## SVG viewBox: the 160×100 flag plus a 4-unit margin for the border.
const VIEW_H := 108.0
const TEX_W := 336
const TEX_H := 216
const CLOTH_SIZE := Vector2(0.9, 0.58)

const DEFAULT_DESIGN := {
	"shape": "swallowtail", "color": "#e8344e", "color2": "#ffd23f", "pattern": "stripes_h",
	"emblem": "star", "image_media_id": null, "use_guild_logo": false,
}

## Paths in a 160×100 box (hoist at x = 0). `at`/`size`: where the emblem or logo goes.
const SHAPES := {
	"rectangle": {"name": "Classic", "path": "M0 0H160V100H0Z", "at": Vector2(72, 50), "size": 56.0},
	"swallowtail": {"name": "Swallowtail", "path": "M0 0H160L122 50L160 100H0Z", "at": Vector2(64, 50), "size": 54.0},
	"pennant": {"name": "Pennant", "path": "M0 0L160 50L0 100Z", "at": Vector2(42, 50), "size": 40.0},
	"guidon": {"name": "Guidon", "path": "M0 0H116Q160 0 160 50Q160 100 116 100H0Z", "at": Vector2(70, 50), "size": 56.0},
	"banner": {"name": "Dovetail", "path": "M0 0H160L138 25L160 50L138 75L160 100H0Z", "at": Vector2(68, 50), "size": 56.0},
	"burgee": {"name": "Burgee", "path": "M0 0L160 32L122 50L160 68L0 100Z", "at": Vector2(46, 50), "size": 42.0},
	"wave": {"name": "Wave", "path": "M0 0H146C164 20 130 34 148 50C166 66 132 80 150 100H0Z", "at": Vector2(70, 50), "size": 56.0},
}

const PATTERNS := {
	"solid": "Solid", "stripes_h": "Stripes", "stripes_v": "Bars", "diagonal": "Diagonal",
	"quartered": "Quarters", "cross": "Cross", "border": "Border", "sunburst": "Sunburst", "hoist": "Hoist",
}

## Emblems drawn in a 100×100 box. Glyph emblems come from assets/icons/flag_emblems.json
## (game-icons.net, CC BY 3.0) and are 512×512.
const EMBLEMS := {
	"none": {"name": "None"},
	"star": {"name": "Star", "svg": "<polygon points='50,4 61,37 96,37 68,58 79,92 50,71 21,92 32,58 4,37 39,37'/>"},
	"sun": {"name": "Sun", "svg": "<polygon points='50,2 56,26 72,8 68,32 90,22 76,42 98,50 76,58 90,78 68,68 72,92 56,74 50,98 44,74 28,92 32,68 10,78 24,58 2,50 24,42 10,22 32,32 28,8 44,26'/><circle cx='50' cy='50' r='17'/>"},
	"skull": {"name": "Skull", "svg": "<path d='M50 8C27 8 13 24 13 44C13 57 20 66 29 71V88H71V71C80 66 87 57 87 44C87 24 73 8 50 8Z'/><circle cx='35' cy='46' r='10' fill='#1d1736'/><circle cx='65' cy='46' r='10' fill='#1d1736'/><path d='M50 58L44 68H56Z' fill='#1d1736'/><path d='M40 88V78M50 88V78M60 88V78' fill='none'/>"},
	"crown": {"name": "Crown", "svg": "<path d='M10 76L16 26L34 48L50 16L66 48L84 26L90 76Z'/><rect x='10' y='76' width='80' height='14' rx='3'/>"},
	"heart": {"name": "Heart", "svg": "<path d='M50 90C20 66 6 50 12 32C18 14 42 12 50 30C58 12 82 14 88 32C94 50 80 66 50 90Z'/>"},
	"bolt": {"name": "Bolt", "svg": "<path d='M60 4L18 56H46L36 96L84 40H56Z'/>"},
	"eye": {"name": "Eye", "svg": "<path d='M4 50Q50 2 96 50Q50 98 4 50Z'/><circle cx='50' cy='50' r='19' fill='#1d1736'/><circle cx='57' cy='43' r='6'/>"},
	"anchor": {"name": "Anchor", "svg": "<circle cx='50' cy='16' r='10' fill='none' stroke-width='9'/><path d='M50 26V88M30 40H70M14 58Q18 88 50 88Q82 88 86 58' fill='none' stroke-width='10'/>"},
	"raven": {"name": "Raven", "glyph": "raven"},
	"dragon": {"name": "Dragon", "glyph": "dragon"},
	"helmet": {"name": "Helmet", "glyph": "helmet"},
	"hammer": {"name": "Hammer", "glyph": "hammer"},
	"fist": {"name": "Fist", "glyph": "fist"},
	"comet": {"name": "Comet", "glyph": "comet"},
	"ghost": {"name": "Ghost", "glyph": "ghost"},
	"moon": {"name": "Moon", "glyph": "moon"},
}

const PALETTE := [
	"#e8344e", "#ff7a3d", "#ffd23f", "#27c98f", "#1f7a55", "#3d8bff", "#1b3f8f", "#8b5cf6",
	"#ff4f8b", "#fff8ec", "#b9c2d6", "#6b3e22", "#1d1736", "#22f2ff", "#c8342d", "#e0a520",
]

static var _textures: Dictionary = {}
static var _glyphs: Dictionary = {}
static var _cloth_shader: Shader


## A complete design with every key valid (unknown values fall back to defaults).
static func normalize(design: Variant) -> Dictionary:
	var d := DEFAULT_DESIGN.duplicate()
	if design is Dictionary:
		for key: String in DEFAULT_DESIGN:
			if design.has(key):
				d[key] = design[key]
		if str(design.get("local_image", "")) != "":
			d["local_image"] = str(design["local_image"])  # A picture kept only on this device.
	if not SHAPES.has(str(d["shape"])):
		d["shape"] = DEFAULT_DESIGN["shape"]
	if not PATTERNS.has(str(d["pattern"])):
		d["pattern"] = DEFAULT_DESIGN["pattern"]
	if not EMBLEMS.has(str(d["emblem"])):
		d["emblem"] = "none"
	for key: String in ["color", "color2"]:
		if not Color.html_is_valid(str(d[key])):
			d[key] = DEFAULT_DESIGN[key]
		d[key] = "#" + Color.html(str(d[key])).to_html(false)
	d["use_guild_logo"] = bool(d["use_guild_logo"])
	var media: Variant = d["image_media_id"]
	d["image_media_id"] = int(media) if (media is int or media is float or (media is String and str(media).is_valid_int())) and int(media) > 0 else null
	return d


## A random design (practice opponents, Randomize).
static func random_design() -> Dictionary:
	var d := DEFAULT_DESIGN.duplicate()
	d["shape"] = SHAPES.keys().pick_random()
	d["pattern"] = PATTERNS.keys().pick_random()
	d["emblem"] = EMBLEMS.keys().pick_random()
	d["color"] = PALETTE.pick_random()
	d["color2"] = PALETTE.pick_random()
	while d["color2"] == d["color"]:
		d["color2"] = PALETTE.pick_random()
	return d


## The flag as a texture. `picture` (optional) is an uploaded photo that fills the cloth
## (mode "photo") or a guild logo placed like an emblem (mode "logo"). `mirror` flips the picture
## and emblem (not the shape) for cloths flying to the left, whose texture is seen reversed.
static func texture(design: Dictionary, picture: Image = null, mode := "photo", scale := 1.0, picture_key := "", mirror := false) -> Texture2D:
	var d := normalize(design)
	if picture != null and picture_key == "":
		picture_key = str(picture.get_instance_id())
	var key := "%s|%s|%s|%s|%s" % [JSON.stringify(d), picture_key if picture else "", mode, scale, mirror]
	if _textures.has(key):
		return _textures[key]
	if _textures.size() > 48:
		_textures.clear()
	var image := _render(d, picture, mode, scale, mirror)
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex


## Waving cloth material for a flag texture. `pole_at_end`: the pole is on the +X end of the cloth.
static func cloth_material(tex: Texture2D, pole_at_end := false) -> ShaderMaterial:
	if _cloth_shader == null:
		_cloth_shader = Shader.new()
		_cloth_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float pole_at_end = 0.0;
uniform float phase = 0.0;

void vertex() {
	float t = mix(UV.x, 1.0 - UV.x, pole_at_end);  // 0 at the pole, 1 at the fly end.
	float k = TIME * 3.2 + phase - t * 7.0 + UV.y * 1.2;
	VERTEX.z += sin(k) * 0.055 * t;
	VERTEX.y -= t * t * 0.035;
	float slope = cos(k) * 0.055 * t * 7.0;
	NORMAL = normalize(vec3(slope * (pole_at_end > 0.5 ? -1.0 : 1.0), 0.0, 1.0));
}

void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, pole_at_end), UV.y);  // The hoist is always at the pole.
	vec4 c = texture(cloth, uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _cloth_shader
	m.set_shader_parameter("cloth", tex)
	m.set_shader_parameter("pole_at_end", 1.0 if pole_at_end else 0.0)
	m.set_shader_parameter("phase", randf() * TAU)
	return m


static func cloth_mesh() -> PlaneMesh:
	var m := PlaneMesh.new()
	m.size = CLOTH_SIZE
	m.orientation = PlaneMesh.FACE_Z
	m.subdivide_width = 18
	m.subdivide_depth = 8
	return m


# --- Rendering ---------------------------------------------------------------------------------

static func _render(d: Dictionary, picture: Image, mode: String, scale: float, mirror: bool) -> Image:
	var shape: Dictionary = SHAPES[d["shape"]]
	if picture == null:
		return _svg_image(_svg(d, shape, true, true, true, mirror), scale)
	var w := int(TEX_W * scale)
	var h := int(TEX_H * scale)
	var mask := _svg_image(_svg_open() + "<path d='%s' fill='#ffffff'/></svg>" % shape["path"], scale)
	var result: Image
	if mode == "logo":
		result = _svg_image(_svg(d, shape, false, false, false, mirror), scale)
		var layer := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var logo := picture.duplicate() as Image
		logo.convert(Image.FORMAT_RGBA8)
		if mirror:
			logo.flip_x()
		var box := float(shape["size"]) * 1.15 * w / VIEW_W
		var fit := minf(box / logo.get_width(), box / logo.get_height())
		logo.resize(maxi(1, int(logo.get_width() * fit)), maxi(1, int(logo.get_height() * fit)), Image.INTERPOLATE_LANCZOS)
		var center: Vector2 = (shape["at"] + Vector2(4, 4)) * w / VIEW_W
		layer.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i(center) - logo.get_size() / 2)
		result.blend_rect_mask(layer, mask, Rect2i(0, 0, w, h), Vector2i.ZERO)
	else:
		result = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var photo := picture.duplicate() as Image
		photo.convert(Image.FORMAT_RGBA8)
		if mirror:
			photo.flip_x()
		# Cover-crop to the cloth's proportions.
		var aspect := float(w) / h
		var pw := photo.get_width()
		var ph := photo.get_height()
		var crop := Rect2i(0, 0, pw, ph)
		if float(pw) / ph > aspect:
			crop = Rect2i(int((pw - ph * aspect) / 2.0), 0, int(ph * aspect), ph)
		else:
			crop = Rect2i(0, int((ph - pw / aspect) / 2.0), pw, int(pw / aspect))
		photo = photo.get_region(crop)
		photo.resize(w, h, Image.INTERPOLATE_LANCZOS)
		result.blend_rect_mask(photo, mask, Rect2i(0, 0, w, h), Vector2i.ZERO)
	var border := _svg_image(_svg_open() + "<path d='%s' fill='none' stroke='%s' stroke-width='5' stroke-linejoin='round'/></svg>" % [shape["path"], INK], scale)
	result.blend_rect(border, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return result


static func _svg_open() -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='-4 -4 %d %d'>" % [TEX_W, TEX_H, VIEW_W, VIEW_H]


static func _svg(d: Dictionary, shape: Dictionary, with_pattern_accent: bool, with_emblem: bool, with_border: bool, mirror := false) -> String:
	var c1: String = d["color"]
	var c2: String = d["color2"]
	var svg := _svg_open()
	svg += "<defs><clipPath id='c'><path d='%s'/></clipPath></defs><g clip-path='url(#c)'>" % shape["path"]
	svg += _pattern(str(d["pattern"]) if with_pattern_accent else "solid", c1, c2)
	if with_emblem and d["emblem"] != "none":
		var fill := c2 if d["pattern"] == "solid" else "#ffffff"
		var emblem := _emblem(str(d["emblem"]), shape["at"], shape["size"], fill)
		if mirror:
			emblem = "<g transform='matrix(-1 0 0 1 %.2f 0)'>%s</g>" % [shape["at"].x * 2.0, emblem]
		svg += emblem
	svg += "</g>"
	if with_border:
		svg += "<path d='%s' fill='none' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % [shape["path"], INK]
	return svg + "</svg>"


static func _pattern(pattern: String, c1: String, c2: String) -> String:
	var bg := "<rect x='-2' y='-2' width='164' height='104' fill='%s'/>" % c1
	match pattern:
		"stripes_h":
			return bg + "<rect x='-2' y='20' width='164' height='20' fill='%s'/><rect x='-2' y='60' width='164' height='20' fill='%s'/>" % [c2, c2]
		"stripes_v":
			return bg + "<rect x='34' y='-2' width='30' height='104' fill='%s'/><rect x='98' y='-2' width='30' height='104' fill='%s'/>" % [c2, c2]
		"diagonal":
			return bg + "<polygon points='-2,102 162,-2 162,102' fill='%s'/>" % c2
		"quartered":
			return bg + "<rect x='-2' y='-2' width='82' height='52' fill='%s'/><rect x='80' y='50' width='82' height='52' fill='%s'/>" % [c2, c2]
		"cross":
			return bg + "<rect x='40' y='-2' width='22' height='104' fill='%s'/><rect x='-2' y='39' width='164' height='22' fill='%s'/>" % [c2, c2]
		"border":
			return "<rect x='-2' y='-2' width='164' height='104' fill='%s'/><rect x='12' y='12' width='136' height='76' fill='%s'/>" % [c2, c1]
		"sunburst":
			var rays := ""
			for i in 12:
				var a0 := TAU * i / 12.0
				var a1 := TAU * (i + 0.5) / 12.0
				rays += "<polygon points='60,50 %.1f,%.1f %.1f,%.1f'/>" % [60 + cos(a0) * 200, 50 + sin(a0) * 200, 60 + cos(a1) * 200, 50 + sin(a1) * 200]
			return bg + "<g fill='%s'>%s</g>" % [c2, rays]
		"hoist":
			return bg + "<rect x='-2' y='-2' width='46' height='104' fill='%s'/>" % c2
	return bg


static func _emblem(key: String, at: Vector2, size: float, fill: String) -> String:
	var info: Dictionary = EMBLEMS.get(key, {})
	var origin := at - Vector2(size, size) * 0.5
	if info.has("glyph"):
		var d := _glyph(str(info["glyph"]))
		if d == "":
			return ""
		var s := size / 512.0
		return "<g transform='translate(%.2f %.2f) scale(%.4f)'><path d='%s' fill='%s' stroke='%s' stroke-width='22' stroke-linejoin='round'/><path d='%s' fill='%s'/></g>" % [origin.x, origin.y, s, d, fill, INK, d, fill]
	if not info.has("svg"):
		return ""
	return "<g transform='translate(%.2f %.2f) scale(%.4f)' fill='%s' stroke='%s' stroke-width='5' stroke-linejoin='round'>%s</g>" % [origin.x, origin.y, size / 100.0, fill, INK, info["svg"]]


static func _glyph(key: String) -> String:
	if _glyphs.is_empty():
		var res: Variant = load("res://assets/icons/flag_emblems.json")
		_glyphs = res.data if res is JSON and res.data is Dictionary else {"_": ""}
	return str(_glyphs.get(key, ""))


static func _svg_image(svg: String, scale: float) -> Image:
	var w := int(TEX_W * scale)
	var h := int(TEX_H * scale)
	var image := Image.new()
	if image.load_svg_from_string(svg, scale) != OK:
		image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != w or image.get_height() != h:
		image.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return image
