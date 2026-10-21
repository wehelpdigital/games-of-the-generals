class_name GameLogo
extends Control
## The animated "Salpakan Tactics!" logo. The shield pops in, the star spins into place, the
## wordmark squashes down and the ribbon swings in. After that a shine sweeps across the wordmark,
## the star twinkles, sparkles blink and the whole logo floats gently. The pieces are PNG layers
## rendered from the vector logo (tools/brand), drawn with mipmaps so they stay crisp at any size.
## The same logo, animated in CSS, is on the web loader (web/shell.src.html).
##
##     var logo := GameLogo.new(220)   # Height in pixels; the width follows the logo's 1000:740.

const VIEW := Vector2(1000, 740)  # Logo space; matches assets/brand/src/layout.json.
const LAYERS := {
	"shield": Rect2(312, 10, 376, 392),
	"star": Rect2(385, 76, 230, 229),
	"wordmark": Rect2(25, 340, 946, 211),
	"ribbon": Rect2(116, 453, 768, 296),
}
const TEXTURES := {
	"shield": preload("res://assets/brand/layers/shield.png"),
	"star": preload("res://assets/brand/layers/star.png"),
	"wordmark": preload("res://assets/brand/layers/wordmark.png"),
	"ribbon": preload("res://assets/brand/layers/ribbon.png"),
}
const SPARKLE_TEXTURE := preload("res://assets/brand/layers/sparkle.png")
const SPARKLE_BOX := 80.0 / 32.0  # sparkle.png spans 80 units for a sparkle of radius 32.
const STAR_CENTER := Vector2(500, 196)
const SPARKLES := [  # [centre, radius, colour, delay]
	[Vector2(286, 92), 36.0, Color("27c98f"), 0.2],
	[Vector2(718, 132), 30.0, Color("ffcf3f"), 0.9],
	[Vector2(690, 42), 20.0, Color("fff8ec"), 1.5],
	[Vector2(270, 238), 21.0, Color("ff4f8b"), 2.1],
	[Vector2(918, 292), 25.0, Color("fff8ec"), 1.2],
	[Vector2(74, 300), 23.0, Color("ffcf3f"), 0.6],
]
const SHINE_SHADER := """
shader_type canvas_item;
// A slanted highlight band sweeping across the bright (yellow) parts of the wordmark.
uniform float progress = -1.0;
uniform float skew = 0.09;
void fragment() {
	vec4 c = COLOR;
	float x = UV.x + (1.0 - UV.y) * skew;
	float band = 1.0 - smoothstep(0.0, 0.06, abs(x - progress));
	band += 0.8 * (1.0 - smoothstep(0.0, 0.012, abs(x - progress - 0.075)));
	float bright = smoothstep(0.42, 0.6, dot(c.rgb, vec3(0.299, 0.587, 0.114)));
	COLOR = vec4(mix(c.rgb, vec3(1.0), clamp(band, 0.0, 1.0) * 0.75 * bright), c.a);
}
"""

var animate := true

var _stage: Control  # Logo space, scaled to fit this control.
var _float: Control
var _parts: Dictionary = {}  # name -> TextureRect
var _sparkles: Array[TextureRect] = []
var _shine: ShaderMaterial
var _loops: Array[Tween] = []
var _intro: Tween


func _init(logo_height := 220.0, animated := true) -> void:
	animate = animated
	set_height(logo_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build()


func _ready() -> void:
	resized.connect(_fit)
	visibility_changed.connect(_on_visibility_changed)
	_fit()
	if animate:
		intro()


## Minimum height in pixels (the width follows the logo's shape).
func set_height(logo_height: float) -> void:
	custom_minimum_size = Vector2(roundf(logo_height * VIEW.x / VIEW.y), roundf(logo_height))


## Plays the entrance again, then the idle loops.
func intro() -> void:
	_stop_loops()
	if _intro:
		_intro.kill()
	var shield: TextureRect = _parts["shield"]
	var star: TextureRect = _parts["star"]
	var word: TextureRect = _parts["wordmark"]
	var ribbon: TextureRect = _parts["ribbon"]
	shield.scale = Vector2.ZERO
	shield.rotation = deg_to_rad(-14.0)
	star.scale = Vector2.ZERO
	star.rotation = -PI
	word.scale = Vector2(0.3, 0.1)
	word.modulate.a = 0.0
	ribbon.scale = Vector2(0.2, 0.2)
	ribbon.rotation = deg_to_rad(-28.0)
	ribbon.modulate.a = 0.0
	_float.position = Vector2.ZERO
	for sparkle in _sparkles:
		sparkle.scale = Vector2.ZERO
	_shine.set_shader_parameter("progress", -1.0)

	var t := create_tween().set_parallel()
	_intro = t
	t.tween_property(shield, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(shield, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "scale", Vector2.ONE, 0.75).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "rotation", 0.0, 0.75).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(word, "modulate:a", 1.0, 0.15).set_delay(0.5)
	t.tween_property(word, "scale", Vector2(1.06, 0.92), 0.32).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(word, "scale", Vector2.ONE, 0.22).set_delay(0.82).set_trans(Tween.TRANS_SINE)
	t.tween_property(ribbon, "modulate:a", 1.0, 0.2).set_delay(0.95)
	t.tween_property(ribbon, "scale", Vector2.ONE, 0.7).set_delay(0.95).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ribbon, "rotation", 0.0, 0.7).set_delay(0.95).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_start_loops)


func _build() -> void:
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = VIEW
	add_child(_stage)
	_float = Control.new()
	_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.size = VIEW
	_stage.add_child(_float)

	_shine = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHINE_SHADER
	_shine.shader = shader
	for part: String in ["shield", "star", "wordmark", "ribbon"]:
		var rect: Rect2 = LAYERS[part]
		var layer := _layer(TEXTURES[part], rect)
		match part:
			"shield":
				layer.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y * 0.7)
			"star":
				layer.pivot_offset = STAR_CENTER - rect.position
			"wordmark":
				layer.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y * 0.85)
				layer.material = _shine
			_:
				layer.pivot_offset = rect.size * 0.5
		_float.add_child(layer)
		_parts[part] = layer
	for spec: Array in SPARKLES:
		var box: float = spec[1] * SPARKLE_BOX
		var sparkle := _layer(SPARKLE_TEXTURE, Rect2(spec[0] - Vector2(box, box) * 0.5, Vector2(box, box)))
		sparkle.pivot_offset = Vector2(box, box) * 0.5
		sparkle.modulate = spec[2]
		sparkle.scale = Vector2.ZERO if animate else Vector2.ONE
		_float.add_child(sparkle)
		_sparkles.append(sparkle)


func _layer(texture: Texture2D, rect: Rect2) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.position = rect.position
	layer.size = rect.size
	return layer


func _fit() -> void:
	var s := minf(size.x / VIEW.x, size.y / VIEW.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((size - VIEW * s) * 0.5).round()


func _start_loops() -> void:
	_stop_loops()
	var bob := _loop()
	bob.tween_property(_float, "position:y", -12.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_float, "position:y", 0.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var star: TextureRect = _parts["star"]
	var twinkle := _loop()
	twinkle.tween_interval(1.6)
	twinkle.tween_property(star, "scale", Vector2(1.14, 1.14), 0.22).set_trans(Tween.TRANS_SINE)
	twinkle.parallel().tween_property(star, "rotation", deg_to_rad(10.0), 0.22).set_trans(Tween.TRANS_SINE)
	twinkle.tween_property(star, "scale", Vector2(0.96, 0.96), 0.22).set_trans(Tween.TRANS_SINE)
	twinkle.parallel().tween_property(star, "rotation", deg_to_rad(-4.0), 0.22).set_trans(Tween.TRANS_SINE)
	twinkle.tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	twinkle.parallel().tween_property(star, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	twinkle.tween_interval(1.0)

	var shine := _loop()
	shine.tween_interval(0.4)
	shine.tween_method(_set_shine, -0.25, 1.35, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shine.tween_interval(2.6)

	var ribbon: TextureRect = _parts["ribbon"]
	var sway := _loop()
	sway.tween_property(ribbon, "rotation", deg_to_rad(1.6), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(ribbon, "rotation", 0.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for i in _sparkles.size():
		var sparkle := _sparkles[i]
		var blink := _loop()
		# Twists in upright, holds, and twists out.
		blink.tween_property(sparkle, "rotation", -PI / 3.0, 0.0)
		blink.tween_interval(float(SPARKLES[i][3]))
		blink.tween_property(sparkle, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		blink.parallel().tween_property(sparkle, "rotation", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
		blink.tween_interval(0.5)
		blink.tween_property(sparkle, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		blink.parallel().tween_property(sparkle, "rotation", PI / 3.0, 0.6)
		blink.tween_interval(2.2 - float(SPARKLES[i][3]) * 0.5)
	_on_visibility_changed()


func _loop() -> Tween:
	var t := create_tween().set_loops()
	_loops.append(t)
	return t


func _stop_loops() -> void:
	for t in _loops:
		t.kill()
	_loops.clear()


func _set_shine(value: float) -> void:
	_shine.set_shader_parameter("progress", value)


## Idle loops pause while the logo is off screen (e.g. during a match).
func _on_visibility_changed() -> void:
	var showing := is_visible_in_tree()
	for t in _loops:
		if showing:
			t.play()
		else:
			t.pause()
