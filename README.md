# Game of the Generals — Godot client

Real-time 3D Salpakan for web (HTML5 / WebGL 2), Android and iOS. Godot 4.7, Compatibility renderer.
The Laravel API in `wehelpdigital/games-of-the-generals-web` is the arbiter: it validates every move,
resolves clashes and hides enemy ranks. This client only shows what the server tells it. The API
contract is in that repo at `docs/API.md`.

## Project layout

```
res://
├── autoload/                 Singletons (registered in project.godot)
│   ├── ApiManager.gd         REST client, Sanctum token in user://auth.json
│   ├── ReverbManager.gd      Pusher-protocol WebSocket client for Laravel Reverb
│   └── GameSession.gd        Current match: API + realtime + polling fallback, offline practice
├── core/                     Pure logic and generated content, no scene dependencies
│   ├── Ranks.gd              Board size, 21-piece set, clash rules (offline practice only)
│   ├── InsigniaFactory.gd    Extruded star/sun/triangle/chevron/eye/flag meshes
│   └── CosmeticLibrary.gd    Board themes and piece skins as StandardMaterial3D, keyed by shop slug
├── scenes/
│   ├── main/Main.tscn        Entry scene: Game3D + DevHUD
│   └── game/
│       ├── Game3D.tscn       Environment, lights, camera rig, board
│       ├── Game3D.gd         Wires GameSession to the board
│       ├── Board3D.gd        9×8 board, raycast picking, drag-and-drop, highlights, animation queue
│       ├── Piece3D.gd        Plaque piece, insignia, lift/slide/clash/eliminate tweens
│       ├── CameraRig.gd      Clamped orbit/pan/zoom for mouse and touch, camera shake
│       └── ClashFX.gd        CPUParticles3D sparks, dust, shockwave, flash
├── ui/
│   ├── dev/DevHUD.gd         Phase 1 test panel (login, practice, matchmaking, skin previews)
│   ├── auth/  leaderboard/  shop/  theme/      Phase 2 screens
├── assets/  models/ textures/ audio/ fonts/   Imported art (empty until real meshes arrive)
├── materials/  boards/ pieces/ fx/            .tres overrides once art replaces the generated looks
└── tests/                    Headless smoke tests
```

## Running

Open the folder in Godot 4.7 and press Play. Without logging in you can play **Practice offline**
against a random-move bot.

The client talks to production by default. To use a local backend, pass a user argument or set
`GOTG_API_URL`:

```
godot --path . -- --api-url=http://127.0.0.1:8000
```

**Controls:** tap or click one of your pieces, then a highlighted tile, or drag the piece. Drag on an
empty part of the board (or right-drag) to orbit, middle-drag or two fingers to pan, and use the
wheel or a pinch to zoom.

## Tests

```
# Offline: setup, tap and drag moves, clashes, resignation, rank reveal
godot --headless --path . res://tests/PracticeSmokeTest.tscn

# Online: needs a local API and Reverb (see docs/API.md in the web repo)
godot --headless --path . res://tests/OnlineSmokeTest.tscn -- --api-url=http://127.0.0.1:8000
```

## Rendering notes

- The renderer is Compatibility, so web, Android and iOS share one path. SSAO and SSR are turned on
  automatically if the project is switched to Forward+ or Mobile. On Compatibility, each piece has a
  blob contact shadow in their place.
- Clash effects use `CPUParticles3D` so they look the same on WebGL 2.
