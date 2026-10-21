# Powerup card art

`generate_card_art.js` draws one original illustration per powerup (toon style, ink outlines, the
game's palette, a backdrop per card type) and renders it with headless Edge/Chrome into
`assets/powerups/art/<id>.webp` (448x336). The game draws the card frames itself
(`ui/widgets/PowerupCard.gd`), so these are only the art windows.

```sh
NODE_PATH=<dir with puppeteer-core> node tools/powerups/generate_card_art.js [--only id,id] [--sheet sheet.png]
```

A new powerup needs a scene in `SCENES` (keyed by its id, with its card type). The art imports with
mipmaps (`mipmaps/generate=true` in each `.import`) so small in-match cards stay smooth.

`bundle_icons.js` bundles the small glyph icons (game-icons.net, CC BY 3.0) used in toasts and banners.
