class_name PlayerRanks
extends RefCounted
## Account ranks (tiers 0–12) earned with XP and tasks. Mirrors config/progression.php on the
## server, which decides promotions; the client only names and draws them.

const NAMES := [
	"Private", "Sergeant", "Second Lieutenant", "First Lieutenant", "Captain", "Major",
	"Lieutenant Colonel", "Colonel", "Brigadier General", "Major General", "Lieutenant General",
	"General", "General of the Army",
]
const SHORT := ["PVT", "SGT", "2LT", "1LT", "CPT", "MAJ", "LTC", "COL", "BGEN", "MGEN", "LTGEN", "GEN", "GOA"]
const MAX_TIER := 12
const GUILD_MIN_TIER := 5  # Major and above may found a guild.


static func clamp_tier(tier: Variant) -> int:
	return clampi(int(tier) if tier != null else 0, 0, MAX_TIER)


static func name_of(tier: Variant) -> String:
	return NAMES[clamp_tier(tier)]


static func short_of(tier: Variant) -> String:
	return SHORT[clamp_tier(tier)]


## Enlisted green, company officers silver, field officers gold, generals red.
static func color_of(tier: Variant) -> Color:
	var t := clamp_tier(tier)
	if t <= 1:
		return AppTheme.MINT
	if t <= 4:
		return AppTheme.SILVER
	if t <= 7:
		return AppTheme.GOLD
	return AppTheme.RED
