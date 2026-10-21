class_name Collections
extends RefCounted
## Themed collections: matching sets of cosmetics in one style (woodblock waves, pirate seas,
## samurai, neon city...). Unlike Seasons they never go off sale; a collection is only a label that
## groups items on the shop's Collections shelf and lets players try the whole look at once.
##
## Items join a collection with a "collection" key in their library entry (exported to the
## server's catalog, where admins can retag items). Every name and design here is a generic genre
## or art style, never a franchise.

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
}
## Shelf order in the shop.
const ORDER := ["great_wave", "treasure_seas", "samurai_ronin", "ninja_clan", "cyber_neon", "giant_robots",
	"kaiju_attack", "space_opera", "synthwave", "arcade_8bit", "wild_west", "steampunk", "norse_vikings",
	"ancient_egypt", "greek_gods", "philippine_myths", "comic_hero", "zombie_outbreak", "magical_sparkle",
	"concert_stage", "street_graffiti", "fantasy_kingdom"]
## Categories a whole look wears (taunts aren't worn; toppers fill the three spots).
const LOOK_CATEGORIES := ["arena", "board", "territory", "chip", "shape", "icons", "aura", "glow", "trail", "kill", "ambience"]

static var _items: Dictionary = {}  # slug -> [[category, slug], ...] (built once)


static func exists(slug: String) -> bool:
	return LIST.has(slug)


static func name_of(slug: String) -> String:
	return str(LIST.get(slug, {}).get("name", slug.capitalize()))


static func color_of(slug: String) -> Color:
	return LIST.get(slug, {}).get("color", AppTheme.PURPLE)


static func blurb_of(slug: String) -> String:
	return str(LIST.get(slug, {}).get("blurb", ""))


## [[category, slug], ...] of every item in the collection, in shop category order.
static func items(slug: String) -> Array:
	if _items.is_empty():
		for entry: Dictionary in CosmeticCatalog.CATEGORIES:
			var category: String = entry["key"]
			for item_slug: String in CosmeticCatalog.slugs(category):
				var tag := CosmeticCatalog.collection_of(category, item_slug)
				if tag != "":
					if not _items.has(tag):
						_items[tag] = []
					(_items[tag] as Array).append([category, item_slug])
	return _items.get(slug, [])


## Collections that have items, in shelf order.
static func listed() -> Array:
	return ORDER.filter(func(slug: String) -> bool: return not items(slug).is_empty())


## Today's spotlight for the Featured page: a different collection every day.
static func spotlight(today := {}) -> String:
	var all := listed()
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


## The whole look: every worn category the collection has (its first item of each) and up to three
## toppers, on top of `base` (usually the player's own look).
static func look(slug: String, base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	var slots: Array = []
	for pair: Array in items(slug):
		var category: String = pair[0]
		var item_slug: String = pair[1]
		if category == "topper":
			if slots.size() < ToppersLibrary.MAX_SLOTS:
				var slot := {"kind": ToppersLibrary.kind_of(item_slug), "slug": item_slug}
				if slot["kind"] == "flag":
					slot["flag"] = FlagFactory.DEFAULT_DESIGN.duplicate()
				slots.append(slot)
		elif category in LOOK_CATEGORIES and not (result.has("_set_" + category)):
			result[category] = item_slug
			result["_set_" + category] = true
	for key: String in result.keys():
		if str(key).begins_with("_set_"):
			result.erase(key)
	if not slots.is_empty():
		result["toppers"] = {"slots": slots}
	return result


## The look's items as [category, slug] pairs (what "Wear it all" equips).
static func look_items(slug: String) -> Array:
	var worn: Array = []
	var seen := {}
	for pair: Array in items(slug):
		if pair[0] == "topper" or (pair[0] in LOOK_CATEGORIES and not seen.has(pair[0])):
			worn.append(pair)
			seen[pair[0]] = true
	return worn
