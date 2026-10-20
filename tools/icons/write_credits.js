// Writes assets/icons/CREDITS.md from the game-icons.net glyphs that generate_icon_packs.js uses.
//   node tools/icons/write_credits.js
// Run after changing which glyphs the packs use; it also fails if a used glyph isn't vendored.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const VENDOR = path.join(__dirname, 'vendor', 'game-icons');
const src = fs.readFileSync(path.join(__dirname, 'generate_icon_packs.js'), 'utf8');
const AUTHORS = { lorc: ['Lorc', 'http://lorcblog.blogspot.com'], delapouite: ['Delapouite', 'https://delapouite.com'] };

const used = [...new Set([...src.matchAll(/'((?:lorc|delapouite)\/[a-z0-9-]+)'/g)].map((m) => m[1]))].sort();
for (const g of used) {
  if (!fs.existsSync(path.join(VENDOR, `${g}.svg`))) throw new Error(`used glyph not vendored: ${g}`);
}

// Which packs use each glyph: slice the source into the per-pack blocks of packsFromGlyphs.
const body = src.slice(src.indexOf('const packsFromGlyphs'));
const blocks = [...body.matchAll(/^ {2}(\w+): \{$/gm)].map((m, i, all) => ({
  slug: m[1], text: body.slice(m.index, i + 1 < all.length ? all[i + 1].index : body.length),
}));

let rows = '';
for (const g of used) {
  const [author, name] = g.split('/');
  const packs = blocks.filter((b) => b.text.includes(`'${g}'`)).map((b) => b.slug).join(', ');
  rows += `| ${name} | ${AUTHORS[author][0]} | https://game-icons.net/1x1/${author}/${name}.html | ${packs} |\n`;
}

const authors = [...new Set(used.map((g) => g.split('/')[0]))].map((a) => `${AUTHORS[a][0]} (${AUTHORS[a][1]})`).join(' and ');
const md = `# Third-party icon credits

The rank icon packs are compositions made by \`tools/icons/generate_icon_packs.js\` and
\`tools/icons/generate_piece_badges.js\`. Some packs place glyphs from **game-icons.net** inside our own
medallions; those glyphs are recoloured and given an ink outline, otherwise unchanged.

- Source: https://game-icons.net (repository https://github.com/game-icons/icons)
- Licence: Creative Commons Attribution 3.0 Unported (CC BY 3.0), https://creativecommons.org/licenses/by/3.0/
  (commercial use allowed with attribution)
- Unmodified copies of every glyph used are kept in \`tools/icons/vendor/game-icons/\` with the upstream licence notice.

Icons made by ${authors}, from https://game-icons.net, licensed CC BY 3.0.

| Glyph | Author | Source | Used in packs |
|---|---|---|---|
${rows}
Everything else in the packs (medallions, stars, suns, pips, chevrons, bars, hearts, sakura, planets, etc.)
is drawn by our scripts.
`;
fs.writeFileSync(path.join(ROOT, 'assets', 'icons', 'CREDITS.md'), md);
console.log(`CREDITS.md: ${used.length} glyphs`);
