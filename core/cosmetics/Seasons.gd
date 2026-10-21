class_name Seasons
extends RefCounted
## The yearly occasions that have their own shop collections. Mirrors the server's seasons table
## (database/migrations/*_add_yearly_windows_to_seasons.php): the server decides what is on sale
## (/api/shop/items `available`, `returns_at`, `seasons`); this copy names and orders them in the
## shop and works out the windows when the server hasn't said (offline, test builds).
##
## Items join a collection with a "season" key in their library entry.

const OCCASIONS := {
	"lunar_new_year": {"name": "Lunar New Year", "start": "01-20", "end": "02-20", "color": Color("d62828"),
		"blurb": "Red lanterns, lucky coins and a lion dance for good fortune."},
	"valentines": {"name": "Valentine's", "start": "02-01", "end": "02-15", "color": Color("ff4f7b"),
		"blurb": "Hearts, roses and Cupid's arrows."},
	"summer": {"name": "Summer & Easter", "start": "04-01", "end": "05-31", "color": Color("12b8c4"),
		"blurb": "Beach days, sandcastles and painted eggs."},
	"fiesta": {"name": "Town Fiesta", "start": "05-01", "end": "05-31", "color": Color("ff3d7f"),
		"blurb": "Banderitas, lechon, jeepneys and the palayok game."},
	"kalayaan": {"name": "Kalayaan", "start": "06-01", "end": "06-15", "color": Color("0038a8"),
		"blurb": "Sun and stars in blue, red and gold for Independence Day."},
	"halloween": {"name": "Halloween & Undas", "start": "10-15", "end": "11-03", "color": Color("ff7a12"),
		"blurb": "Tombstones, jack-o'-lanterns, cauldrons and a witch's hex."},
	"thanksgiving": {"name": "Harvest & Thanksgiving", "start": "11-15", "end": "11-30", "color": Color("c8641e"),
		"blurb": "A farm full of hay bales, turkeys and pie."},
	"christmas": {"name": "Pasko (Christmas)", "start": "12-01", "end": "01-06", "color": Color("d62f3a"),
		"blurb": "Parol stars, a snowy village, gingerbread and Santa's sleigh."},
	"new_year": {"name": "New Year", "start": "12-26", "end": "01-07", "color": Color("ffcf3f"),
		"blurb": "Midnight fireworks, torotot horns and twelve round fruits."},
}
## Calendar order for the shop's Seasonal tab.
const ORDER := ["lunar_new_year", "valentines", "summer", "fiesta", "kalayaan", "halloween", "thanksgiving", "christmas", "new_year"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func exists(slug: String) -> bool:
	return OCCASIONS.has(slug)


static func name_of(slug: String) -> String:
	return str(OCCASIONS.get(slug, {}).get("name", slug.capitalize()))


static func color_of(slug: String) -> Color:
	return OCCASIONS.get(slug, {}).get("color", AppTheme.PURPLE)


## "Oct 15 – Nov 3"
static func window_text(slug: String) -> String:
	var o: Dictionary = OCCASIONS.get(slug, {})
	if o.is_empty():
		return ""
	return "%s – %s" % [_md_text(o["start"]), _md_text(o["end"])]


## Is today (local time) inside the occasion's yearly window? Windows may wrap the new year.
static func is_live(slug: String, today := {}) -> bool:
	var o: Dictionary = OCCASIONS.get(slug, {})
	if o.is_empty():
		return false
	var date: Dictionary = today if not today.is_empty() else Time.get_date_dict_from_system()
	var now := int(date["month"]) * 100 + int(date["day"])
	var start := _md_value(o["start"])
	var end := _md_value(o["end"])
	return (now >= start and now <= end) if start <= end else (now >= start or now <= end)


## "Oct 15": when an off-season occasion comes back.
static func returns_text(slug: String) -> String:
	return _md_text(str(OCCASIONS.get(slug, {}).get("start", "")))


static func _md_value(md: String) -> int:
	var bits := md.split("-")
	return int(bits[0]) * 100 + int(bits[1]) if bits.size() == 2 else 0


static func _md_text(md: String) -> String:
	var bits := md.split("-")
	if bits.size() != 2:
		return md
	return "%s %d" % [MONTHS[clampi(int(bits[0]) - 1, 0, 11)], int(bits[1])]
