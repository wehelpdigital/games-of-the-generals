class_name CosmeticCatalog
extends RefCounted
## Every cosmetic category the shop sells, and where each category's items are defined. Each item
## is {name, rarity, swatch: [Color], desc?}. Item lists are read from their owning libraries at
## runtime, so each library stays the single source of truth for its own items.

const CATEGORIES := [
	{"key": "arena", "label": "Arenas", "blurb": "The world around your board. Only you see it."},
	{"key": "board", "label": "Boards", "blurb": "The board itself, as you see it."},
	{"key": "territory", "label": "Territory", "blurb": "How your half of the board looks. Your opponent sees it too."},
	{"key": "chip", "label": "Chips", "blurb": "The material and colours of your pieces."},
	{"key": "shape", "label": "Chip Shapes", "blurb": "The shape of your pieces: orbs, coins, dice and more. Your opponent sees it too."},
	{"key": "icons", "label": "Icon packs", "blurb": "The rank symbols on your pieces."},
	{"key": "aura", "label": "Auras", "blurb": "An effect around your pieces. Your opponent sees it too."},
	{"key": "glow", "label": "Board glow", "blurb": "A glow along your half of the board. Your opponent sees it too."},
	{"key": "trail", "label": "Move trails", "blurb": "Left behind when your pieces move."},
	{"key": "kill", "label": "Kill effects", "blurb": "Plays when one of your pieces wins a clash."},
	{"key": "taunt", "label": "Taunts", "blurb": "Throw these at your opponent's side during a match. Tap Throw! to try one."},
]

## Category key -> [script path, constant name].
const SOURCES := {
	"arena": ["res://core/cosmetics/ArenaLibrary.gd", "ARENAS"],
	"board": ["res://core/CosmeticLibrary.gd", "BOARD_THEMES"],
	"territory": ["res://core/CosmeticLibrary.gd", "TERRITORIES"],
	"chip": ["res://core/CosmeticLibrary.gd", "PIECE_SKINS"],
	"shape": ["res://core/cosmetics/ChipShapes.gd", "STYLES"],
	"icons": ["res://core/PieceIcons.gd", "PACKS"],
	"aura": ["res://core/cosmetics/AuraFX.gd", "STYLES"],
	"glow": ["res://core/cosmetics/BoardGlowFX.gd", "STYLES"],
	"trail": ["res://core/cosmetics/TrailFX.gd", "STYLES"],
	"kill": ["res://core/cosmetics/KillFX.gd", "STYLES"],
	"taunt": ["res://core/cosmetics/TauntFX.gd", "STYLES"],
}

const RARITY_ORDER := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}

static var _cache: Dictionary = {}


## slug -> item info for a category (empty if the library isn't there).
static func items(category: String) -> Dictionary:
	if _cache.has(category):
		return _cache[category]
	var found: Dictionary = {}
	var source: Array = SOURCES.get(category, [])
	if source.size() == 2 and ResourceLoader.exists(source[0]):
		var script: Script = load(source[0])
		var value: Variant = script.get_script_constant_map().get(source[1])
		if value is Dictionary:
			found = value
	_cache[category] = found
	return found


## Slugs ordered for display: cheapest rarity first, then by name.
static func slugs(category: String) -> Array:
	var all := items(category)
	var keys: Array = all.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = RARITY_ORDER.get(str(all[a].get("rarity", "common")), 0)
		var rb: int = RARITY_ORDER.get(str(all[b].get("rarity", "common")), 0)
		return ra < rb if ra != rb else str(all[a].get("name", a)) < str(all[b].get("name", b)))
	return keys


static func info(category: String, slug: String) -> Dictionary:
	return items(category).get(slug, {})


static func label(category: String) -> String:
	for c: Dictionary in CATEGORIES:
		if c["key"] == category:
			return c["label"]
	return category.capitalize()


static func count() -> int:
	var total := 0
	for c: Dictionary in CATEGORIES:
		total += items(c["key"]).size()
	return total
