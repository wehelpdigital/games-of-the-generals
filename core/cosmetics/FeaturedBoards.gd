class_name FeaturedBoards
extends RefCounted
## Featured Boards: curated complete looks, at least one per shop theme (Collections). Each one
## dresses every worn category (arena, board, territory, chips, shape, icons, aura, glow, trail,
## kill, ambience) and up to three toppers. The shop shows them as big showcase cards: preview the
## whole board, try it on My Board, wear the pieces you own, or buy the set as one bundle.
##
## A set sells on the server as a "bundle" item (category "bundle", metadata.items = the items'
## server slugs; see the catalog export in tests/ShopShots.gd). Its listed price is about 20% off
## the items' total and admins can change it; buying charges that price scaled by the share of the
## set you don't own yet, so items you already have are never paid twice. Holiday sets sell during
## their occasion, like their items.

const LOOK_CATEGORIES := ["arena", "board", "territory", "chip", "shape", "icons", "aura", "glow", "trail", "kill", "ambience"]
const DISCOUNT := 0.8

const BOARDS := {
	"fb_great_wave": {"name": "Woodblock Tide", "theme": "great_wave",
		"arena": "great_wave_coast", "board": "board_woodblock_sea", "territory": "territory_indigo_waves", "chip": "pieces_woodblock", "shape": "shape_lantern", "icons": "ocean", "aura": "aura_sea_spray", "glow": "glow_rolling_surf", "trail": "trail_koi", "kill": "kill_wave_crash", "ambience": "ambience_wave_spray",
		"toppers": ["topper_koi_bowl", "topper_paper_lantern", "topper_stone_lantern"]},
	"fb_treasure_seas": {"name": "Captain's Deck", "theme": "treasure_seas",
		"arena": "pirate_ship_deck", "board": "board_treasure_map", "territory": "territory_ship_planks", "chip": "pieces_doubloon", "shape": "shape_coin", "icons": "pirates", "aura": "aura_treasure_glint", "glow": "glow_treasure_gold", "trail": "trail_sea_foam", "kill": "kill_kraken", "ambience": "ambience_broadside",
		"toppers": ["topper_parrot", "topper_treasure_chest"]},
	"fb_samurai_ronin": {"name": "Ronin's Road", "theme": "samurai_ronin",
		"arena": "bamboo_grove", "board": "board_tatami_dojo", "territory": "territory_raked_gravel", "chip": "pieces_lacquer", "shape": "shape_lantern", "icons": "samurai", "aura": "aura_ink_brush", "glow": "glow_sakura", "trail": "trail_maple", "kill": "kill_katana_draw", "ambience": "ambience_maple_wind",
		"toppers": ["topper_stone_lantern", "topper_training_dummy"]},
	"fb_ninja_clan": {"name": "Shadow Rooftops", "theme": "ninja_clan",
		"arena": "moonlit_rooftops", "board": "board_moonlit_roof", "territory": "territory_night_tiles", "chip": "pieces_shadow_cloth", "shape": "shape_hex", "icons": "samurai", "aura": "aura_shadow_smoke", "glow": "glow_shadow", "trail": "trail_smoke_bomb", "kill": "kill_ninja_slash", "ambience": "ambience_smoke_bombs",
		"toppers": ["topper_training_dummy", "topper_stone_lantern"]},
	"fb_cyber_neon": {"name": "Neon Downtown", "theme": "cyber_neon",
		"arena": "neon_city", "board": "board_circuit", "territory": "territory_neon_grid", "chip": "pieces_holo_glass", "shape": "shape_hex", "icons": "neon", "aura": "aura_neon", "glow": "glow_neon", "trail": "trail_data_stream", "kill": "kill_glitch_out", "ambience": "ambience_neon_drones",
		"toppers": ["topper_holo_cat", "topper_lava_lamp", "topper_boombox"]},
	"fb_giant_robots": {"name": "Hangar Launch", "theme": "giant_robots",
		"arena": "robot_hangar", "board": "board_hazard_hangar", "territory": "territory_hangar_deck", "chip": "pieces_armor_plate", "shape": "shape_dog_tag", "icons": "mecha", "aura": "aura_power_core", "glow": "glow_thruster", "trail": "trail_thruster", "kill": "kill_rocket_punch", "ambience": "ambience_searchlights",
		"toppers": ["topper_mini_mecha", "topper_rocket", "topper_ringed_planet"]},
	"fb_kaiju_attack": {"name": "Monster Mayhem", "theme": "kaiju_attack",
		"arena": "kaiju_city", "board": "board_city_block", "territory": "territory_scorched_city", "chip": "pieces_monster_scale", "shape": "shape_drum", "icons": "mecha", "aura": "aura_rubble_dust", "glow": "glow_thruster", "trail": "trail_rubble", "kill": "kill_giant_stomp", "ambience": "ambience_choppers",
		"toppers": ["topper_kaiju_plush", "topper_mini_mecha"]},
	"fb_space_opera": {"name": "Galactic Frontier", "theme": "space_opera",
		"arena": "deep_space", "board": "board_starship_bridge", "territory": "territory_starfield", "chip": "pieces_galaxy", "shape": "shape_gem", "icons": "space", "aura": "aura_galaxy", "glow": "glow_starlight", "trail": "trail_stardust", "kill": "kill_black_hole", "ambience": "ambience_starfighters",
		"toppers": ["topper_rocket", "topper_ringed_planet", "topper_holo_cat"]},
	"fb_synthwave": {"name": "Sunset Drive", "theme": "synthwave",
		"arena": "synthwave_sunset", "board": "board_chrome_sunset", "territory": "territory_pink_grid", "chip": "pieces_neon_wireframe", "shape": "shape_poker_chip", "icons": "neon", "aura": "aura_sunset_haze", "glow": "glow_sunset_laser", "trail": "trail_neon_streak", "kill": "kill_laser_disc", "ambience": "ambience_laser_horizon",
		"toppers": ["topper_lava_lamp", "topper_boombox", "topper_holo_cat"]},
	"fb_arcade_8bit": {"name": "Insert Coin", "theme": "arcade_8bit",
		"arena": "pixel_hills", "board": "board_pixel_arcade", "territory": "territory_pixel_grass", "chip": "pieces_arcade", "shape": "shape_poker_chip", "icons": "dinos", "aura": "aura_pixel_hearts", "glow": "glow_sunset_laser", "trail": "trail_pixels", "kill": "kill_game_over", "ambience": "ambience_pixel_weather",
		"toppers": ["topper_arcade_cabinet", "topper_lava_lamp", "topper_boombox"]},
	"fb_wild_west": {"name": "High Noon", "theme": "wild_west",
		"arena": "frontier_town", "board": "board_saloon_floor", "territory": "territory_dusty_planks", "chip": "pieces_sheriff_tin", "shape": "shape_drum", "icons": "wildwest", "aura": "aura_dust_devil", "glow": "none", "trail": "trail_dust_kick", "kill": "kill_quick_draw", "ambience": "ambience_tumbleweeds",
		"toppers": ["topper_cowboy_hat", "topper_cactus", "topper_toy_tank"]},
	"fb_steampunk": {"name": "Brass Skyport", "theme": "steampunk",
		"arena": "airship_dock", "board": "board_brass_gears", "territory": "territory_copper_plates", "chip": "pieces_brass_walnut", "shape": "shape_gem", "icons": "classic", "aura": "aura_clockwork", "glow": "glow_steam_vent", "trail": "trail_cogs", "kill": "kill_steam_cannon", "ambience": "ambience_steam_works",
		"toppers": ["topper_mini_airship", "topper_trophy"]},
	"fb_norse_vikings": {"name": "Fjord Raiders", "theme": "norse_vikings",
		"arena": "fjord_longhouse", "board": "board_runestone", "territory": "territory_frost_runes", "chip": "pieces_iron_fur", "shape": "shape_shield", "icons": "vikings", "aura": "aura_frost_rune", "glow": "glow_frost", "trail": "trail_frost_runes", "kill": "kill_thunder_hammer", "ambience": "ambience_raven_watch",
		"toppers": ["topper_rune_stone", "topper_snow_globe", "topper_castle_tower"]},
	"fb_ancient_egypt": {"name": "Desert Dynasty", "theme": "ancient_egypt",
		"arena": "pyramid_desert", "board": "board_sandstone_glyphs", "territory": "territory_lapis_gold", "chip": "pieces_pharaoh", "shape": "shape_gem", "icons": "egypt", "aura": "aura_scarab_gold", "glow": "glow_golden_sands", "trail": "trail_golden_sand", "kill": "kill_mummy_wrap", "ambience": "ambience_sandstorm",
		"toppers": ["topper_cat_statue", "topper_trophy"]},
	"fb_greek_gods": {"name": "Mount of the Gods", "theme": "greek_gods",
		"arena": "mount_olympus", "board": "board_olympus_marble", "territory": "territory_cloud_marble", "chip": "pieces_marble_laurel", "shape": "shape_gem", "icons": "classic", "aura": "aura_divine_light", "glow": "glow_golden_halo", "trail": "trail_laurel", "kill": "kill_lightning_strike", "ambience": "ambience_heavenly_rays",
		"toppers": ["topper_amphora", "topper_trophy"]},
	"fb_philippine_myths": {"name": "Diwata's Grove", "theme": "philippine_myths",
		"arena": "diwata_forest", "board": "board_balete_wood", "territory": "territory_moss_fireflies", "chip": "pieces_capiz", "shape": "shape_lantern", "icons": "safari", "aura": "aura_diwata_glow", "glow": "glow_firefly_edge", "trail": "trail_firefly", "kill": "kill_balete_roots", "ambience": "ambience_fireflies",
		"toppers": ["topper_tikbalang", "topper_kapre_tree", "topper_bonsai"]},
	"fb_comic_hero": {"name": "Front Page Hero", "theme": "comic_hero",
		"arena": "halftone_city", "board": "board_halftone_pop", "territory": "territory_comic_panels", "chip": "pieces_hero_primary", "shape": "shape_poker_chip", "icons": "heroes", "aura": "aura_hero_glow", "glow": "none", "trail": "trail_speed_lines", "kill": "kill_anvil_drop", "ambience": "ambience_sound_effects",
		"toppers": ["topper_comic_burst", "topper_dino", "topper_lucky_cat"]},
	"fb_zombie_outbreak": {"name": "Last Town Standing", "theme": "zombie_outbreak",
		"arena": "ruined_town", "board": "board_quarantine", "territory": "territory_toxic", "chip": "pieces_undead", "shape": "shape_dog_tag", "icons": "halloween", "aura": "aura_stench_cloud", "glow": "glow_toxic", "trail": "trail_ooze", "kill": "kill_grave_grab", "ambience": "ambience_toxic_mist",
		"toppers": ["topper_zombie_hand"]},
	"fb_magical_sparkle": {"name": "Starlight Wish", "theme": "magical_sparkle",
		"arena": "starlight_garden", "board": "board_pastel_ribbon", "territory": "territory_stardust_lilac", "chip": "pieces_pastel_gem", "shape": "shape_gem", "icons": "zodiac", "aura": "aura_wish_sparkles", "glow": "glow_pastel_ribbon", "trail": "trail_ribbon_stars", "kill": "kill_star_shower", "ambience": "ambience_twinkle_dust",
		"toppers": ["topper_crystal_ball", "topper_magic_wand", "topper_teddy"]},
	"fb_concert_stage": {"name": "Encore Night", "theme": "concert_stage",
		"arena": "concert_arena", "board": "board_stage_lights", "territory": "territory_led_floor", "chip": "pieces_idol", "shape": "shape_poker_chip", "icons": "music", "aura": "aura_light_sticks", "glow": "glow_stage_neon", "trail": "trail_light_sticks", "kill": "kill_mic_drop", "ambience": "ambience_stage_lights",
		"toppers": ["topper_light_stick", "topper_lava_lamp", "topper_boombox"]},
	"fb_street_graffiti": {"name": "Block Party", "theme": "street_graffiti",
		"arena": "skate_park", "board": "board_brick_wall", "territory": "territory_skate_concrete", "chip": "pieces_street_art", "shape": "shape_poker_chip", "icons": "music", "aura": "aura_spray_mist", "glow": "glow_stage_neon", "trail": "trail_spray_paint", "kill": "kill_skate_ollie", "ambience": "ambience_street_beats",
		"toppers": ["topper_skateboard", "topper_spray_can", "topper_light_stick"]},
	"fb_fantasy_kingdom": {"name": "Dragon's Keep", "theme": "fantasy_kingdom",
		"arena": "castle_kingdom", "board": "board_castle_stone", "territory": "territory_royal_gold", "chip": "pieces_royal_gold", "shape": "shape_shield", "icons": "fantasy", "aura": "aura_enchanted", "glow": "glow_pastel_ribbon", "trail": "trail_royal_sparkle", "kill": "kill_dragon_breath", "ambience": "ambience_dragon_flyover",
		"toppers": ["topper_castle_tower", "topper_trophy", "topper_crystal_ball"]},
	"fb_sakura_blossom": {"name": "Blossom Season", "theme": "sakura_blossom",
		"arena": "sakura_garden", "board": "board_tatami_dojo", "territory": "territory_sakura", "chip": "pieces_sakura", "shape": "shape_lantern", "icons": "samurai", "aura": "aura_sakura", "glow": "glow_sakura", "trail": "trail_petals", "kill": "kill_sakura_burst", "ambience": "ambience_cherry_blossoms",
		"toppers": ["topper_stone_lantern", "topper_bonsai", "topper_succulent"]},
	"fb_lava_fire": {"name": "Volcano Core", "theme": "lava_fire",
		"arena": "lava_pit", "board": "board_lava_forge", "territory": "territory_ember", "chip": "pieces_lava_rock", "shape": "shape_gem", "icons": "classic", "aura": "aura_flame", "glow": "glow_lava", "trail": "trail_fire", "kill": "kill_fire_explosion", "ambience": "ambience_choppers",
		"toppers": ["topper_kaiju_plush"]},
	"fb_ocean_water": {"name": "Coral Lagoon", "theme": "ocean_water",
		"arena": "ocean_reef", "board": "board_coral_reef", "territory": "territory_ocean", "chip": "pieces_pearl", "shape": "shape_mochi", "icons": "ocean", "aura": "aura_sea_spray", "glow": "glow_rolling_surf", "trail": "trail_bubbles", "kill": "kill_wave_crash", "ambience": "ambience_bubbles",
		"toppers": ["topper_koi_bowl", "topper_paper_lantern", "topper_parrot"]},
	"fb_ice_snow": {"name": "Polar Outpost", "theme": "ice_snow",
		"arena": "frozen_tundra", "board": "board_ice", "territory": "territory_frost", "chip": "pieces_ice_crystal", "shape": "shape_gem", "icons": "vikings", "aura": "aura_frost", "glow": "glow_frost", "trail": "trail_frost_runes", "kill": "kill_freeze_ray", "ambience": "ambience_aurora",
		"toppers": ["topper_snow_globe", "topper_rune_stone"]},
	"fb_nature_garden": {"name": "Green Getaway", "theme": "nature_garden",
		"arena": "jungle_temple", "board": "board_balete_wood", "territory": "territory_meadow", "chip": "pieces_capiz", "shape": "shape_lantern", "icons": "safari", "aura": "aura_diwata_glow", "glow": "glow_firefly_edge", "trail": "trail_firefly", "kill": "kill_earth_shaman", "ambience": "ambience_birds",
		"toppers": ["topper_bonsai", "topper_succulent", "topper_sunflower"]},
	"fb_sky_weather": {"name": "Eye of the Storm", "theme": "sky_weather",
		"arena": "cloud_kingdom", "board": "board_olympus_marble", "territory": "territory_cloud_marble", "chip": "pieces_marble_laurel", "shape": "shape_tent_card", "icons": "classic", "aura": "aura_lightning", "glow": "glow_electric", "trail": "trail_lightning", "kill": "kill_tornado", "ambience": "ambience_thunderstorm",
		"toppers": ["topper_amphora"]},
	"fb_spooky": {"name": "Midnight Grove", "theme": "spooky",
		"arena": "haunted_grove", "board": "board_quarantine", "territory": "territory_toxic", "chip": "pieces_undead", "shape": "shape_lantern", "icons": "halloween", "aura": "aura_ghostly", "glow": "glow_ghostly", "trail": "trail_ooze", "kill": "kill_ghost", "ambience": "ambience_ghosts",
		"toppers": ["topper_zombie_hand"]},
	"fb_cute_candy": {"name": "Sugar Rush", "theme": "cute_candy",
		"arena": "candy_land", "board": "board_candy", "territory": "territory_candy", "chip": "pieces_candy", "shape": "shape_mochi", "icons": "candy", "aura": "aura_rainbow", "glow": "glow_rainbow", "trail": "trail_rainbow", "kill": "kill_star_shower", "ambience": "ambience_twinkle_dust",
		"toppers": ["topper_teddy", "topper_crystal_ball", "topper_magic_wand"]},
	"fb_military_classic": {"name": "Field HQ", "theme": "military_classic",
		"arena": "frontier_town", "board": "board_saloon_floor", "territory": "territory_dusty_planks", "chip": "pieces_sheriff_tin", "shape": "shape_drum", "icons": "wildwest", "aura": "aura_dust_devil", "glow": "glow_thruster", "trail": "trail_dust_kick", "kill": "kill_airstrike", "ambience": "ambience_army_march",
		"toppers": ["topper_toy_tank", "topper_cowboy_hat", "topper_cactus"]},
	"fb_royal_gold": {"name": "Golden Throne", "theme": "royal_gold",
		"arena": "castle_kingdom", "board": "board_jade_temple", "territory": "territory_royal_gold", "chip": "pieces_obsidian", "shape": "shape_gem", "icons": "fantasy", "aura": "aura_enchanted", "glow": "none", "trail": "trail_royal_sparkle", "kill": "kill_dragon_breath", "ambience": "ambience_dragon_flyover",
		"toppers": ["topper_trophy", "topper_castle_tower"]},
	"fb_toys_fun": {"name": "Toy Box", "theme": "toys_fun",
		"arena": "candy_land", "board": "board_candy", "territory": "territory_candy", "chip": "pieces_candy", "shape": "shape_poker_chip", "icons": "dinos", "aura": "aura_rainbow", "glow": "glow_rainbow", "trail": "trail_rainbow", "kill": "kill_confetti", "ambience": "ambience_parade",
		"toppers": ["topper_dino", "topper_lucky_cat", "topper_toy_robot"]},
	"fb_classics": {"name": "The Original", "theme": "classics",
		"arena": "classic", "board": "board_marble_slate", "territory": "default", "chip": "pieces_classic_wood", "shape": "shape_classic", "icons": "classic", "aura": "none", "glow": "none", "trail": "none", "kill": "classic", "ambience": "none",
		"toppers": ["topper_mini_fan", "topper_coffee_mug"]},
	"fb_lunar_new_year": {"name": "Lucky Lanterns", "theme": "lunar_new_year",
		"arena": "classic", "board": "board_jade_dragon", "territory": "territory_red_scales", "chip": "pieces_red_gold", "shape": "shape_lucky_coin", "icons": "classic", "aura": "aura_lucky_coins", "glow": "glow_lucky_red", "trail": "trail_gold_coins", "kill": "kill_lion_dance", "ambience": "ambience_red_lanterns",
		"toppers": ["topper_red_lantern", "topper_trophy"]},
	"fb_valentines": {"name": "Sweetheart", "theme": "valentines",
		"arena": "candy_land", "board": "board_sweetheart", "territory": "territory_rose_petals", "chip": "pieces_sweetheart", "shape": "shape_heart", "icons": "candy", "aura": "aura_love_hearts", "glow": "glow_valentine_hearts", "trail": "trail_rose_petals", "kill": "kill_cupid_arrow", "ambience": "ambience_heart_balloons",
		"toppers": ["topper_rose_bouquet", "topper_teddy"]},
	"fb_summer": {"name": "Beach Day", "theme": "summer",
		"arena": "sunny_beach", "board": "board_seaside", "territory": "territory_beach_sand", "chip": "pieces_pastel_easter", "shape": "shape_easter_egg", "icons": "ocean", "aura": "none", "glow": "none", "trail": "trail_hibiscus", "kill": "classic", "ambience": "ambience_seaside_gulls",
		"toppers": ["topper_bunny", "topper_sandcastle"]},
	"fb_fiesta": {"name": "Town Fiesta", "theme": "fiesta",
		"arena": "classic", "board": "board_fiesta", "territory": "territory_banig", "chip": "pieces_fiesta", "shape": "shape_poker_chip", "icons": "dinos", "aura": "none", "glow": "glow_fiesta_confetti", "trail": "trail_fiesta_confetti", "kill": "kill_confetti", "ambience": "ambience_banderitas",
		"toppers": ["topper_jeepney", "topper_lechon", "topper_dino"]},
	"fb_kalayaan": {"name": "Sun and Stars", "theme": "kalayaan",
		"arena": "classic", "board": "board_kalayaan", "territory": "territory_sunrise", "chip": "pieces_kalayaan", "shape": "shape_gem", "icons": "classic", "aura": "aura_sunburst", "glow": "glow_kalayaan", "trail": "trail_gold_stars", "kill": "kill_airstrike", "ambience": "ambience_kalayaan_fireworks",
		"toppers": ["topper_sun_standard", "topper_trophy", "topper_toy_tank"]},
	"fb_halloween": {"name": "Trick or Treat", "theme": "halloween",
		"arena": "spooky_graveyard", "board": "board_pumpkin_patch", "territory": "territory_graveyard", "chip": "pieces_jack_o_lantern", "shape": "shape_pumpkin", "icons": "halloween", "aura": "aura_witch_wisps", "glow": "glow_ghostly", "trail": "trail_bat_swarm", "kill": "kill_ghost_pop", "ambience": "ambience_haunted_night",
		"toppers": ["topper_jack_o_lantern", "topper_cauldron", "topper_tombstone"]},
	"fb_thanksgiving": {"name": "Harvest Table", "theme": "thanksgiving",
		"arena": "harvest_farm", "board": "board_harvest", "territory": "territory_wheat_field", "chip": "pieces_harvest", "shape": "shape_drum", "icons": "safari", "aura": "none", "glow": "none", "trail": "trail_autumn_leaves", "kill": "kill_earth_shaman", "ambience": "ambience_harvest_breeze",
		"toppers": ["topper_cornucopia", "topper_turkey", "topper_bonsai"]},
	"fb_christmas": {"name": "Noche Buena", "theme": "christmas",
		"arena": "snowy_village", "board": "board_candy_cane", "territory": "territory_fresh_snow", "chip": "pieces_gingerbread", "shape": "shape_ornament", "icons": "classic", "aura": "aura_frost", "glow": "glow_christmas_lights", "trail": "trail_candy_cane", "kill": "kill_gift_box", "ambience": "ambience_santa_sleigh",
		"toppers": ["topper_parol", "topper_christmas_tree", "topper_snow_globe"]},
	"fb_new_year": {"name": "Midnight Countdown", "theme": "new_year",
		"arena": "classic", "board": "board_midnight_gold", "territory": "territory_midnight", "chip": "pieces_champagne", "shape": "shape_poker_chip", "icons": "dinos", "aura": "none", "glow": "glow_new_year_gold", "trail": "trail_sparklers", "kill": "kill_firecracker", "ambience": "ambience_midnight_fireworks",
		"toppers": ["topper_twelve_fruits", "topper_dino", "topper_lucky_cat"]},
}


static func exists(slug: String) -> bool:
	return BOARDS.has(slug)


static func info(slug: String) -> Dictionary:
	return BOARDS.get(slug, {})


static func name_of(slug: String) -> String:
	return str(info(slug).get("name", slug.capitalize()))


static func theme_of(slug: String) -> String:
	return str(info(slug).get("theme", "classics"))


## The holiday a set belongs to ("" for all-year sets).
static func season_of(slug: String) -> String:
	var theme := theme_of(slug)
	return theme if Collections.is_holiday(theme) else ""


## Every set in shelf order (by theme).
static func all() -> Array:
	var order: Array = Collections.ORDER + Collections.STYLES + Seasons.ORDER
	var slugs: Array = BOARDS.keys()
	slugs.sort_custom(func(a: String, b: String) -> bool: return order.find(theme_of(a)) < order.find(theme_of(b)))
	return slugs


## The sets of one theme.
static func of_theme(theme: String) -> Array:
	return all().filter(func(slug: String) -> bool: return theme_of(slug) == theme)


## A one-line summary for cards: the arena, board and kill.
static func blurb(slug: String) -> String:
	var b := info(slug)
	return "%s arena, %s board, %s kill and %d more." % [
		CosmeticCatalog.info("arena", b["arena"]).get("name", ""), CosmeticCatalog.info("board", b["board"]).get("name", ""),
		CosmeticCatalog.info("kill", b["kill"]).get("name", ""), items(slug).size() - 3]


## The complete loadout (as Loadout.items) the set wears.
static func look(slug: String) -> Dictionary:
	var b := info(slug)
	var result := {}
	for category: String in LOOK_CATEGORIES:
		result[category] = b.get(category, Loadout.DEFAULTS[category])
	var slots: Array = []
	for topper: String in b.get("toppers", []):
		slots.append({"kind": ToppersLibrary.kind_of(topper), "slug": topper})
	result["toppers"] = {"slots": slots}
	return result


## [[category, slug], ...] of the set's items, leaving out the free defaults everyone has.
static func items(slug: String) -> Array:
	var b := info(slug)
	var pairs: Array = []
	for category: String in LOOK_CATEGORIES:
		var item := str(b.get(category, ""))
		if item != "" and item != Loadout.DEFAULTS.get(category):
			pairs.append([category, item])
	for topper: String in b.get("toppers", []):
		pairs.append(["topper", topper])
	return pairs


## The server's global slug for an item (board and chip slugs are already global).
static func server_slug(category: String, slug: String) -> String:
	return slug if category in ["board", "chip"] else "%s.%s" % [category, slug]


## The set's catalogue price: 20% off the items' default prices, to the nearest 50 credits.
static func default_price(slug: String) -> int:
	var total := 0
	for pair: Array in items(slug):
		total += int(Loadout.RARITY_PRICES.get(str(CosmeticCatalog.info(pair[0], pair[1]).get("rarity", "common")), 300))
	return int(roundf(total * DISCOUNT / 50.0) * 50.0)


## The full set's price: the server's (admins can change it), else the default.
static func full_price(slug: String) -> int:
	var server: Dictionary = Loadout.shop_info("bundle", slug)
	if server.has("price") and server["price"] != null:
		return int(server["price"])
	return default_price(slug)


## What buying the set costs this player: the full price scaled by the share (by item prices) of
## the set they don't own yet. The server charges the same.
static func set_price(slug: String) -> int:
	var total := 0
	var missing := 0
	for pair: Array in items(slug):
		var value := Loadout.price(pair[0], pair[1])
		total += value
		if not Loadout.owns(pair[0], pair[1]):
			missing += value
	if total <= 0:
		return 0
	return roundi(float(full_price(slug)) * missing / total)


## The full value of the items one by one (shown struck through next to the set price).
static func items_value(slug: String, missing_only := false) -> int:
	var total := 0
	for pair: Array in items(slug):
		if not missing_only or not Loadout.owns(pair[0], pair[1]):
			total += Loadout.price(pair[0], pair[1])
	return total


static func owned_count(slug: String) -> int:
	return items(slug).filter(func(pair: Array) -> bool: return Loadout.owns(pair[0], pair[1])).size()


static func owns_all(slug: String) -> bool:
	return owned_count(slug) == items(slug).size()


## Whether the set can be bought today (holiday sets sell during their occasion).
static func available(slug: String) -> bool:
	var server: Dictionary = Loadout.shop_info("bundle", slug)
	if server.has("available") and server["available"] != null:
		return bool(server["available"])
	var season := season_of(slug)
	return season == "" or Seasons.is_live(season)


## Puts on every piece of the set the player owns (and the defaults it uses); the rest stays as it
## was. Returns how many of the set's items were put on.
static func wear_owned(slug: String) -> int:
	var b := info(slug)
	var worn := 0
	for category: String in LOOK_CATEGORIES:
		var item := str(b.get(category, ""))
		if item != "" and Loadout.owns(category, item):
			Loadout.equip(category, item)
			worn += 1 if item != Loadout.DEFAULTS.get(category) else 0
	var slots: Array = []
	for topper: String in b.get("toppers", []):
		if Loadout.owns("topper", topper):
			slots.append({"kind": ToppersLibrary.kind_of(topper), "slug": topper})
	if not slots.is_empty():
		Loadout.set_toppers({"slots": slots})
		worn += slots.size()
	return worn
