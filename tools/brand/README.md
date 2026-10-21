# Brand: logo, icon, web loader

The Salpakan Tactics! logo is generated from code. It is an original design: a shield with a
faceted star, the arched SALPAKAN wordmark and the TACTICS! ribbon. The wordmark uses
Lilita One (SIL OFL, `assets/fonts/LilitaOne-OFL.txt`), with the text converted to paths.

```sh
# 1. SVGs, icon.svg and web/shell.html (needs opentype.js)
NODE_PATH=<dir with opentype.js@1.3.4> node tools/brand/generate_logo.js
# 2. PNGs (needs puppeteer-core and Edge/Chrome; set BROWSER for another binary)
NODE_PATH=<dir with puppeteer-core> node tools/brand/render_png.js [--web ../games-of-the-generals-web/public] [--preview <dir>]
```

| Output | Used by |
| --- | --- |
| `assets/brand/src/logo.svg`, `emblem.svg`, `logo.png` | Source art (ignored by Godot) |
| `assets/brand/layers/*.png` (mipmapped) | `ui/widgets/GameLogo.gd`, the animated in-game logo (title screen, dashboard) |
| `assets/brand/splash.png` (imported as "Keep File") | Godot boot splash: Keep stretch on the `#1d1736` splash colour |
| `icon.svg` | App icon; the web export turns it into the favicon and the apple-touch icon |
| `web/shell.html` | Custom HTML shell of the Web export preset: an animated logo loader with progress and tips |
| `--web`: `public/brand/*`, `public/favicon.ico` | Website icons, logo and social preview image |

Edit `web/shell.src.html`, never `shell.html`: the generator inlines the animated logo SVG and
the font into the source to produce `shell.html`. The loader stays up until the game calls
`window.salpakanBooted()` (`TitleScreen._notify_web_loader`), or until 8 s after the engine
starts. It then fades into the canvas.

`GameLogo.gd` hard-codes the layer boxes from `assets/brand/src/layout.json`. Update its
`LAYERS` and `SPARKLES` constants if the geometry changes.
