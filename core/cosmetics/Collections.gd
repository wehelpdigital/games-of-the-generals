class_name Collections
extends RefCounted
## Shop themes: every cosmetic belongs to one, so the shop's Themes tab can shelve the whole
## catalogue. A theme is a pop-culture style set (woodblock waves, pirate seas, samurai, neon
## city...), a general look (Lava & Fire, Ocean & Water, Toys & Fun...), one of the holiday
## collections (Seasons; those items keep their own sale windows), or Classics for the rest. Unlike
## Seasons a theme never goes off sale: it is only a label that groups items and lets players try
## a whole look at once (FeaturedBoards).
##
## Items join a theme with a "collection" key in their library entry, which is exported to the
## server's catalog; admins can retag items there, and the shop follows the server's tag. Every
## name and design here is a generic genre or art style, never a franchise.

const LIST := {
	"great_wave": {"name": "Great Wave", "color": Color("2a4a8a"),
		"blurb": "Woodblock-print seas: towering curling waves, a snowy peak, koi and drifting sakura."},
	"treasure_seas": {"name": "Treasure Seas", "color": Color("1f7fae"),
		"blurb": "Set sail for adventure: a ship's deck, treasure maps, doubloons and cannon fire."},
	"samurai_ronin": {"name": "Samurai & Ronin", "color": Color("b8282e"),
		"blurb": "Tatami floors, a bamboo grove, red maple leaves and one clean stroke of the blade."},
	"ninja_clan": {"name": "Ninja Clan", "color": Color("3a2f6a"),
		"blurb": "Moonlit rooftops, smoke bombs and shuriken out of the dark."},
	"cyber_neon": {"name": "Neon Cyber City", "color": Color("d62bb8"),
		"blurb": "Rain-soaked neon streets, holograms, data streams and glitches."},
	"giant_robots": {"name": "Giant Robots", "color": Color("2f6bd8"),
		"blurb": "Hangar bays, armour plating, thrusters and the rocket punch."},
	"kaiju_attack": {"name": "Kaiju Attack", "color": Color("e8541c"),
		"blurb": "A giant shadow stomps across the city skyline. Hold the line!"},
	"space_opera": {"name": "Space Opera", "color": Color("5a3cd6"),
		"blurb": "Starship bridges, energy blades, shield bubbles and the jump to warp."},
	"synthwave": {"name": "Synthwave '84", "color": Color("e83a9a"),
		"blurb": "A neon grid under a striped sunset, chrome, lasers and cassette tapes."},
	"arcade_8bit": {"name": "8-Bit Arcade", "color": Color("1fae6a"),
		"blurb": "Chunky pixels, blocky hills, coins and a big GAME OVER."},
	"wild_west": {"name": "Wild West", "color": Color("c0641e"),
		"blurb": "A frontier town at high noon: wanted posters, dust, tumbleweeds and quick draws."},
	"steampunk": {"name": "Steampunk", "color": Color("a8742a"),
		"blurb": "Brass and copper, ticking gears, hissing steam and airships overhead."},
	"norse_vikings": {"name": "Vikings & Norse Myth", "color": Color("3f6a8a"),
		"blurb": "Longships in a snowy fjord, runestones and thunder from the north."},
	"ancient_egypt": {"name": "Ancient Egypt", "color": Color("d49a1a"),
		"blurb": "Pyramids, obelisks, lapis and gold, and wraps for the unlucky."},
	"greek_gods": {"name": "Greek Gods", "color": Color("4a8ad6"),
		"blurb": "Marble temples above the clouds, laurel leaves and bolts from the sky."},
	"philippine_myths": {"name": "Mitolohiya", "color": Color("2a8a5a"),
		"blurb": "Philippine myths and legends: a diwata forest, balete roots, a kapre's tree and fireflies."},
	"comic_hero": {"name": "Comic Hero", "color": Color("e8b21a"),
		"blurb": "Halftone skies, speed lines and big POW! BAM! KA-BOOM! moments."},
	"zombie_outbreak": {"name": "Zombie Outbreak", "color": Color("6a9a2a"),
		"blurb": "A boarded-up town, green fog, ooze and hands bursting out of the ground."},
	"magical_sparkle": {"name": "Magical Sparkle", "color": Color("f06aa8"),
		"blurb": "Wands, ribbons, hearts and twinkling stars in pastel light."},
	"concert_stage": {"name": "Concert Stage", "color": Color("9a3ad6"),
		"blurb": "Stage lights, a sea of light sticks and a mic drop to end the show."},
	"street_graffiti": {"name": "Street Graffiti", "color": Color("ee5a1a"),
		"blurb": "Spray paint, brick walls, skate ramps and the sound of the city."},
	"fantasy_kingdom": {"name": "Fantasy Kingdom", "color": Color("6a4ad6"),
		"blurb": "Castle walls, heraldry, knights and a dragon circling the towers."},
	# General looks.
	"sakura_blossom": {"name": "Cherry Blossom", "color": Color("ff7ab0"),
		"blurb": "Blossom gardens, paper lanterns and pink petals on the breeze."},
	"lava_fire": {"name": "Lava & Fire", "color": Color("e8401c"),
		"blurb": "Molten rock, volcanic glass, embers and roaring flames."},
	"ocean_water": {"name": "Ocean & Water", "color": Color("1fa0c8"),
		"blurb": "Coral reefs, tides, pearls and bubbles."},
	"ice_snow": {"name": "Ice & Snow", "color": Color("4f9ae8"),
		"blurb": "Glaciers, frost, crystal chips, snowfall and northern lights."},
	"nature_garden": {"name": "Nature & Garden", "color": Color("3fa85a"),
		"blurb": "Meadows, jungle ruins, potted plants, birds and butterflies."},
	"sky_weather": {"name": "Sky & Storms", "color": Color("3d6bd6"),
		"blurb": "Clouds, rain, lightning, twisters and things that fly."},
	"spooky": {"name": "Spooky", "color": Color("5a3a9a"),
		"blurb": "Haunted groves, ghosts, bats and mist, all year round."},
	"cute_candy": {"name": "Cute & Candy", "color": Color("f0609a"),
		"blurb": "Bubblegum, sprinkles, hearts, rainbows and teddy bears."},
	"military_classic": {"name": "Military Classic", "color": Color("5a7a3a"),
		"blurb": "Challenge coins, dog tags, field cards, drums and toy soldiers."},
	"royal_gold": {"name": "Royal & Gold", "color": Color("c8941a"),
		"blurb": "Gold, jade, gems, a golden banner and the champion's trophy."},
	"toys_fun": {"name": "Toys & Fun", "color": Color("ff8a1f"),
		"blurb": "Dice, rubber ducks, party poppers, parades and a clown horn."},
	"classics": {"name": "Classics", "color": Color("8a5a3a"),
		"blurb": "The originals: toy-box wood, marble, the classic plaque and the comic POW!"},
}
## Shelf order in the shop: pop-culture sets, then general looks, then the holidays (Seasons).
const ORDER := ["great_wave", "treasure_seas", "samurai_ronin", "ninja_clan", "cyber_neon", "giant_robots",
	"kaiju_attack", "space_opera", "synthwave", "arcade_8bit", "wild_west", "steampunk", "norse_vikings",
	"ancient_egypt", "greek_gods", "philippine_myths", "comic_hero", "zombie_outbreak", "magical_sparkle",
	"concert_stage", "street_graffiti", "fantasy_kingdom"]
const STYLES := ["sakura_blossom", "lava_fire", "ocean_water", "ice_snow", "nature_garden", "sky_weather", "spooky",
	"cute_candy", "military_classic", "royal_gold", "toys_fun", "classics"]
## Categories a whole look wears (taunts aren't worn; toppers fill the three spots).
const LOOK_CATEGORIES := ["arena", "board", "territory", "chip", "shape", "icons", "aura", "glow", "trail", "kill", "ambience"]

static var _items: Dictionary = {}  # theme -> [[category, slug], ...] (built on first use)


## A theme the shop knows: a style set, a general look or a holiday.
static func exists(slug: String) -> bool:
	return LIST.has(slug) or Seasons.exists(slug)


static func is_holiday(slug: String) -> bool:
	return Seasons.exists(slug) and not LIST.has(slug)


static func name_of(slug: String) -> String:
	if is_holiday(slug):
		return Seasons.name_of(slug)
	return str(LIST.get(slug, {}).get("name", slug.capitalize()))


static func color_of(slug: String) -> Color:
	if is_holiday(slug):
		return Seasons.color_of(slug)
	return LIST.get(slug, {}).get("color", AppTheme.PURPLE)


static func blurb_of(slug: String) -> String:
	if is_holiday(slug):
		return str(Seasons.OCCASIONS[slug].get("blurb", ""))
	return str(LIST.get(slug, {}).get("blurb", ""))


## The theme an item is shelved under: the server's tag (admins can retag), else its own.
static func theme_of(category: String, slug: String) -> String:
	var server: Variant = Loadout.shop_info(category, slug).get("collection")
	if server != null and exists(str(server)):
		return str(server)
	return CosmeticCatalog.collection_of(category, slug)


## [[category, slug], ...] of every item in the theme, in shop category order.
static func items(slug: String) -> Array:
	if _items.is_empty():
		for entry: Dictionary in CosmeticCatalog.CATEGORIES:
			var category: String = entry["key"]
			for item_slug: String in CosmeticCatalog.slugs(category):
				var tag := theme_of(category, item_slug)
				if not _items.has(tag):
					_items[tag] = []
				(_items[tag] as Array).append([category, item_slug])
	return _items.get(slug, [])


## Regroups after the server's tags arrive (Loadout.shop_updated).
static func refresh() -> void:
	_items.clear()


## Themes that have items, in shelf order.
static func listed() -> Array:
	var all: Array = ORDER + STYLES + Seasons.ORDER
	return all.filter(func(slug: String) -> bool: return not items(slug).is_empty())


## Today's spotlight for the Featured page: a different collection every day.
static func spotlight(today := {}) -> String:
	var all := listed().filter(func(slug: String) -> bool: return slug in ORDER)
	if all.is_empty():
		return ""
	var date: Dictionary = today if not today.is_empty() else Time.get_date_dict_from_system()
	var day := int(Time.get_unix_time_from_datetime_dict({"year": date["year"], "month": date["month"], "day": date["day"]}) / 86400)
	return all[posmod(day, all.size())]


## The picture that stands for the collection: its arena, else its board, else its first item.
static func cover(slug: String) -> Array:
	var all := items(slug)
	for category: String in ["arena", "board", "ambience", "chip"]:
		for pair: Array in all:
			if pair[0] == category:
				return pair
	return all[0] if not all.is_empty() else []


## The whole look: the rarest item of each worn category the theme has and up to three toppers,
## on top of `base` (usually the player's own look).
static func look(slug: String, base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	var slots: Array = []
	for pair: Array in look_items(slug):
		if pair[0] == "topper":
			var slot := {"kind": ToppersLibrary.kind_of(pair[1]), "slug": pair[1]}
			if slot["kind"] == "flag":
				slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
			slots.append(slot)
		else:
			result[pair[0]] = pair[1]
	if not slots.is_empty():
		result["toppers"] = {"slots": slots}
	return result


## The look's items as [category, slug] pairs: the rarest of each worn category, then the rarest
## three toppers.
static func look_items(slug: String) -> Array:
	var best := {}
	var toppers: Array = []
	for pair: Array in items(slug):
		var category: String = pair[0]
		if category == "topper":
			toppers.append(pair)
		elif category in LOOK_CATEGORIES and (not best.has(category) or _rank(pair) > _rank(best[category])):
			best[category] = pair
	toppers.sort_custom(func(a: Array, b: Array) -> bool: return _rank(a) > _rank(b))
	var worn: Array = []
	for category: String in LOOK_CATEGORIES:
		if best.has(category):
			worn.append(best[category])
	worn.append_array(toppers.slice(0, ToppersLibrary.MAX_SLOTS))
	return worn


static func _rank(pair: Array) -> int:
	return CosmeticCatalog.RARITY_ORDER.get(str(CosmeticCatalog.info(pair[0], pair[1]).get("rarity", "common")), 0)
