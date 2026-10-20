class_name PieceIcons
extends RefCounted
## Rank icon packs shown on piece faces (and usable in UI). Each pack is one JSON bundle of SVG
## sources, assets/icons/packs/<pack>.json = {"G5": "<svg…>", …, "UNKNOWN": "<svg…>"}, built by
## tools/icons (generate_piece_badges.js for classic, generate_icon_packs.js for the rest, then
## bundle_icons.js). Every pack keeps gameplay readable: the medallion colour/shape tells the rank
## group and the number of marks counts the rank.
##
## Sharpness: icons are rasterised at runtime straight from vector at BASE px and every mip level
## is Lanczos-filtered from the level above (not box-filtered), and the art itself uses bold ink
## outlines and chunky marks, so pieces stay crisp at every camera distance.
## Memory: BASE 512 RGBA8 + mips ≈ 1.4 MB per icon, so a match (2 packs × 16 icons) ≈ 45 MB.
## Download: all packs together are ~1.7 MB of SVG text instead of hundreds of textures.

const UNKNOWN := "UNKNOWN"  ## The "?" badge for a piece whose rank the viewer doesn't know.
const DEFAULT_PACK := "classic"
const BASE := 512
const SVG_SIZE := 512.0  ## Width the bundled SVGs declare.

## Shop catalogue: slug -> {name, rarity, desc, swatch}.
const PACKS := {
	"classic": {"name": "Classic Enamel", "rarity": "common", "desc": "Gold stars, suns, pips and chevrons on enamel medallions.",
		"swatch": [Color("5470e0"), Color("ec5a72"), Color("41aee6"), Color("ffc93c")]},
	"sports": {"name": "Sports Day", "rarity": "common", "desc": "Trophies, medals and footballs; a whistle spy and a chequered flag.",
		"swatch": [Color("2f8a4a"), Color("2f5fb0"), Color("e86a2a"), Color("ffc93c")]},
	"knights": {"name": "Medieval Knights", "rarity": "rare", "desc": "Heraldic shields with crowns, towers, swords and chevrons.",
		"swatch": [Color("7b4fd0"), Color("d1394a"), Color("3a7fe0"), Color("ffc93c")]},
	"neon": {"name": "Neon Glyphs", "rarity": "rare", "desc": "Minimal glowing glyphs on dark tiles.",
		"swatch": [Color("120e24"), Color("ffd23f"), Color("ff3fb4"), Color("22e3ff")]},
	"candy": {"name": "Candy Land", "rarity": "rare", "desc": "Hearts, donuts, candy corn and candy-cane stripes.",
		"swatch": [Color("ff8ec0"), Color("7de8c8"), Color("9dbcff"), Color("ffe68a")]},
	"ocean": {"name": "Deep Sea", "rarity": "rare", "desc": "Starfish, seashells, fish and waves in bubbly medallions.",
		"swatch": [Color("ff8a65"), Color("3fc5c0"), Color("4c86e6"), Color("5cbf7e")]},
	"safari": {"name": "Wild Safari", "rarity": "rare", "desc": "Paw prints, leaves, feathers and claw marks on rope-rimmed badges.",
		"swatch": [Color("f6c25a"), Color("86c95a"), Color("e07a48"), Color("b89a72")]},
	"wildwest": {"name": "Wild West", "rarity": "rare", "desc": "Sheriff stars, horseshoes and cacti on stitched leather; a cowboy-hat spy.",
		"swatch": [Color("d9a24a"), Color("c2553a"), Color("6aa84f"), Color("8a6a4a")]},
	"vikings": {"name": "Vikings", "rarity": "rare", "desc": "Horned helmets, war hammers and round shields on planked wood; a raven spy.",
		"swatch": [Color("8a6a46"), Color("b8323a"), Color("2f6a9a"), Color("a9b4c8")]},
	"halloween": {"name": "Halloween Monsters", "rarity": "rare", "desc": "Jack-o'-lanterns, bats, ghosts and bones; a dangling spider spy.",
		"swatch": [Color("5a3f86"), Color("ff9a2e"), Color("3fae6a"), Color("ffe48a")]},
	"dinos": {"name": "Dino Park", "rarity": "rare", "desc": "Fossil footprints, dino eggs, teeth and bones on rough stone; a raptor spy.",
		"swatch": [Color("f2b84b"), Color("7ab85a"), Color("d9734a"), Color("a89a7a")]},
	"music": {"name": "Rock Stars", "rarity": "rare", "desc": "Vinyl records with notes, guitars, drums and EQ bars; headphones and a mic.",
		"swatch": [Color("ff4f8b"), Color("ffcf3f"), Color("3d8bff"), Color("27c98f")]},
	"samurai": {"name": "Samurai & Ninja", "rarity": "epic", "desc": "Lacquered mon crests with sakura, fans, diamonds and a shuriken spy.",
		"swatch": [Color("e2463c"), Color("3e5bb0"), Color("3e9a72"), Color("ffc93c")]},
	"space": {"name": "Space Fleet", "rarity": "epic", "desc": "Hex insignia with twinkle stars, ringed planets and delta wings.",
		"swatch": [Color("6c4ff0"), Color("e0476a"), Color("2bb3c0"), Color("3fe0ff")]},
	"pirates": {"name": "Pirate Crew", "rarity": "epic", "desc": "Gold doubloons with skulls, anchors, cutlasses and a spyglass.",
		"swatch": [Color("4a4a56"), Color("3a62b0"), Color("b23a4a"), Color("ffc93c")]},
	"fantasy": {"name": "Dragons & Wizards", "rarity": "epic", "desc": "Starry medallions with gems, potions and wizard hats; a dragon flag.",
		"swatch": [Color("9b5cf0"), Color("3ec98a"), Color("4a8cf0"), Color("bfefff")]},
	"mecha": {"name": "Robots & Mecha", "rarity": "epic", "desc": "Gear-edged plates with cogs, microchips, hex nuts and batteries.",
		"swatch": [Color("ffb03a"), Color("5f7fa8"), Color("38c9a0"), Color("8f97a8")]},
	"egypt": {"name": "Ancient Egypt", "rarity": "epic", "desc": "Ankhs, scarabs and pyramids in lapis and gold; a jackal-headed spy.",
		"swatch": [Color("2f6fd0"), Color("2ea38f"), Color("d2603a"), Color("ffc93c")]},
	"zodiac": {"name": "Mystic Zodiac", "rarity": "epic", "desc": "Moons, comets and hourglasses under the stars; a crystal-ball spy.",
		"swatch": [Color("3a3a8a"), Color("8a3ac8"), Color("2a8ab0"), Color("ffc93c")]},
	"heroes": {"name": "Super Squad", "rarity": "epic", "desc": "Comic bursts with lightning bolts, fists and rockets; a masked spy.",
		"swatch": [Color("2f5fe0"), Color("e8323a"), Color("ffcf3f"), Color("27c98f")]},
}

static var _bundles: Dictionary = {}    # pack -> {RANK: svg text}
static var _textures: Dictionary = {}   # "pack/RANK" -> ImageTexture
static var _materials: Dictionary = {}  # "pack/RANK" -> StandardMaterial3D
static var _quad: QuadMesh


## `pack` if it exists, otherwise the classic pack.
static func pack_or_default(pack: String) -> String:
	return pack if PACKS.has(pack) else DEFAULT_PACK


## The badge for a rank code (G5 … FLG, or UNKNOWN) in `pack`; null for anything else.
static func icon_texture(rank: String, pack := DEFAULT_PACK) -> Texture2D:
	if not Ranks.INFO.has(rank) and rank != UNKNOWN:
		return null
	var p := pack_or_default(pack)
	var key := "%s/%s" % [p, rank]
	if not _textures.has(key):
		_textures[key] = _rasterise(_svg(p, rank))
	return _textures[key]


## Badge for `rank`, falling back to the pack's "?" badge when the rank is hidden ("").
static func badge_or_mystery(rank: String, pack := DEFAULT_PACK) -> Texture2D:
	return icon_texture(rank if Ranks.INFO.has(rank) else UNKNOWN, pack)


## Unshaded so the art keeps its colours under any light; alpha-blended for the round edge.
static func face_material(rank: String, pack := DEFAULT_PACK) -> StandardMaterial3D:
	var key := "%s/%s" % [pack_or_default(pack), rank]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = icon_texture(rank, pack)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.render_priority = 1  # After see-through (holo) piece bodies.
		_materials[key] = m
	return _materials[key]


## Coroutine: rasterises a whole pack one icon per frame so a match or shop preview doesn't
## stall (useful on single-threaded web builds). Optional; icon_texture() works without it.
static func warm_pack(pack: String) -> void:
	var p := pack_or_default(pack)
	var tree := Engine.get_main_loop() as SceneTree
	for rank: String in Ranks.INFO.keys() + [UNKNOWN]:
		if not _textures.has("%s/%s" % [p, rank]):
			icon_texture(rank, p)
			if tree:
				await tree.process_frame


## Frees a pack's textures (e.g. after leaving the shop) to keep texture memory down.
static func release_pack(pack: String) -> void:
	var prefix := pack_or_default(pack) + "/"
	for cache: Dictionary in [_textures, _materials]:
		for key: String in cache.keys():
			if key.begins_with(prefix):
				cache.erase(key)


## A unit quad facing +Z, shared by every piece face.
static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


static func _svg(pack: String, rank: String) -> String:
	if not _bundles.has(pack):
		var res: Variant = load("res://assets/icons/packs/%s.json" % pack)
		_bundles[pack] = res.data if res is JSON and res.data is Dictionary else {}
		if (_bundles[pack] as Dictionary).is_empty():
			push_error("PieceIcons: missing or empty icon bundle for pack '%s'" % pack)
	return str(_bundles[pack].get(rank, ""))


## SVG -> BASE px raster (ThorVG's analytic anti-aliasing) -> a mip chain where each level is
## Lanczos-filtered from the one above. Box-filtered mips (the default) are what made icons look
## soft on distant pieces; Lanczos keeps edges and the rank marks crisp. ~8 ms per icon on desktop.
static func _rasterise(svg: String) -> ImageTexture:
	var level := Image.new()
	if svg == "" or level.load_svg_from_string(svg, BASE / SVG_SIZE) != OK:
		level = Image.create_empty(BASE, BASE, false, Image.FORMAT_RGBA8)
	level.convert(Image.FORMAT_RGBA8)
	if level.get_width() != BASE or level.get_height() != BASE:
		level.resize(BASE, BASE, Image.INTERPOLATE_LANCZOS)
	var data := level.get_data()
	var size := BASE >> 1
	while size >= 1:
		level = level.duplicate() as Image
		level.resize(size, size, Image.INTERPOLATE_LANCZOS)
		data.append_array(level.get_data())
		size >>= 1
	return ImageTexture.create_from_image(Image.create_from_data(BASE, BASE, true, Image.FORMAT_RGBA8, data))
