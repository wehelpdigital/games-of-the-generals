# Salpakan Tactics! — Godot client

Real-time 3D Salpakan with a cel-shaded, toy-like anime look. Runs in the browser today (HTML5 /
WebGL 2) and is built for Android and iOS later: Godot 4.7, Compatibility renderer, touch-first
controls. The Laravel API in `wehelpdigital/games-of-the-generals-web` is the online arbiter; its
`docs/API.md` is the contract.

## Playing

- **Browser:** <https://games-of-the-generals-web-production-6zraos.laravel.cloud/> serves the latest
  web export.
- **Editor:** open the folder in Godot 4.7 and press Play. You land on the title screen:
  - **Play vs AI**: offline practice against Rookie, Officer or General difficulty.
  - **Play Online**: log in, then use the global lobby: quick match, host a match, join one from
    the list, or resume your open match.
  - **Leaderboard** (all-time or monthly) and **Shop** (cosmetic boards and piece skins, previewed
    live on the 3D board).

The client talks to production by default. To use a local backend, pass
`-- --api-url=http://127.0.0.1:8000` or set `GOTG_API_URL`.

**Controls:** tap or click one of your pieces, then a highlighted tile, or drag the piece. Drag the
empty board (or right-drag) to orbit, middle-drag or two fingers to pan, and use the wheel or a
pinch to zoom.

## Project layout

```text
res://
├── autoload/
│   ├── ApiManager.gd        REST client; Sanctum token in user://auth.json
│   ├── ReverbManager.gd     Pusher-protocol WebSocket client for Laravel Reverb
│   └── GameSession.gd       Current match: online (API + realtime + polling) or offline vs AI
├── core/                    Rules and generated content, no scene dependencies
│   ├── Ranks.gd             Board, the 21-piece set, clash rules
│   ├── LocalArbiter.gd      Full-information referee for offline games
│   ├── SalpakanAI.gd        Offline opponent (fair: learns ranks only from clashes)
│   ├── PieceIcons.gd        Chibi rank portraits shown on piece faces (and usable in UI)
│   ├── InsigniaFactory.gd   Rounded slabs, outline hulls, emblem and FX shapes
│   └── CosmeticLibrary.gd   Toon materials for every board theme / piece skin (shop slugs)
├── scenes/
│   ├── main/Main.tscn       Entry: Game3D underneath, UI on top
│   └── game/                Game3D (scene glue), Board3D, Piece3D, CameraRig, ClashFX
├── ui/
│   ├── UIRoot.gd            Screen manager, toasts, confirm dialogs
│   ├── theme/AppTheme.gd    Candy buttons, cards, fonts, colours
│   └── screens/             Title, AiSetup, Auth, Lobby, Leaderboard, Shop, GameHUD
├── assets/fonts/            Lilita One + Fredoka (SIL OFL, licences alongside)
├── assets/icons/pieces/     One anime mascot SVG per rank (generated, see tools/)
├── tools/icons/             generate_piece_icons.js: node tools/icons/generate_piece_icons.js
└── tests/                   Headless smoke tests, AI benchmark, screenshot renderers
```

## The AI

`SalpakanAI` never peeks at hidden ranks. Each enemy piece carries the set of ranks it could still
be; every clash narrows it (the AI knows its own piece's rank), and pieces that never moved from the
back row are more likely to be the flag. To move, it samples complete rank assignments consistent
with everything observed, scores each legal move across them (material, threats, flag safety, flag
hunting), and on General also considers your best reply. Work is spread across frames, so it never
freezes the game, even in single-threaded browsers.

Benchmark (10 games each): General beats a random mover 10/10, Rookie 10/10, Officer 7/10, at about
80 ms per move.

## Tests

```text
godot --headless --path . res://tests/PracticeSmokeTest.tscn      # offline game through pointer input
godot --headless --path . res://tests/AiBenchmark.tscn -- --games=10
godot --headless --path . res://tests/OnlineSmokeTest.tscn -- --api-url=http://127.0.0.1:8000
godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/UiScreenshots.tscn -- --out=<dir>
```

The online test needs a local API and Reverb (see `docs/API.md` in the web repo) on a fresh database.

## Publishing the browser build

Export templates for 4.7.2 must be installed (Editor → Manage Export Templates). Then:

```text
godot --headless --path . --export-release "Web" ../games-of-the-generals-web/public/play/index.html
```

Commit `public/play/` in the web repo and push; Laravel Cloud deploys it and serves it at `/`. The
export is single-threaded, so no cross-origin-isolation headers are needed.
