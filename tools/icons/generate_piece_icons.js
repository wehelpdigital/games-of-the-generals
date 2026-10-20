// Generates the chibi anime rank icons shown on each piece's face.
//   node tools/icons/generate_piece_icons.js
// Writes assets/icons/pieces/<RANK>.svg (256 viewBox, 512 px). Every icon is assembled from the
// same parts (backdrop disc, body, head, hair, eyes, mouth, hat, insignia patch) so the set stays
// consistent; only the per-rank recipe at the bottom differs. Re-run after editing, then let Godot
// reimport.

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', '..', 'assets', 'icons', 'pieces');
const INK = '#1d1736';
const SW = 8; // Main outline width (at 256 px).
const SKIN = '#ffe2cb';
const SKIN_SHADE = '#f7bfa0';
const BLUSH = '#ff8aa4';
const MOUTH = '#8a2a45';
const GOLD = '#ffc93c';
const GOLD_SHADE = '#e89a17';

// Backdrop tiers: [edge, centre].
const TIERS = {
  gold: ['#ffd34d', '#fff1b8'],
  coral: ['#ff9d8a', '#ffe0d8'],
  blue: ['#7fb6ff', '#dcecff'],
  green: ['#86d98a', '#ddf6d8'],
  purple: ['#b39bff', '#ebe3ff'],
  pink: ['#ff9cc8', '#ffe4f0'],
};

const stroke = (w = SW) => `stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
const shape = (d, fill, w = SW, extra = '') => `<path d="${d}" fill="${fill}" ${w > 0 ? stroke(w) : ''} ${extra}/>`;
const line = (d, w = 6, color = INK) =>
  `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const ellipse = (cx, cy, rx, ry, fill, w = 0, extra = '') =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" ${w > 0 ? stroke(w) : ''} ${extra}/>`;

// Five-point star / n-ray sun / triangle as path data around (cx, cy).
function starPath(cx, cy, r, points = 5, inner = 0.45, rot = -90) {
  let d = '';
  for (let i = 0; i < points * 2; i++) {
    const rr = i % 2 === 0 ? r : r * inner;
    const a = ((rot + (i * 180) / points) * Math.PI) / 180;
    d += `${i === 0 ? 'M' : 'L'} ${(cx + Math.cos(a) * rr).toFixed(1)} ${(cy + Math.sin(a) * rr).toFixed(1)} `;
  }
  return d + 'Z';
}
const triPath = (cx, cy, r) =>
  `M ${cx} ${cy - r} L ${(cx + r * 0.95).toFixed(1)} ${(cy + r * 0.62).toFixed(1)} L ${(cx - r * 0.95).toFixed(1)} ${(cy + r * 0.62).toFixed(1)} Z`;
const chevronPath = (cx, cy, w, h, t) =>
  `M ${cx - w} ${cy + h * 0.2} L ${cx} ${cy - h * 0.8} L ${cx + w} ${cy + h * 0.2} L ${cx + w} ${cy + h * 0.2 + t} L ${cx} ${cy - h * 0.8 + t} L ${cx - w} ${cy + h * 0.2 + t} Z`;

// --- Parts -------------------------------------------------------------------------------------

function backdrop(tier) {
  const [edge, centre] = TIERS[tier];
  return `
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="60%">
      <stop offset="0%" stop-color="${centre}"/>
      <stop offset="100%" stop-color="${edge}"/>
    </radialGradient>
    <clipPath id="disc"><circle cx="128" cy="128" r="118"/></clipPath>
  </defs>
  <circle cx="128" cy="128" r="118" fill="url(#bg)"/>
  <g opacity="0.55" fill="#ffffff">
    <circle cx="44" cy="92" r="5"/><circle cx="214" cy="80" r="4"/><circle cx="58" cy="60" r="3"/>
    ${starPath(206, 132, 9, 4, 0.35, -90)}
    ${starPath(50, 140, 7, 4, 0.35, -90)}
  </g>`;
}

const ring = () => `<circle cx="128" cy="128" r="118" fill="none" ${stroke(SW)}/>`;

function body(color, opts = {}) {
  const collar = opts.collar || '#ffffff';
  let s = shape('M 26 262 C 30 214 70 192 128 192 C 186 192 226 214 230 262 Z', color);
  // Shirt V and lapels.
  s += shape('M 106 192 L 128 222 L 150 192 Z', collar, 6);
  s += shape('M 100 190 L 128 224 L 112 236 L 88 200 Z', shade(color, 0.12), 6);
  s += shape('M 156 190 L 128 224 L 144 236 L 168 200 Z', shade(color, 0.12), 6);
  if (opts.tie) s += shape('M 122 214 L 134 214 L 138 240 L 128 248 L 118 240 Z', opts.tie, 5);
  return s;
}

function neck() {
  return shape('M 112 160 L 112 198 Q 128 208 144 198 L 144 160 Z', SKIN, 6) +
    shape('M 114 168 Q 128 182 142 168 L 142 178 Q 128 190 114 178 Z', SKIN_SHADE, 0);
}

const HEAD = 'M 66 112 C 66 70 94 48 128 48 C 162 48 190 70 190 112 C 190 152 164 180 128 180 C 92 180 66 152 66 112 Z';

function head() {
  return `
  <defs><clipPath id="face"><path d="${HEAD}"/></clipPath></defs>
  ${shape(HEAD, SKIN)}
  <g clip-path="url(#face)"><path d="M 168 60 C 200 100 196 160 150 186 L 210 190 L 210 50 Z" fill="${SKIN_SHADE}" opacity="0.7"/></g>
  ${shape(HEAD, 'none')}`;
}

function hairBack(style, color) {
  switch (style) {
    case 'long':
      return shape('M 60 118 C 50 62 94 36 128 36 C 162 36 206 62 196 118 L 206 198 C 192 208 176 204 170 192 L 86 192 C 80 204 64 208 50 198 Z', color);
    case 'bob':
      return shape('M 58 122 C 52 64 94 38 128 38 C 162 38 204 64 198 122 C 200 146 196 164 186 172 L 70 172 C 60 164 56 146 58 122 Z', color);
    case 'twin':
      return shape('M 60 118 C 50 62 94 36 128 36 C 162 36 206 62 196 118 Z', color) +
        shape('M 52 96 C 22 110 18 168 36 196 C 44 176 58 150 64 124 Z', color) +
        shape('M 204 96 C 234 110 238 168 220 196 C 212 176 198 150 192 124 Z', color);
    default:
      return shape('M 62 124 C 52 64 94 38 128 38 C 162 38 204 64 194 124 C 190 112 186 104 180 100 L 76 100 C 70 104 66 112 62 124 Z', color);
  }
}

function hairFront(style, color) {
  switch (style) {
    case 'swept':
      return shape('M 64 114 C 62 68 98 46 140 50 C 170 54 192 74 192 108 C 176 92 156 84 130 88 C 106 92 86 102 64 114 Z', color);
    case 'long':
    case 'bob':
    case 'twin':
      return shape('M 64 114 C 66 70 96 50 128 50 C 160 50 190 70 192 114 Q 178 98 164 110 Q 148 92 128 106 Q 108 92 92 110 Q 78 98 64 114 Z', color);
    default: // spiky
      return shape('M 64 112 C 66 70 96 50 128 50 C 160 50 190 70 192 112 L 178 98 L 170 114 L 158 94 L 146 112 L 132 92 L 120 112 L 108 94 L 98 114 L 88 98 L 78 114 Z', color);
  }
}

// Eyes: 'open' (glossy anime eyes), 'wink' (right eye closed), 'happy' (both ^ ^), 'sharp' (spy).
function eyes(kind, iris) {
  const one = (x, closed) => {
    if (closed) return line(`M ${x - 13} 130 Q ${x} 116 ${x + 13} 130`, 6);
    return `
    ${ellipse(x, 130, 13, 17, '#ffffff', 0)}
    ${ellipse(x, 132, 12, 16, iris, 0)}
    ${ellipse(x, 128, 7.5, 10, INK, 0)}
    ${ellipse(x, 138, 8, 5, lighten(iris, 0.35), 0, 'opacity="0.9"')}
    <circle cx="${x + 4}" cy="${123}" r="5" fill="#ffffff"/>
    <circle cx="${x - 5}" cy="${139}" r="2.6" fill="#ffffff"/>
    ${line(`M ${x - 15} 117 Q ${x} 108 ${x + 15} 117`, 6)}`;
  };
  if (kind === 'happy') return one(104, true) + one(152, true);
  if (kind === 'wink') return one(104, false) + one(152, true);
  if (kind === 'sharp') {
    const sharpEye = (x, flip) => `
      <path d="M ${x - 17} ${flip ? 120 : 126} L ${x + 17} ${flip ? 126 : 120} L ${x + 14} 140 Q ${x} 146 ${x - 14} 140 Z" fill="#ffffff"/>
      ${ellipse(x, 133, 11, 11, iris, 0)}
      ${ellipse(x, 133, 5, 8, INK, 0)}
      <circle cx="${x + 4}" cy="128" r="3.4" fill="#ffffff"/>
      <circle cx="${x - 4}" cy="138" r="1.8" fill="#ffffff"/>
      ${line(`M ${x - 18} ${flip ? 118 : 126} L ${x + 18} ${flip ? 126 : 118}`, 7)}`;
    return sharpEye(104, true) + sharpEye(152, false);
  }
  return one(104, false) + one(152, false);
}

function brows(kind) {
  switch (kind) {
    case 'stern':
      return line('M 90 104 L 116 110', 5) + line('M 166 104 L 140 110', 5);
    case 'worried':
      return line('M 92 110 L 114 102', 5) + line('M 164 110 L 142 102', 5);
    case 'raised':
      return line('M 92 102 Q 104 96 116 102', 5) + line('M 140 102 Q 152 96 164 102', 5);
    default:
      return '';
  }
}

function mouth(kind) {
  switch (kind) {
    case 'grin':
      return shape('M 112 152 Q 128 174 144 152 Z', MOUTH, 5) + shape('M 120 162 Q 128 168 136 162 Q 128 158 120 162 Z', '#ff7a8a', 0);
    case 'fang':
      return shape('M 112 152 Q 128 174 144 152 Z', MOUTH, 5) + shape('M 134 153 L 138 160 L 141 153 Z', '#ffffff', 2);
    case 'smirk':
      return line('M 118 158 Q 132 162 142 150', 5);
    case 'nervous':
      return line('M 112 158 Q 116 152 120 158 Q 124 164 128 158 Q 132 152 136 158 Q 140 164 144 158', 4.5);
    case 'o':
      return ellipse(128, 158, 6, 7, MOUTH, 4);
    case 'cat':
      return line('M 114 154 Q 121 162 128 154 Q 135 162 142 154', 5);
    case 'calm':
      return line('M 120 158 Q 128 162 136 158', 5);
    default: // smile
      return line('M 116 154 Q 128 166 140 154', 5);
  }
}

const blush = () => ellipse(86, 152, 11, 6, BLUSH, 0, 'opacity="0.65"') + ellipse(170, 152, 11, 6, BLUSH, 0, 'opacity="0.65"');

// Hats ---------------------------------------------------------------------------------------

function peakedCap(stars, boss = false) {
  let s = shape('M 52 98 C 44 54 90 26 128 26 C 166 26 212 54 204 98 Z', boss ? '#22348a' : '#2f4aa8');
  s += shape('M 160 36 C 186 46 202 66 204 96 L 186 96 C 186 70 176 50 160 36 Z', '#253b8c', 0);
  s += shape('M 62 86 L 194 86 L 194 104 L 62 104 Z', GOLD, 6);
  s += shape('M 64 102 Q 128 132 192 102 Q 176 116 128 118 Q 80 116 64 102 Z', INK, 4);
  if (boss) {
    // Gold chin cord across the visor: the supreme commander's cap.
    s += line('M 70 100 Q 128 122 186 100', 5, GOLD);
    s += `<circle cx="70" cy="100" r="5" fill="${GOLD}" stroke="${INK}" stroke-width="3"/><circle cx="186" cy="100" r="5" fill="${GOLD}" stroke="${INK}" stroke-width="3"/>`;
  }
  // Countable gold stars across the crown.
  const size = stars >= 4 ? 13 : 15;
  const gap = stars >= 4 ? 27 : 31;
  for (let i = 0; i < stars; i++) {
    const x = 128 + (i - (stars - 1) / 2) * gap;
    s += shape(starPath(x, 60, size), GOLD, 4);
  }
  return s;
}

function beret(color) {
  return shape('M 54 92 C 44 52 112 26 168 38 C 210 48 220 78 200 94 C 158 102 98 102 54 92 Z', color) +
    shape('M 60 88 Q 128 102 198 90 L 200 98 Q 128 112 58 98 Z', shade(color, 0.25), 5) +
    shape(starPath(80, 74, 9, 8, 0.55), GOLD, 3);
}

function garrisonCap(color) {
  // A boat-shaped side cap perched on top of the head, tilted.
  return '<g transform="rotate(-8 128 70)">' +
    shape('M 66 78 C 72 52 104 40 136 40 C 170 40 192 56 196 80 C 160 90 100 90 66 78 Z', color) +
    line('M 82 74 C 110 62 150 58 184 70', 4, shade(color, 0.35)) +
    shape('M 64 76 Q 130 94 198 78 L 198 88 Q 130 104 64 86 Z', shade(color, 0.3), 5) +
    '</g>';
}

function helmet(color, oversized) {
  const dy = oversized ? 0 : -10; // Keep the eyes clear; the private's still slips a little.
  const t = oversized ? 'transform="rotate(-6 128 90)"' : '';
  return `<g ${t}>
    ${shape(`M ${oversized ? 46 : 56} ${108 + dy} C ${oversized ? 44 : 54} ${50 + dy} 92 ${24 + dy} 128 ${24 + dy} C 164 ${24 + dy} ${oversized ? 212 : 202} ${50 + dy} ${oversized ? 210 : 200} ${108 + dy} Z`, color)}
    ${shape(`M 158 ${36 + dy} C 186 ${48 + dy} ${oversized ? 206 : 198} ${70 + dy} ${oversized ? 208 : 200} ${104 + dy} L 184 ${104 + dy} C 182 ${74 + dy} 174 ${54 + dy} 158 ${36 + dy} Z`, shade(color, 0.18), 0)}
    ${shape(`M ${oversized ? 34 : 46} ${104 + dy} Q 128 ${126 + dy} ${oversized ? 222 : 210} ${104 + dy} L ${oversized ? 222 : 210} ${116 + dy} Q 128 ${138 + dy} ${oversized ? 34 : 46} ${116 + dy} Z`, shade(color, 0.12), 6)}
    <circle cx="96" cy="${60 + dy}" r="4" fill="${shade(color, 0.3)}"/><circle cx="150" cy="${52 + dy}" r="5" fill="${shade(color, 0.3)}"/><circle cx="124" cy="${76 + dy}" r="3.5" fill="${shade(color, 0.3)}"/>
  </g>`;
}

// Insignia patch on the chest: kind = sun | triangle | chevron.
function patch(kind, count) {
  if (kind === 'chevron') {
    const h = count === 1 ? 26 : 40;
    let s = shape(`M ${128 - 22} ${206} L ${128 + 22} ${206} L ${128 + 22} ${206 + h} Q 128 ${206 + h + 10} ${128 - 22} ${206 + h} Z`, '#2a3a2a', 5);
    for (let i = 0; i < count; i++) s += shape(chevronPath(128, 222 + i * 10, 16, 12, 6), GOLD, 2.5);
    return s;
  }
  const w = count * 33 + 14;
  let s = shape(`M ${128 - w / 2} 202 L ${128 + w / 2} 202 L ${128 + w / 2} 238 L ${128 - w / 2} 238 Z`, '#2a2350', 5);
  for (let i = 0; i < count; i++) {
    const x = 128 + (i - (count - 1) / 2) * 33;
    s += kind === 'sun'
      ? shape(starPath(x, 220, 14.5, 8, 0.58), GOLD, 2.5) + `<circle cx="${x}" cy="220" r="5" fill="${GOLD_SHADE}"/>`
      : shape(triPath(x, 222, 14), GOLD, 2.5);
  }
  return s;
}

// --- Extras ----------------------------------------------------------------------------------

const sparkle = (x, y, r) => shape(starPath(x, y, r, 4, 0.3), '#ffffff', 3);
const sweat = () => shape('M 186 96 Q 200 116 192 126 Q 180 130 178 118 Q 178 108 186 96 Z', '#8fd3ff', 4);

function epaulettes() {
  return shape('M 30 214 Q 58 196 90 204 L 86 222 Q 58 214 36 230 Z', GOLD, 5) +
    shape('M 226 214 Q 198 196 166 204 L 170 222 Q 198 214 220 230 Z', GOLD, 5) +
    line('M 42 232 L 40 244 M 52 226 L 50 240 M 62 222 L 61 236', 4, GOLD_SHADE) +
    line('M 214 232 L 216 244 M 204 226 L 206 240 M 194 222 L 195 236', 4, GOLD_SHADE);
}

function medals() {
  return shape('M 150 210 L 166 210 L 166 222 L 150 222 Z', '#e8344d', 3) +
    `<circle cx="158" cy="230" r="7" fill="${GOLD}" stroke="${INK}" stroke-width="3"/>` +
    shape('M 90 210 L 106 210 L 106 222 L 90 222 Z', '#3fa9ff', 3) +
    `<circle cx="98" cy="230" r="7" fill="${GOLD}" stroke="${INK}" stroke-width="3"/>`;
}

function spyHood() {
  return shape('M 46 142 C 36 60 90 24 128 24 C 166 24 220 60 210 142 C 206 176 196 196 186 210 L 70 210 C 60 196 50 176 46 142 Z', '#4a2f8a');
}

function spyMask() {
  return shape('M 66 150 Q 128 142 190 150 C 188 168 170 186 128 188 C 86 186 68 168 66 150 Z', '#2a1d55', 6) +
    line('M 92 168 Q 128 176 164 168', 3, '#6a54b8');
}

// --- Colour helpers ---------------------------------------------------------------------------

function hex(c) {
  const n = parseInt(c.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
const toHex = (rgb) => '#' + rgb.map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
const shade = (c, k) => toHex(hex(c).map((v) => v * (1 - k)));
const lighten = (c, k) => toHex(hex(c).map((v) => v + (255 - v) * k));

// --- Assembly ---------------------------------------------------------------------------------

function person(r) {
  let s = backdrop(r.tier) + '<g clip-path="url(#disc)">';
  if (r.hood) s += spyHood();
  if (r.cape) s += shape('M 14 262 C 18 206 60 178 128 178 C 196 178 238 206 242 262 Z', '#d6283f');
  s += body(r.uniform, { tie: r.tie, collar: r.collar });
  if (r.epaulettes) s += epaulettes();
  s += neck();
  if (!r.hood) s += hairBack(r.hairStyle, r.hair);
  s += head();
  if (r.hood) s += shape('M 64 112 C 66 74 96 56 128 56 C 160 56 190 74 192 112 Q 160 92 128 100 Q 96 92 64 112 Z', '#1d1736', 0);
  if (!r.mask) s += blush();
  s += eyes(r.eyes, r.iris);
  if (!r.hood) s += hairFront(r.hairStyle, r.hair);
  s += brows(r.brows);
  if (r.mask) s += spyMask(); else s += mouth(r.mouth);
  if (r.hat) s += r.hat;
  if (r.patch) s += r.patch;
  if (r.medals) s += medals();
  if (r.sweat) s += sweat();
  for (const sp of r.sparkles || []) s += sparkle(...sp);
  s += '</g>' + ring();
  return s;
}

function flag() {
  let s = backdrop('pink') + '<g clip-path="url(#disc)">';
  s += shape('M 70 46 L 82 46 L 82 236 L 70 236 Z', '#c98a3a', 6);
  s += `<circle cx="76" cy="40" r="11" fill="${GOLD}" stroke="${INK}" stroke-width="6"/>`;
  s += shape('M 82 56 C 116 40 146 74 200 54 C 206 90 202 128 206 160 C 152 180 120 148 82 166 Z', '#ffffff');
  s += shape('M 82 56 C 116 40 146 74 200 54 C 202 70 202 84 202 96 C 150 114 118 82 82 100 Z', '#ff4f8b', 0);
  s += shape('M 82 56 C 116 40 146 74 200 54 C 206 90 202 128 206 160 C 152 180 120 148 82 166 Z', 'none');
  // Face on the cloth.
  s += ellipse(122, 122, 9, 12, INK, 0) + ellipse(166, 118, 9, 12, INK, 0);
  s += '<circle cx="125" cy="117" r="3.5" fill="#ffffff"/><circle cx="169" cy="113" r="3.5" fill="#ffffff"/>';
  s += ellipse(108, 140, 9, 5, BLUSH, 0, 'opacity="0.8"') + ellipse(182, 136, 9, 5, BLUSH, 0, 'opacity="0.8"');
  s += line('M 134 140 Q 144 150 154 138', 5);
  s += shape(starPath(144, 82, 10, 5), GOLD, 3);
  s += sparkle(212, 196, 9) + sparkle(46, 120, 7);
  s += '</g>' + ring();
  return s;
}

const GEN = { tier: 'gold', uniform: '#2f4aa8', tie: '#e8344d', iris: '#3a6bd6' };
const RECIPES = {
  G5: { ...GEN, hat: peakedCap(5, true), cape: true, hair: '#e9eef8', hairStyle: 'swept', eyes: 'open', iris: '#c0392b', brows: 'stern', mouth: 'smirk', epaulettes: true, medals: true, sparkles: [[200, 168, 10]] },
  G4: { ...GEN, hat: peakedCap(4), hair: '#2b2b3a', hairStyle: 'swept', eyes: 'open', brows: 'stern', mouth: 'calm', medals: true },
  G3: { ...GEN, hat: peakedCap(3), hair: '#7a4a2a', hairStyle: 'long', eyes: 'open', iris: '#2e9e6b', mouth: 'smile' },
  G2: { ...GEN, hat: peakedCap(2), hair: '#e2572b', hairStyle: 'spiky', eyes: 'open', iris: '#d68a1a', brows: 'raised', mouth: 'grin' },
  G1: { ...GEN, hat: peakedCap(1), hair: '#f2c94c', hairStyle: 'spiky', eyes: 'happy', mouth: 'grin' },

  COL: { tier: 'coral', uniform: '#b23a48', hat: beret('#8c1f3a'), patch: patch('sun', 3), hair: '#27406e', hairStyle: 'swept', eyes: 'open', iris: '#4a6fd8', brows: 'stern', mouth: 'smile' },
  LTC: { tier: 'coral', uniform: '#b23a48', hat: beret('#8c1f3a'), patch: patch('sun', 2), hair: '#ff7eb6', hairStyle: 'long', eyes: 'wink', iris: '#c43c8c', mouth: 'grin' },
  MAJ: { tier: 'coral', uniform: '#b23a48', hat: beret('#8c1f3a'), patch: patch('sun', 1), hair: '#2aa79b', hairStyle: 'spiky', eyes: 'open', iris: '#1f8a7f', brows: 'raised', mouth: 'calm' },

  CPT: { tier: 'blue', uniform: '#3a7bd5', hat: garrisonCap('#23488f'), patch: patch('triangle', 3), hair: '#6b3d22', hairStyle: 'spiky', eyes: 'open', iris: '#8a5a2b', brows: 'raised', mouth: 'fang' },
  '1LT': { tier: 'blue', uniform: '#3a7bd5', hat: garrisonCap('#23488f'), patch: patch('triangle', 2), hair: '#ffd25e', hairStyle: 'twin', eyes: 'open', iris: '#3a9be0', mouth: 'o' },
  '2LT': { tier: 'blue', uniform: '#3a7bd5', hat: garrisonCap('#23488f'), patch: patch('triangle', 1), hair: '#b39bff', hairStyle: 'bob', eyes: 'happy', mouth: 'cat' },

  SGT: { tier: 'green', uniform: '#5f8f3e', collar: '#e8f2d8', hat: helmet('#6f9a45', false), patch: patch('chevron', 3), hair: '#ff8c2b', hairStyle: 'spiky', eyes: 'open', iris: '#3f8f2f', brows: 'stern', mouth: 'fang' },
  PVT: { tier: 'green', uniform: '#5f8f3e', collar: '#e8f2d8', hat: helmet('#7aa84c', true), patch: patch('chevron', 1), hair: '#b07a4a', hairStyle: 'spiky', eyes: 'open', iris: '#5c8a3a', brows: 'worried', mouth: 'nervous', sweat: true },

  SPY: { tier: 'purple', uniform: '#3a2a6b', collar: '#2a1d55', hood: true, mask: true, eyes: 'sharp', iris: '#b14cff', brows: 'stern', sparkles: [[176, 112, 9]] },
};

fs.mkdirSync(OUT, { recursive: true });
const write = (code, inner) =>
  fs.writeFileSync(path.join(OUT, `${code}.svg`),
    `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 256 256">${inner}\n</svg>\n`);

for (const [code, recipe] of Object.entries(RECIPES)) write(code, person(recipe));
write('FLG', flag());
console.log(`wrote ${Object.keys(RECIPES).length + 1} icons to ${OUT}`);
