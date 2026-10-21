class_name ChipShapes
extends RefCounted
## Chip shapes: the geometry of a player's pieces (the chip skin still decides their colours and
## materials). Every shape keeps the same contract as the classic plaque:
## - the rank face (badge + label) sits on `face`, pointing at the owner or straight up;
## - the opponent only ever sees an identical neutral side (`back`, or the blank top of face-up
##   tokens with the same emblem), and enemy pieces are built without a rank anyway, so no shape
##   can leak a rank;
## - roles map surfaces to materials: "body"/"base" from the chip skin, "accent" in the skin's ink,
##   and a few shape-owned materials (the Wish Orb's crystal and stars, drum heads, lantern paper).
## Geometry is baked once per shape (ShapeKit) and shared by every piece.

const DEFAULT := "shape_classic"

const STYLES := {
	"shape_classic": {"name": "Classic Plaque", "rarity": "common", "desc": "The original toy plaque on a stand.",
		"swatch": [Color("fff0cf"), Color("3fa9ff"), Color("3d3760")]},
	"shape_wish_orb": {"name": "Wish Orbs", "rarity": "legendary", "desc": "Glowing amber crystal orbs with red stars floating inside. Gather your army and make a wish.",
		"swatch": [Color("ffd27a"), Color("ff9a1f"), Color("e8341c"), Color("fff3c4")]},
	"shape_coin": {"name": "Commander's Coin", "rarity": "rare", "desc": "Chunky challenge coins with a raised rim, rank stamped on top.",
		"swatch": [Color("ffd54a"), Color("e0a520"), Color("8a5a12")]},
	"shape_hex": {"name": "Hex Tokens", "rarity": "common", "desc": "Two-tone hexagon tokens, board-game style.",
		"swatch": [Color("7fd6ff"), Color("3d8bff"), Color("1d1736")]},
	"shape_shield": {"name": "Shield Crest", "rarity": "rare", "desc": "Heater shields standing proud on a plinth.",
		"swatch": [Color("e8344e"), Color("ffd23f"), Color("2a2350")]},
	"shape_gem": {"name": "Cut Gems", "rarity": "epic", "desc": "Faceted gems set in a crown mount. Shine on.",
		"swatch": [Color("b8f3ff"), Color("ff8ae0"), Color("8b5cf6"), Color("ffffff")]},
	"shape_dice": {"name": "Lucky Dice", "rarity": "common", "desc": "Rounded dice with the rank on top. Roll with it.",
		"swatch": [Color("ffffff"), Color("1d1736"), Color("ff5a5f")]},
	"shape_poker_chip": {"name": "High Roller Chips", "rarity": "rare", "desc": "A little stack of two casino-style chips with striped edges.",
		"swatch": [Color("e8344e"), Color("ffffff"), Color("1f7a55"), Color("1d1736")]},
	"shape_mahjong": {"name": "Tile Rack", "rarity": "rare", "desc": "Chunky two-tone tiles leaning on a rack, parlour style.",
		"swatch": [Color("fff4dc"), Color("27c98f"), Color("6b3e22")]},
	"shape_dog_tag": {"name": "Dog Tags", "rarity": "rare", "desc": "Stamped metal tags hanging from a bead chain.",
		"swatch": [Color("dde1e8"), Color("9aa3b5"), Color("4f5a74")]},
	"shape_tent_card": {"name": "Field Cards", "rarity": "common", "desc": "Folded A-frame cards, like a briefing on the map table.",
		"swatch": [Color("fff8ec"), Color("ffcf3f"), Color("6e678c")]},
	"shape_bottle_cap": {"name": "Bottle Caps", "rarity": "common", "desc": "Crimped caps you'd flick across a table.",
		"swatch": [Color("ff5a5f"), Color("ffffff"), Color("b9c2d6")]},
	"shape_drum": {"name": "War Drums", "rarity": "epic", "desc": "Little marching drums with laced cords. Boom.",
		"swatch": [Color("c8342d"), Color("fff6e0"), Color("ffd23f"), Color("6b3e22")]},
	"shape_lantern": {"name": "Paper Lanterns", "rarity": "epic", "desc": "Festival lanterns that glow softly and sway in the breeze.",
		"swatch": [Color("ff7a3d"), Color("ffd27a"), Color("c8342d"), Color("1d1736")]},
	"shape_mochi": {"name": "Jelly Mochi", "rarity": "epic", "desc": "Squishy, wobbly mochi blobs that never stop jiggling.",
		"swatch": [Color("ffd1ea"), Color("c9f5e8"), Color("fff4fa"), Color("78c46b")]},
	"shape_pumpkin": {"name": "Pumpkins", "rarity": "epic", "season": "halloween", "desc": "Plump, ribbed pumpkins with a curly stem. The skin picks the colour.",
		"swatch": [Color("ff8a1f"), Color("e0701a"), Color("4a6b2a")]},
	"shape_ornament": {"name": "Ornament Baubles", "rarity": "epic", "season": "christmas", "desc": "Shiny Christmas baubles with a little cap and hook.",
		"swatch": [Color("d62f3a"), Color("ffcf3f"), Color("2f8f4e")]},
	"shape_gingerbread": {"name": "Gingerbread Folks", "rarity": "rare", "season": "christmas", "desc": "Little cookie people with iced cuffs, standing to attention.",
		"swatch": [Color("c8803f"), Color("ffffff"), Color("e63946")]},
}

const ORB_AMBER := Color("ff8a1c")
const ORB_CORE := Color("ffd65a")
const ORB_STAR := Color("e8141c")

static var _geometry: Dictionary = {}  # slug -> baked geometry
static var _materials: Dictionary = {}


static func exists(slug: String) -> bool:
	return STYLES.has(slug)


static func slug_or_default(slug: String) -> String:
	return slug if STYLES.has(slug) else DEFAULT


## Baked, shared geometry for a shape: {mesh, roles, hull, face: Transform3D, back: Transform3D or
## null (face-up tokens show the neutral emblem on the face while the rank is unknown),
## emblem: bool, pick: [size, centre], idle: "" | "wobble" | "sway"}.
static func geometry(slug: String) -> Dictionary:
	slug = slug_or_default(slug)
	if _geometry.has(slug):
		return _geometry[slug]
	var spec: Dictionary = _spec(slug)
	var baked := ShapeKit.bake(spec["parts"])
	baked["face"] = spec["face"]
	baked["back"] = spec.get("back")
	baked["emblem"] = spec.get("emblem", true)
	baked["pick"] = spec.get("pick", [Vector3(0.84, 0.7, 0.84), Vector3(0, 0.35, 0)])
	baked["idle"] = spec.get("idle", "")
	_geometry[slug] = baked
	return baked


## Material for one surface role of a piece wearing `skin` on `side`.
static func material(role: String, skin: String, side: String) -> Material:
	match role:
		"body", "base":
			return CosmeticLibrary.piece_material(skin, side, role)
		"accent":
			return CosmeticLibrary.piece_material(skin, side, "insignia")
		"paper":
			return _paper_material(skin, side)
		"orb":
			return _orb_material()
		"orb_star":
			return _solid("orb_star", ORB_STAR, 0.6, ORB_STAR, 1.1)
		"head":
			return _solid("head", Color("fff6e0"), 0.2)
		"leaf":
			return _solid("leaf", Color("5fbf5a"), 0.4)
		"gem":
			return _gem_material(skin, side)
	return CosmeticLibrary.piece_material(skin, side, "body")


# --- Shapes ------------------------------------------------------------------------------------

static func _spec(slug: String) -> Dictionary:
	match slug:
		"shape_wish_orb":
			return _wish_orb()
		"shape_coin":
			return _coin()
		"shape_hex":
			return _hex()
		"shape_shield":
			return _shield()
		"shape_gem":
			return _gem()
		"shape_dice":
			return _dice()
		"shape_poker_chip":
			return _poker_chip()
		"shape_mahjong":
			return _mahjong()
		"shape_dog_tag":
			return _dog_tag()
		"shape_tent_card":
			return _tent_card()
		"shape_bottle_cap":
			return _bottle_cap()
		"shape_drum":
			return _drum()
		"shape_lantern":
			return _lantern()
		"shape_mochi":
			return _mochi()
		"shape_pumpkin":
			return _pumpkin()
		"shape_ornament":
			return _ornament()
		"shape_gingerbread":
			return _gingerbread()
	return _classic()


## A face lying flat on top at `height`, its "up" pointing away from the owner.
static func _face_up(height: float, scale: float) -> Transform3D:
	return Transform3D(ShapeKit.FLAT.scaled(Vector3.ONE * scale), Vector3(0, height, 0))


## A face leaning back by `tilt` radians at `pos`.
static func _face_tilted(pos: Vector3, tilt: float, scale: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, tilt).scaled(Vector3.ONE * scale), pos)


## The neutral back emblem: same placement rules as the classic plaque.
static func _back(xf: Transform3D, scale := 0.34) -> Transform3D:
	return xf * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale), Vector3.ZERO)


static func _classic() -> Dictionary:
	var pivot := Transform3D(Basis(Vector3.RIGHT, -0.52), Vector3(0, 0.06, 0))
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.box(Vector3(0.74, 0.62, 0.16), 0.14, 0.05), pivot * ShapeKit.at(Vector3(0, 0.31, 0))),
			ShapeKit.part("base", ShapeKit.box(Vector3(0.86, 0.48, 0.1), 0.13, 0.035), ShapeKit.at(Vector3(0, 0.05, 0), ShapeKit.FLAT)),
		],
		"face": pivot * ShapeKit.at(Vector3(0, 0.31, 0.08)),
		"back": _back(pivot * ShapeKit.at(Vector3(0, 0.3224, -0.08))),
		"pick": [Vector3(0.88, 0.82, 0.54), Vector3(0, 0.41, 0)],
	}


static func _wish_orb() -> Dictionary:
	var center := Vector3(0, 0.4, 0)
	# The player's camera looks down at ~58°: the badge sits where the orb faces it, and five stars
	# float in a ring around it, so they show on every orb (the enemy sees the same ring).
	var toward_camera := Basis(Vector3.RIGHT, -1.0)
	var screen_up := toward_camera * Vector3.UP
	var parts := [
		ShapeKit.part("base", ShapeKit.cylinder(0.24, 0.29, 0.07, 32), ShapeKit.at(Vector3(0, 0.035, 0))),
		ShapeKit.part("base", ShapeKit.torus(0.15, 0.25, 32, 10), ShapeKit.at(Vector3(0, 0.085, 0)), 0.02),
		ShapeKit.part("orb", ShapeKit.sphere(0.33, -1.0, 40), ShapeKit.at(center), 0.0),
	]
	var star := ShapeKit.prism(InsigniaFactory.star_polygon(5, 0.5, 0.22), 0.3, 0.06)
	for i in 5:
		var a := PI / 2.0 + TAU * i / 5.0
		var offset := Vector3.RIGHT * cos(a) * 0.2 + screen_up * sin(a) * 0.2
		var xf := Transform3D((toward_camera * Basis(Vector3.BACK, a)).scaled(Vector3.ONE * 0.12), center + offset)
		parts.append(ShapeKit.part("orb_star", star, xf, 0.0))
	return {
		"parts": parts,
		"face": Transform3D(toward_camera.scaled(Vector3.ONE * 0.46), center + toward_camera * Vector3.BACK * 0.335),
		"back": null,
		"emblem": false,  # The star ring is the orb's neutral side.
		"pick": [Vector3(0.74, 0.8, 0.74), Vector3(0, 0.4, 0)],
	}


static func _coin() -> Dictionary:
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.cylinder(0.385, 0.385, 0.11, 40), ShapeKit.at(Vector3(0, 0.055, 0))),
			ShapeKit.part("base", ShapeKit.torus(0.335, 0.405, 40, 10), ShapeKit.at(Vector3(0, 0.112, 0)), 0.02),
		],
		"face": _face_up(0.114, 0.9),
		"back": null,
		"pick": [Vector3(0.84, 0.36, 0.84), Vector3(0, 0.18, 0)],
	}


static func _hex() -> Dictionary:
	var lower := InsigniaFactory.regular_polygon(6, 0.43, PI / 6.0)
	var upper := InsigniaFactory.regular_polygon(6, 0.37, PI / 6.0)
	return {
		"parts": [
			ShapeKit.part("base", ShapeKit.prism(lower, 0.08, 0.02), ShapeKit.at(Vector3(0, 0.04, 0), ShapeKit.FLAT)),
			ShapeKit.part("body", ShapeKit.prism(upper, 0.08, 0.025), ShapeKit.at(Vector3(0, 0.115, 0), ShapeKit.FLAT)),
		],
		"face": _face_up(0.156, 0.84),
		"back": null,
		"pick": [Vector3(0.84, 0.4, 0.84), Vector3(0, 0.2, 0)],
	}


static func _shield() -> Dictionary:
	var raw := PackedVector2Array([Vector2(-0.31, 0.36), Vector2(0.31, 0.36), Vector2(0.31, 0.04)])
	for i in range(1, 13):
		var t := i / 12.0
		raw.append(_bezier(Vector2(0.31, 0.04), Vector2(0.3, -0.24), Vector2(0.0, -0.38), t))
	for i in range(1, 13):
		var t := i / 12.0
		raw.append(_bezier(Vector2(0.0, -0.38), Vector2(-0.3, -0.24), Vector2(-0.31, 0.04), t))
	var outline := InsigniaFactory.offset(InsigniaFactory.offset(raw, -0.05), 0.05)
	var pivot := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.07, 0.02))
	var center := pivot * ShapeKit.at(Vector3(0, 0.39, 0))
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.prism(outline, 0.13, 0.035, true), center),
			ShapeKit.part("base", ShapeKit.box(Vector3(0.66, 0.42, 0.1), 0.12, 0.035), ShapeKit.at(Vector3(0, 0.05, 0), ShapeKit.FLAT)),
		],
		"face": center * Transform3D(Basis().scaled(Vector3.ONE * 0.86), Vector3(0, 0.04, 0.065)),
		"back": _back(center * ShapeKit.at(Vector3(0, 0.05, -0.065))),
		"pick": [Vector3(0.8, 0.86, 0.56), Vector3(0, 0.43, 0)],
	}


static func _gem() -> Dictionary:
	return {
		"parts": [
			ShapeKit.part("base", ShapeKit.frustum(8, 0.2, 0.34, 0.1, PI / 8.0), ShapeKit.at(Vector3(0, 0.05, 0))),
			ShapeKit.part("gem", ShapeKit.frustum(8, 0.38, 0.38, 0.035, 0.0), ShapeKit.at(Vector3(0, 0.1175, 0))),
			ShapeKit.part("gem", ShapeKit.frustum(8, 0.38, 0.29, 0.1, 0.0), ShapeKit.at(Vector3(0, 0.185, 0))),
			ShapeKit.part("gem", ShapeKit.frustum(8, 0.3, 0.2, 0.09, PI / 8.0), ShapeKit.at(Vector3(0, 0.28, 0))),
		],
		"face": _face_up(0.327, 0.56),
		"back": null,
		"pick": [Vector3(0.84, 0.46, 0.84), Vector3(0, 0.23, 0)],
	}


static func _dice() -> Dictionary:
	const SIZE := 0.58
	var half := SIZE * 0.5
	var parts := [ShapeKit.part("body", ShapeKit.box(Vector3(SIZE, SIZE, SIZE), 0.13, 0.08), ShapeKit.at(Vector3(0, half, 0)))]
	# Pips on the four sides (the top carries the rank), the same on every die.
	var pip := ShapeKit.cylinder(0.05, 0.05, 0.02, 14)
	var sides := [
		[Vector3.BACK, [Vector2(-0.13, 0.13), Vector2(0, 0), Vector2(0.13, -0.13)]],
		[Vector3.FORWARD, [Vector2(-0.13, 0.13), Vector2(0.13, 0.13), Vector2(-0.13, -0.13), Vector2(0.13, -0.13)]],
		[Vector3.RIGHT, [Vector2(-0.12, 0.12), Vector2(0.12, -0.12)]],
		[Vector3.LEFT, [Vector2(-0.13, 0.13), Vector2(0.13, 0.13), Vector2(0, 0), Vector2(-0.13, -0.13), Vector2(0.13, -0.13)]],
	]
	for side: Array in sides:
		var normal: Vector3 = side[0]
		var right := Vector3.UP.cross(normal).normalized()
		var basis := Basis(right, normal, right.cross(normal))  # Cylinder axis (Y) along the normal.
		for spot: Vector2 in side[1]:
			var pos := Vector3(0, half, 0) + normal * (half - 0.004) + right * spot.x + Vector3.UP * spot.y
			parts.append(ShapeKit.part("accent", pip, Transform3D(basis, pos), 0.0))
	return {
		"parts": parts,
		"face": _face_up(SIZE + 0.002, 0.74),
		"back": null,
		"pick": [Vector3(0.7, 0.66, 0.7), Vector3(0, 0.33, 0)],
	}


static func _poker_chip() -> Dictionary:
	var parts := [
		ShapeKit.part("base", ShapeKit.cylinder(0.375, 0.375, 0.075, 40), ShapeKit.at(Vector3(0, 0.0375, 0))),
		ShapeKit.part("body", ShapeKit.cylinder(0.375, 0.375, 0.075, 40), ShapeKit.at(Vector3(0.025, 0.115, -0.02))),
		ShapeKit.part("base", ShapeKit.torus(0.262, 0.292, 40, 6), ShapeKit.at(Vector3(0.025, 0.153, -0.02)), 0.0),
	]
	# Edge spots: base colour on the top chip, body colour on the bottom one.
	var spot := ShapeKit.box(Vector3(0.1, 0.066, 0.03), 0.015, 0.008)
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		var basis := Basis(dir.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, dir)
		parts.append(ShapeKit.part("base", spot, Transform3D(basis, Vector3(0.025, 0.115, -0.02) + dir * 0.37), 0.0))
		var b := Basis(Vector3.UP, TAU / 16.0) * basis
		parts.append(ShapeKit.part("body", spot, Transform3D(b, Vector3(0, 0.0375, 0) + Basis(Vector3.UP, TAU / 16.0) * dir * 0.37), 0.0))
	return {
		"parts": parts,
		"face": Transform3D(ShapeKit.FLAT.scaled(Vector3.ONE * 0.8), Vector3(0.025, 0.155, -0.02)),
		"back": null,
		"pick": [Vector3(0.84, 0.4, 0.84), Vector3(0, 0.2, 0)],
	}


static func _mahjong() -> Dictionary:
	var pivot := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 0.11, 0.0))
	var tile := pivot * ShapeKit.at(Vector3(0, 0.31, 0))
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.box(Vector3(0.58, 0.62, 0.18), 0.09, 0.045), tile),
			ShapeKit.part("base", ShapeKit.box(Vector3(0.58, 0.62, 0.1), 0.09, 0.03), tile * ShapeKit.at(Vector3(0, 0, -0.14))),
			ShapeKit.part("accent", ShapeKit.box(Vector3(0.8, 0.13, 0.12), 0.05, 0.03), ShapeKit.at(Vector3(0, 0.065, 0.2))),
		],
		"face": tile * Transform3D(Basis().scaled(Vector3.ONE * 0.84), Vector3(0, 0.01, 0.09)),
		"back": _back(tile * ShapeKit.at(Vector3(0, 0.02, -0.19))),
		"pick": [Vector3(0.84, 0.8, 0.6), Vector3(0, 0.4, 0)],
	}


static func _dog_tag() -> Dictionary:
	var pivot := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.07, 0.02))
	var tag := pivot * ShapeKit.at(Vector3(0, 0.37, 0))
	var outline := InsigniaFactory.rounded_rect(Vector2(0.54, 0.68), 0.16, 6)
	var parts := [
		ShapeKit.part("body", ShapeKit.prism(outline, 0.06, 0.02, true), tag),
		ShapeKit.part("base", ShapeKit.torus(0.035, 0.065, 20, 8), tag * ShapeKit.at(Vector3(0, 0.25, 0), Basis(Vector3.RIGHT, PI / 2.0)), 0.015),
		ShapeKit.part("base", ShapeKit.box(Vector3(0.7, 0.4, 0.09), 0.12, 0.03), ShapeKit.at(Vector3(0, 0.045, 0), ShapeKit.FLAT)),
	]
	# A bead chain loops from the hole down behind the tag into the stand.
	var bead := ShapeKit.sphere(0.024, -1.0, 10)
	for i in 15:
		var t := i / 14.0
		var p := Vector3(lerpf(-0.04, -0.3, t) + 0.05 * sin(t * PI), 0.25 - t * 0.5, -0.06 - 0.06 * sin(t * PI))
		parts.append(ShapeKit.part("accent", bead, tag * ShapeKit.at(p), 0.0))
	return {
		"parts": parts,
		"face": tag * Transform3D(Basis().scaled(Vector3.ONE * 0.8), Vector3(0, -0.03, 0.032)),
		"back": _back(tag * ShapeKit.at(Vector3(0, -0.01, -0.032)), 0.3),
		"pick": [Vector3(0.84, 0.82, 0.56), Vector3(0, 0.41, 0)],
	}


static func _tent_card() -> Dictionary:
	const HEIGHT := 0.66
	const LEAN := 0.42
	var foot := sin(LEAN) * HEIGHT
	var front := Transform3D(Basis(Vector3.RIGHT, -LEAN), Vector3(0, 0, foot)) * ShapeKit.at(Vector3(0, HEIGHT * 0.5, 0))
	var back := Transform3D(Basis(Vector3.RIGHT, LEAN), Vector3(0, 0, -foot)) * ShapeKit.at(Vector3(0, HEIGHT * 0.5, 0))
	var ridge := Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, cos(LEAN) * HEIGHT, 0))
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.box(Vector3(0.76, HEIGHT, 0.035), 0.06, 0.012), front),
			ShapeKit.part("body", ShapeKit.box(Vector3(0.76, HEIGHT, 0.035), 0.06, 0.012), back),
			ShapeKit.part("base", ShapeKit.cylinder(0.035, 0.035, 0.8, 16), ridge, 0.02),
		],
		"face": front * Transform3D(Basis().scaled(Vector3.ONE * 0.9), Vector3(0, -0.02, 0.019)),
		"back": _back(back * ShapeKit.at(Vector3(0, 0.0, -0.019))),
		"pick": [Vector3(0.84, 0.66, 0.66), Vector3(0, 0.33, 0)],
	}


static func _bottle_cap() -> Dictionary:
	var crimp := InsigniaFactory.star_polygon(21, 0.39, 0.355)
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.prism(crimp, 0.13, 0.025), ShapeKit.at(Vector3(0, 0.065, 0), ShapeKit.FLAT)),
			ShapeKit.part("base", ShapeKit.cylinder(0.3, 0.3, 0.012, 36), ShapeKit.at(Vector3(0, 0.133, 0)), 0.0),
		],
		"face": _face_up(0.141, 0.8),
		"back": null,
		"pick": [Vector3(0.84, 0.4, 0.84), Vector3(0, 0.2, 0)],
	}


static func _drum() -> Dictionary:
	var shell := PackedVector2Array([Vector2(0.31, 0.03), Vector2(0.34, 0.2), Vector2(0.31, 0.37)])
	var parts := [
		ShapeKit.part("body", ShapeKit.lathe(shell, 28), Transform3D.IDENTITY),
		ShapeKit.part("base", ShapeKit.torus(0.29, 0.355, 32, 8), ShapeKit.at(Vector3(0, 0.035, 0)), 0.02),
		ShapeKit.part("base", ShapeKit.torus(0.29, 0.355, 32, 8), ShapeKit.at(Vector3(0, 0.37, 0)), 0.02),
		ShapeKit.part("head", ShapeKit.cylinder(0.3, 0.3, 0.012, 32), ShapeKit.at(Vector3(0, 0.375, 0)), 0.0),
	]
	# Laced cords zig-zag between the hoops.
	var cord := ShapeKit.cylinder(0.012, 0.012, 1.0, 6)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 0.5) / 10.0
		var p0 := Vector3(cos(a0) * 0.335, 0.06, sin(a0) * 0.335)
		var p1 := Vector3(cos(a1) * 0.345, 0.345, sin(a1) * 0.345)
		for pair: Array in [[p0, p1], [p1, Vector3(cos(a0 + TAU / 10.0) * 0.335, 0.06, sin(a0 + TAU / 10.0) * 0.335)]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var up := (b - a).normalized()
			var side := up.cross(Vector3((a + b).x, 0, (a + b).z).normalized()).normalized()
			var basis := Basis(side, up * (b - a).length(), side.cross(up))
			parts.append(ShapeKit.part("accent", cord, Transform3D(basis, (a + b) * 0.5 + Vector3((a + b).x, 0, (a + b).z).normalized() * 0.012), 0.0))
	return {
		"parts": parts,
		"face": _face_up(0.383, 0.76),
		"back": null,
		"pick": [Vector3(0.78, 0.44, 0.78), Vector3(0, 0.22, 0)],
	}


static func _lantern() -> Dictionary:
	var center := Vector3(0, 0.36, 0)
	var parts := [
		ShapeKit.part("paper", ShapeKit.sphere(0.32, 0.54, 28), ShapeKit.at(center)),
		ShapeKit.part("base", ShapeKit.cylinder(0.15, 0.17, 0.07, 20), ShapeKit.at(Vector3(0, 0.07, 0))),
		ShapeKit.part("base", ShapeKit.cylinder(0.12, 0.15, 0.06, 20), ShapeKit.at(Vector3(0, 0.64, 0))),
		ShapeKit.part("base", ShapeKit.torus(0.04, 0.07, 16, 6), ShapeKit.at(Vector3(0, 0.7, 0), Basis(Vector3.RIGHT, PI / 2.0)), 0.015),
	]
	for y: float in [-0.14, 0.0, 0.14]:
		var r := 0.32 * sqrt(1.0 - pow(y / 0.27, 2.0)) + 0.004
		parts.append(ShapeKit.part("accent", ShapeKit.torus(r - 0.012, r + 0.008, 32, 6), ShapeKit.at(center + Vector3(0, y, 0)), 0.0))
	return {
		"parts": parts,
		"face": _face_tilted(Vector3(0, 0.44, 0.318), -0.5, 0.62),
		"back": _back(ShapeKit.at(Vector3(0, 0.38, -0.335)) * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO), 0.28),
		"pick": [Vector3(0.7, 0.76, 0.7), Vector3(0, 0.38, 0)],
		"idle": "sway",
	}


static func _mochi() -> Dictionary:
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.sphere(0.38, 0.46, 32), ShapeKit.at(Vector3(0, 0.23, 0))),
			ShapeKit.part("leaf", ShapeKit.sphere(0.1, 0.035, 12), ShapeKit.at(Vector3(0.21, 0.4, -0.18), Basis(Vector3(1, 0, 1).normalized(), 0.55)), 0.015),
		],
		"face": _face_up(0.47, 0.72),
		"back": null,
		"pick": [Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, 0)],
		"idle": "wobble",
	}


static func _pumpkin() -> Dictionary:
	var center := Vector3(0, 0.27, 0)
	var parts := [ShapeKit.part("body", ShapeKit.sphere(0.3, 0.46, 24), ShapeKit.at(center), 0.0)]
	for i in 8:
		var a := TAU * i / 8.0
		parts.append(ShapeKit.part("body", ShapeKit.sphere(0.19, 0.48, 16), ShapeKit.at(center + Vector3(cos(a), 0, sin(a)) * 0.17)))
	parts.append(ShapeKit.part("leaf", ShapeKit.cylinder(0.035, 0.05, 0.16, 8), ShapeKit.at(Vector3(0.02, 0.55, 0), Basis(Vector3.BACK, -0.25)), 0.015))
	parts.append(ShapeKit.part("leaf", ShapeKit.torus(0.03, 0.05, 12, 5), ShapeKit.at(Vector3(0.08, 0.6, 0), Basis(Vector3.RIGHT, PI / 2.0)), 0.01))
	return {
		"parts": parts,
		"face": _face_tilted(Vector3(0, 0.33, 0.36), -0.45, 0.5),
		"back": _back(ShapeKit.at(Vector3(0, 0.31, -0.37)) * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO), 0.26),
		"pick": [Vector3(0.78, 0.66, 0.78), Vector3(0, 0.3, 0)],
	}


static func _ornament() -> Dictionary:
	var center := Vector3(0, 0.34, 0)
	return {
		"parts": [
			ShapeKit.part("body", ShapeKit.sphere(0.31, -1.0, 32), ShapeKit.at(center)),
			ShapeKit.part("base", ShapeKit.torus(0.3, 0.33, 40, 6), ShapeKit.at(center), 0.0),
			ShapeKit.part("accent", ShapeKit.cylinder(0.08, 0.09, 0.08, 16), ShapeKit.at(Vector3(0, 0.67, 0))),
			ShapeKit.part("accent", ShapeKit.torus(0.03, 0.05, 14, 5), ShapeKit.at(Vector3(0, 0.74, 0), Basis(Vector3.RIGHT, PI / 2.0)), 0.012),
			ShapeKit.part("base", ShapeKit.cylinder(0.14, 0.17, 0.05, 20), ShapeKit.at(Vector3(0, 0.025, 0))),
		],
		"face": _face_tilted(Vector3(0, 0.4, 0.29), -0.5, 0.56),
		"back": _back(ShapeKit.at(Vector3(0, 0.36, -0.32)) * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO), 0.26),
		"pick": [Vector3(0.7, 0.8, 0.7), Vector3(0, 0.38, 0)],
		"idle": "sway",
	}


static func _gingerbread() -> Dictionary:
	var pivot := Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(0, 0.08, 0))
	var t := 0.1
	var parts := [
		ShapeKit.part("base", ShapeKit.box(Vector3(0.72, 0.42, 0.08), 0.13, 0.03), ShapeKit.at(Vector3(0, 0.04, 0), ShapeKit.FLAT)),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.34, 0.36, t), 0.12, 0.03), pivot * ShapeKit.at(Vector3(0, 0.3, 0))),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.27, 0.27, t), 0.13, 0.03), pivot * ShapeKit.at(Vector3(0, 0.6, 0))),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.34, 0.12, t), 0.06, 0.02), pivot * ShapeKit.at(Vector3(0.26, 0.4, 0), Basis(Vector3.BACK, 0.35))),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.34, 0.12, t), 0.06, 0.02), pivot * ShapeKit.at(Vector3(-0.26, 0.4, 0), Basis(Vector3.BACK, -0.35))),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.13, 0.3, t), 0.06, 0.02), pivot * ShapeKit.at(Vector3(0.1, 0.1, 0), Basis(Vector3.BACK, 0.15))),
		ShapeKit.part("body", ShapeKit.box(Vector3(0.13, 0.3, t), 0.06, 0.02), pivot * ShapeKit.at(Vector3(-0.1, 0.1, 0), Basis(Vector3.BACK, -0.15))),
	]
	# Iced cuffs on wrists and ankles.
	for spot: Vector3 in [Vector3(0.37, 0.44, 0.0), Vector3(-0.37, 0.44, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0)]:
		parts.append(ShapeKit.part("head", ShapeKit.box(Vector3(0.04, 0.13, t + 0.02), 0.015, 0.006), pivot * ShapeKit.at(spot, Basis(Vector3.BACK, 0.35 if spot.x > 0.2 else (-0.35 if spot.x < -0.2 else 0.0))), 0.0))
	return {
		"parts": parts,
		"face": pivot * Transform3D(Basis().scaled(Vector3.ONE * 0.6), Vector3(0, 0.3, t * 0.5 + 0.006)),
		"back": _back(pivot * ShapeKit.at(Vector3(0, 0.32, -t * 0.5 - 0.006)), 0.24),
		"pick": [Vector3(0.84, 0.8, 0.5), Vector3(0, 0.4, 0)],
	}


static func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


# --- Shape-owned materials ---------------------------------------------------------------------

static func _solid(key: String, color: Color, shine: float, glow := Color(0, 0, 0, 0), energy := 0.0) -> Material:
	if not _materials.has(key):
		var m := CosmeticLibrary.toon(color, shine)
		if glow.a > 0.0:
			m.emission_enabled = true
			m.emission = glow
			m.emission_energy_multiplier = energy
		_materials[key] = m
	return _materials[key]


## Cut gem: the skin's body colour with a hard glint and rim so each facet reads.
static func _gem_material(skin: String, side: String) -> Material:
	var key := "gem/%s/%s" % [skin, side]
	if not _materials.has(key):
		var colors: Dictionary = CosmeticLibrary.piece_skin(skin)[side]
		var m := CosmeticLibrary.toon(colors["body"], 1.0)
		m.rim = 0.5
		var glow: Variant = colors.get("glow")
		if glow is Color:
			m.emission_enabled = true
			m.emission = glow
			m.emission_energy_multiplier = 0.5
		_materials[key] = m
	return _materials[key]


## Lantern paper: the skin's body colour, lit from inside.
static func _paper_material(skin: String, side: String) -> Material:
	var key := "paper/%s/%s" % [skin, side]
	if not _materials.has(key):
		var colors: Dictionary = CosmeticLibrary.piece_skin(skin)[side]
		var body: Color = colors["body"]
		var m := CosmeticLibrary.toon(body, 0.2)
		m.emission_enabled = true
		m.emission = body.lerp(Color("ffd27a"), 0.35)
		m.emission_energy_multiplier = 0.45
		_materials[key] = m
	return _materials[key]


## Translucent amber crystal with an ink rim (fresnel), a hot core and a toon glint.
static func _orb_material() -> Material:
	if not _materials.has("orb"):
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

uniform vec3 core_color : source_color;
uniform vec3 edge_color : source_color;
uniform vec3 ink : source_color;
uniform float opacity = 0.58;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 base = mix(core_color, edge_color, smoothstep(0.05, 0.6, rim));
	float outline = smoothstep(0.66, 0.72, rim);
	ALBEDO = mix(base, ink, outline);
	EMISSION = base * 0.42 * (1.0 - outline);
	ALPHA = mix(opacity, 1.0, max(outline, smoothstep(0.35, 0.66, rim) * 0.55));
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
}
"""
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("core_color", ORB_CORE)
		m.set_shader_parameter("edge_color", ORB_AMBER)
		m.set_shader_parameter("ink", CosmeticLibrary.INK)
		_materials["orb"] = m
	return _materials["orb"]
