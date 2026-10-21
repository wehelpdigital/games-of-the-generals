"""Every sound in the game: how it is built, and which shop items use it.

`SFX` and `LOOPS` map a sound name to a builder (no arguments, returns mono float32 at SR).
`MUSIC` lists the tracks. `ITEMS` maps each shop item (category -> slug) to a sound name;
`KEYWORDS` and `DEFAULTS` give later items a fitting sound without editing this file.

Kill effects start when the effect starts: action kills wind up and hit at the impact time the
effect reports (KillFX.ACTIONS[...].impact), which is the delay used for the hit layer here.
Taunts fly for 1.0 s (TauntFX.FLIGHT_TIME) before they land: the payload sits at 1.0 s.
"""

from pathlib import Path

import numpy as np

from sfxlib import *  # noqa: F401,F403 (the recipe vocabulary)
import sfxlib as S

SOURCES = Path(".")  # Set by build_audio.py: the folder with the unpacked source packs.
_index = {}


def _build_index():
    if _index:
        return
    for p in SOURCES.rglob("*"):
        if p.suffix.lower() not in (".ogg", ".wav", ".mp3"):
            continue
        parts = p.relative_to(SOURCES).parts
        packs = [q for q in parts if q.startswith("k_") or q == "junkala"]
        if not packs:
            continue
        pack = packs[0].replace("k_", "")
        key = f"j/{p.stem}" if pack == "junkala" else f"{pack}/{p.stem}"
        _index.setdefault(key, p)


def K(key, gain=0.0, start=0.0, length=None):
    """A Kenney sound by "pack/name" (interface, impact, rpg, scifi, casino, digital, jingles)."""
    _build_index()
    x = S.load(_index[key], start, length)
    return x * (10 ** (gain / 20))


def J(name, gain=0.0, start=0.0, length=None):
    """A sound from Juhani Junkala's collection, by file name."""
    _build_index()
    x = S.load(_index[f"j/{name}"], start, length)
    return x * (10 ** (gain / 20))


def source_files_of(builder):
    """Which source files a builder reads (for CREDITS.md)."""
    _build_index()
    used = []
    real_k, real_j = K, J

    def k(key, *a, **kw):
        used.append(str(_index.get(key, key)))
        return real_k(key, *a, **kw)

    def j(name, *a, **kw):
        used.append(str(_index.get(f"j/{name}", name)))
        return real_j(name, *a, **kw)

    globals()["K"], globals()["J"] = k, j
    try:
        builder()
    finally:
        globals()["K"], globals()["J"] = real_k, real_j
    return used


def throw(payload, at=1.0):
    """A thrown taunt: a whoosh on launch, the payload when it lands."""
    return mix((whoosh(0.45, 600, 1800), 0, -10), (payload, at, 0))


def crowd(d=4.0):
    x = bandpass(noise(d, "pink"), 300, 2500)
    tt = seconds(d)
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * tt) * np.sin(2 * np.pi * 1.9 * tt + 1)
    return (x * lfo * 0.5).astype(np.float32)


def flaps(d=1.0, count=6):
    return mix(*[(lowpass(noise(0.05, "pink"), 900) * env_exp(0.05, 0.015), i * d / count, -4) for i in range(count)], length=d)


def sad_trombone():
    notes = [(392.0, 0.32), (370.0, 0.32), (349.2, 0.32), (329.6, 0.9)]
    layers, t = [], 0.0
    for f, d in notes:
        w = lowpass(vibrato_tone(f, d, 6, 0.012 if d < 0.5 else 0.03, "saw"), 1400) * env_swell(d, 0.1, 0.5, 0.6)
        layers.append((w, t, 0))
        t += d
    return mix(*layers)


# --- One-shot sounds -----------------------------------------------------------------------------

SFX = {
    # Interface.
    "ui_click": lambda: K("interface/click_002"),
    "ui_tab": lambda: K("interface/select_002"),
    "ui_open": lambda: K("interface/maximize_003"),
    "ui_close": lambda: K("interface/minimize_003"),
    "ui_back": lambda: K("interface/back_002"),
    "ui_toast": lambda: K("interface/pluck_001"),
    "ui_error": lambda: K("interface/error_004"),
    "ui_confirm": lambda: K("interface/confirmation_001"),
    "ui_toggle": lambda: K("interface/toggle_002"),
    "ui_equip": lambda: mix(K("casino/chip-lay-2"), (K("interface/switch_005"), 0.02, -8)),
    "ui_purchase": lambda: mix(J("sfx_coin_cluster3"), (K("interface/confirmation_002"), 0.12, -2)),
    "ui_notify": lambda: K("interface/bong_001"),
    "coins": lambda: J("sfx_coin_double3"),
    "daily_reward": lambda: mix(J("sfx_coin_cluster5"), (arpeggio([659.26, 783.99, 1046.5, 1318.5], 0.08), 0.1, -6)),
    "rank_up": lambda: J("sfx_sounds_fanfare3"),
    "achievement": lambda: mix(J("sfx_sounds_powerup6"), (twinkle(0.8, 8), 0.1, -8)),
    # Gameplay.
    "piece_pickup": lambda: pitch(K("casino/chip-lay-1"), 1.1),
    "piece_place": lambda: K("impact/impactWood_light_002"),
    "piece_move": lambda: mix((K("casino/card-slide-2"), 0, -8), (K("impact/impactWood_light_003"), 0.16, -2)),
    "setup_shuffle": lambda: fade(K("casino/card-shuffle", length=1.4), 0, 0.25),
    "ready": lambda: K("interface/confirmation_003"),
    "match_start": lambda: arpeggio([523.25, 659.26, 783.99, 1046.5], 0.09),
    "your_turn": lambda: arpeggio([659.26, 987.77], 0.09, 0.5),
    "clash_hit": lambda: K("impact/impactPunch_medium_001"),
    "clash_tie": lambda: mix(K("impact/impactPunch_heavy_002"), (K("impact/impactPlate_heavy_001"), 0.02, -4)),
    "flag_capture": lambda: J("sfx_sounds_fanfare2"),
    "timer_tick": lambda: K("interface/tick_001"),
    "timer_urgent": lambda: pitch(K("interface/tick_002"), 1.25),
    "timeout": lambda: J("sfx_sounds_error5"),
    "card_draw": lambda: K("casino/card-slide-5"),
    "card_flip": lambda: K("casino/card-shove-2"),
    "card_slam": lambda: mix(K("casino/card-place-3"), (K("impact/impactSoft_heavy_001"), 0, -3), (twinkle(0.5, 4, 6), 0.05, -14)),
    "card_reveal": lambda: mix(K("casino/cards-pack-open-1"), (K("digital/powerUp4"), 0.1, -6)),
    "powerup_good": lambda: J("sfx_sounds_powerup3"),
    "powerup_bad": lambda: J("sfx_sounds_negative1"),
    "chat_message": lambda: pitch(K("interface/pluck_002"), 1.2),
    "shoutout": lambda: mix((party_horn(0.5, 600), 0, -6), (J("sfx_sounds_fanfare1"), 0.1, 0)),
    "victory": lambda: mix(J("sfx_sounds_fanfare2"), (applause(2.0), 0.4, -10)),
    "defeat": lambda: sad_trombone(),
    # Kill effects: the hit lands at the effect's impact time (see the module docstring).
    "kill_classic": lambda: mix(K("impact/impactPunch_heavy_001"), (pop(600), 0, -6), (whoosh(0.25, 800, 3000), 0, -14)),
    "kill_fire_explosion": lambda: mix(J("sfx_exp_short_soft3"), (crackle(0.8), 0.02, -8), (fire_whoosh(0.6), 0, -6)),
    "kill_ice_shatter": lambda: mix(K("impact/impactGlass_heavy_002"), (bell(2093, 0.6), 0, -10), (bell(2637, 0.5), 0.05, -12)),
    "kill_pixel_burst": lambda: mix(J("sfx_exp_short_hard8"), (chip8([1046.5, 784, 523.25], 0.04), 0, -8)),
    "kill_confetti": lambda: mix(pop(400, 0.12), (crunch(0.5, 14), 0.05, -12), (party_horn(0.5), 0.05, -8), (applause(0.9), 0.1, -14)),
    "kill_lightning_strike": lambda: thunder(1.6),
    "kill_black_hole": lambda: mix(tone((900, 40), 1.1) * env_swell(1.1, 0.7), (swirl(1.1, 1200, 200), 0, -6), (K("scifi/lowFrequency_explosion_000"), 1.0, -8)),
    "kill_sakura_burst": lambda: mix((swirl(0.9, 600, 2400), 0, -8), (twinkle(1.0, 8), 0, -2)),
    "kill_ghost": lambda: ghost_boo(1.0),
    "kill_toxic_splat": lambda: mix(splat(0.4), (bubbles(0.9, 12, 300, 900), 0.1, -4), (fade(K("scifi/slime_000", length=0.8), 0, 0.2), 0, -6)),
    "kill_star_shower": lambda: mix(twinkle(1.2, 14, 3), (arpeggio([1046.5, 1318.5, 1568, 2093], 0.06), 0, -6)),
    "kill_bazooka": lambda: mix((J("sfx_wpn_missilelaunch"), 0, -2), (J("sfx_exp_medium4"), 0.45, 0)),
    "kill_wizard_fireball": lambda: mix((K("digital/phaserUp3"), 0, -8), (fire_whoosh(0.55), 0, -4), (J("sfx_exp_short_soft5"), 0.55, 0), (crackle(0.6), 0.57, -8)),
    "kill_earth_shaman": lambda: mix(rumble(1.2, 110), (K("impact/impactMining_002"), 0.35, 0), (K("impact/impactMining_004"), 0.42, -4), (lowpass(noise(0.6, "brown"), 500) * env_exp(0.6, 0.15), 0.36, -4)),
    "kill_airstrike": lambda: mix((whoosh(0.6, 300, 1500), 0, -8), (whistle_fall(0.75, 2600, 900), 0, -4), (J("sfx_exp_medium7"), 0.75, 0)),
    "kill_ninja_slash": lambda: mix((whoosh(0.28, 1500, 6000), 0, -4), (K("rpg/knifeSlice"), 0.3, 0), (metal_ring(3200, 0.4), 0.3, -10)),
    "kill_storm_caller": lambda: mix((wind(0.6, 200, 700) * env_swell(0.6, 0.8), 0, -6), (thunder(1.6), 0.55, 0)),
    "kill_orbital_laser": lambda: mix((lowpass(zwoop(0.5, 200, 1800, "saw"), 3000), 0, -10), (K("scifi/laserLarge_002"), 0.5, 0), (J("sfx_exp_short_hard3"), 0.55, -3)),
    "kill_anvil_drop": lambda: mix((whistle_fall(0.45, 2200, 800), 0, -6), (K("impact/impactMetal_heavy_003"), 0.45, 0), (K("impact/impactBell_heavy_001"), 0.45, -6), (boing(120, 0.4), 0.5, -12)),
    "kill_pocket_wormhole": lambda: mix((K("digital/phaseJump2"), 0, -4), (swirl(0.9, 1600, 200), 0.2, -6), (tone((600, 60), 0.4) * env_exp(0.4, 0.15), 0.4, -2)),
    "kill_freeze_ray": lambda: mix((K("scifi/laserSmall_003"), 0, -4), (zwoop(0.5, 800, 2400) * 0.5, 0, -12), (K("impact/impactGlass_heavy_000"), 0.5, 0), (bell(2637, 0.5), 0.52, -10)),
    "kill_catapult": lambda: mix((K("rpg/creak2"), 0, -4), (whoosh(0.5, 250, 900), 0.08, -6), (K("impact/impactWood_heavy_002"), 0.6, 0), (K("impact/impactMining_001"), 0.62, -4)),
    "kill_pirate_cannon": lambda: mix((hiss(0.35, 2500), 0, -16), (J("sfx_wpn_cannon2"), 0.4, 0), (whoosh(0.3, 400, 1200), 0.45, -10)),
    "kill_tornado": lambda: mix(swirl(1.4, 250, 1200, 6), (zwoop(0.8, 300, 1200), 0.4, -10)),
    "kill_ufo_abduction": lambda: mix((beam_hum(1.3, 90), 0, -4), (zwoop(0.9, 300, 1800), 0.45, -4), (K("scifi/forceField_001"), 0.4, -8)),
    "kill_kraken": lambda: mix((lowpass(noise(0.6, "pink"), 900) * env_swell(0.6, 0.9), 0, -6), (bubbles(0.5, 10, 250, 700), 0, -8), (splash(0.9, 1.3), 0.47, 0), (bubbles(1.0, 14, 200, 600), 0.55, -4)),
    "kill_boxing_glove": lambda: mix((boing(220, 0.35), 0, -6), (K("impact/impactPunch_heavy_003"), 0.3, 0), (whoosh(0.3, 600, 2500), 0.32, -10)),
    "kill_dragon_breath": lambda: mix((lowpass(vibrato_tone((150, 110), 0.45, 9, 0.08, "saw"), 700) * env_swell(0.45, 0.4), 0, -8), (fire_whoosh(1.0), 0.4, 0), (crackle(0.8), 0.5, -6)),
    "kill_bubble_trap": lambda: mix((bubbles(0.35, 6), 0, -6), (boing(400, 0.4) * 0.5, 0.35, -8), (zwoop(0.6, 500, 1400), 0.4, -10), (pop(900, 0.08), 1.0, 0)),
    "kill_meteor_call": lambda: mix((whoosh(0.6, 2400, 300), 0, -2), (J("sfx_exp_medium2"), 0.6, 0)),
    "kill_ghost_pop": lambda: mix((ghost_boo(0.5, 260), 0, -2), (pop(500, 0.1), 0.45, 0), (squeak(2400, 0.08), 0.5, -8)),
    "kill_gift_box": lambda: mix((thud(110, 0.25), 0, -6), (pop(450, 0.12), 0.4, 0), (twinkle(0.8, 8), 0.42, -6), (crunch(0.4, 10), 0.45, -14)),
    "kill_firecracker": lambda: mix(*[(pop(float(f), 0.06), t, -4) for f, t in zip([420, 610, 380, 700, 520, 450, 650, 400], np.arange(0, 0.5, 0.065))], (J("sfx_exp_short_hard2"), 0.55, 0)),
    "kill_cupid_arrow": lambda: mix((whoosh(0.3, 1800, 5000), 0, -8), (K("impact/impactWood_light_001"), 0.35, -2), (arpeggio([1046.5, 1318.5, 1568, 2093, 2637], 0.05), 0.38, -6)),
    "kill_lion_dance": lambda: mix((drum(120, 0.3), 0, -2), (cymbal(0.4), 0.12, -12), (drum(140, 0.3), 0.25, -2), (drum(100, 0.4), 0.5, 0), (cymbal(0.8), 0.5, -6)),
    "kill_wave_crash": lambda: mix((lowpass(noise(0.6, "pink"), 1200) * env_swell(0.6, 0.95), 0, -4), (splash(1.0, 1.6), 0.55, 0)),
    "kill_katana_draw": lambda: mix((K("rpg/drawKnife2"), 0, -4), (whoosh(0.2, 2000, 7000), 0.22, -8), (K("rpg/knifeSlice2"), 0.32, 0), (metal_ring(3000, 0.5), 0.32, -12)),
    "kill_shuriken": lambda: mix(*[(tone((3200, 2600), 0.18) * env_swell(0.18, 0.5), i * 0.1, -10) for i in range(3)], (K("impact/impactWood_light_004"), 0.45, 0), (K("impact/impactWood_light_002"), 0.5, -4)),
    "kill_glitch_out": lambda: mix((K("interface/glitch_002"), 0, -2), (K("interface/glitch_004"), 0.3, 0), (chip8([880, 440, 220], 0.05), 0.32, -8)),
    "kill_rocket_punch": lambda: mix((K("scifi/thrusterFire_002", length=0.45), 0, -4), (K("impact/impactPunch_heavy_004"), 0.45, 0), (J("sfx_exp_short_soft2"), 0.47, -8)),
    "kill_giant_stomp": lambda: mix((thud(50, 0.3), 0, -10), (thud(40, 0.6), 0.5, 0), (rumble(0.8, 90), 0.5, -4), (K("impact/impactMining_003"), 0.52, -8)),
    "kill_plasma_blade": lambda: mix((K("scifi/laserLarge_000"), 0, -8), (whoosh(0.3, 800, 3500), 0.02, -6), (K("scifi/laserLarge_003"), 0.32, 0)),
    "kill_laser_disc": lambda: mix((lowpass(tone(220, 0.45, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * seconds(0.45))), 2500) * env_swell(0.45, 0.8), 0, -10), (K("digital/laser4"), 0.45, 0)),
    "kill_game_over": lambda: mix(chip8([784, 659.26, 523.25, 392, 329.6, 261.6], 0.09), (J("sfx_exp_short_hard9"), 0.22, -6)),
    "kill_quick_draw": lambda: mix((K("rpg/beltHandle1"), 0, -6), (J("sfx_weapon_singleshot5"), 0.4, 0), (ricochet(0.35), 0.45, -10)),
    "kill_steam_cannon": lambda: mix((hiss(0.5, 2000), 0, -6), (J("sfx_wpn_cannon4"), 0.5, 0), (hiss(0.6, 1500), 0.55, -10)),
    "kill_thunder_hammer": lambda: mix((whoosh(0.5, 300, 1000), 0, -6), (K("impact/impactMetal_heavy_001"), 0.55, 0), (thunder(1.4), 0.55, -2)),
    "kill_mummy_wrap": lambda: mix((K("rpg/cloth1"), 0, -4), (K("rpg/cloth3"), 0.2, -4), (swirl(0.6, 500, 2000), 0, -8), (hiss(0.6, 3000), 0.6, -6), (poof(0.4), 0.6, -4)),
    "kill_balete_roots": lambda: mix(rumble(1.0), (K("rpg/creak1"), 0.2, -4), (K("impact/impactWood_heavy_001"), 0.55, 0), (K("rpg/creak3"), 0.6, -6)),
    "kill_ka_boom": lambda: mix((whoosh(0.25, 500, 2000), 0, -6), (J("sfx_exp_double2"), 0.25, 0)),
    "kill_grave_grab": lambda: mix((rumble(0.6, 140), 0, -4), (K("impact/impactMining_000"), 0.3, -6), (ghost_boo(0.6, 180), 0.4, -8), (K("impact/impactSoft_heavy_002"), 0.5, 0)),
    "kill_wand_twinkle": lambda: mix((twinkle(0.45, 5), 0, -6), (K("digital/powerUp7"), 0.2, -4), (pop(800, 0.08), 0.45, 0), (twinkle(0.6, 6, 6), 0.47, -6)),
    "kill_mic_drop": lambda: mix((whistle_fall(0.5, 1500, 600) * 0.4, 0, -14), (thud(90, 0.3), 0.5, 0), (K("impact/impactMetal_light_002"), 0.5, -4), (tone(2400, 0.4) * env_swell(0.4, 0.3), 0.52, -18), (applause(1.2), 0.6, -8)),
    "kill_skate_ollie": lambda: mix((lowpass(noise(0.4, "brown"), 600) * env_swell(0.4, 0.5), 0, -6), (K("impact/impactWood_medium_002"), 0.3, -4), (K("impact/impactPlank_medium_001"), 0.4, 0), (hiss(0.4, 3000), 0.45, -8)),
    # Fallbacks for kill effects added later: a wind-up, then the hit at the effect's impact time.
    "kill_generic": lambda: mix(K("impact/impactPunch_heavy_000"), (J("sfx_exp_short_soft7"), 0.01, -6)),
    "kill_generic_windup": lambda: whoosh(0.4, 400, 2200),
    # Taunts: thrown, then the payload lands after the 1 s flight.
    "taunt_banana_peel": lambda: throw(mix((splat(0.2, 0.3), 0, -6), (slide_whistle(1600, 500, 0.45), 0.1, 0))),
    "taunt_beach_ball": lambda: throw(mix(boing(160, 0.5), (boing(200, 0.4), 0.35, -4))),
    "taunt_candy_corn": lambda: throw(crunch(0.6, 18)),
    "taunt_confetti_cannon": lambda: throw(mix(pop(350, 0.14), (crunch(0.5, 14), 0, -10), (party_horn(0.5), 0.05, -8))),
    "taunt_cream_pie": lambda: throw(splat(0.35, 1.0)),
    "taunt_egg": lambda: throw(mix(highpass(noise(0.03), 1500) * env_exp(0.03, 0.006), (splat(0.25, 0.6, 400), 0.02, -4))),
    "taunt_fruitcake": lambda: throw(thud(70, 0.4)),
    "taunt_glitter_bomb": lambda: throw(mix(pop(500, 0.12), (twinkle(1.0, 14, 5), 0, -2), (hiss(0.6, 6000), 0, -14))),
    "taunt_honk": lambda: throw(mix(honk(), (honk(), 0.32, 0))),
    "taunt_kiss": lambda: throw(mix(mwah(), (twinkle(0.6, 5, 6), 0.3, -8))),
    "taunt_love_letter": lambda: throw(mix((K("rpg/bookFlip1"), 0, -4), (mwah(), 0.15, -4), (bell(1568, 0.6), 0.3, -10))),
    "taunt_mud_ball": lambda: throw(lowpass(splat(0.4, 0.7, 150), 900)),
    "taunt_paint_bomb": lambda: throw(mix(splash(0.6, 0.9), (splat(0.3), 0.02, -4))),
    "taunt_palayok": lambda: throw(mix(K("impact/impactPlate_heavy_002"), (crunch(0.6, 16), 0.05, -6), (twinkle(0.5, 4), 0.1, -12))),
    "taunt_poop": lambda: throw(mix(plop(200), (buzz(1.0, 180), 0.15, -10))),
    "taunt_pumpkin_pie": lambda: throw(splat(0.38, 1.1, 180)),
    "taunt_red_envelope": lambda: throw(mix((K("rpg/bookFlip2"), 0, -6), (J("sfx_coin_cluster4"), 0.08, 0))),
    "taunt_rotten_tomato": lambda: throw(mix(splat(0.3, 1.2, 260), (pop(300), 0.05, -10))),
    "taunt_rubber_chicken": lambda: throw(squawk(0.55)),
    "taunt_slime": lambda: throw(mix(fade(K("scifi/slime_001", length=0.9), 0, 0.2), (boing(140, 0.5) * 0.4, 0, -10))),
    "taunt_snowball": lambda: throw(mix(poof(0.45), (crunch(0.15, 4), 0, -10))),
    "taunt_stink_cloud": lambda: throw(mix((slide_whistle(900, 300, 0.6), 0, -6), (buzz(0.8, 150), 0.1, -12), (hiss(0.6, 2500), 0, -16))),
    "taunt_torotot": lambda: throw(mix(party_horn(0.7), (party_horn(0.5, 600), 0.75, 0))),
    "taunt_water_balloon": lambda: throw(mix(splash(0.7, 1.0), (pop(900, 0.06), 0, -6))),
    "taunt_cannonball": lambda: throw(mix(J("sfx_exp_short_hard6"), (poof(0.5), 0.02, -6))),
    "taunt_smoke_bomb": lambda: throw(mix(poof(0.6), (tone((3200, 2600), 0.18) * env_swell(0.18, 0.5), 0.15, -10), (tone((3000, 2500), 0.18) * env_swell(0.18, 0.5), 0.27, -12))),
    "taunt_wave_splash": lambda: throw(splash(0.9, 1.4)),
    "taunt_generic": lambda: throw(splat(0.3, 0.8)),
    # Move trails (short and quiet: they play on every move).
    "trail_whoosh": lambda: whoosh(0.35, 500, 2500),
    "trail_speed": lambda: whoosh(0.25, 1200, 5000),
    "trail_sparkle": lambda: twinkle(0.5, 5, 6),
    "trail_stars": lambda: arpeggio([1568, 2093, 2637], 0.05, 0.35),
    "trail_fire": lambda: fire_whoosh(0.45),
    "trail_electric": lambda: mix(K("digital/zap1"), (crackle(0.3, 120), 0, -8)),
    "trail_leaves": lambda: bandpass(noise(0.5, "pink"), 1500, 5000) * env_swell(0.5, 0.4),
    "trail_bubbles": lambda: bubbles(0.5, 6),
    "trail_coins": lambda: J("sfx_coin_single2"),
    "trail_smoke": lambda: poof(0.35),
    "trail_cogs": lambda: mix(K("impact/impactMetal_light_001"), (K("impact/impactMetal_light_003"), 0.08, -4)),
    "trail_pixels": lambda: chip8([1046.5, 1568], 0.05),
    "trail_thruster": lambda: K("scifi/thrusterFire_000", length=0.5),
    "trail_warp": lambda: K("digital/phaserUp2"),
    "trail_dust": lambda: mix(lowpass(noise(0.4, "pink"), 2500) * env_exp(0.4, 0.12), (crackle(0.3, 60), 0, -10)),
    "trail_ooze": lambda: fade(pitch(K("scifi/slime_000", length=0.6), 1.3), 0, 0.1),
    "trail_water": lambda: mix(plop(400), (bubbles(0.3, 3), 0.05, -6)),
    "trail_hearts": lambda: mix(pop(900, 0.08), (pop(1100, 0.08), 0.1, -2)),
    "trail_chime": lambda: mix(bell(1318.5, 0.5), (bell(1760, 0.5), 0.06, -3)),
    "trail_spray": lambda: hiss(0.4, 2500),
    "trail_crackle": lambda: highpass(crackle(0.5, 160), 1500),
    "trail_flutter": lambda: mix(flaps(0.5, 5), (squeak(4200, 0.06), 0.2, -8)),
    "trail_firefly": lambda: twinkle(0.5, 3, 4),
    # Auras and board glows: a soft shimmer, only when shown in the shop or on My Board.
    "aura_shimmer": lambda: shimmer(1.0),
    "aura_fire": lambda: mix(fire_whoosh(0.8), (crackle(0.8, 40), 0, -6)),
    "aura_electric": lambda: mix(K("digital/zap2"), (beam_hum(0.8, 120), 0, -10)),
    "aura_ice": lambda: mix(bell(2093, 0.8), (bell(2637, 0.8), 0.1, -4), (bell(3136, 0.8), 0.2, -8)),
    "aura_dark": lambda: mix(lowpass(vibrato_tone((110, 90), 1.0, 4, 0.05, "saw"), 600) * env_swell(1.0, 0.4), (whoosh(0.8, 200, 600), 0, -8)),
    "aura_holy": lambda: mix(pad(1.2, (523.25, 659.26, 783.99, 1046.5)) * env_swell(1.2, 0.3), (twinkle(1.0, 6, 6), 0, -10)),
    "aura_toxic": lambda: mix(bubbles(0.9, 10, 250, 800), (fade(K("scifi/slime_001", length=0.9), 0, 0.2), 0, -10)),
    "aura_love": lambda: mix(arpeggio([783.99, 987.77, 1174.66, 1567.98], 0.07, 0.5), (twinkle(0.6, 4), 0.2, -10)),
    "aura_nature": lambda: mix(bird_chirp(), (bandpass(noise(0.8, "pink"), 1500, 5000) * env_swell(0.8, 0.4), 0, -12)),
    "aura_water": lambda: mix(bubbles(0.6, 6), (plop(500), 0.1, -6)),
    # Toppers: a little sound when one is put on the table.
    "topper_pop": lambda: mix(pop(520, 0.12), (K("impact/impactWood_light_000"), 0, -8)),
    "topper_flag": lambda: mix(K("rpg/cloth2"), (K("rpg/cloth4"), 0.12, -4)),
    "topper_squeak": lambda: mix(squeak(2600, 0.12), (squeak(3000, 0.1), 0.14, -2)),
    "topper_rustle": lambda: bandpass(noise(0.45, "pink"), 1200, 5000) * env_swell(0.45, 0.3),
    "topper_clink": lambda: mix(K("impact/impactMetal_light_004"), (metal_ring(2200, 0.4), 0, -10)),
    "topper_chime": lambda: mix(bell(1318.5, 0.8), (bell(1975.5, 0.8), 0.08, -5)),
    "topper_spooky": lambda: ghost_boo(0.6, 240),
    "topper_animal": lambda: lowpass(mix(squawk(0.3), (squeak(1800, 0.08), 0.32, -6)), 3000),
    # Equipping the rest of a look.
    "equip_arena": lambda: mix((whoosh(0.6, 300, 1500), 0, -6), (bell(783.99, 0.8), 0.2, -10)),
    "equip_board": lambda: mix(K("impact/impactWood_medium_000"), (K("casino/chips-stack-2"), 0.05, -8)),
    "equip_territory": lambda: mix((whoosh(0.4, 600, 2000), 0, -8), (bell(1046.5, 0.5), 0.12, -12)),
    "equip_chip": lambda: K("casino/chips-stack-1"),
    "equip_shape": lambda: mix(pop(600), (pop(820), 0.06, -2)),
    "equip_icons": lambda: mix(K("impact/impactSoft_medium_000"), (K("rpg/bookPlace1"), 0.02, -6)),
    "equip_fire": lambda: mix(fire_whoosh(0.5), (crackle(0.4), 0.1, -8)),
    "equip_ice": lambda: mix(bell(2093, 0.6), (bell(2637, 0.6), 0.08, -5)),
    "equip_digital": lambda: mix(K("digital/zapTwoTone"), (chip8([880, 1318.5], 0.05), 0.05, -10)),
    "equip_water": lambda: mix(plop(380), (bubbles(0.4, 4), 0.05, -6)),
    "equip_space": lambda: K("digital/phaserUp5"),
    "equip_spooky": lambda: mix(ghost_boo(0.5, 230), (bell(311.13, 0.6), 0.1, -12)),
    "equip_sweet": lambda: twinkle(0.5, 5, 5),
    "equip_nature": lambda: mix(bird_chirp(), (bandpass(noise(0.4, "pink"), 1500, 5000) * env_swell(0.4, 0.4), 0, -14)),
    "equip_royal": lambda: arpeggio([523.25, 659.26, 783.99, 1046.5], 0.06, 0.6),
    "equip_military": lambda: mix(drum(140, 0.3, 0.4), (drum(140, 0.3, 0.4), 0.14, -4)),
}


# --- Looping ambience beds ---------------------------------------------------------------------

def _fireworks(d=8.0):
    layers = [(whistle_fall(0.8, 900, 2400) * 0.3, t, -14) for t in (0.5, 3.6, 6.1)]
    for t in (1.3, 4.4, 6.9):
        layers.append((lowpass(J("sfx_exp_medium5"), 1800), t, -8))
        layers.append((highpass(crackle(0.9, 140), 2000), t + 0.1, -16))
    return mix(*layers, length=d)


def beat_bed(d, bpm, tail=0.0, kick=True, snare=True, hats=True):
    """A simple beat on a grid that divides `d` (for periodic())."""
    beat = 60.0 / bpm
    layers = []
    for i in range(int(round(d / beat))):
        t = i * beat
        if kick and i % 2 == 0:
            layers.append((drum(60, 0.35), t, 0))
        if snare and i % 2 == 1:
            layers.append((bandpass(noise(0.18), 1200, 6000) * env_exp(0.18, 0.05, 0.001), t, -4))
        if hats:
            for k in range(2):
                layers.append((highpass(noise(0.04), 7000) * env_exp(0.04, 0.012, 0.0), t + k * beat / 2, -14))
    return mix(*layers, length=d + tail)


def tile(x, d):
    """Repeats a seamless source loop to fill `d` seconds."""
    n = int(round(d * S.SR))
    return np.tile(x, int(np.ceil(n / max(1, len(x)))))[:n].astype(np.float32)


def _caws(d, count, low=False):
    calls = [(lowpass(squawk(0.32), 1600 if low else 2600), _rng_t(d, i, count), -12) for i in range(count)]
    return mix(*calls, length=d)


def _rng_t(d, i, count):
    return (i + 0.3) * d / count


LOOPS = {
    "amb_rain": lambda: bed(8, rain_bed(8.4)),
    "amb_storm": lambda: bed(8, rain_bed(8.4, True), (thunder(2.5), 2.6, -6)),
    "amb_blizzard": lambda: bed(8, wind(8.4, 300, 1500, 0.2), (hiss(8.4, 4000), 0, -18)),
    "amb_snow": lambda: bed(8, wind(8.4, 200, 700, 0.1) * 0.5, (chimes(8.4, 5), 0, -16)),
    "amb_sand": lambda: bed(8, wind(8.4, 500, 3000, 0.18), (highpass(crackle(8.4, 30), 3000), 0, -14)),
    "amb_breeze": lambda: bed(8, wind(8.4, 250, 900, 0.12) * 0.6, (bandpass(noise(8.4, "pink"), 2000, 6000) * 0.15, 0, -6)),
    "amb_clouds": lambda: bed(8, wind(8.4, 200, 650, 0.08) * 0.5),
    "amb_birds": lambda: bed(8, birds_bed(8.4)),
    "amb_butterflies": lambda: bed(8, wind(8.4, 300, 900, 0.1) * 0.4, (twinkle(8.4, 6, 6), 0, -16), (bird_chirp(), 3.0, -16)),
    "amb_night": lambda: bed(8, crickets(8.4), (wind(8.4, 150, 500, 0.08) * 0.2, 0, 0)),
    "amb_haunted": lambda: bed(8, wind(8.4, 150, 600, 0.1) * 0.7, (ghost_boo(1.4, 190), 1.8, -12), (mix(tone(420, 0.25) * env_swell(0.25, 0.3), (tone(380, 0.4) * env_swell(0.4, 0.3), 0.32, 0)), 5.2, -14), (squeak(4200, 0.06), 3.7, -18)),
    "amb_bats": lambda: bed(8, wind(8.4, 150, 500, 0.08) * 0.3, *[(mix(flaps(0.5, 5), (squeak(4300, 0.05), 0.2, -6)), t, -10) for t in (0.6, 2.3, 4.0, 6.2)]),
    "amb_ghosts": lambda: bed(8, wind(8.4, 150, 500, 0.08) * 0.4, (ghost_boo(1.5, 220), 0.8, -10), (ghost_boo(1.3, 280), 4.6, -12)),
    "amb_fireworks": lambda: bed(8, _fireworks(8.4)),
    "amb_party": lambda: bed(8, crowd(8.4), (party_horn(0.5, 650), 2.2, -18), (flaps(1.0, 8), 5.0, -16)),
    "amb_parade": lambda: periodic(8, lambda d, tail: march_bed(d, 120, tail)) + bed(8, (crowd(8.4), 0, -6), (chimes(8.4, 6), 0, -14)),
    "amb_march": lambda: periodic(8, lambda d, tail: march_bed(d, 120, tail)),
    "amb_villagers": lambda: bed(8, crowd(8.4) * 0.5, *[(K(f"impact/footstep_grass_00{i % 5}"), 0.4 + i * 0.55, -12) for i in range(13)]),
    "amb_ufo": lambda: bed(8, beam_hum(8.4, 85) * 0.7),
    "amb_balloons": lambda: bed(8, wind(8.4, 200, 700, 0.08) * 0.5, (fire_whoosh(1.2), 2.5, -12), (fire_whoosh(1.0), 6.2, -14)),
    "amb_planes": lambda: bed(8, wind(8.4, 250, 800, 0.08) * 0.3, (whoosh(1.2, 400, 1200), 1.0, -10), (whoosh(1.0, 500, 1400), 4.8, -12)),
    "amb_bubbles": lambda: bed(8, bubbles(8.4, 34, 300, 1200)),
    "amb_aurora": lambda: bed(8, pad(8.4, (196.0, 293.66, 392.0, 587.33)) * 0.5, (shimmer(8.4), 0, -12)),
    "amb_meteors": lambda: bed(8, wind(8.4, 150, 500, 0.06) * 0.3, (whoosh(1.0, 2400, 300), 1.2, -10), (thud(45, 0.6), 2.2, -14), (whoosh(0.9, 2200, 300), 5.0, -12)),
    "amb_fog": lambda: bed(8, lowpass(noise(8.4, "brown"), 300) * 0.6, (pad(8.4, (98.0, 146.83, 196.0)) * 0.25, 0, 0)),
    "amb_lanterns": lambda: bed(8, wind(8.4, 250, 800, 0.1) * 0.4, (chimes(8.4, 8), 0, -10)),
    "amb_sleigh": lambda: periodic(8, lambda d, tail: sleigh_bells(d, 4.0, tail)) + bed(8, (wind(8.4, 250, 700, 0.1) * 0.3, 0, 0)),
    "amb_sea": lambda: bed(8, waves_bed(8.4), (gull_call(), 2.0, -14), (gull_call(), 6.0, -16)),
    "amb_hearts": lambda: bed(8, pad(8.4, (523.25, 659.26, 783.99)) * 0.2, (twinkle(8.4, 8, 5), 0, -12)),
    "amb_fire": lambda: bed(8, crackle(8.4, 40), (rumble(8.4, 100), 0, -10)),
    "amb_city": lambda: bed(8, beam_hum(8.4, 60) * 0.3, (crowd(8.4), 0, -12), (rain_bed(8.4) * 0.25, 0, -6)),
    "amb_cannons": lambda: bed(8, waves_bed(8.4) * 0.6, (lowpass(J("sfx_wpn_cannon3"), 900), 1.6, -10), (lowpass(J("sfx_wpn_cannon5"), 900), 5.1, -12)),
    "amb_choppers": lambda: bed(8, tile(lowpass(J("sfx_vehicle_helicopterloop1"), 1800), 8.4), (wind(8.4, 200, 600, 0.08) * 0.3, 0, 0)),
    "amb_dragon": lambda: bed(8, wind(8.4, 150, 600, 0.1) * 0.6, (whoosh(1.4, 200, 900), 2.0, -6), (fire_whoosh(1.0), 2.8, -8), (lowpass(vibrato_tone((140, 100), 0.6, 8, 0.08, "saw"), 700) * env_swell(0.6, 0.4), 2.4, -14)),
    "amb_heavenly": lambda: bed(8, pad(8.4, (392.0, 493.88, 587.33, 783.99)) * 0.45, (twinkle(8.4, 10, 6), 0, -12)),
    "amb_lasers": lambda: bed(8, pad(8.4, (110.0, 164.81, 220.0)) * 0.3, *[(K(f"digital/laser{i}"), 0.6 + i * 0.85, -14) for i in range(1, 9)]),
    "amb_gusts": lambda: bed(8, wind(8.4, 250, 1200, 0.25), (bandpass(noise(8.4, "pink"), 2000, 6000) * 0.25, 0, -4)),
    "amb_drones": lambda: bed(8, beam_hum(8.4, 140) * 0.5, *[(tone(1760, 0.08) * env_exp(0.08, 0.03), t, -16) for t in (1.0, 1.2, 4.3, 4.5, 6.7)]),
    "amb_pixel": lambda: bed(8, rain_bed(8.4) * 0.35, *[(chip8([float(f)], 0.05), t, -16) for f, t in zip([1046.5, 1318.5, 1568, 2093, 1174.66, 1760], [0.7, 2.1, 3.4, 4.8, 6.0, 7.2])]),
    "amb_ravens": lambda: bed(8, wind(8.4, 200, 800, 0.1) * 0.6, (_caws(8.4, 3, True), 0, 0)),
    "amb_hangar": lambda: bed(8, beam_hum(8.4, 50) * 0.4, (lowpass(noise(8.4, "brown"), 250), 0, -10), (K("impact/impactMetal_light_000"), 3.0, -16), (K("impact/impactMetal_medium_001"), 6.4, -18)),
    "amb_smoke": lambda: bed(8, wind(8.4, 200, 600, 0.08) * 0.3, (poof(0.6), 1.0, -8), (poof(0.6), 4.4, -10), (tone((3200, 2600), 0.18) * env_swell(0.18, 0.5), 1.3, -16), (tone((3000, 2500), 0.18) * env_swell(0.18, 0.5), 4.7, -16)),
    "amb_comic": lambda: bed(8, (pop(500, 0.12), 0.8, -10), (boing(220, 0.5), 2.2, -12), (K("digital/zap1"), 3.7, -14), (K("impact/impactPunch_medium_000"), 5.1, -12), (pop(700, 0.1), 6.6, -10)),
    "amb_concert": lambda: periodic(8, lambda d, tail: beat_bed(d, 120, tail, snare=False)) * 0.6 + bed(8, (crowd(8.4), 0, 0), (applause(1.6), 3.0, -10)),
    "amb_dogfight": lambda: bed(8, (whoosh(1.4, 300, 1500), 0.5, -8), (K("scifi/laserSmall_000"), 1.2, -12), (K("scifi/laserSmall_002"), 1.4, -12), (whoosh(1.2, 400, 1800), 4.2, -8), (K("scifi/laserRetro_001"), 4.8, -12), (K("scifi/laserSmall_004"), 5.0, -14)),
    "amb_steam": lambda: bed(8, (hiss(0.9, 1500), 0.6, -6), (hiss(0.7, 1800), 4.0, -8), *[(K("impact/impactMetal_light_002"), t, -18) for t in (1.8, 2.3, 5.6, 6.1)]),
    "amb_beats": lambda: periodic(8, lambda d, tail: beat_bed(d, 90, tail)) * 0.7 + bed(8, (hiss(0.5, 2500), 2.0, -14), (hiss(0.5, 2500), 6.0, -16)),
    "amb_toxic": lambda: bed(8, bubbles(8.4, 30, 200, 700), (lowpass(noise(8.4, "brown"), 300) * 0.5, 0, -6)),
    "amb_desert": lambda: bed(8, wind(8.4, 400, 2500, 0.15) * 0.7, (_caws(8.4, 2), 0, -2)),
    "amb_space": lambda: bed(8, pad(8.4, (110.0, 164.81, 220.0, 329.63)) * 0.4, (beam_hum(8.4, 55) * 0.15, 0, 0), (twinkle(8.4, 4, 7), 0, -18)),
}


# --- Music ---------------------------------------------------------------------------------------
# name -> (source file relative to SOURCES, kbps, description). Loops as published.

MUSIC = {
    "menu": ("x/musicbox/musicbox2_cute_tune.ogg", 64, "Cute music box tune (menus, dashboard)"),
    "menu_spooky": ("x/musicbox/musicbox1_spooky_waltz.ogg", 64, "Spooky music box waltz (Halloween season menus)"),
    "menu_winter": ("winter_dust.ogg", 80, "Winter Dust (Christmas and New Year season menus)"),
    "lobby": ("tiggo.ogg", 80, "Menu loop 'tiggo' (rooms, ranked search, lobby)"),
    "shop": ("happy_clappy.wav", 80, "Happy Clappy Loop (shop, My Board)"),
    "shop_alt": ("swinging_sweet.ogg", 80, "Swinging Sweet (shop, alternate)"),
    "match_a": ("tigrun.ogg", 80, "Level loop 'tigrun' (matches)"),
    "match_b": ("happy_adventure.mp3", 80, "Happy Adventure (matches)"),
    "match_c": ("just_saying_tho.ogg", 80, "Just Saying Tho (matches)"),
}

MUSIC_SOURCES = {
    "menu": ("4 Music Box Tracks", "Aureolus_Omicron", "https://opengameart.org/node/136996"),
    "menu_spooky": ("4 Music Box Tracks", "Aureolus_Omicron", "https://opengameart.org/node/136996"),
    "menu_winter": ("Short Loops Background Music Pack: Winter Dust", "hernandack", "https://opengameart.org/content/short-loops-background-music-pack"),
    "lobby": ("Two Simple Game Music Loops: menumusicloop-tiggo", "qubodup", "https://opengameart.org/content/two-simple-game-music-loops"),
    "shop": ("Happy Clappy Loop", "OwlishMedia", "https://opengameart.org/content/happy-clappy-loop"),
    "shop_alt": ("Short Loops Background Music Pack: Swinging Sweet", "hernandack", "https://opengameart.org/content/short-loops-background-music-pack"),
    "match_a": ("Two Simple Game Music Loops: levelmusicloop-tigrun", "qubodup", "https://opengameart.org/content/two-simple-game-music-loops"),
    "match_b": ("Happy Adventure (Loop)", "TinyWorlds", "https://opengameart.org/content/happy-adventure-loop"),
    "match_c": ("Short Loops Background Music Pack: Just Saying Tho", "hernandack", "https://opengameart.org/content/short-loops-background-music-pack"),
}

PACK_SOURCES = {
    "interface": ("Interface Sounds", "Kenney", "https://kenney.nl/assets/interface-sounds"),
    "impact": ("Impact Sounds", "Kenney", "https://kenney.nl/assets/impact-sounds"),
    "jingles": ("Music Jingles", "Kenney", "https://kenney.nl/assets/music-jingles"),
    "scifi": ("Sci-fi Sounds", "Kenney", "https://kenney.nl/assets/sci-fi-sounds"),
    "rpg": ("RPG Audio", "Kenney", "https://kenney.nl/assets/rpg-audio"),
    "casino": ("Casino Audio", "Kenney", "https://kenney.nl/assets/casino-audio"),
    "digital": ("Digital Audio", "Kenney", "https://kenney.nl/assets/digital-audio"),
    "junkala": ("The Essential Retro Video Game Sound Effects Collection [512 sounds]", "Juhani Junkala (SubspaceAudio)", "https://opengameart.org/content/512-sound-effects-8-bit-style"),
}


# --- Which shop item plays which sound -----------------------------------------------------------
# Explicit entries for every item at the time of writing; KEYWORDS (matched against the slug and
# the item name) and DEFAULTS cover items added later.

ITEMS = {
    "kill": {
        "classic": "kill_classic",
        **{s: s for s in [
            "kill_fire_explosion", "kill_ice_shatter", "kill_pixel_burst", "kill_confetti", "kill_lightning_strike",
            "kill_black_hole", "kill_sakura_burst", "kill_ghost", "kill_toxic_splat", "kill_star_shower",
            "kill_bazooka", "kill_wizard_fireball", "kill_earth_shaman", "kill_airstrike", "kill_ninja_slash",
            "kill_storm_caller", "kill_orbital_laser", "kill_anvil_drop", "kill_pocket_wormhole", "kill_freeze_ray",
            "kill_catapult", "kill_pirate_cannon", "kill_tornado", "kill_ufo_abduction", "kill_kraken",
            "kill_boxing_glove", "kill_dragon_breath", "kill_bubble_trap", "kill_meteor_call", "kill_ghost_pop",
            "kill_gift_box", "kill_firecracker", "kill_cupid_arrow", "kill_lion_dance", "kill_wave_crash",
            "kill_katana_draw", "kill_shuriken", "kill_glitch_out", "kill_rocket_punch", "kill_giant_stomp",
            "kill_plasma_blade", "kill_laser_disc", "kill_game_over", "kill_quick_draw", "kill_steam_cannon",
            "kill_thunder_hammer", "kill_mummy_wrap", "kill_balete_roots", "kill_ka_boom", "kill_grave_grab",
            "kill_wand_twinkle", "kill_mic_drop", "kill_skate_ollie",
        ]},
    },
    "taunt": {s: f"taunt_{s}" for s in [
        "banana_peel", "beach_ball", "candy_corn", "confetti_cannon", "cream_pie", "egg", "fruitcake",
        "glitter_bomb", "honk", "kiss", "love_letter", "mud_ball", "paint_bomb", "palayok", "poop", "pumpkin_pie",
        "red_envelope", "rotten_tomato", "rubber_chicken", "slime", "snowball", "stink_cloud", "torotot",
        "water_balloon", "cannonball", "smoke_bomb", "wave_splash",
    ]},
    "trail": {
        "none": "",
        "trail_autumn_leaves": "trail_leaves", "trail_bat_swarm": "trail_flutter", "trail_bubbles": "trail_bubbles",
        "trail_candy_cane": "trail_chime", "trail_cogs": "trail_cogs", "trail_data_stream": "trail_electric",
        "trail_dust_kick": "trail_dust", "trail_fiesta_confetti": "trail_crackle", "trail_fire": "trail_fire",
        "trail_firefly": "trail_firefly", "trail_frost_runes": "trail_chime", "trail_gold_coins": "trail_coins",
        "trail_gold_stars": "trail_stars", "trail_golden_sand": "trail_dust", "trail_hearts": "trail_hearts",
        "trail_hibiscus": "trail_leaves", "trail_koi": "trail_water", "trail_laurel": "trail_leaves",
        "trail_light_sticks": "trail_chime", "trail_lightning": "trail_electric", "trail_maple": "trail_leaves",
        "trail_neon_streak": "trail_sparkle", "trail_ooze": "trail_ooze", "trail_petals": "trail_leaves",
        "trail_pixels": "trail_pixels", "trail_rainbow": "trail_sparkle", "trail_ribbon_stars": "trail_stars",
        "trail_rose_petals": "trail_leaves", "trail_royal_sparkle": "trail_sparkle", "trail_rubble": "trail_dust",
        "trail_sea_foam": "trail_water", "trail_smoke": "trail_smoke", "trail_smoke_bomb": "trail_smoke",
        "trail_sparkle": "trail_sparkle", "trail_sparklers": "trail_crackle", "trail_speed_lines": "trail_speed",
        "trail_spray_paint": "trail_spray", "trail_stardust": "trail_stars", "trail_thruster": "trail_thruster",
        "trail_warp": "trail_warp",
    },
    "ambience": {
        "none": "",
        "ambience_army_march": "amb_march", "ambience_aurora": "amb_aurora", "ambience_autumn_leaves": "amb_breeze",
        "ambience_balloons": "amb_balloons", "ambience_banderitas": "amb_party", "ambience_bats": "amb_bats",
        "ambience_birds": "amb_birds", "ambience_blizzard": "amb_blizzard", "ambience_bubbles": "amb_bubbles",
        "ambience_butterflies": "amb_butterflies", "ambience_cherry_blossoms": "amb_breeze", "ambience_clouds": "amb_clouds",
        "ambience_confetti": "amb_party", "ambience_fireflies": "amb_night", "ambience_fireworks": "amb_fireworks",
        "ambience_fog": "amb_fog", "ambience_ghosts": "amb_ghosts", "ambience_harvest_breeze": "amb_breeze",
        "ambience_haunted_night": "amb_haunted", "ambience_heart_balloons": "amb_hearts",
        "ambience_kalayaan_fireworks": "amb_fireworks", "ambience_meteors": "amb_meteors",
        "ambience_midnight_fireworks": "amb_fireworks", "ambience_paper_planes": "amb_planes",
        "ambience_parade": "amb_parade", "ambience_rain": "amb_rain", "ambience_red_lanterns": "amb_lanterns",
        "ambience_sandstorm": "amb_sand", "ambience_santa_sleigh": "amb_sleigh", "ambience_seaside_gulls": "amb_sea",
        "ambience_snowfall": "amb_snow", "ambience_thunderstorm": "amb_storm", "ambience_ufo": "amb_ufo",
        "ambience_villagers": "amb_villagers",
        "ambience_broadside": "amb_cannons", "ambience_choppers": "amb_choppers",
        "ambience_dragon_flyover": "amb_dragon", "ambience_heavenly_rays": "amb_heavenly",
        "ambience_laser_horizon": "amb_lasers", "ambience_maple_wind": "amb_gusts", "ambience_neon_drones": "amb_drones",
        "ambience_pixel_weather": "amb_pixel", "ambience_raven_watch": "amb_ravens", "ambience_searchlights": "amb_hangar",
        "ambience_smoke_bombs": "amb_smoke", "ambience_sound_effects": "amb_comic", "ambience_stage_lights": "amb_concert",
        "ambience_starfighters": "amb_dogfight", "ambience_steam_works": "amb_steam", "ambience_street_beats": "amb_beats",
        "ambience_toxic_mist": "amb_toxic", "ambience_tumbleweeds": "amb_desert", "ambience_twinkle_dust": "amb_hearts",
        "ambience_wave_spray": "amb_sea",
    },
}

# Ordered [keyword, sound] rules, checked against "<slug> <item name>" in lower case.
KEYWORDS = {
    "kill": [
        ["fire", "kill_fire_explosion"], ["flame", "kill_fire_explosion"], ["ice", "kill_ice_shatter"],
        ["frost", "kill_ice_shatter"], ["pixel", "kill_pixel_burst"], ["8-bit", "kill_pixel_burst"],
        ["laser", "kill_orbital_laser"], ["lightning", "kill_lightning_strike"], ["thunder", "kill_lightning_strike"],
        ["ghost", "kill_ghost"], ["boo", "kill_ghost"], ["wave", "kill_wave_crash"], ["water", "kill_kraken"],
        ["cannon", "kill_pirate_cannon"], ["sword", "kill_katana_draw"], ["blade", "kill_plasma_blade"],
        ["star", "kill_star_shower"], ["confetti", "kill_confetti"], ["petal", "kill_sakura_burst"],
        ["toxic", "kill_toxic_splat"], ["goo", "kill_toxic_splat"], ["boom", "kill_ka_boom"], ["punch", "kill_boxing_glove"],
        ["stomp", "kill_giant_stomp"], ["magic", "kill_wand_twinkle"], ["wand", "kill_wand_twinkle"],
    ],
    "taunt": [
        ["pie", "taunt_cream_pie"], ["egg", "taunt_egg"], ["ball", "taunt_beach_ball"], ["snow", "taunt_snowball"],
        ["water", "taunt_water_balloon"], ["horn", "taunt_torotot"], ["confetti", "taunt_confetti_cannon"],
        ["glitter", "taunt_glitter_bomb"], ["kiss", "taunt_kiss"], ["heart", "taunt_kiss"], ["coin", "taunt_red_envelope"],
        ["envelope", "taunt_red_envelope"], ["slime", "taunt_slime"], ["mud", "taunt_mud_ball"], ["paint", "taunt_paint_bomb"],
        ["pot", "taunt_palayok"], ["chicken", "taunt_rubber_chicken"], ["candy", "taunt_candy_corn"],
    ],
    "trail": [
        ["fire", "trail_fire"], ["flame", "trail_fire"], ["spark", "trail_sparkle"], ["star", "trail_stars"],
        ["leaf", "trail_leaves"], ["leaves", "trail_leaves"], ["petal", "trail_leaves"], ["flower", "trail_leaves"],
        ["bubble", "trail_bubbles"], ["water", "trail_water"], ["wave", "trail_water"], ["foam", "trail_water"],
        ["coin", "trail_coins"], ["gold", "trail_coins"], ["smoke", "trail_smoke"], ["pixel", "trail_pixels"],
        ["lightning", "trail_electric"], ["neon", "trail_electric"], ["data", "trail_electric"], ["laser", "trail_electric"],
        ["warp", "trail_warp"], ["thruster", "trail_thruster"], ["jet", "trail_thruster"], ["dust", "trail_dust"],
        ["sand", "trail_dust"], ["heart", "trail_hearts"], ["ooze", "trail_ooze"], ["paint", "trail_spray"],
        ["confetti", "trail_crackle"], ["cog", "trail_cogs"], ["gear", "trail_cogs"], ["bat", "trail_flutter"],
    ],
    "ambience": [
        ["thunder", "amb_storm"], ["storm", "amb_storm"], ["rain", "amb_rain"], ["blizzard", "amb_blizzard"],
        ["snow", "amb_snow"], ["winter", "amb_snow"], ["sand", "amb_sand"], ["desert", "amb_sand"],
        ["sea", "amb_sea"], ["ocean", "amb_sea"], ["wave", "amb_sea"], ["ship", "amb_sea"], ["koi", "amb_sea"],
        ["pirate", "amb_sea"], ["firework", "amb_fireworks"], ["lantern", "amb_lanterns"], ["sleigh", "amb_sleigh"],
        ["bell", "amb_sleigh"], ["ghost", "amb_ghosts"], ["haunt", "amb_haunted"], ["zombie", "amb_haunted"],
        ["spooky", "amb_haunted"], ["grave", "amb_haunted"], ["bat", "amb_bats"], ["firefl", "amb_night"],
        ["night", "amb_night"], ["bird", "amb_birds"], ["forest", "amb_birds"], ["jungle", "amb_birds"],
        ["bamboo", "amb_birds"], ["butterfl", "amb_butterflies"], ["bubble", "amb_bubbles"], ["aurora", "amb_aurora"],
        ["space", "amb_space"], ["star", "amb_space"], ["meteor", "amb_meteors"], ["ufo", "amb_ufo"],
        ["neon", "amb_city"], ["cyber", "amb_city"], ["city", "amb_city"], ["fire", "amb_fire"], ["lava", "amb_fire"],
        ["steam", "amb_fire"], ["fog", "amb_fog"], ["mist", "amb_fog"], ["parade", "amb_parade"],
        ["march", "amb_march"], ["army", "amb_march"], ["party", "amb_party"], ["fiesta", "amb_party"],
        ["concert", "amb_party"], ["confetti", "amb_party"], ["heart", "amb_hearts"], ["balloon", "amb_balloons"],
        ["plane", "amb_planes"], ["cloud", "amb_clouds"], ["villag", "amb_villagers"], ["leaves", "amb_breeze"],
        ["petal", "amb_breeze"], ["blossom", "amb_breeze"],
    ],
    "aura": [
        ["fire", "aura_fire"], ["flame", "aura_fire"], ["lava", "aura_fire"], ["inferno", "aura_fire"], ["ember", "aura_fire"],
        ["lightning", "aura_electric"], ["electric", "aura_electric"], ["storm", "aura_electric"], ["neon", "aura_electric"],
        ["plasma", "aura_electric"], ["cyber", "aura_electric"], ["ice", "aura_ice"], ["frost", "aura_ice"], ["snow", "aura_ice"],
        ["crystal", "aura_ice"], ["shadow", "aura_dark"], ["dark", "aura_dark"], ["void", "aura_dark"], ["ghost", "aura_dark"],
        ["spooky", "aura_dark"], ["witch", "aura_dark"], ["holy", "aura_holy"], ["angel", "aura_holy"], ["divine", "aura_holy"],
        ["royal", "aura_holy"], ["gold", "aura_holy"], ["sun", "aura_holy"], ["toxic", "aura_toxic"], ["poison", "aura_toxic"],
        ["slime", "aura_toxic"], ["heart", "aura_love"], ["love", "aura_love"], ["rose", "aura_love"], ["leaf", "aura_nature"],
        ["nature", "aura_nature"], ["flower", "aura_nature"], ["petal", "aura_nature"], ["water", "aura_water"],
        ["bubble", "aura_water"], ["wave", "aura_water"], ["ocean", "aura_water"],
    ],
    "topper": [
        ["jack", "topper_spooky"], ["pumpkin", "topper_spooky"], ["treasure", "coins"], ["chest", "coins"],
        ["piggy", "coins"], ["wand", "equip_sweet"], ["boombox", "equip_digital"], ["arcade", "equip_digital"],
        ["lava lamp", "trail_bubbles"], ["planet", "equip_space"], ["flag", "topper_flag"], ["banner", "topper_flag"], ["pennant", "topper_flag"], ["standard", "topper_flag"],
        ["duck", "topper_squeak"], ["toy", "topper_squeak"], ["plush", "topper_squeak"], ["teddy", "topper_squeak"],
        ["cactus", "topper_rustle"], ["succulent", "topper_rustle"], ["bonsai", "topper_rustle"], ["sunflower", "topper_rustle"],
        ["tree", "topper_rustle"], ["flower", "topper_rustle"], ["bouquet", "topper_rustle"], ["plant", "topper_rustle"],
        ["robot", "topper_clink"], ["mecha", "topper_clink"], ["trophy", "topper_clink"], ["rocket", "topper_clink"],
        ["statue", "topper_clink"], ["airship", "topper_clink"], ["fan", "topper_clink"], ["mug", "topper_clink"],
        ["lantern", "topper_chime"], ["parol", "topper_chime"], ["globe", "topper_chime"], ["crystal", "topper_chime"],
        ["light", "topper_chime"], ["bell", "topper_chime"], ["tomb", "topper_spooky"], ["grave", "topper_spooky"],
        ["cauldron", "topper_spooky"], ["ghost", "topper_spooky"], ["skull", "topper_spooky"], ["pumpkin", "topper_spooky"],
        ["jack", "topper_spooky"], ["parrot", "topper_animal"], ["turkey", "topper_animal"], ["bunny", "topper_animal"],
        ["cat", "topper_animal"], ["dino", "topper_animal"], ["koi", "topper_animal"],
    ],
}
# Arenas, boards, territories, chips, shapes and icon packs share the equip keywords.
_EQUIP_KEYWORDS = [
    ["lava", "equip_fire"], ["fire", "equip_fire"], ["volcano", "equip_fire"], ["inferno", "equip_fire"], ["ember", "equip_fire"],
    ["ice", "equip_ice"], ["snow", "equip_ice"], ["frost", "equip_ice"], ["winter", "equip_ice"], ["crystal", "equip_ice"],
    ["neon", "equip_digital"], ["cyber", "equip_digital"], ["synth", "equip_digital"], ["arcade", "equip_digital"],
    ["pixel", "equip_digital"], ["hologram", "equip_digital"], ["circuit", "equip_digital"], ["robot", "equip_digital"],
    ["ocean", "equip_water"], ["sea", "equip_water"], ["wave", "equip_water"], ["pirate", "equip_water"], ["beach", "equip_water"],
    ["koi", "equip_water"], ["water", "equip_water"], ["space", "equip_space"], ["star", "equip_space"], ["galaxy", "equip_space"],
    ["cosmic", "equip_space"], ["moon", "equip_space"], ["planet", "equip_space"], ["spooky", "equip_spooky"],
    ["haunt", "equip_spooky"], ["grave", "equip_spooky"], ["ghost", "equip_spooky"], ["pumpkin", "equip_spooky"],
    ["zombie", "equip_spooky"], ["candy", "equip_sweet"], ["sweet", "equip_sweet"], ["heart", "equip_sweet"],
    ["love", "equip_sweet"], ["sakura", "equip_sweet"], ["pastel", "equip_sweet"], ["jungle", "equip_nature"],
    ["forest", "equip_nature"], ["garden", "equip_nature"], ["bamboo", "equip_nature"], ["meadow", "equip_nature"],
    ["royal", "equip_royal"], ["gold", "equip_royal"], ["castle", "equip_royal"], ["olymp", "equip_royal"],
    ["army", "equip_military"], ["camo", "equip_military"], ["military", "equip_military"], ["tank", "equip_military"],
]
for _cat in ("arena", "board", "territory", "chip", "shape", "icons", "glow"):
    KEYWORDS.setdefault(_cat, list(_EQUIP_KEYWORDS))
KEYWORDS["glow"] = KEYWORDS["aura"] + KEYWORDS["glow"]

DEFAULTS = {
    "kill": "kill_generic", "taunt": "taunt_generic", "trail": "trail_whoosh", "ambience": "amb_breeze",
    "aura": "aura_shimmer", "glow": "aura_shimmer", "topper": "topper_pop", "arena": "equip_arena",
    "board": "equip_board", "territory": "equip_territory", "chip": "equip_chip", "shape": "equip_shape",
    "icons": "equip_icons",
}

# Labels for the Sound test screen.
GROUPS = [
    ("Music", list(MUSIC.keys())),
    ("Interface", [n for n in SFX if n.startswith("ui_")] + ["coins", "daily_reward", "rank_up", "achievement"]),
    ("Gameplay", ["piece_pickup", "piece_place", "piece_move", "setup_shuffle", "ready", "match_start", "your_turn",
                  "clash_hit", "clash_tie", "flag_capture", "timer_tick", "timer_urgent", "timeout", "card_draw",
                  "card_flip", "card_slam", "card_reveal", "powerup_good", "powerup_bad", "chat_message", "shoutout",
                  "victory", "defeat"]),
]
