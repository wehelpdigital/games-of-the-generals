# Web build checks

These are headless browser checks for the exported web build. They need Node, `puppeteer-core` and Edge or Chrome.

```sh
# Serve an export. <dir> must contain play/index.html.
node tools/web/serve.js <dir> 8099
node tools/web/checks.js flow  http://127.0.0.1:8099/play/index.html   # load, first click, match start, FPS, stalls
LOGIN_USER=... LOGIN_PASS=... node tools/web/checks.js login http://127.0.0.1:8099/play/index.html
node tools/web/checks.js sweep http://127.0.0.1:8099/play/index.html   # every cosmetic on software GL
node tools/web/checks.js phone http://127.0.0.1:8099/play/index.html   # phone keyboard opens on a login field
```

Two URL options help with debugging:
- `?perf=1` makes the game print FPS, frame times and draw calls to the console (`core/PerfProbe.gd`).
- `?sweep=1` makes it wear every cosmetic in turn (`core/ShaderSweep.gd`).

First visits are slow in Chromium on Windows, because WebGL compiles each shader through Direct3D at about 0.1–0.6 s apiece. The game works around this in two ways:
- `Game3D._warm_up` compiles the shaders behind the loader, one material at a time.
- `core/Graphics.gd` keeps the title, the practice AI and the guest showcase on looks that are already compiled.

Chrome caches compiled shaders, so repeat visits are faster.
