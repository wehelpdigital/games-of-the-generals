// Generates the rank badges shown on each piece's face.
//   node tools/icons/generate_piece_badges.js
// Writes assets/icons/src/classic/<RANK>.svg (256 viewBox, 512 px); run bundle_icons.js afterwards.
//
// All artwork here is drawn from scratch for this game: enamel-pin style medallions with faceted
// gold insignia. The rank symbols follow public Philippine Army conventions (stars for generals,
// suns for field officers, triangles for company officers, chevrons for enlisted) but no shape is
// traced from any existing board game. The Spy is a faceless fedora-and-collar agent and the Flag
// is an original swallowtail banner, deliberately unlike the classic "eyes" and national flag.

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', '..', 'assets', 'icons', 'src', 'classic');
const INK = '#1d1736';
const METAL = { light: '#ffe680', mid: '#ffc93c', dark: '#ef9f0f' };
const SILVER = { light: '#ffffff', mid: '#e9e6f5', dark: '#bdb8d6' };

// Medallion colours per rank group: [centre, edge].
const TIERS = {
  general: ['#5470e0', '#1f2a6e'],
  field: ['#ec5a72', '#8f1d33'],
  company: ['#41aee6', '#145d8c'],
  enlisted: ['#52c47a', '#1f6b3a'],
  spy: ['#5a5672', '#1b1a28'],
  flag: ['#fffaf0', '#f0d6a2'],
  unknown: ['#8b84a8', '#3a3552'],
};

const fmt = (n) => Number(n.toFixed(2));
const poly = (pts) => 'M' + pts.map(([x, y]) => `${fmt(x)} ${fmt(y)}`).join(' L') + ' Z';
const fill = (d, color) => `<path d="${d}" fill="${color}"/>`;
const outline = (d, w) =>
  `<path d="${d}" fill="none" stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`;

// --- Insignia -------------------------------------------------------------------------------

// Five-point star split into ten facets, alternating light and dark like a stamped medal.
function star(cx, cy, r, metal = METAL) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = ((-90 + i * 36) * Math.PI) / 180;
    const rr = i % 2 === 0 ? r : r * 0.47;
    pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
  }
  let s = '';
  for (let i = 0; i < 10; i++) {
    s += fill(poly([[cx, cy], pts[i], pts[(i + 1) % 10]]), i % 2 === 0 ? metal.light : metal.dark);
  }
  return s + outline(poly(pts), Math.max(6, r * 0.18));
}

// Eight broad rays, each split into a lit and a shaded facet, around a domed hub.
function sun(cx, cy, r) {
  const pts = [];
  for (let k = 0; k < 8; k++) {
    const tip = ((-90 + k * 45) * Math.PI) / 180;
    const valley = ((-90 + k * 45 + 22.5) * Math.PI) / 180;
    pts.push([cx + Math.cos(tip) * r, cy + Math.sin(tip) * r]);
    pts.push([cx + Math.cos(valley) * r * 0.56, cy + Math.sin(valley) * r * 0.56]);
  }
  let s = '';
  for (let i = 0; i < 16; i++) {
    s += fill(poly([[cx, cy], pts[i], pts[(i + 1) % 16]]), i % 2 === 0 ? METAL.dark : METAL.light);
  }
  s += outline(poly(pts), Math.max(6, r * 0.15));
  const hub = r * 0.38;
  s += `<circle cx="${fmt(cx)}" cy="${fmt(cy)}" r="${fmt(hub)}" fill="${METAL.mid}" stroke="${INK}" stroke-width="${fmt(Math.max(4.5, r * 0.11))}"/>`;
  s += `<circle cx="${fmt(cx - hub * 0.28)}" cy="${fmt(cy - hub * 0.28)}" r="${fmt(hub * 0.34)}" fill="#ffffff" opacity="0.75"/>`;
  return s;
}

// Beveled triangle pip: three facets meeting at the centroid.
function triangle(cx, cy, r) {
  const a = [cx, cy - r];
  const b = [cx + r * 0.94, cy + r * 0.62];
  const c = [cx - r * 0.94, cy + r * 0.62];
  const g = [cx, cy + r * 0.08];
  return (
    fill(poly([a, b, g]), METAL.dark) +
    fill(poly([b, c, g]), METAL.mid) +
    fill(poly([c, a, g]), METAL.light) +
    outline(poly([a, b, c]), Math.max(6, r * 0.17))
  );
}

// Upward chevron, left arm lit, right arm shaded.
function chevron(cx, cy, w, h, t) {
  const top = [cx, cy - h / 2];
  const rightTop = [cx + w / 2, cy + h / 2];
  const rightBottom = [cx + w / 2, cy + h / 2 + t];
  const inner = [cx, cy - h / 2 + t * 1.5];
  const leftBottom = [cx - w / 2, cy + h / 2 + t];
  const leftTop = [cx - w / 2, cy + h / 2];
  return (
    fill(poly([top, inner, leftBottom, leftTop]), METAL.light) +
    fill(poly([top, rightTop, rightBottom, inner]), METAL.dark) +
    outline(poly([top, rightTop, rightBottom, inner, leftBottom, leftTop]), 7)
  );
}

// Faceless agent: a pinched fedora, a face lost in shadow, and a turned-up coat collar, all clipped
// to the medallion.
function agent() {
  const collar = 'M44 250 C52 214 76 192 102 182 L128 214 L154 182 C180 192 204 214 212 250 Z';
  const shadow = 'M92 150 C92 190 110 204 128 204 C146 204 164 190 164 150 Z';
  const brim = 'M30 146 C48 132 84 136 128 136 C172 136 208 132 226 146 C208 164 170 168 128 168 C86 168 48 164 30 146 Z';
  const crown = 'M80 144 L88 92 C92 74 110 70 128 82 C146 70 164 74 168 92 L176 144 Z';
  const crownShade = 'M128 82 C146 70 164 74 168 92 L176 144 L146 144 C150 116 146 96 128 82 Z';
  const band = 'M82 124 C112 132 144 132 174 124 L176 144 C144 152 112 152 80 144 Z';
  return (
    `<defs><clipPath id="inside"><circle cx="128" cy="128" r="107"/></clipPath></defs>` +
    `<g clip-path="url(#inside)">` +
    fill(collar, '#3b3852') + outline(collar, 8) +
    fill('M102 182 L128 214 L154 182 C144 178 112 178 102 182 Z', '#141322') +
    '</g>' +
    fill(shadow, '#141322') + outline(shadow, 7) +
    fill(brim, SILVER.dark) + outline(brim, 8) +
    fill(crown, SILVER.mid) + fill(crownShade, SILVER.dark) +
    fill(band, '#e2475f') +
    outline(crown, 8) + outline(band, 6) +
    outline('M108 84 Q128 100 148 84', 5) +
    fill('M96 98 C99 86 106 80 114 78 C108 88 104 98 102 110 Z', '#ffffff')
  );
}

// Original swallowtail banner with a star, on a gold pole.
function banner() {
  const cloth = 'M84 60 C120 54 160 74 200 64 L174 102 L200 140 C160 150 120 130 84 136 Z';
  return (
    `<rect x="66" y="50" width="16" height="168" rx="8" fill="${METAL.mid}" stroke="${INK}" stroke-width="7"/>` +
    `<rect x="70" y="58" width="5" height="150" rx="2.5" fill="${METAL.light}"/>` +
    `<circle cx="74" cy="44" r="13" fill="${METAL.light}" stroke="${INK}" stroke-width="7"/>` +
    fill(cloth, '#ef4a68') +
    fill('M84 98 C120 92 160 112 190 104 L200 140 C160 150 120 130 84 136 Z', '#c9304f') +
    outline(cloth, 8) +
    star(134, 98, 24, SILVER)
  );
}

// A hidden enemy piece in battle clips: a big gold question mark.
function mystery() {
  const hook = 'M98 96 C98 62 158 60 158 96 C158 120 128 122 128 150';
  return (
    `<path d="${hook}" fill="none" stroke="${INK}" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>` +
    `<path d="${hook}" fill="none" stroke="${METAL.mid}" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>` +
    `<path d="M104 88 C108 74 124 70 136 72" fill="none" stroke="${METAL.light}" stroke-width="7" stroke-linecap="round"/>` +
    `<circle cx="128" cy="190" r="17" fill="${METAL.mid}" stroke="${INK}" stroke-width="8"/>`
  );
}

// --- Badge ------------------------------------------------------------------------------------

function medallion(tier) {
  const [centre, edge] = TIERS[tier];
  const ring = tier === 'flag' ? '#ffffff' : centre;
  return (
    `<defs><radialGradient id="m" cx="0.38" cy="0.32" r="0.75">` +
    `<stop offset="0" stop-color="${centre}"/><stop offset="1" stop-color="${edge}"/></radialGradient></defs>` +
    `<circle cx="128" cy="128" r="112" fill="url(#m)" stroke="${INK}" stroke-width="10"/>` +
    `<circle cx="128" cy="128" r="97" fill="none" stroke="${ring}" stroke-width="5" opacity="0.55"/>` +
    `<ellipse cx="96" cy="66" rx="52" ry="20" transform="rotate(-24 96 66)" fill="#ffffff" opacity="0.16"/>`
  );
}

const LAYOUTS = {
  1: [[128, 128]],
  2: [[84, 128], [172, 128]],
  3: [[128, 82], [80, 160], [176, 160]],
};
const STAR_LAYOUTS = {
  1: { r: 60, at: [[128, 128]] },
  2: { r: 44, at: [[82, 128], [174, 128]] },
  3: { r: 38, at: [[74, 142], [128, 106], [182, 142]] },
  4: { r: 34, at: [[90, 92], [166, 92], [90, 166], [166, 166]] },
  5: { r: 31, at: [[70, 104], [128, 80], [186, 104], [96, 166], [160, 166]] },
};

function stars(n) {
  const { r, at } = STAR_LAYOUTS[n];
  return at.map(([x, y]) => star(x, y, r)).join('');
}

function repeated(n, draw) {
  const size = { 1: 62, 2: 46, 3: 42 }[n];
  return LAYOUTS[n].map(([x, y]) => draw(x, y, size)).join('');
}

const BADGES = {
  G5: ['general', () => stars(5)],
  G4: ['general', () => stars(4)],
  G3: ['general', () => stars(3)],
  G2: ['general', () => stars(2)],
  G1: ['general', () => stars(1)],
  COL: ['field', () => repeated(3, sun)],
  LTC: ['field', () => repeated(2, sun)],
  MAJ: ['field', () => repeated(1, sun)],
  CPT: ['company', () => repeated(3, triangle)],
  '1LT': ['company', () => repeated(2, triangle)],
  '2LT': ['company', () => repeated(1, triangle)],
  SGT: ['enlisted', () => chevron(128, 82, 132, 40, 20) + chevron(128, 126, 132, 40, 20) + chevron(128, 170, 132, 40, 20)],
  PVT: ['enlisted', () => chevron(128, 112, 150, 62, 28)],
  SPY: ['spy', agent],
  FLG: ['flag', banner],
  UNKNOWN: ['unknown', mystery],
};

fs.mkdirSync(OUT, { recursive: true });
for (const [code, [tier, draw]] of Object.entries(BADGES)) {
  fs.writeFileSync(
    path.join(OUT, `${code}.svg`),
    `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 256 256">${medallion(tier)}${draw()}</svg>\n`,
  );
}
console.log(`Wrote ${Object.keys(BADGES).length} badges to ${OUT}`);
