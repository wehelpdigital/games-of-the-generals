// Bundles the game-icons.net glyphs offered as flag emblems into one JSON resource.
//   node tools/icons/bundle_flag_emblems.js
// Reads tools/icons/vendor/game-icons/<author>/<name>.svg (512×512, black backdrop + white glyph)
// and writes assets/icons/flag_emblems.json = {"<name>": "<path d>", …} for FlagFactory. The glyphs
// are CC BY 3.0 (see assets/icons/CREDITS.md).

const fs = require('fs');
const path = require('path');

const VENDOR = path.join(__dirname, 'vendor', 'game-icons');
const OUT = path.join(__dirname, '..', '..', 'assets', 'icons', 'flag_emblems.json');
const GLYPHS = {
  raven: 'lorc/raven',
  dragon: 'delapouite/spiked-dragon-head',
  helmet: 'delapouite/viking-helmet',
  hammer: 'delapouite/thor-hammer',
  fist: 'lorc/fist',
  comet: 'lorc/comet-spark',
  ghost: 'lorc/ghost',
  moon: 'lorc/moon',
};

const bundle = {};
for (const [key, file] of Object.entries(GLYPHS)) {
  const svg = fs.readFileSync(path.join(VENDOR, `${file}.svg`), 'utf8');
  const paths = [...svg.matchAll(/<path[^>]*\sd="([^"]+)"/g)].map((m) => m[1]);
  const glyph = paths.filter((d) => d !== 'M0 0h512v512H0z');
  if (glyph.length === 0) throw new Error(`no glyph in ${file}`);
  bundle[key] = glyph.join(' ');
}
fs.writeFileSync(OUT, JSON.stringify(bundle));
console.log(`${Object.keys(bundle).length} emblems, ${(fs.statSync(OUT).size / 1024).toFixed(1)} KB`);
