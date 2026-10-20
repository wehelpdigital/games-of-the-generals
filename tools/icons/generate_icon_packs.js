// Generates the themed rank-icon packs sold in the shop.
//   node tools/icons/generate_icon_packs.js
// Writes assets/icons/src/<pack>/<RANK>.svg (256 viewBox, 512 px) for G5 … FLG plus UNKNOWN;
// then run bundle_icons.js. The "classic" pack comes from generate_piece_badges.js.
//
// Every pack keeps the game readable: the medallion colour/shape still tells the rank group, and
// the number of marks still counts the rank (5–1 for generals, 3–1 for field and company officers,
// 3 or 1 for enlisted). All shapes are drawn from scratch here; themes use generic motifs only
// (sakura, fans, shuriken; planets and deltas; crowns and towers; neon glyphs; sweets; skulls and
// anchors), never anything from an existing franchise.

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', '..', 'assets', 'icons', 'src');
const INK = '#1d1736';
const GOLD = { light: '#ffe680', mid: '#ffc93c', dark: '#ef9f0f' };
const SILVER = { light: '#ffffff', mid: '#e4e8f2', dark: '#a9b2c8' };
const RANKS = ['G5', 'G4', 'G3', 'G2', 'G1', 'COL', 'LTC', 'MAJ', 'CPT', '1LT', '2LT', 'SGT', 'PVT', 'SPY', 'FLG', 'UNKNOWN'];
const TIER = {
  G5: 'general', G4: 'general', G3: 'general', G2: 'general', G1: 'general',
  COL: 'field', LTC: 'field', MAJ: 'field', CPT: 'company', '1LT': 'company', '2LT': 'company',
  SGT: 'enlisted', PVT: 'enlisted', SPY: 'spy', FLG: 'flag', UNKNOWN: 'unknown',
};
const COUNT = { G5: 5, G4: 4, G3: 3, G2: 2, G1: 1, COL: 3, LTC: 2, MAJ: 1, CPT: 3, '1LT': 2, '2LT': 1, SGT: 3, PVT: 1 };

// --- SVG helpers ------------------------------------------------------------------------------

const fmt = (n) => Number(n.toFixed(2));
const P = (pts) => 'M' + pts.map(([x, y]) => `${fmt(x)} ${fmt(y)}`).join(' L') + ' Z';
const fill = (d, c, extra = '') => `<path d="${d}" fill="${c}" ${extra}/>`;
const ink = (d, w) =>
  `<path d="${d}" fill="none" stroke="${INK}" stroke-width="${fmt(w)}" stroke-linejoin="round" stroke-linecap="round"/>`;
const shape = (d, c, w) => fill(d, c) + ink(d, w);
const stroke = (d, c, w, extra = '') =>
  `<path d="${d}" fill="none" stroke="${c}" stroke-width="${fmt(w)}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
const circ = (cx, cy, r, c, w = 0, extra = '') =>
  `<circle cx="${fmt(cx)}" cy="${fmt(cy)}" r="${fmt(r)}" fill="${c}"${w ? ` stroke="${INK}" stroke-width="${fmt(w)}"` : ''} ${extra}/>`;
const ell = (cx, cy, rx, ry, c, w = 0, rot = 0, extra = '') =>
  `<ellipse cx="${fmt(cx)}" cy="${fmt(cy)}" rx="${fmt(rx)}" ry="${fmt(ry)}" fill="${c}"` +
  `${w ? ` stroke="${INK}" stroke-width="${fmt(w)}"` : ''}${rot ? ` transform="rotate(${fmt(rot)} ${fmt(cx)} ${fmt(cy)})"` : ''} ${extra}/>`;
const rect = (x, y, w, h, rx, c, sw = 0) =>
  `<rect x="${fmt(x)}" y="${fmt(y)}" width="${fmt(w)}" height="${fmt(h)}" rx="${fmt(rx)}" fill="${c}"${sw ? ` stroke="${INK}" stroke-width="${fmt(sw)}"` : ''}/>`;
const polar = (cx, cy, r, deg) => [cx + Math.cos((deg * Math.PI) / 180) * r, cy + Math.sin((deg * Math.PI) / 180) * r];
const circlePath = (cx, cy, r) => `M${fmt(cx - r)} ${fmt(cy)} a${fmt(r)} ${fmt(r)} 0 1 0 ${fmt(2 * r)} 0 a${fmt(r)} ${fmt(r)} 0 1 0 ${fmt(-2 * r)} 0 Z`;
const lw = (r) => Math.max(5.5, r * 0.17);  // Bold enough to survive mipmapping on small pieces.
const radial = (id, centre, edge) =>
  `<radialGradient id="${id}" cx="0.38" cy="0.32" r="0.75"><stop offset="0" stop-color="${centre}"/><stop offset="1" stop-color="${edge}"/></radialGradient>`;
const gloss = (op = 0.16) => `<ellipse cx="96" cy="66" rx="52" ry="20" transform="rotate(-24 96 66)" fill="#ffffff" opacity="${op}"/>`;

// Shared geometry -------------------------------------------------------------------------------

function starPoints(cx, cy, r, points, inner, start = -90) {
  const pts = [];
  for (let i = 0; i < points * 2; i++) {
    pts.push(polar(cx, cy, i % 2 === 0 ? r : r * inner, start + (i * 180) / points));
  }
  return pts;
}

// A star/spiky shape split into facets that alternate light and dark, like stamped metal.
function faceted(cx, cy, pts, metal, w) {
  let s = '';
  for (let i = 0; i < pts.length; i++) {
    s += fill(P([[cx, cy], pts[i], pts[(i + 1) % pts.length]]), i % 2 === 0 ? metal.light : metal.dark);
  }
  return s + ink(P(pts), w);
}

function chevronPts(cx, cy, w, h, t) {
  return [[cx, cy - h / 2], [cx + w / 2, cy + h / 2], [cx + w / 2, cy + h / 2 + t], [cx, cy - h / 2 + t * 1.5],
    [cx - w / 2, cy + h / 2 + t], [cx - w / 2, cy + h / 2]];
}

function chevron(cx, cy, w, h, t, metal) {
  const p = chevronPts(cx, cy, w, h, t);
  return fill(P([p[0], p[3], p[4], p[5]]), metal.light) + fill(P([p[0], p[1], p[2], p[3]]), metal.dark) + ink(P(p), 7);
}

const HOOK = 'M98 96 C98 62 158 60 158 96 C158 120 128 122 128 150';
function mysteryMark(metal) {
  return stroke(HOOK, INK, 40) + stroke(HOOK, metal.mid, 24) +
    stroke('M104 88 C108 74 124 70 136 72', metal.light, 7) + circ(128, 190, 17, metal.mid, 8);
}

// Layouts (centred on 128,128 for a ~112 px medallion): [r, [[x, y], ...]].
const GEN = {
  1: [58, [[128, 128]]], 2: [44, [[82, 128], [174, 128]]], 3: [38, [[74, 142], [128, 106], [182, 142]]],
  4: [34, [[90, 92], [166, 92], [90, 166], [166, 166]]], 5: [31, [[70, 104], [128, 80], [186, 104], [96, 166], [160, 166]]],
};
const OFF = { 1: [60, [[128, 128]]], 2: [44, [[84, 128], [172, 128]]], 3: [40, [[128, 84], [80, 160], [176, 160]]] };

function placed(layout, n, area, draw) {
  const [r, at] = layout[n];
  return at.map(([x, y]) => draw(128 + (x - 128) * area.s + area.dx, 128 + (y - 128) * area.s + area.dy, r * area.s)).join('');
}

// --- Medallions ---------------------------------------------------------------------------------

function circleMedal(c, e, ring) {
  return `<defs>${radial('m', c, e)}</defs><circle cx="128" cy="128" r="112" fill="url(#m)" stroke="${INK}" stroke-width="10"/>` +
    `<circle cx="128" cy="128" r="97" fill="none" stroke="${ring}" stroke-width="5" opacity="0.55"/>` + gloss();
}

// Samurai "mon" crest: lacquer disc with a gold inner ring.
function monMedal(c, e) {
  return `<defs>${radial('m', c, e)}</defs><circle cx="128" cy="128" r="112" fill="url(#m)" stroke="${INK}" stroke-width="10"/>` +
    `<circle cx="128" cy="128" r="100" fill="none" stroke="${GOLD.mid}" stroke-width="5"/>` +
    `<circle cx="128" cy="128" r="93" fill="none" stroke="${INK}" stroke-width="2.5" opacity="0.45"/>` + gloss(0.14);
}

// Space Fleet: hexagonal insignia plate with corner rivets.
function hexMedal(c, e, ring) {
  const outer = [];
  const inner = [];
  for (let k = 0; k < 6; k++) {
    outer.push(polar(128, 128, 118, -90 + k * 60));
    inner.push(polar(128, 128, 101, -90 + k * 60));
  }
  let s = `<defs>${radial('m', c, e)}</defs>` + fill(P(outer), 'url(#m)') + ink(P(outer), 10) +
    stroke(P(inner), ring, 4, 'opacity="0.55"');
  for (const [x, y] of inner) s += circ(x, y, 4.5, ring, 0, 'opacity="0.8"');
  return s + gloss(0.14);
}

const SHIELD = 'M38 30 H218 V118 C218 186 172 226 128 244 C84 226 38 186 38 118 Z';
function shieldMedal(c, e, ring) {
  return `<defs>${radial('m', c, e)}<clipPath id="shield"><path d="${SHIELD}"/></clipPath></defs>` +
    fill(SHIELD, 'url(#m)') + ink(SHIELD, 10) +
    `<path d="${SHIELD}" fill="none" stroke="${ring}" stroke-width="5" opacity="0.55" transform="translate(128 132) scale(0.86) translate(-128 -132)"/>` +
    gloss(0.14);
}

function neonPath(d, color, w = 6) {
  return stroke(d, color, w * 3.4, 'opacity="0.16"') + stroke(d, color, w * 1.9, 'opacity="0.35"') +
    stroke(d, color, w) + stroke(d, '#ffffff', w * 0.38, 'opacity="0.85"');
}

function neonMedal(color) {
  const frame = 'M70 30 H186 Q226 30 226 70 V186 Q226 226 186 226 H70 Q30 226 30 186 V70 Q30 30 70 30 Z';
  return rect(14, 14, 228, 228, 50, '#120e24', 8) + rect(20, 20, 216, 216, 46, '#1b1535') + neonPath(frame, color, 5);
}

function candyMedal(c, e) {
  const pts = [];
  for (let i = 0; i < 180; i++) {
    const a = (i / 180) * Math.PI * 2;
    const r = 109 + 6 * Math.cos(a * 18);
    pts.push([128 + Math.cos(a) * r, 128 + Math.sin(a) * r]);
  }
  return `<defs>${radial('m', c, e)}</defs>` + fill(P(pts), 'url(#m)') + ink(P(pts), 9) +
    `<circle cx="128" cy="128" r="93" fill="none" stroke="#ffffff" stroke-width="6" stroke-dasharray="1 13" stroke-linecap="round" opacity="0.9"/>` +
    gloss(0.22);
}

// Pirate doubloon: ridged gold rim around an enamel inlay.
function coinMedal(c, e) {
  const rim = [];
  for (let i = 0; i < 72; i++) rim.push(polar(128, 128, i % 2 === 0 ? 118 : 112, i * 5));
  let s = `<defs>${radial('m', c, e)}</defs>` + shape(P(rim), GOLD.mid, 7) +
    circ(128, 128, 104, GOLD.dark, 0) + `<circle cx="128" cy="128" r="97" fill="url(#m)" stroke="${INK}" stroke-width="6"/>`;
  for (let i = 0; i < 24; i++) {
    const [x, y] = polar(128, 128, 101, i * 15);
    s += circ(x, y, 2.4, GOLD.light, 0);
  }
  return s + gloss(0.14);
}

// --- Pack: Samurai & Ninja --------------------------------------------------------------------

function sakura(cx, cy, r) {
  const w = lw(r) * 0.8;
  let back = '';
  let front = '';
  let notch = '';
  for (let k = 0; k < 5; k++) {
    const a = -90 + k * 72;
    const [px, py] = polar(cx, cy, r * 0.5, a);
    back += ell(px, py, r * 0.34 + w / 2, r * 0.5 + w / 2, INK, 0, a + 90);
    front += ell(px, py, r * 0.34, r * 0.5, k % 2 === 0 ? GOLD.mid : GOLD.light, 0, a + 90);
    const [l1x, l1y] = polar(cx, cy, r * 1.0, a - 8);
    const [nx, ny] = polar(cx, cy, r * 0.84, a);
    const [l2x, l2y] = polar(cx, cy, r * 1.0, a + 8);
    notch += stroke(`M${fmt(l1x)} ${fmt(l1y)} L${fmt(nx)} ${fmt(ny)} L${fmt(l2x)} ${fmt(l2y)}`, INK, Math.max(2.5, r * 0.07));
  }
  let s = back + front + notch + circ(cx, cy, r * 0.22, GOLD.dark, w * 0.7);
  for (let k = 0; k < 5; k++) {
    const [x, y] = polar(cx, cy, r * 0.32, -54 + k * 72);
    s += circ(x, y, r * 0.05, INK, 0);
  }
  return s;
}

function fan(cx, cy, r) {
  const px = cx;
  const py = cy + r * 0.48;
  const R = r * 1.08;
  const Ri = R * 0.26;
  const n = 6;
  let s = '';
  const outer = [];
  const inner = [];
  for (let i = 0; i <= n; i++) {
    const a = -160 + (140 * i) / n;
    outer.push(polar(px, py, R, a));
    inner.push(polar(px, py, Ri, a));
  }
  for (let i = 0; i < n; i++) {
    s += fill(P([inner[i], outer[i], outer[i + 1], inner[i + 1]]), i % 2 === 0 ? GOLD.light : GOLD.mid);
  }
  const outline = [...outer, ...inner.slice().reverse()];
  for (let i = 1; i < n; i++) s += stroke(`M${fmt(inner[i][0])} ${fmt(inner[i][1])} L${fmt(outer[i][0])} ${fmt(outer[i][1])}`, INK, 2.5);
  s += ink(P(outline), lw(r) * 0.85);
  return s + circ(px, py, r * 0.12, '#c8202f', lw(r) * 0.5);
}

function hishi(cx, cy, r) {
  const t = [cx, cy - r];
  const rt = [cx + r * 0.72, cy];
  const b = [cx, cy + r];
  const l = [cx - r * 0.72, cy];
  const c = [cx, cy];
  return fill(P([t, l, c]), GOLD.light) + fill(P([t, rt, c]), GOLD.mid) + fill(P([b, rt, c]), GOLD.dark) +
    fill(P([b, l, c]), GOLD.mid) + ink(P([t, rt, b, l]), lw(r)) +
    ink(P([[cx, cy - r * 0.45], [cx + r * 0.32, cy], [cx, cy + r * 0.45], [cx - r * 0.32, cy]]), 2.5);
}

function bamboo(cx, cy, w, h) {
  return rect(cx - w / 2, cy - h / 2, w, h, h / 2, GOLD.mid, 0) +
    rect(cx - w / 2 + h * 0.3, cy - h / 2 + h * 0.16, w - h * 0.6, h * 0.24, h * 0.12, GOLD.light, 0) +
    stroke(`M${fmt(cx - w / 6)} ${fmt(cy - h / 2)} V${fmt(cy + h / 2)} M${fmt(cx + w / 6)} ${fmt(cy - h / 2)} V${fmt(cy + h / 2)}`, INK, 3.5) +
    rect(cx - w / 2, cy - h / 2, w, h, h / 2, 'none', 7);
}

function shuriken(cx, cy, r) {
  return faceted(cx, cy, starPoints(cx, cy, r, 4, 0.3, -45), SILVER, lw(r)) + circ(cx, cy, r * 0.14, '#120d1c', lw(r) * 0.6);
}

function nobori() {
  const cloth = 'M92 60 H178 V190 L162 178 L146 192 L130 178 L114 192 L92 182 Z';
  let s = rect(76, 38, 13, 182, 6.5, GOLD.mid, 7) + rect(76, 48, 108, 11, 5.5, GOLD.mid, 6) + shape(cloth, '#d62839', 8);
  for (const y of [72, 104, 136, 166]) s += rect(89, y, 9, 12, 3, '#ffffff', 3);
  return s + sakura(137, 116, 30);
}

const samurai = {
  name: 'Samurai & Ninja', rarity: 'epic',
  tiers: {
    general: ['#e2463c', '#7a1310'], field: ['#3e5bb0', '#141f52'], company: ['#3e9a72', '#123f2c'],
    enlisted: ['#c9893f', '#5e3a14'], spy: ['#4a3d63', '#120d1c'], flag: ['#fff6e6', '#eed9b0'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => monMedal(t[0], t[1]),
  area: { s: 1, dx: 0, dy: 0 },
  general: sakura, field: fan, company: hishi,
  enlisted: (cx, cy, big) => bamboo(cx, cy, big ? 158 : 140, big ? 42 : 30),
  spy: () => shuriken(128, 128, 82),
  flag: nobori,
  mystery: () => mysteryMark(GOLD),
};

// --- Pack: Space Fleet --------------------------------------------------------------------------

function sparkle(cx, cy, r) {
  return faceted(cx, cy, starPoints(cx, cy, r, 4, 0.3), GOLD, lw(r)) + circ(cx + r * 0.62, cy - r * 0.62, r * 0.13, '#ffffff', 0);
}

function planet(cx, cy, r) {
  const rx = r * 1.18;
  const ry = r * 0.36;
  const ring = (c, w, front) => {
    const d = front
      ? `M${fmt(cx - rx)} ${fmt(cy)} A${fmt(rx)} ${fmt(ry)} 0 0 0 ${fmt(cx + rx)} ${fmt(cy)}`
      : `M${fmt(cx - rx)} ${fmt(cy)} A${fmt(rx)} ${fmt(ry)} 0 0 1 ${fmt(cx + rx)} ${fmt(cy)}`;
    return `<g transform="rotate(-18 ${fmt(cx)} ${fmt(cy)})">${stroke(d, c, w)}</g>`;
  };
  const body = r * 0.66;
  return ring(INK, r * 0.3, false) + ring(GOLD.mid, r * 0.15, false) +
    circ(cx, cy, body, GOLD.mid, lw(r) * 0.85) +
    `<path d="M${fmt(cx - body * 0.2)} ${fmt(cy - body * 0.98)} A${fmt(body)} ${fmt(body)} 0 0 1 ${fmt(cx + body * 0.98)} ${fmt(cy + body * 0.2)} A${fmt(body * 0.7)} ${fmt(body * 0.7)} 0 0 0 ${fmt(cx - body * 0.2)} ${fmt(cy - body * 0.98)} Z" fill="${GOLD.dark}" opacity="0.6"/>` +
    ell(cx - body * 0.35, cy - body * 0.35, body * 0.22, body * 0.14, '#ffffff', 0, -30, 'opacity="0.7"') +
    ring(INK, r * 0.3, true) + ring(GOLD.mid, r * 0.15, true);
}

function delta(cx, cy, r) {
  const tip = [cx, cy - r];
  const right = [cx + r * 0.82, cy + r * 0.72];
  const notch = [cx, cy + r * 0.32];
  const left = [cx - r * 0.82, cy + r * 0.72];
  return fill(P([tip, notch, left]), SILVER.light) + fill(P([tip, right, notch]), SILVER.dark) +
    ink(P([tip, right, notch, left]), lw(r)) + circ(cx, cy, r * 0.12, '#3fe0ff', lw(r) * 0.4);
}

function energyBar(cx, cy, w, h) {
  return rect(cx - w / 2 - 4, cy - h / 2 - 4, w + 8, h + 8, (h + 8) / 2, '#3fe0ff', 0).replace('/>', ' opacity="0.3"/>') +
    rect(cx - w / 2, cy - h / 2, w, h, h / 2, '#3fe0ff', 7) +
    stroke(`M${fmt(cx - w / 2 + h * 0.6)} ${fmt(cy)} H${fmt(cx + w / 2 - h * 0.6)}`, '#ffffff', h * 0.28);
}

function astroHelmet() {
  const visor = 'M70 114 C70 86 186 86 186 114 C186 152 70 152 70 114 Z';
  return rect(92, 186, 72, 22, 9, '#b6bfd6', 7) + circ(128, 122, 74, '#eef1f8', 9) +
    shape(visor, '#141a2e', 7) + stroke('M88 106 C94 96 108 92 122 92', '#ffffff', 6, 'opacity="0.8"') +
    circ(64, 140, 7, '#3fe0ff', 4) + circ(192, 140, 7, '#3fe0ff', 4) +
    stroke('M168 62 L184 38', INK, 7) + stroke('M168 62 L184 38', '#b6bfd6', 3) + circ(186, 35, 7, '#ff5a5f', 4);
}

function moonFlag() {
  const ground = 'M50 188 Q128 160 206 188 Q198 210 128 214 Q58 210 50 188 Z';
  return shape(ground, '#c9cfdf', 7) + circ(96, 194, 7, '#aab2c6', 3) + circ(160, 196, 5, '#aab2c6', 3) +
    rect(106, 50, 11, 140, 5.5, GOLD.mid, 6) + shape('M117 56 L198 80 L117 106 Z', '#e0476a', 7) + sparkle(146, 80, 14);
}

const space = {
  name: 'Space Fleet', rarity: 'epic',
  tiers: {
    general: ['#6c4ff0', '#1d1150'], field: ['#e0476a', '#5e0f24'], company: ['#2bb3c0', '#0b4a52'],
    enlisted: ['#7f8fae', '#262e42'], spy: ['#3a3f5c', '#0b0d17'], flag: ['#eef4ff', '#b6c6e6'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => hexMedal(t[0], t[1], t[0]),
  area: { s: 0.98, dx: 0, dy: 0 },
  general: sparkle, field: planet, company: delta,
  enlisted: (cx, cy, big) => energyBar(cx, cy, big ? 156 : 138, big ? 38 : 26),
  spy: astroHelmet,
  flag: moonFlag,
  mystery: () => mysteryMark(SILVER),
};

// --- Pack: Medieval Knights ---------------------------------------------------------------------

function crown(cx, cy, r) {
  const pts = [[-1, 0.5], [-1, -0.35], [-0.5, 0.05], [0, -0.62], [0.5, 0.05], [1, -0.35], [1, 0.5]].map(([x, y]) => [cx + x * r, cy + y * r]);
  return fill(P(pts), GOLD.mid) + fill(P([[cx - r, cy + r * 0.18], [cx + r, cy + r * 0.18], [cx + r, cy + r * 0.5], [cx - r, cy + r * 0.5]]), GOLD.dark) +
    ink(P(pts), lw(r)) + circ(cx - r, cy - r * 0.35, r * 0.13, '#e8475f', lw(r) * 0.5) + circ(cx, cy - r * 0.62, r * 0.15, '#3d8bff', lw(r) * 0.5) +
    circ(cx + r, cy - r * 0.35, r * 0.13, '#e8475f', lw(r) * 0.5) + circ(cx, cy + r * 0.34, r * 0.1, '#ffffff', 0);
}

function tower(cx, cy, r) {
  const pts = [[-0.62, 0.85], [-0.62, -0.85], [-0.32, -0.85], [-0.32, -0.6], [-0.12, -0.6], [-0.12, -0.85], [0.12, -0.85],
    [0.12, -0.6], [0.32, -0.6], [0.32, -0.85], [0.62, -0.85], [0.62, 0.85]].map(([x, y]) => [cx + x * r, cy + y * r]);
  const door = `M${fmt(cx - r * 0.2)} ${fmt(cy + r * 0.85)} V${fmt(cy + r * 0.38)} A${fmt(r * 0.2)} ${fmt(r * 0.2)} 0 0 1 ${fmt(cx + r * 0.2)} ${fmt(cy + r * 0.38)} V${fmt(cy + r * 0.85)} Z`;
  return fill(P(pts), SILVER.mid) + fill(P([[cx + r * 0.25, cy - r * 0.6], [cx + r * 0.62, cy - r * 0.6], [cx + r * 0.62, cy + r * 0.85], [cx + r * 0.25, cy + r * 0.85]]), SILVER.dark) +
    ink(P(pts), lw(r)) + shape(door, '#2a2236', lw(r) * 0.6) + rect(cx - r * 0.1, cy - r * 0.32, r * 0.2, r * 0.32, r * 0.08, '#2a2236', 0);
}

function sword(cx, cy, r) {
  r *= 1.08;
  const w = r * 0.32;
  const blade = [[cx, cy - r], [cx + w / 2, cy - r + w], [cx + w / 2, cy + r * 0.42], [cx - w / 2, cy + r * 0.42], [cx - w / 2, cy - r + w]];
  return fill(P(blade), SILVER.light) + fill(P([[cx, cy - r], [cx + w / 2, cy - r + w], [cx + w / 2, cy + r * 0.42], [cx, cy + r * 0.42]]), SILVER.dark) +
    ink(P(blade), lw(r) * 0.8) + rect(cx - r * 0.48, cy + r * 0.38, r * 0.96, r * 0.16, r * 0.08, GOLD.mid, lw(r) * 0.7) +
    rect(cx - r * 0.1, cy + r * 0.54, r * 0.2, r * 0.32, r * 0.06, '#7a4a2a', lw(r) * 0.6) + circ(cx, cy + r * 0.95, r * 0.13, GOLD.mid, lw(r) * 0.6);
}

function hood() {
  const cloak = 'M48 232 C54 184 84 160 128 156 C172 160 202 184 208 232 Z';
  const hoodPath = 'M128 40 C170 52 192 98 186 156 L70 156 C64 98 86 52 128 40 Z';
  return `<g clip-path="url(#shield)">${shape(cloak, '#4b4760', 8)}</g>` + shape(hoodPath, '#5b5770', 8) +
    fill('M128 40 C170 52 192 98 186 156 L156 156 C160 104 150 64 128 40 Z', '#46425a') +
    ell(128, 124, 33, 40, '#0d0c14', 6) + stroke('M110 160 L118 196 M146 160 L138 196', INK, 5);
}

function gonfalon() {
  const cloth = 'M72 64 H184 V168 L166 194 L148 168 L128 198 L108 168 L90 194 L72 168 Z';
  return stroke('M72 60 L128 36 L184 60', INK, 5) + rect(60, 56, 136, 12, 6, GOLD.mid, 6) + circ(60, 62, 8, GOLD.light, 5) +
    circ(196, 62, 8, GOLD.light, 5) + shape(cloth, '#d1394a', 8) + fill('M150 64 H184 V168 L166 194 L150 172 Z', '#b02a3b') + crown(128, 116, 28);
}

const knights = {
  name: 'Medieval Knights', rarity: 'rare',
  tiers: {
    general: ['#7b4fd0', '#2c1458'], field: ['#d1394a', '#5f1018'], company: ['#3a7fe0', '#13356a'],
    enlisted: ['#45995a', '#163d20'], spy: ['#4a4a58', '#141418'], flag: ['#f7f2e7', '#d9cbaa'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => shieldMedal(t[0], t[1], t[0] === '#f7f2e7' ? '#ffffff' : t[0]),
  area: { s: 0.9, dx: 0, dy: -4 },
  general: crown, field: tower, company: sword,
  enlisted: (cx, cy, big) => (big ? chevron(cx, cy - 8, 132, 52, 26, GOLD) : chevron(cx, cy, 116, 34, 18, GOLD)),
  spy: hood,
  flag: gonfalon,
  mystery: () => mysteryMark(GOLD),
};

// --- Pack: Neon Glyphs --------------------------------------------------------------------------

const NEON = { general: '#ffd23f', field: '#ff3fb4', company: '#22e3ff', enlisted: '#7cff4f', spy: '#b26bff', flag: '#ffffff', unknown: '#cfcadf' };
const neon = {
  name: 'Neon Glyphs', rarity: 'rare',
  tiers: Object.fromEntries(Object.entries(NEON).map(([k, v]) => [k, [v, v]])),
  medal: (t) => neonMedal(t[0]),
  area: { s: 0.92, dx: 0, dy: 0 },
  general: (cx, cy, r) => neonPath(P(starPoints(cx, cy, r * 0.95, 5, 0.45)), NEON.general, Math.max(3.5, r * 0.12)),
  field: (cx, cy, r) => neonPath(circlePath(cx, cy, r * 0.7), NEON.field, Math.max(3.5, r * 0.12)) + circ(cx, cy, r * 0.16, NEON.field, 0),
  company: (cx, cy, r) => neonPath(P([[cx, cy - r * 0.85], [cx + r * 0.85, cy + r * 0.6], [cx - r * 0.85, cy + r * 0.6]]), NEON.company, Math.max(3.5, r * 0.12)),
  enlisted: (cx, cy, big) => {
    const w = big ? 70 : 62;
    const h = big ? 34 : 24;
    return neonPath(`M${cx - w} ${cy + h} L${cx} ${cy - h} L${cx + w} ${cy + h}`, NEON.enlisted, big ? 8 : 6);
  },
  spy: () => neonPath(circlePath(128, 102, 28), NEON.spy, 7) + neonPath('M116 128 L102 182 H154 L140 128', NEON.spy, 7),
  flag: () => neonPath('M92 204 V52', NEON.flag, 7) + neonPath('M92 58 L186 86 L92 116', NEON.flag, 7) +
    neonPath(P(starPoints(120, 86, 12, 5, 0.45)), '#ffd23f', 3.5),
  mystery: () => neonPath(HOOK, NEON.unknown, 9) + circ(128, 190, 9, NEON.unknown, 0),
};

// --- Pack: Candy Land ---------------------------------------------------------------------------

function heart(cx, cy, r) {
  const d = `M${fmt(cx)} ${fmt(cy + r * 0.8)} C${fmt(cx - r * 1.3)} ${fmt(cy)} ${fmt(cx - r * 0.75)} ${fmt(cy - r * 1.05)} ${fmt(cx)} ${fmt(cy - r * 0.42)} ` +
    `C${fmt(cx + r * 0.75)} ${fmt(cy - r * 1.05)} ${fmt(cx + r * 1.3)} ${fmt(cy)} ${fmt(cx)} ${fmt(cy + r * 0.8)} Z`;
  return shape(d, '#ffffff', lw(r)) + ell(cx - r * 0.42, cy - r * 0.3, r * 0.2, r * 0.13, '#ffd6e6', 0, -35);
}

function donut(cx, cy, r) {
  const colors = ['#ff5a5f', '#ffd23f', '#3d8bff', '#27c98f', '#ffffff'];
  let s = circ(cx, cy, r * 0.82, '#f0b46a', lw(r)) + circ(cx, cy, r * 0.66, '#ff8fc4', 0) + circ(cx, cy, r * 0.26, '#1d9a76', lw(r) * 0.8);
  for (let i = 0; i < 8; i++) {
    const [x, y] = polar(cx, cy, r * 0.47, i * 45 + 10);
    const [x2, y2] = polar(x, y, r * 0.1, i * 70);
    s += stroke(`M${fmt(x)} ${fmt(y)} L${fmt(x2)} ${fmt(y2)}`, colors[i % colors.length], Math.max(3, r * 0.07));
  }
  return s;
}

function candyCorn(cx, cy, r) {
  const apex = [cx, cy - r];
  const bl = [cx - r * 0.9, cy + r * 0.72];
  const br = [cx + r * 0.9, cy + r * 0.72];
  const at = (t) => [[cx - r * 0.9 * t, cy - r + r * 1.72 * t], [cx + r * 0.9 * t, cy - r + r * 1.72 * t]];
  const [a1, b1] = at(0.38);
  const [a2, b2] = at(0.7);
  return fill(P([apex, b1, a1]), '#ffffff') + fill(P([a1, b1, b2, a2]), '#ff9a2e') + fill(P([a2, b2, br, bl]), '#ffd23f') + ink(P([apex, br, bl]), lw(r));
}

let caneId = 0;
function caneChevron(cx, cy, w, h, t) {
  const p = chevronPts(cx, cy, w, h, t);
  const id = `cane${caneId++}`;
  let stripes = '';
  for (let x = cx - w; x < cx + w; x += 18) stripes += `<path d="M${fmt(x)} ${fmt(cy + h + t)} L${fmt(x + 30)} ${fmt(cy - h - t)}" stroke="#ff4a6e" stroke-width="8"/>`;
  return `<defs><clipPath id="${id}"><path d="${P(p)}"/></clipPath></defs>` + fill(P(p), '#ffffff') +
    `<g clip-path="url(#${id})">${stripes}</g>` + ink(P(p), 7);
}

function lollipopLens() {
  let spiral = '';
  for (let i = 0; i <= 60; i++) {
    const a = i * 0.32;
    const r = 4 + i * 0.72;
    spiral += `${i === 0 ? 'M' : 'L'}${fmt(110 + Math.cos(a) * r)} ${fmt(106 + Math.sin(a) * r)} `;
  }
  return stroke('M146 142 L196 194', INK, 26) + stroke('M146 142 L196 194', '#ffffff', 14) +
    circ(110, 106, 56, '#ff6fa8', 9) + circ(110, 106, 44, '#ffffff', 0) + stroke(spiral, '#ff4a6e', 7) +
    ell(92, 84, 12, 7, '#ffffff', 0, -35, 'opacity="0.85"');
}

let flagCaneId = 0;
function caneFlag() {
  const id = `flagcane${flagCaneId++}`;
  const pole = 'M82 212 V66 C82 40 116 40 116 62';
  let stripes = '';
  for (let y = 30; y < 220; y += 16) stripes += `<path d="M60 ${y + 18} L140 ${y - 6}" stroke="#ff4a6e" stroke-width="7"/>`;
  const wafer = 'M90 72 L192 92 L90 124 Z';
  let grid = '';
  for (let i = 1; i < 5; i++) grid += stroke(`M${90 + i * 20} ${fmt(72 + i * 4)} V${fmt(124 - i * 6.4)}`, '#d99a4c', 3);
  return stroke(pole, INK, 22) + stroke(pole, '#ffffff', 12) +
    `<defs><clipPath id="${id}"><path d="M70 220 H96 V60 H70 Z"/></clipPath></defs><g clip-path="url(#${id})">${stripes}</g>` +
    shape(wafer, '#f5c27a', 7) + grid + ink(wafer, 7);
}

const candy = {
  name: 'Candy Land', rarity: 'rare',
  tiers: {
    general: ['#ff8ec0', '#d13a7c'], field: ['#7de8c8', '#1d9a76'], company: ['#9dbcff', '#3d5fd6'],
    enlisted: ['#ffe68a', '#eba21e'], spy: ['#6a5680', '#221a2b'], flag: ['#fff6e4', '#f3d39f'], unknown: ['#c9c2dd', '#6f6890'],
  },
  medal: (t) => candyMedal(t[0], t[1]),
  area: { s: 0.94, dx: 0, dy: 0 },
  general: heart, field: donut, company: candyCorn,
  enlisted: (cx, cy, big) => (big ? caneChevron(cx, cy - 8, 140, 56, 28) : caneChevron(cx, cy, 124, 34, 20)),
  spy: lollipopLens,
  flag: caneFlag,
  mystery: () => mysteryMark({ light: '#ffd6e6', mid: '#ff6fa8', dark: '#d13a7c' }),
};

// --- Pack: Pirates ------------------------------------------------------------------------------

function skull(cx, cy, r) {
  const w = lw(r) * 0.8;
  const bone = '#f4ecd8';
  return circ(cx, cy - r * 0.15, r * 0.72 + w / 2, INK) + rect(cx - r * 0.42 - w / 2, cy + r * 0.22 - w / 2, r * 0.84 + w, r * 0.5 + w, r * 0.18, INK) +
    circ(cx, cy - r * 0.15, r * 0.72, bone) + rect(cx - r * 0.42, cy + r * 0.22, r * 0.84, r * 0.5, r * 0.15, bone) +
    ell(cx - r * 0.28, cy - r * 0.12, r * 0.2, r * 0.24, INK) + ell(cx + r * 0.28, cy - r * 0.12, r * 0.2, r * 0.24, INK) +
    fill(P([[cx, cy + r * 0.08], [cx - r * 0.09, cy + r * 0.24], [cx + r * 0.09, cy + r * 0.24]]), INK) +
    stroke(`M${fmt(cx - r * 0.18)} ${fmt(cy + r * 0.42)} V${fmt(cy + r * 0.66)} M${fmt(cx)} ${fmt(cy + r * 0.42)} V${fmt(cy + r * 0.68)} M${fmt(cx + r * 0.18)} ${fmt(cy + r * 0.42)} V${fmt(cy + r * 0.66)}`, INK, Math.max(2, r * 0.06));
}

function anchor(cx, cy, r) {
  const d = `M${fmt(cx)} ${fmt(cy - r * 0.6)} V${fmt(cy + r * 0.8)} M${fmt(cx - r * 0.5)} ${fmt(cy - r * 0.38)} H${fmt(cx + r * 0.5)} ` +
    `M${fmt(cx - r * 0.78)} ${fmt(cy + r * 0.2)} Q${fmt(cx)} ${fmt(cy + r * 1.2)} ${fmt(cx + r * 0.78)} ${fmt(cy + r * 0.2)}`;
  const ring = circlePath(cx, cy - r * 0.8, r * 0.18);
  const fluke = (x, s) => P([[x, cy + r * 0.05], [x + s * r * 0.24, cy + r * 0.32], [x - s * r * 0.1, cy + r * 0.3]]);
  return stroke(d, INK, r * 0.34) + stroke(ring, INK, r * 0.3) + stroke(d, GOLD.mid, r * 0.17) + stroke(ring, GOLD.mid, r * 0.14) +
    shape(fluke(cx - r * 0.78, -1), GOLD.mid, 4) + shape(fluke(cx + r * 0.78, 1), GOLD.mid, 4);
}

function cutlass(cx, cy, r) {
  r *= 1.12;
  const blade = `M${fmt(cx - r * 0.2)} ${fmt(cy + r * 0.32)} C${fmt(cx - r * 0.3)} ${fmt(cy - r * 0.3)} ${fmt(cx + r * 0.02)} ${fmt(cy - r * 0.84)} ${fmt(cx + r * 0.44)} ${fmt(cy - r)} ` +
    `C${fmt(cx + r * 0.28)} ${fmt(cy - r * 0.55)} ${fmt(cx + r * 0.2)} ${fmt(cy - r * 0.1)} ${fmt(cx + r * 0.2)} ${fmt(cy + r * 0.32)} Z`;
  const bow = `M${fmt(cx - r * 0.42)} ${fmt(cy + r * 0.36)} Q${fmt(cx - r * 0.5)} ${fmt(cy + r * 0.95)} ${fmt(cx + r * 0.05)} ${fmt(cy + r * 0.95)}`;
  return shape(blade, SILVER.mid, lw(r) * 0.85) + rect(cx - r * 0.45, cy + r * 0.3, r * 0.9, r * 0.14, r * 0.07, GOLD.mid, lw(r) * 0.6) +
    rect(cx - r * 0.09, cy + r * 0.44, r * 0.18, r * 0.4, r * 0.06, '#7a4a2a', lw(r) * 0.55) +
    stroke(bow, INK, r * 0.16) + stroke(bow, GOLD.mid, r * 0.08);
}

function ropeChevron(cx, cy, w, h, t) {
  const p = chevronPts(cx, cy, w, h, t);
  let twists = '';
  for (let i = 1; i < 6; i++) {
    const f = i / 6;
    const [x1, y1] = [p[5][0] + (p[0][0] - p[5][0]) * f, p[5][1] + (p[0][1] - p[5][1]) * f];
    const [x2, y2] = [p[1][0] + (p[0][0] - p[1][0]) * f, p[1][1] + (p[0][1] - p[1][1]) * f];
    twists += stroke(`M${fmt(x1)} ${fmt(y1)} l${fmt(-6)} ${fmt(t)}`, '#8a5a2b', 3) + stroke(`M${fmt(x2)} ${fmt(y2)} l${fmt(6)} ${fmt(t)}`, '#8a5a2b', 3);
  }
  return fill(P(p), '#e3bd85') + twists + ink(P(p), 7);
}

function spyglass() {
  return `<g transform="rotate(-32 128 128)">` +
    rect(52, 108, 66, 40, 8, '#7a4a2a', 7) + rect(112, 112, 52, 32, 7, GOLD.mid, 7) + rect(158, 117, 40, 22, 6, GOLD.light, 7) +
    rect(196, 120, 12, 16, 4, '#3b2a20', 5) + rect(70, 104, 10, 48, 4, GOLD.mid, 5) + ell(52, 128, 10, 22, '#9fd8ff', 6) + '</g>';
}

function pirateFlag() {
  const cloth = 'M84 52 C120 44 160 62 198 52 V140 C160 150 120 132 84 140 Z';
  return rect(70, 42, 13, 176, 6.5, GOLD.mid, 7) + shape(cloth, '#1b1b22', 8) +
    stroke('M118 126 L162 84 M118 84 L162 126', INK, 13) + stroke('M118 126 L162 84 M118 84 L162 126', '#f4ecd8', 7) + skull(140, 96, 24);
}

const pirates = {
  name: 'Pirate Crew', rarity: 'epic',
  tiers: {
    general: ['#4a4a56', '#121217'], field: ['#3a62b0', '#152a55'], company: ['#b23a4a', '#541520'],
    enlisted: ['#3aa39a', '#145049'], spy: ['#5b4a7a', '#211a33'], flag: ['#f6ecd2', '#dcc597'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => coinMedal(t[0], t[1]),
  area: { s: 0.88, dx: 0, dy: 0 },
  general: skull, field: anchor, company: cutlass,
  enlisted: (cx, cy, big) => (big ? ropeChevron(cx, cy - 8, 128, 52, 26) : ropeChevron(cx, cy, 114, 32, 18)),
  spy: spyglass,
  flag: pirateFlag,
  mystery: () => mysteryMark(GOLD),
};

// --- Pack: Deep Sea -----------------------------------------------------------------------------

function bubbleMedal(c, e) {
  return circleMedal(c, e, '#bff3ff') +
    circ(52, 168, 9, 'none', 0, `stroke="#ffffff" stroke-width="3" opacity="0.7"`) + circ(44, 146, 5, 'none', 0, `stroke="#ffffff" stroke-width="2.5" opacity="0.7"`) +
    circ(204, 176, 7, 'none', 0, `stroke="#ffffff" stroke-width="3" opacity="0.7"`) + circ(212, 196, 4, '#ffffff', 0, 'opacity="0.6"');
}

function starfish(cx, cy, r) {
  const pts = starPoints(cx, cy, r, 5, 0.5);
  let s = fill(P(pts), '#ffb14a') + ink(P(pts), lw(r) * 1.15);
  for (let k = 0; k < 5; k++) {
    for (const f of [0.38, 0.64]) {
      const [x, y] = polar(cx, cy, r * f, -90 + k * 72);
      s += circ(x, y, Math.max(1.8, r * 0.07), '#fff1d6', 0);
    }
  }
  return s + circ(cx, cy, r * 0.12, '#ff7a3a', 0);
}

function shell(cx, cy, r) {
  const px = cx;
  const py = cy + r * 0.62;
  const R = r * 1.12;
  const n = 7;
  const tips = [];
  for (let i = 0; i <= n; i++) tips.push(polar(px, py, R, -165 + (150 * i) / n));
  let edge = `M${fmt(px)} ${fmt(py)} L${fmt(tips[0][0])} ${fmt(tips[0][1])}`;
  for (let i = 0; i < n; i++) {
    const [mx, my] = polar(px, py, R * 1.08, -165 + (150 * (i + 0.5)) / n);
    edge += ` Q${fmt(mx)} ${fmt(my)} ${fmt(tips[i + 1][0])} ${fmt(tips[i + 1][1])}`;
  }
  edge += ' Z';
  let ribs = '';
  for (let i = 1; i < n; i++) ribs += stroke(`M${fmt(px)} ${fmt(py)} L${fmt(tips[i][0])} ${fmt(tips[i][1])}`, '#e79a8a', Math.max(2, r * 0.06));
  const ear = P([[px - r * 0.34, py + r * 0.02], [px + r * 0.34, py + r * 0.02], [px + r * 0.22, py + r * 0.26], [px - r * 0.22, py + r * 0.26]]);
  return shape(ear, '#ffd2c4', lw(r) * 0.6) + fill(edge, '#ffe3d6') + ribs + ink(edge, lw(r) * 0.9);
}

function fish(cx, cy, r) {
  const body = `M${fmt(cx - r * 0.55)} ${fmt(cy)} C${fmt(cx - r * 0.3)} ${fmt(cy - r * 0.62)} ${fmt(cx + r * 0.55)} ${fmt(cy - r * 0.55)} ${fmt(cx + r * 0.8)} ${fmt(cy)} ` +
    `C${fmt(cx + r * 0.55)} ${fmt(cy + r * 0.55)} ${fmt(cx - r * 0.3)} ${fmt(cy + r * 0.62)} ${fmt(cx - r * 0.55)} ${fmt(cy)} Z`;
  const tail = P([[cx - r * 0.45, cy], [cx - r * 1.0, cy - r * 0.45], [cx - r * 0.9, cy], [cx - r * 1.0, cy + r * 0.45]]);
  return shape(tail, '#ff9a2e', lw(r) * 0.8) + shape(body, '#ffd23f', lw(r) * 0.85) +
    stroke(`M${fmt(cx + r * 0.05)} ${fmt(cy - r * 0.42)} Q${fmt(cx + r * 0.2)} ${fmt(cy)} ${fmt(cx + r * 0.05)} ${fmt(cy + r * 0.42)}`, '#ff9a2e', Math.max(3, r * 0.12)) +
    circ(cx + r * 0.48, cy - r * 0.1, r * 0.1, INK, 0) + circ(cx + r * 0.51, cy - r * 0.13, r * 0.035, '#ffffff', 0);
}

function wave(cx, cy, big) {
  const w = big ? 150 : 132;
  const a = big ? 18 : 11;
  let d = `M${fmt(cx - w / 2)} ${fmt(cy)}`;
  for (let i = 1; i <= 24; i++) {
    const x = cx - w / 2 + (w * i) / 24;
    d += ` L${fmt(x)} ${fmt(cy - Math.sin((i / 24) * Math.PI * 3) * a)}`;
  }
  return stroke(d, INK, big ? 24 : 18) + stroke(d, '#e8fbff', big ? 13 : 9);
}

function periscope() {
  const water = 'M40 178 Q64 166 88 178 T136 178 T184 178 T232 178 V250 H24 V178 Z';
  return `<defs><clipPath id="disc"><circle cx="128" cy="128" r="106"/></clipPath></defs>` +
    `<g clip-path="url(#disc)">${shape(water, '#1e6fb8', 7)}</g>` +
    stroke('M112 196 V82 H158', INK, 34) + stroke('M112 196 V82 H158', '#9aa4bc', 20) +
    rect(150, 64, 34, 36, 8, '#9aa4bc', 7) + rect(178, 70, 12, 24, 4, '#7fe0ff', 5) +
    stroke('M104 120 H120 M104 150 H120', INK, 4);
}

function buoyFlag() {
  const waterLine = 'M56 196 Q74 186 92 196 T128 196 T164 196 T200 196';
  const buoy = 'M92 196 L108 112 H148 L164 196 Z';
  return stroke('M128 112 V48', INK, 10) + stroke('M128 112 V48', GOLD.mid, 5) + shape('M131 50 L188 66 L131 84 Z', '#ff5a5f', 6) +
    shape(buoy, '#ffffff', 7) + fill('M100 156 H156 L160 176 H96 Z', '#ff5a5f') + ink(buoy, 7) +
    stroke(waterLine, INK, 14) + stroke(waterLine, '#7fd6ff', 7);
}

const ocean = {
  name: 'Deep Sea', rarity: 'rare',
  tiers: {
    general: ['#ff8a65', '#b8361e'], field: ['#3fc5c0', '#0f5e66'], company: ['#4c86e6', '#18397a'],
    enlisted: ['#5cbf7e', '#1c5a37'], spy: ['#3a3f6a', '#0a0d24'], flag: ['#fff3d6', '#e9c98c'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => bubbleMedal(t[0], t[1]),
  area: { s: 0.96, dx: 0, dy: 0 },
  general: starfish, field: shell, company: fish,
  enlisted: (cx, cy, big) => wave(cx, cy, big),
  spy: periscope,
  flag: buoyFlag,
  mystery: () => mysteryMark(GOLD),
};

// --- Pack: Wild Safari --------------------------------------------------------------------------

function ropeMedal(c, e) {
  return `<defs>${radial('m', c, e)}</defs><circle cx="128" cy="128" r="112" fill="url(#m)" stroke="${INK}" stroke-width="10"/>` +
    `<circle cx="128" cy="128" r="99" fill="none" stroke="#e6c48a" stroke-width="7"/>` +
    `<circle cx="128" cy="128" r="99" fill="none" stroke="#8a5a2b" stroke-width="7" stroke-dasharray="5 7"/>` + gloss(0.14);
}

function paw(cx, cy, r) {
  const pad = `M${fmt(cx)} ${fmt(cy + r * 0.05)} C${fmt(cx + r * 0.5)} ${fmt(cy + r * 0.05)} ${fmt(cx + r * 0.62)} ${fmt(cy + r * 0.72)} ${fmt(cx)} ${fmt(cy + r * 0.72)} ` +
    `C${fmt(cx - r * 0.62)} ${fmt(cy + r * 0.72)} ${fmt(cx - r * 0.5)} ${fmt(cy + r * 0.05)} ${fmt(cx)} ${fmt(cy + r * 0.05)} Z`;
  let s = shape(pad, '#3b2416', lw(r) * 0.5);
  for (const [dx, dy, rot] of [[-0.56, -0.18, -25], [-0.2, -0.56, -8], [0.2, -0.56, 8], [0.56, -0.18, 25]]) {
    s += ell(cx + dx * r, cy + dy * r, r * 0.17, r * 0.24, '#3b2416', lw(r) * 0.5, rot);
  }
  return s + ell(cx - r * 0.12, cy + r * 0.3, r * 0.12, r * 0.07, '#ffffff', 0, -20, 'opacity="0.35"');
}

function leaf(cx, cy, r) {
  const d = `M${fmt(cx)} ${fmt(cy - r)} C${fmt(cx + r * 0.7)} ${fmt(cy - r * 0.4)} ${fmt(cx + r * 0.7)} ${fmt(cy + r * 0.4)} ${fmt(cx)} ${fmt(cy + r * 0.9)} ` +
    `C${fmt(cx - r * 0.7)} ${fmt(cy + r * 0.4)} ${fmt(cx - r * 0.7)} ${fmt(cy - r * 0.4)} ${fmt(cx)} ${fmt(cy - r)} Z`;
  let veins = stroke(`M${fmt(cx)} ${fmt(cy - r * 0.8)} V${fmt(cy + r * 1.05)}`, '#4e7a1e', Math.max(2.5, r * 0.08));
  for (const f of [-0.4, 0, 0.4]) {
    veins += stroke(`M${fmt(cx)} ${fmt(cy + f * r)} L${fmt(cx + r * 0.36)} ${fmt(cy + f * r - r * 0.26)} M${fmt(cx)} ${fmt(cy + f * r)} L${fmt(cx - r * 0.36)} ${fmt(cy + f * r - r * 0.26)}`,
      '#4e7a1e', Math.max(2, r * 0.06));
  }
  return `<g transform="rotate(20 ${fmt(cx)} ${fmt(cy)})">` + fill(d, '#d6f28a') + veins + ink(d, lw(r) * 0.85) + '</g>';
}

function feather(cx, cy, r) {
  r *= 1.12;
  const vane = `M${fmt(cx)} ${fmt(cy - r)} C${fmt(cx + r * 0.66)} ${fmt(cy - r * 0.5)} ${fmt(cx + r * 0.6)} ${fmt(cy + r * 0.35)} ${fmt(cx + r * 0.05)} ${fmt(cy + r * 0.6)} ` +
    `L${fmt(cx - r * 0.05)} ${fmt(cy + r * 0.6)} C${fmt(cx - r * 0.6)} ${fmt(cy + r * 0.35)} ${fmt(cx - r * 0.66)} ${fmt(cy - r * 0.5)} ${fmt(cx)} ${fmt(cy - r)} Z`;
  let barbs = '';
  for (const f of [-0.55, -0.2, 0.15]) barbs += stroke(`M${fmt(cx)} ${fmt(cy + f * r)} L${fmt(cx + r * 0.32)} ${fmt(cy + f * r - r * 0.16)}`, '#d9a066', Math.max(2, r * 0.06));
  return `<g transform="rotate(-18 ${fmt(cx)} ${fmt(cy)})">` + fill(vane, '#fff1d6') + barbs + ink(vane, lw(r) * 0.85) +
    stroke(`M${fmt(cx)} ${fmt(cy - r * 0.85)} V${fmt(cy + r * 1.0)}`, INK, Math.max(5, r * 0.16)) + stroke(`M${fmt(cx)} ${fmt(cy - r * 0.85)} V${fmt(cy + r * 1.0)}`, '#c8742f', Math.max(2.5, r * 0.08)) + '</g>';
}

function clawSlash(cx, cy, big) {
  const w = big ? 84 : 72;
  const h = big ? 26 : 17;
  const d = `M${fmt(cx - w)} ${fmt(cy + h)} Q${fmt(cx)} ${fmt(cy - h * 2.2)} ${fmt(cx + w)} ${fmt(cy - h)} Q${fmt(cx)} ${fmt(cy - h * 0.2)} ${fmt(cx - w)} ${fmt(cy + h)} Z`;
  return shape(d, '#fff1d6', big ? 7 : 6);
}

function binoculars() {
  return rect(70, 84, 46, 92, 18, '#3b3852', 8) + rect(140, 84, 46, 92, 18, '#3b3852', 8) + rect(108, 104, 40, 34, 8, '#2a2836', 7) +
    circ(93, 166, 26, '#7fd6ff', 8) + circ(163, 166, 26, '#7fd6ff', 8) +
    stroke('M82 156 Q88 148 98 148 M152 156 Q158 148 168 148', '#ffffff', 5, 'opacity="0.85"') + rect(118, 72, 20, 22, 6, '#6e6a8a', 6);
}

function explorerFlag() {
  const grass = 'M60 212 L74 180 L84 204 L96 172 L106 206 L120 178 L128 210 Z';
  return rect(96, 46, 12, 160, 6, '#8a5a2b', 7) + shape('M108 52 L196 74 L108 100 Z', '#7cbf4e', 7) + paw(140, 72, 18) + shape(grass, '#5aa03a', 6);
}

const safari = {
  name: 'Wild Safari', rarity: 'rare',
  tiers: {
    general: ['#f6c25a', '#9a5a12'], field: ['#86c95a', '#2f5e1a'], company: ['#e07a48', '#7a2e10'],
    enlisted: ['#b89a72', '#4e3b24'], spy: ['#5a5644', '#191710'], flag: ['#fff4dc', '#e6cf9c'], unknown: ['#8b84a8', '#3a3552'],
  },
  medal: (t) => ropeMedal(t[0], t[1]),
  area: { s: 0.94, dx: 0, dy: 0 },
  general: paw, field: leaf, company: feather,
  enlisted: (cx, cy, big) => clawSlash(cx, cy, big),
  spy: binoculars,
  flag: explorerFlag,
  mystery: () => mysteryMark(GOLD),
};

// --- Third-party glyphs (game-icons.net, CC BY 3.0; see assets/icons/CREDITS.md) ----------------

const VENDOR = path.join(__dirname, 'vendor', 'game-icons');
const glyphCache = {};
let gradId = 0;

function glyphPaths(name) {
  if (!glyphCache[name]) {
    const svg = fs.readFileSync(path.join(VENDOR, `${name}.svg`), 'utf8');
    glyphCache[name] = [...svg.matchAll(/<path[^>]*\sd="([^"]+)"[^>]*\/>/g)].map((m) => m[1]).filter((d) => !d.startsWith('M0 0h512v512H0z'));
    if (glyphCache[name].length === 0) throw new Error(`no glyph path in ${name}`);
  }
  return glyphCache[name];
}

// A vendored glyph centred on (cx, cy) inside a `size` box, filled with a vertical gradient and
// wrapped in our ink outline (stroked underneath so only the outer half shows).
function glyph(name, cx, cy, size, paint, outlinePx = Math.max(5, size * 0.05)) {
  const k = size / 512;
  const id = `g${gradId++}`;
  const w = (2 * outlinePx) / k;
  let s = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${paint.light}"/>` +
    `<stop offset="0.55" stop-color="${paint.mid}"/><stop offset="1" stop-color="${paint.dark}"/></linearGradient></defs>` +
    `<g transform="translate(${fmt(cx - size / 2)} ${fmt(cy - size / 2)}) scale(${Number(k.toFixed(5))})">`;
  for (const d of glyphPaths(name)) s += `<path d="${d}" fill="${INK}" stroke="${INK}" stroke-width="${fmt(w)}" stroke-linejoin="round"/>`;
  for (const d of glyphPaths(name)) s += `<path d="${d}" fill="url(#${id})"/>`;
  return s + '</g>';
}

// Repeated rank mark from a glyph: `size` scales the mark relative to its layout radius.
const mark = (name, paint, scale = 2.1) => (cx, cy, r) => glyph(name, cx, cy, r * scale, paint);

const PAINT = {
  gold: GOLD, silver: SILVER,
  ice: { light: '#ffffff', mid: '#bfefff', dark: '#5cc6e6' },
  bone: { light: '#ffffff', mid: '#f1e8d2', dark: '#c9b98f' },
  orange: { light: '#ffd27a', mid: '#ff9a2e', dark: '#d9580a' },
  green: { light: '#c8f5a0', mid: '#7bd65a', dark: '#2f8a2a' },
  red: { light: '#ff9a9a', mid: '#ff4a5a', dark: '#b31a2a' },
  ghost: { light: '#ffffff', mid: '#eef0ff', dark: '#b9bfe0' },
  dark: { light: '#6a6480', mid: '#3a3550', dark: '#1d1736' },
  wood: { light: '#e0a066', mid: '#b86a32', dark: '#7a3e16' },
  emerald: { light: '#b8f5d0', mid: '#3ec98a', dark: '#137a4a' },
  purple: { light: '#e2c8ff', mid: '#b07cf0', dark: '#6a32b8' },
};

// Simple bar mark shared by several enlisted sets.
function bar(cx, cy, w, h, paint, stripe = null) {
  let s = rect(cx - w / 2, cy - h / 2, w, h, h / 2, paint.mid, 0) +
    rect(cx - w / 2 + h * 0.3, cy - h / 2 + h * 0.15, w - h * 0.6, h * 0.24, h * 0.12, paint.light, 0);
  if (stripe) s += rect(cx - w / 2 + h * 0.5, cy - h * 0.12, w - h, h * 0.24, h * 0.12, stripe, 0);
  return s + rect(cx - w / 2, cy - h / 2, w, h, h / 2, 'none', 7);
}
const barSet = (paint, stripe = null) => (cx, cy, big) => bar(cx, cy, big ? 160 : 142, big ? 44 : 30, paint, stripe);

// Extra medallions --------------------------------------------------------------------------------

function gearMedal(c, e) {
  const pts = [];
  for (let i = 0; i < 24; i++) {
    const a0 = i * 15;
    pts.push(polar(128, 128, i % 2 === 0 ? 118 : 106, a0 - 4.5), polar(128, 128, i % 2 === 0 ? 118 : 106, a0 + 4.5));
  }
  return `<defs>${radial('m', c, e)}</defs>` + fill(P(pts), 'url(#m)') + ink(P(pts), 9) +
    `<circle cx="128" cy="128" r="94" fill="none" stroke="#ffffff" stroke-width="4" opacity="0.35"/>` + gloss(0.14);
}

function stitchedMedal(c, e, thread) {
  return circleMedal(c, e, c) +
    `<circle cx="128" cy="128" r="101" fill="none" stroke="${thread}" stroke-width="5" stroke-dasharray="9 7" stroke-linecap="round"/>`;
}

function woodShieldMedal(c, e) {
  let planks = '';
  for (let x = 58; x <= 198; x += 28) planks += stroke(`M${x} 26 V230`, INK, 3, 'opacity="0.35"');
  return `<defs>${radial('m', c, e)}<clipPath id="inner"><circle cx="128" cy="128" r="100"/></clipPath></defs>` +
    `<circle cx="128" cy="128" r="112" fill="#9aa4b8" stroke="${INK}" stroke-width="10"/>` +
    `<circle cx="128" cy="128" r="100" fill="url(#m)" stroke="${INK}" stroke-width="5"/>` +
    `<g clip-path="url(#inner)">${planks}</g>` +
    [0, 90, 180, 270].map((a) => { const [x, y] = polar(128, 128, 106, a + 45); return circ(x, y, 4.5, '#e9edf5', 2.5); }).join('') + gloss(0.12);
}

function stoneMedal(c, e) {
  const pts = [];
  const jag = [0, 5, -3, 4, -5, 2, 6, -2, 3, -4, 5, -1, 2, -5, 4, -3, 6, -2];
  for (let i = 0; i < 36; i++) pts.push(polar(128, 128, 111 + jag[i % jag.length] * 0.9, i * 10));
  return `<defs>${radial('m', c, e)}</defs>` + fill(P(pts), 'url(#m)') + ink(P(pts), 10) +
    stroke('M60 62 L72 74 M188 196 L176 186 M196 74 L184 82', INK, 3, 'opacity="0.35"') + gloss(0.12);
}

function vinylMedal(c, e) {
  return `<defs>${radial('m', c, e)}</defs>` + circ(128, 128, 116, '#1b1a22', 9) +
    [108, 102, 96].map((r) => `<circle cx="128" cy="128" r="${r}" fill="none" stroke="#3a3946" stroke-width="2"/>`).join('') +
    `<circle cx="128" cy="128" r="90" fill="url(#m)" stroke="${INK}" stroke-width="5"/>` +
    stroke('M52 70 A90 90 0 0 1 96 34', '#ffffff', 5, 'opacity="0.25"');
}

function burstMedal(c, e) {
  const pts = starPoints(128, 128, 120, 16, 0.86, -90);
  return `<defs>${radial('m', c, e)}</defs>` + fill(P(pts), 'url(#m)') + ink(P(pts), 9) +
    `<circle cx="128" cy="128" r="94" fill="none" stroke="#ffffff" stroke-width="4" opacity="0.4"/>` + gloss(0.14);
}

function starryMedal(c, e) {
  let dots = '';
  for (const [x, y, r] of [[56, 92, 2.5], [70, 186, 2], [190, 70, 2.5], [204, 160, 2], [150, 214, 2], [100, 44, 2]]) dots += circ(x, y, r, '#ffffff', 0, 'opacity="0.8"');
  return circleMedal(c, e, '#ffe680') + dots;
}

// Self-drawn simple marks (bold silhouettes that stay readable when small) -------------------------

function gem(cx, cy, r) {
  const p = [[-0.95, -0.28], [-0.5, -0.78], [0.5, -0.78], [0.95, -0.28], [0, 0.95]].map(([x, y]) => [cx + x * r, cy + y * r]);
  const c = [cx, cy - r * 0.28];
  return fill(P([p[0], p[1], p[2], p[3]]), PAINT.ice.light) + fill(P([p[0], p[3], p[4]]), PAINT.ice.mid) +
    fill(P([c, p[3], p[4]]), PAINT.ice.dark) + stroke(`M${fmt(p[0][0])} ${fmt(p[0][1])} H${fmt(p[3][0])}`, INK, 3) +
    ink(P(p), lw(r));
}

function sheriffStar(cx, cy, r) {
  const pts = starPoints(cx, cy, r * 0.92, 6, 0.55);
  let s = faceted(cx, cy, pts, GOLD, lw(r));
  for (let i = 0; i < 6; i++) {
    const [x, y] = polar(cx, cy, r * 0.98, -90 + i * 60);
    s += circ(x, y, r * 0.13, GOLD.light, lw(r) * 0.55);
  }
  return s + circ(cx, cy, r * 0.22, GOLD.dark, lw(r) * 0.5);
}

function ankh(cx, cy, r) {
  const d = `M${fmt(cx)} ${fmt(cy - r * 0.1)} V${fmt(cy + r)} M${fmt(cx - r * 0.55)} ${fmt(cy + r * 0.05)} H${fmt(cx + r * 0.55)}`;
  const loop = `M${fmt(cx)} ${fmt(cy - r * 0.1)} C${fmt(cx - r * 0.55)} ${fmt(cy - r * 0.45)} ${fmt(cx - r * 0.38)} ${fmt(cy - r * 1.02)} ${fmt(cx)} ${fmt(cy - r * 1.02)} ` +
    `C${fmt(cx + r * 0.38)} ${fmt(cy - r * 1.02)} ${fmt(cx + r * 0.55)} ${fmt(cy - r * 0.45)} ${fmt(cx)} ${fmt(cy - r * 0.1)}`;
  return stroke(d, INK, r * 0.42) + stroke(loop, INK, r * 0.36) + stroke(d, GOLD.mid, r * 0.24) + stroke(loop, GOLD.mid, r * 0.2) +
    stroke(`M${fmt(cx - r * 0.06)} ${fmt(cy + r * 0.2)} V${fmt(cy + r * 0.85)}`, GOLD.light, r * 0.07);
}

function pyramid(cx, cy, r) {
  const top = [cx, cy - r * 0.85];
  const bl = [cx - r, cy + r * 0.7];
  const br = [cx + r, cy + r * 0.7];
  const mid = [cx + r * 0.18, cy + r * 0.7];
  return fill(P([top, bl, mid]), '#ffe08a') + fill(P([top, mid, br]), '#d99a2e') +
    stroke(`M${fmt(cx - r * 0.45)} ${fmt(cy - r * 0.05)} L${fmt(cx + r * 0.08)} ${fmt(cy - r * 0.05)} M${fmt(cx - r * 0.7)} ${fmt(cy + r * 0.32)} L${fmt(cx + r * 0.13)} ${fmt(cy + r * 0.32)}`, '#b07a1e', Math.max(2.5, r * 0.06)) +
    ink(P([top, br, bl]), lw(r));
}

function bone(cx, cy, w, h, color) {
  const knob = h * 0.42;
  const ends = [[cx - w / 2, cy - knob * 0.7], [cx - w / 2, cy + knob * 0.7], [cx + w / 2, cy - knob * 0.7], [cx + w / 2, cy + knob * 0.7]];
  let s = rect(cx - w / 2, cy - h * 0.3 - 6, w, h * 0.6 + 12, h * 0.3, INK, 0);
  for (const [x, y] of ends) s += circ(x, y, knob + 6, INK, 0);
  s += rect(cx - w / 2, cy - h * 0.3, w, h * 0.6, h * 0.3, color, 0);
  for (const [x, y] of ends) s += circ(x, y, knob, color, 0);
  return s + rect(cx - w / 2 + 8, cy - h * 0.18, w - 16, h * 0.14, h * 0.07, '#ffffff', 0).replace('/>', ' opacity="0.6"/>');
}
const boneSet = (color) => (cx, cy, big) => bone(cx, cy, big ? 120 : 108, big ? 48 : 34, color);

function dinoPrint(cx, cy, r) {
  const col = '#3b2416';
  let s = ell(cx, cy + r * 0.35, r * 0.42, r * 0.36, col, lw(r) * 0.45);
  for (const a of [-125, -90, -55]) {
    const [x, y] = polar(cx, cy + r * 0.2, r * 0.72, a);
    const [bx, by] = polar(cx, cy + r * 0.2, r * 0.25, a);
    s += stroke(`M${fmt(bx)} ${fmt(by)} L${fmt(x)} ${fmt(y)}`, INK, r * 0.36) + stroke(`M${fmt(bx)} ${fmt(by)} L${fmt(x)} ${fmt(y)}`, col, r * 0.24);
  }
  return s;
}

function note(cx, cy, r) {
  const head = ell(cx - r * 0.25, cy + r * 0.55, r * 0.38, r * 0.28, GOLD.mid, lw(r) * 0.8, -20);
  const stem = `M${fmt(cx + r * 0.1)} ${fmt(cy + r * 0.5)} V${fmt(cy - r * 0.9)}`;
  const flag = `M${fmt(cx + r * 0.1)} ${fmt(cy - r * 0.9)} C${fmt(cx + r * 0.5)} ${fmt(cy - r * 0.6)} ${fmt(cx + r * 0.75)} ${fmt(cy - r * 0.35)} ${fmt(cx + r * 0.45)} ${fmt(cy + r * 0.05)}`;
  return stroke(stem, INK, r * 0.26) + stroke(flag, INK, r * 0.28) + stroke(stem, GOLD.mid, r * 0.13) + stroke(flag, GOLD.mid, r * 0.14) + head;
}

function equalizer(cx, cy, big) {
  const n = 5;
  const w = big ? 150 : 140;
  const h = big ? 40 : 28;
  const seg = (w - (n - 1) * 6) / n;
  const colors = ['#27c98f', '#7bd65a', '#ffd23f', '#ff9a2e', '#ff4a5a'];
  let s = '';
  for (let i = 0; i < n; i++) s += rect(cx - w / 2 + i * (seg + 6), cy - h / 2, seg, h, 6, colors[i], 6);
  return s;
}

function bolt(cx, cy, r) {
  const pts = [[0.26, -1], [-0.72, 0.14], [-0.03, 0.14], [-0.26, 1], [0.75, -0.2], [0.08, -0.2]].map(([x, y]) => [cx + x * r, cy + y * r]);
  return fill(P([pts[0], pts[1], pts[2], pts[5]]), GOLD.light) + fill(P([pts[2], pts[3], pts[4], pts[5]]), GOLD.dark) + ink(P(pts), lw(r));
}

function speedBar(cx, cy, big) {
  const w = big ? 156 : 140;
  const h = big ? 40 : 28;
  const d = P([[cx - w / 2, cy - h / 2], [cx + w / 2 - h * 0.6, cy - h / 2], [cx + w / 2, cy], [cx + w / 2 - h * 0.6, cy + h / 2], [cx - w / 2, cy + h / 2], [cx - w / 2 + h * 0.5, cy]]);
  return shape(d, GOLD.mid, 7) + stroke(`M${fmt(cx - w * 0.2)} ${fmt(cy)} H${fmt(cx + w * 0.25)}`, '#ffffff', h * 0.18);
}

function hexNut(cx, cy, r) {
  const pts = [];
  for (let k = 0; k < 6; k++) pts.push(polar(cx, cy, r * 0.92, k * 60));
  return faceted(cx, cy, pts, SILVER, lw(r)) + circ(cx, cy, r * 0.36, '#0f5a48', lw(r) * 0.7);
}

function battery(cx, cy, big) {
  const w = big ? 150 : 132;
  const h = big ? 46 : 32;
  let s = rect(cx - w / 2, cy - h / 2, w - 12, h, 8, '#30363f', 7) + rect(cx + w / 2 - 12, cy - h * 0.22, 12, h * 0.44, 3, '#30363f', 5);
  const cells = 4;
  const cw = (w - 12 - 18 - (cells - 1) * 5) / cells;
  for (let i = 0; i < cells; i++) s += rect(cx - w / 2 + 9 + i * (cw + 5), cy - h / 2 + 7, cw, h - 14, 3, '#7bd65a', 0);
  return s;
}

function pennant(color, emblem) {
  return rect(72, 40, 13, 180, 6.5, GOLD.mid, 7) + shape('M85 52 L196 80 L85 112 Z', color, 8) + emblem;
}

// --- New packs ------------------------------------------------------------------------------------

const UNK = ['#8b84a8', '#3a3552'];
const packsFromGlyphs = {
  fantasy: {
    name: 'Dragons & Wizards', rarity: 'epic',
    tiers: { general: ['#9b5cf0', '#3a1670'], field: ['#3ec98a', '#0f5236'], company: ['#4a8cf0', '#152f74'], enlisted: ['#e0607a', '#6a1424'], spy: ['#4b4566', '#16131f'], flag: ['#fff1d0', '#e3b866'], unknown: UNK },
    medal: (t) => starryMedal(t[0], t[1]), area: { s: 0.96, dx: 0, dy: 0 },
    general: gem, field: mark('lorc/round-bottom-flask', PAINT.gold), company: mark('lorc/pointy-hat', PAINT.gold, 2.2),
    enlisted: barSet(GOLD, '#b07cf0'),
    spy: () => glyph('delapouite/wizard-face', 128, 132, 168, PAINT.ghost),
    flag: () => glyph('delapouite/spiked-dragon-head', 128, 128, 176, PAINT.emerald),
    mystery: () => mysteryMark(GOLD),
  },
  mecha: {
    name: 'Robots & Mecha', rarity: 'epic',
    tiers: { general: ['#ffb03a', '#a0480e'], field: ['#5f7fa8', '#1f3350'], company: ['#38c9a0', '#0f5a48'], enlisted: ['#8f97a8', '#30363f'], spy: ['#3a3f4f', '#0d0f14'], flag: ['#e9eef5', '#a9b4c4'], unknown: UNK },
    medal: (t) => gearMedal(t[0], t[1]), area: { s: 0.92, dx: 0, dy: 0 },
    general: mark('lorc/cog', PAINT.silver, 2.05), field: mark('lorc/microchip', PAINT.gold, 2.15), company: hexNut,
    enlisted: battery,
    spy: () => glyph('lorc/radar-dish', 128, 128, 164, PAINT.silver),
    flag: () => glyph('delapouite/robot-antennas', 128, 130, 168, PAINT.orange),
    mystery: () => mysteryMark(SILVER),
  },
  wildwest: {
    name: 'Wild West', rarity: 'rare',
    tiers: { general: ['#d9a24a', '#7a4a14'], field: ['#c2553a', '#5e1f10'], company: ['#6aa84f', '#2a4d1a'], enlisted: ['#8a6a4a', '#3b2a1a'], spy: ['#4a4038', '#15110d'], flag: ['#fff2d8', '#e2c38f'], unknown: UNK },
    medal: (t) => stitchedMedal(t[0], t[1], '#f3dfb4'), area: { s: 0.96, dx: 0, dy: 0 },
    general: sheriffStar, field: mark('delapouite/horseshoe', PAINT.silver, 2.0), company: mark('delapouite/cactus', PAINT.green, 2.15),
    enlisted: (cx, cy, big) => (big ? ropeChevron(cx, cy - 8, 128, 52, 26) : ropeChevron(cx, cy, 114, 32, 18)),
    spy: () => glyph('delapouite/western-hat', 128, 124, 176, PAINT.wood),
    flag: () => pennant('#2f5fb0', sheriffStar(132, 82, 20)),
    mystery: () => mysteryMark(GOLD),
  },
  egypt: {
    name: 'Ancient Egypt', rarity: 'epic',
    tiers: { general: ['#2f6fd0', '#102a66'], field: ['#2ea38f', '#0e4a40'], company: ['#d2603a', '#6a2410'], enlisted: ['#c9b48a', '#6e5a34'], spy: ['#3f3a52', '#121019'], flag: ['#fff4d8', '#e6c88a'], unknown: UNK },
    medal: (t) => circleMedal(t[0], t[1], '#ffc93c'), area: { s: 0.96, dx: 0, dy: 0 },
    general: ankh, field: mark('lorc/scarab-beetle', PAINT.gold, 2.1), company: pyramid,
    enlisted: barSet(GOLD, '#2f6fd0'),
    spy: () => glyph('delapouite/anubis', 128, 126, 172, PAINT.gold),
    flag: () => glyph('delapouite/egyptian-sphinx', 128, 130, 178, PAINT.gold),
    mystery: () => mysteryMark(GOLD),
  },
  vikings: {
    name: 'Vikings', rarity: 'rare',
    tiers: { general: ['#8a6a46', '#3a2614'], field: ['#b8323a', '#5a1218'], company: ['#2f6a9a', '#12304c'], enlisted: ['#5a7a4a', '#24361c'], spy: ['#a9b4c8', '#4a5466'], flag: ['#e8e2d4', '#b8ac94'], unknown: UNK },
    medal: (t) => woodShieldMedal(t[0], t[1]), area: { s: 0.92, dx: 0, dy: 0 },
    general: mark('delapouite/viking-helmet', PAINT.silver, 1.62), field: mark('delapouite/thor-hammer', PAINT.silver, 2.05),
    company: mark('delapouite/viking-shield', PAINT.gold, 1.95),
    enlisted: (cx, cy, big) => (big ? chevron(cx, cy - 8, 132, 52, 26, GOLD) : chevron(cx, cy, 116, 34, 18, GOLD)),
    spy: () => glyph('lorc/raven', 128, 128, 168, PAINT.dark),
    flag: () => glyph('delapouite/drakkar', 128, 130, 180, PAINT.wood),
    mystery: () => mysteryMark(GOLD),
  },
  halloween: {
    name: 'Halloween Monsters', rarity: 'rare',
    tiers: { general: ['#5a3f86', '#1a1028'], field: ['#ffe48a', '#c8901a'], company: ['#3fae6a', '#123e22'], enlisted: ['#5a5a6a', '#1e1e26'], spy: ['#2a2236', '#0b0910'], flag: ['#d7dbe8', '#8a90a6'], unknown: UNK },
    medal: (t) => stitchedMedal(t[0], t[1], '#1d1736'), area: { s: 0.96, dx: 0, dy: 0 },
    general: mark('lorc/pumpkin-lantern', PAINT.orange, 1.92), field: mark('delapouite/bat', PAINT.dark, 2.2), company: mark('lorc/ghost', PAINT.ghost, 2.1),
    enlisted: boneSet('#f1e8d2'),
    spy: () => glyph('lorc/hanging-spider', 128, 128, 176, PAINT.purple),
    flag: () => glyph('lorc/tombstone', 128, 132, 172, PAINT.silver),
    mystery: () => mysteryMark(PAINT.orange),
  },
  dinos: {
    name: 'Dino Park', rarity: 'rare',
    tiers: { general: ['#f2b84b', '#8a4a12'], field: ['#7ab85a', '#2c5218'], company: ['#d9734a', '#6a2a12'], enlisted: ['#a89a7a', '#4e4532'], spy: ['#4a5a3a', '#151c10'], flag: ['#ffb070', '#d9481a'], unknown: UNK },
    medal: (t) => stoneMedal(t[0], t[1]), area: { s: 0.94, dx: 0, dy: 0 },
    general: (cx, cy, r) => dinoPrint(cx, cy, r * 1.15), field: mark('lorc/dinosaur-egg', PAINT.bone, 1.95), company: mark('lorc/tooth', PAINT.bone, 2.05),
    enlisted: boneSet('#e8d8b0'),
    spy: () => glyph('delapouite/velociraptor', 128, 130, 182, PAINT.green),
    flag: () => pennant('#3fae6a', '') + glyph('lorc/dinosaur-egg', 116, 82, 44, PAINT.bone) + shape('M60 214 Q90 186 128 198 Q166 186 196 214 Z', '#7ab85a', 7),
    mystery: () => mysteryMark(GOLD),
  },
  zodiac: {
    name: 'Mystic Zodiac', rarity: 'epic',
    tiers: { general: ['#3a3a8a', '#0f0f3a'], field: ['#8a3ac8', '#2e0f52'], company: ['#2a8ab0', '#0c3248'], enlisted: ['#c84a8a', '#4e1232'], spy: ['#3a3550', '#0d0b16'], flag: ['#2a2c62', '#06071c'], unknown: UNK },
    medal: (t) => starryMedal(t[0], t[1]), area: { s: 0.96, dx: 0, dy: 0 },
    general: mark('lorc/moon', PAINT.gold, 1.95), field: mark('lorc/comet-spark', PAINT.gold, 2.1), company: mark('lorc/hourglass', PAINT.gold, 2.1),
    enlisted: barSet(SILVER, '#c84a8a'),
    spy: () => glyph('lorc/crystal-ball', 128, 126, 168, PAINT.ice),
    flag: () => glyph('lorc/star-swirl', 128, 128, 178, PAINT.gold),
    mystery: () => mysteryMark(GOLD),
  },
  music: {
    name: 'Rock Stars', rarity: 'rare',
    tiers: { general: ['#ff4f8b', '#9a1a46'], field: ['#ffcf3f', '#b07a08'], company: ['#3d8bff', '#14347a'], enlisted: ['#27c98f', '#0c5a3e'], spy: ['#8b5cf6', '#2e1670'], flag: ['#f4f4f4', '#b8b8c8'], unknown: UNK },
    medal: (t) => vinylMedal(t[0], t[1]), area: { s: 0.84, dx: 0, dy: 0 },
    general: note, field: mark('lorc/guitar', PAINT.red, 2.2), company: mark('delapouite/drum', PAINT.gold, 2.0),
    enlisted: equalizer,
    spy: () => glyph('delapouite/headphones', 128, 128, 150, PAINT.silver),
    flag: () => glyph('delapouite/microphone', 128, 128, 150, PAINT.silver),
    mystery: () => mysteryMark(GOLD),
  },
  sports: {
    name: 'Sports Day', rarity: 'common',
    tiers: { general: ['#2f8a4a', '#0f3a1c'], field: ['#2f5fb0', '#102a5c'], company: ['#e86a2a', '#7a2a08'], enlisted: ['#c8323a', '#5a1014'], spy: ['#3a3f4f', '#0f1118'], flag: ['#f4f6fa', '#b8c0d0'], unknown: UNK },
    medal: (t) => circleMedal(t[0], t[1], '#ffffff'), area: { s: 0.96, dx: 0, dy: 0 },
    general: mark('delapouite/trophy-cup', PAINT.gold, 2.05), field: mark('delapouite/sport-medal', PAINT.gold, 2.1),
    company: mark('delapouite/soccer-ball', PAINT.ghost, 1.95),
    enlisted: barSet(PAINT.ghost, '#c8323a'),
    spy: () => glyph('delapouite/whistle', 128, 128, 160, PAINT.silver),
    flag: () => glyph('delapouite/checkered-flag', 128, 128, 168, PAINT.ghost),
    mystery: () => mysteryMark(GOLD),
  },
  heroes: {
    name: 'Super Squad', rarity: 'epic',
    tiers: { general: ['#2f5fe0', '#0f2470'], field: ['#e8323a', '#6a0a10'], company: ['#ffcf3f', '#c07a08'], enlisted: ['#27c98f', '#0c5a3e'], spy: ['#3a3550', '#0d0b16'], flag: ['#ffffff', '#c8d0e0'], unknown: UNK },
    medal: (t) => burstMedal(t[0], t[1]), area: { s: 0.9, dx: 0, dy: 0 },
    general: bolt, field: mark('lorc/fist', PAINT.gold, 2.05), company: mark('lorc/rocket', PAINT.red, 2.15),
    enlisted: speedBar,
    spy: () => glyph('lorc/domino-mask', 128, 128, 176, PAINT.red),
    flag: () => glyph('delapouite/cape', 128, 132, 176, PAINT.red),
    mystery: () => mysteryMark(GOLD),
  },
};

// --- Writer -------------------------------------------------------------------------------------

const PACKS = { samurai, space, knights, neon, candy, pirates, ocean, safari, ...packsFromGlyphs };

function draw(pack, rank) {
  gradId = 0;  // Gradient ids only need to be unique within one file.
  const tier = TIER[rank];
  const medal = pack.medal(pack.tiers[tier]);
  const a = pack.area;
  let marks = '';
  switch (tier) {
    case 'general': marks = placed(GEN, COUNT[rank], a, pack.general); break;
    case 'field': marks = placed(OFF, COUNT[rank], a, pack.field); break;
    case 'company': marks = placed(OFF, COUNT[rank], a, pack.company); break;
    case 'enlisted':
      marks = COUNT[rank] === 3
        ? [84, 128, 172].map((y) => pack.enlisted(128 + a.dx, 128 + (y - 128) * a.s + a.dy, false)).join('')
        : pack.enlisted(128 + a.dx, 120 + a.dy, true);
      break;
    case 'spy': marks = pack.spy(); break;
    case 'flag': marks = pack.flag(); break;
    default: marks = pack.mystery();
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 256 256">${medal}${marks}</svg>\n`;
}

for (const [slug, pack] of Object.entries(PACKS)) {
  const dir = path.join(OUT, slug);
  fs.mkdirSync(dir, { recursive: true });
  for (const rank of RANKS) fs.writeFileSync(path.join(dir, `${rank}.svg`), draw(pack, rank));
}
console.log(`Wrote ${Object.keys(PACKS).length} packs × ${RANKS.length} icons to ${OUT}`);
