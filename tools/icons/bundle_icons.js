// Bundles every pack's SVG sources into one JSON resource per pack for the game to load.
//   node tools/icons/bundle_icons.js
// Reads assets/icons/src/<pack>/<RANK>.svg (ignored by Godot via .gdignore) and writes
// assets/icons/packs/<pack>.json = {"G5": "<svg…>", …}. PieceIcons rasterises these at runtime at
// the resolution the device can afford, so the web download carries compact SVG text instead of
// hundreds of pre-rendered textures.

const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..', '..', 'assets', 'icons', 'src');
const OUT = path.join(__dirname, '..', '..', 'assets', 'icons', 'packs');
const RANKS = ['G5', 'G4', 'G3', 'G2', 'G1', 'COL', 'LTC', 'MAJ', 'CPT', '1LT', '2LT', 'SGT', 'PVT', 'SPY', 'FLG', 'UNKNOWN'];

fs.mkdirSync(OUT, { recursive: true });
let total = 0;
for (const pack of fs.readdirSync(SRC).filter((d) => fs.statSync(path.join(SRC, d)).isDirectory()).sort()) {
  const bundle = {};
  for (const rank of RANKS) {
    const file = path.join(SRC, pack, `${rank}.svg`);
    if (!fs.existsSync(file)) throw new Error(`missing ${pack}/${rank}.svg`);
    bundle[rank] = fs.readFileSync(file, 'utf8').trim();
  }
  const json = JSON.stringify(bundle);
  fs.writeFileSync(path.join(OUT, `${pack}.json`), json);
  total += json.length;
  console.log(`${pack}.json  ${(json.length / 1024).toFixed(0)} KB`);
}
console.log(`total ${(total / 1024 / 1024).toFixed(2)} MB`);
