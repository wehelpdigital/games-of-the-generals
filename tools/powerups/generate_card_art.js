// Draws the powerup card illustrations: one original toon scene per powerup (ink outlines, the
// game's palette, a backdrop per card type), rendered by headless Edge/Chrome into
// assets/powerups/art/<id>.webp. Card frames are drawn by the game (ui/widgets/PowerupCard.gd);
// these are only the art windows.
//
//   NODE_PATH=<dir with puppeteer-core> node tools/powerups/generate_card_art.js [--only id,id] [--sheet out.png]
//
// Set BROWSER to a Chrome binary if Edge isn't at its default path.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'assets', 'powerups', 'art');
const BROWSER = process.env.BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const W = 480;
const H = 360;
const PX = 2; // render scale: 960x720 source, then downscaled to OUT_W
const OUT_W = 448;
const OUT_H = 336;

const INK = '#1d1736';
const PAPER = '#fff8ec';
const C = {
  pink: '#ff4f8b', blue: '#3d8bff', yellow: '#ffcf3f', mint: '#27c98f', purple: '#8b5cf6', red: '#ff5a5f',
  gold: '#ffb703', orange: '#ff8a3d', sky: '#7cc4ff', ice: '#bfeaff', sand: '#e7c27a', wood: '#9a6a43',
  grey: '#b9c2d6', dark: '#3a3358', white: '#ffffff', green: '#4caf50', brown: '#7a5233', steel: '#8e9bb5',
};
const SW = 7; // ink stroke width

// Card type backdrops: [top, bottom, accent].
const KIND = {
  clock: ['#7ff0cc', '#15a77a', '#d6fff1'],
  intel: ['#3156a8', '#101a45', '#7fb6ff'],
  tactics: ['#b99bff', '#5a2fc2', '#e7dcff'],
  trap: ['#ff8fae', '#c41d4c', '#ffe1ea'],
  support: ['#ffe27a', '#e58b12', '#fff4cf'],
};

// --- SVG primitives -----------------------------------------------------------------------------

// Ink outline attributes; `extra` may override the stroke colour or width.
const has = (extra, attr) => new RegExp('(^|\\s)' + attr + '=').test(extra);
const ink = (extra = '') => `${has(extra, 'stroke') ? '' : `stroke="${INK}" `}${has(extra, 'stroke-width') ? '' : `stroke-width="${SW}" `}stroke-linejoin="round" stroke-linecap="round"${extra}`;
const g = (t, ...kids) => `<g transform="${t}">${kids.join('')}</g>`;
const P = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" ${ink(extra)}/>`;
const line = (d, w = SW, color = INK) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const circle = (cx, cy, r, fill, extra = '') => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" ${ink(extra)}/>`;
const ellipse = (cx, cy, rx, ry, fill, extra = '') => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" ${ink(extra)}/>`;
const rect = (x, y, w, h, r, fill, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" ${ink(extra)}/>`;
const poly = (pts, fill, extra = '') => `<polygon points="${pts.map((p) => p.join(',')).join(' ')}" fill="${fill}" ${ink(extra)}/>`;
const shadow = (cx, cy, rx, ry, a = 0.25) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${INK}" opacity="${a}"/>`;
const shine = (d, a = 0.45) => `<path d="${d}" fill="#ffffff" opacity="${a}"/>`;
const text = (x, y, s, fill, size, extra = '') => `<text x="${x}" y="${y}" font-family="Lilita One" font-size="${size}" text-anchor="middle" fill="${fill}" stroke="${INK}" ${has(extra, 'stroke-width') ? '' : `stroke-width="${Math.max(4, size / 7)}" `}paint-order="stroke" stroke-linejoin="round"${extra}>${s}</text>`;

function starPts(cx, cy, r1, r2, n = 5, rot = -90) {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 === 0 ? r1 : r2;
    const a = ((rot + (i * 180) / n) * Math.PI) / 180;
    pts.push([+(cx + Math.cos(a) * r).toFixed(1), +(cy + Math.sin(a) * r).toFixed(1)]);
  }
  return pts;
}
const star = (cx, cy, r, fill = C.yellow, extra = '') => poly(starPts(cx, cy, r, r * 0.45), fill, extra);
const sparkle = (cx, cy, s, fill = C.white) => P(`M${cx} ${cy - s} Q${cx + s * 0.18} ${cy - s * 0.18} ${cx + s} ${cy} Q${cx + s * 0.18} ${cy + s * 0.18} ${cx} ${cy + s} Q${cx - s * 0.18} ${cy + s * 0.18} ${cx - s} ${cy} Q${cx - s * 0.18} ${cy - s * 0.18} ${cx} ${cy - s}Z`, fill, ` stroke-width="4"`);
const sparkles = (list) => list.map(([x, y, s, f]) => sparkle(x, y, s, f)).join('');
function rays(cx, cy, r1, r2, n, color, a = 0.35, width = 10) {
  let out = '';
  for (let i = 0; i < n; i++) {
    const ang = (i * 2 * Math.PI) / n;
    out += `<path d="M${cx + Math.cos(ang) * r1} ${cy + Math.sin(ang) * r1} L${cx + Math.cos(ang) * r2} ${cy + Math.sin(ang) * r2}" stroke="${color}" stroke-width="${width}" stroke-linecap="round" opacity="${a}"/>`;
  }
  return out;
}
const speedLines = (x, y, n, len, gap, color = C.white, a = 0.8) => Array.from({ length: n }, (_, i) =>
  `<path d="M${x} ${y + i * gap} h${-len + (i % 2) * 18}" stroke="${color}" stroke-width="7" stroke-linecap="round" opacity="${a}"/>`).join('');

// --- Backdrops ------------------------------------------------------------------------------------

function backdrop(kind) {
  const [top, bottom, accent] = KIND[kind];
  let deco = '';
  if (kind === 'clock') {
    deco = `<g opacity="0.22">${circle(380, 70, 120, 'none', ' stroke="#ffffff" stroke-width="10"')}`
      + Array.from({ length: 12 }, (_, i) => { const a = (i * Math.PI) / 6; return `<path d="M${380 + Math.cos(a) * 95} ${70 + Math.sin(a) * 95} L${380 + Math.cos(a) * 110} ${70 + Math.sin(a) * 110}" stroke="#fff" stroke-width="9" stroke-linecap="round"/>`; }).join('')
      + '</g>';
  } else if (kind === 'intel') {
    let grid = '';
    for (let x = 0; x <= W; x += 40) grid += `<path d="M${x} 0V${H}" stroke="${accent}" stroke-width="2" opacity="0.18"/>`;
    for (let y = 0; y <= H; y += 40) grid += `<path d="M0 ${y}H${W}" stroke="${accent}" stroke-width="2" opacity="0.18"/>`;
    deco = grid + [[50, 40], [420, 60], [300, 30], [120, 90], [450, 150]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3" fill="#fff" opacity="0.7"/>`).join('');
  } else if (kind === 'tactics') {
    deco = Array.from({ length: 9 }, (_, i) => `<path d="M${-60 + i * 70} ${H} L${80 + i * 70} 0" stroke="${accent}" stroke-width="26" opacity="0.13"/>`).join('');
  } else if (kind === 'trap') {
    let stripes = '';
    for (let x = -40; x < W + 40; x += 44) stripes += `<path d="M${x} ${H} l26 -34 h22 l-26 34z" fill="${INK}" opacity="0.85"/>`;
    deco = `<rect x="0" y="${H - 34}" width="${W}" height="34" fill="${C.yellow}"/>${stripes}<path d="M0 ${H - 34}H${W}" stroke="${INK}" stroke-width="5"/>`;
  } else if (kind === 'support') {
    deco = rays(W / 2, H * 0.55, 30, 420, 18, '#ffffff', 0.22, 26);
  }
  return `<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>`
    + `<radialGradient id="glow" cx="0.5" cy="0.55" r="0.55"><stop offset="0" stop-color="#ffffff" stop-opacity="0.35"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient></defs>`
    + `<rect width="${W}" height="${H}" fill="url(#bg)"/><rect width="${W}" height="${H}" fill="url(#glow)"/>${deco}`;
}

// --- Motifs -----------------------------------------------------------------------------------------

// A game piece: standing plaque on a slab with a round badge. face: star | q | chevron | spy | flag | sun | none.
function chip(x, y, s = 1, o = {}) {
  const enemy = !!o.enemy;
  const body = o.body || (enemy ? '#4a4170' : PAPER);
  const base = o.base || (enemy ? C.pink : C.blue);
  const badge = o.badge || (enemy ? '#6d5fb0' : C.blue);
  const face = o.face || 'star';
  let icon = '';
  if (face === 'star') icon = star(0, -64, 15, C.yellow, ' stroke-width="4"');
  else if (face === 'q') icon = text(0, -51, '?', C.white, 38);
  else if (face === 'chevron') icon = line('M-14 -56 L0 -70 L14 -56', 8, C.yellow) + line('M-14 -46 L0 -60 L14 -46', 8, C.yellow);
  else if (face === 'sun') icon = circle(0, -64, 10, C.yellow, ' stroke-width="4"') + rays(0, -64, 13, 20, 8, C.yellow, 1, 4);
  else if (face === 'spy') icon = P('M-20 -58 Q0 -86 20 -58 Z', INK, ' stroke-width="3"') + rect(-24, -61, 48, 7, 3, INK, ' stroke-width="2"') + rect(-14, -50, 28, 9, 4, C.white, ' stroke-width="3"');
  else if (face === 'flag') icon = line('M-8 -80 V-46', 5) + P('M-8 -80 L16 -72 L-8 -63 Z', C.red, ' stroke-width="4"');
  else if (face === 'up') icon = P('M0 -84 L16 -64 H6 V-46 H-6 V-64 H-16 Z', C.yellow, ' stroke-width="4"');
  return g(`translate(${x} ${y}) rotate(${o.rot || 0}) scale(${s})`,
    o.noShadow ? '' : shadow(0, 10, 54, 13),
    rect(-48, -16, 96, 26, 12, base),
    rect(-41, -114, 82, 102, 20, body),
    shine('M-33 -104 h50 q10 0 10 10 v6 q-30 -8 -60 4 z', enemy ? 0.15 : 0.6),
    circle(0, -64, 28, badge, ' stroke-width="5"'),
    icon);
}

function hourglass(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 92, 70, 14),
    rect(-66, -96, 132, 22, 9, C.wood), rect(-66, 70, 132, 22, 9, C.wood),
    P('M-48 -74 C-48 -10 -8 -10 -8 0 C-8 10 -48 10 -48 70 H48 C48 10 8 10 8 0 C8 -10 48 -10 48 -74 Z', '#e9f8ff'),
    P('M-34 -56 C-30 -26 -6 -16 0 -6 C6 -16 30 -26 34 -56 Z', C.sand, ' stroke-width="4"'),
    P('M-36 66 C-30 40 -10 32 0 26 C10 32 30 40 36 66 Z', C.sand, ' stroke-width="4"'),
    `<path d="M0 -4 V30" stroke="${C.sand}" stroke-width="5" stroke-dasharray="4 6"/>`,
    shine('M-40 -66 C-40 -40 -30 -26 -22 -20 C-30 -30 -32 -48 -30 -66Z', 0.7));
}

function clockFace(x, y, r, o = {}) {
  const hands = o.hands !== false;
  let ticks = '';
  for (let i = 0; i < 12; i++) {
    const a = (i * Math.PI) / 6;
    ticks += `<path d="M${Math.cos(a) * r * 0.72} ${Math.sin(a) * r * 0.72} L${Math.cos(a) * r * 0.84} ${Math.sin(a) * r * 0.84}" stroke="${INK}" stroke-width="5" stroke-linecap="round"/>`;
  }
  return g(`translate(${x} ${y})`,
    o.noShadow ? '' : shadow(0, r + 14, r * 0.9, 14),
    circle(0, 0, r, o.rim || C.red), circle(0, 0, r * 0.82, PAPER, ' stroke-width="5"'), ticks,
    hands ? line(`M0 0 L0 ${-r * 0.55}`, 8) + line(`M0 0 L${r * 0.4} ${r * 0.12}`, 8) : '',
    circle(0, 0, 7, INK, ' stroke-width="2"'),
    shine(`M${-r * 0.6} ${-r * 0.5} q${r * 0.3} ${-r * 0.35} ${r * 0.75} ${-r * 0.32} q${-r * 0.5} ${r * 0.05} ${-r * 0.6} ${r * 0.3}z`, 0.5));
}

function stopwatch(x, y, r, rim = C.gold) {
  return g(`translate(${x} ${y})`,
    rect(-12, -r - 26, 24, 18, 6, rim), rect(-20, -r - 36, 40, 14, 6, C.steel),
    clockFace(0, 0, r, { rim }));
}

function bolt(x, y, s = 1, fill = C.yellow) {
  return g(`translate(${x} ${y}) scale(${s})`, P('M12 -70 L-30 6 H-2 L-14 70 L34 -14 H6 L22 -70 Z', fill), shine('M10 -60 L-18 -4 H-8 Z', 0.6));
}

function magnifier(x, y, s = 1, rot = -35) {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`,
    rect(-12, 52, 24, 76, 10, C.wood), rect(-15, 42, 30, 18, 6, C.steel),
    circle(0, 0, 48, '#cfeeff'), circle(0, 0, 48, 'none', ' stroke-width="12" stroke="' + C.steel + '"'), circle(0, 0, 48, 'none'),
    shine('M-30 -20 q8 -22 30 -26 q-18 12 -22 30z', 0.8));
}

function cloud(x, y, s = 1, fill = '#f2f0ff', a = 1) {
  return g(`translate(${x} ${y}) scale(${s})`, `<g opacity="${a}">${P('M-70 20 C-96 20 -96 -18 -66 -18 C-62 -48 -20 -54 -6 -30 C6 -56 54 -50 54 -18 C84 -22 90 20 62 22 Z', fill)}${shine('M-60 -10 C-56 -30 -30 -38 -16 -26 C-34 -26 -46 -20 -54 -6Z', 0.7)}</g>`);
}

function card(x, y, s = 1, rot = 0, o = {}) {
  const fill = o.fill || PAPER;
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`,
    shadow(4, 92, 46, 9, 0.2),
    rect(-50, -70, 100, 140, 14, fill),
    rect(-38, -56, 76, 60, 8, o.art || C.sky, ' stroke-width="4"'),
    o.icon || star(0, -26, 18, C.yellow, ' stroke-width="4"'),
    line('M-30 22 H30', 6, '#c9c4d9'), line('M-30 38 H18', 6, '#c9c4d9'));
}

function boot(x, y, s = 1, color = C.red) {
  return g(`translate(${x} ${y}) scale(${s})`,
    P('M-22 -60 H22 V10 C44 12 64 22 66 40 H-30 C-34 20 -26 0 -22 -10 Z', color),
    rect(-34, 36, 104, 18, 8, INK, ' stroke-width="3"'),
    line('M-22 -36 H22', 5), line('M-22 -20 H20', 5),
    shine('M-14 -54 h10 v40 h-10z', 0.5));
}

function shield(x, y, s = 1, fill = C.blue) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 104, 70, 14),
    P('M0 -96 C40 -80 66 -78 76 -76 C76 0 52 60 0 92 C-52 60 -76 0 -76 -76 C-66 -78 -40 -80 0 -96Z', fill),
    P('M0 -70 C26 -60 44 -58 52 -56 C52 0 34 44 0 66 C-34 44 -52 0 -52 -56 C-44 -58 -26 -60 0 -70Z', 'none', ' stroke="#ffffff" stroke-width="6" opacity="0.6"'),
    star(0, -2, 34, C.yellow),
    shine('M-60 -66 C-30 -72 -10 -80 0 -84 L0 -70 C-20 -62 -40 -58 -50 -56Z', 0.5));
}

function flagOnPole(x, y, s = 1, color = C.red, wave = true) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 6, 34, 8),
    rect(-6, -170, 12, 176, 6, C.wood), circle(0, -176, 12, C.gold),
    wave ? P('M6 -160 C40 -176 70 -144 110 -160 V-92 C70 -76 40 -108 6 -92 Z', color) : P('M6 -160 H110 V-92 H6 Z', color),
    shine('M14 -150 C40 -162 60 -140 90 -150 V-138 C60 -128 40 -150 14 -140Z', 0.45));
}

function bomb(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 64, 60, 12),
    circle(0, 0, 58, '#2d2a40'), rect(-18, -74, 36, 22, 6, C.steel),
    line('M0 -74 C10 -100 34 -100 44 -116', 7, C.wood),
    sparkle(48, -122, 18, C.yellow), sparkle(48, -122, 9, C.orange),
    shine('M-36 -26 C-30 -44 -12 -52 6 -50 C-12 -40 -24 -30 -30 -12Z', 0.35));
}

function dice(x, y, s = 1, rot = 0, pips = 5) {
  const spots = { 1: [[0, 0]], 2: [[-18, -18], [18, 18]], 3: [[-18, -18], [0, 0], [18, 18]], 4: [[-18, -18], [18, -18], [-18, 18], [18, 18]], 5: [[-18, -18], [18, -18], [0, 0], [-18, 18], [18, 18]], 6: [[-18, -20], [18, -20], [-18, 0], [18, 0], [-18, 20], [18, 20]] }[pips];
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`,
    rect(-40, -40, 80, 80, 16, PAPER), ...spots.map(([px, py]) => `<circle cx="${px}" cy="${py}" r="8" fill="${INK}"/>`),
    shine('M-30 -34 h40 q-30 6 -36 30 z', 0.6));
}

function megaphone(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    P('M-70 -18 L20 -64 V64 L-70 18 Z', C.red), rect(-90, -22, 26, 44, 8, C.yellow),
    rect(-58, 18, 18, 46, 6, C.steel), ellipse(22, 0, 18, 66, '#ffdbe4'),
    shine('M-60 -12 L10 -50 V-40 L-54 -4Z', 0.5));
}

function lamp(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    `<path d="M-120 210 L-60 30 H60 L120 210 Z" fill="#fff6b3" opacity="0.55"/>`,
    line('M0 -60 V0', 6), P('M-60 34 C-60 -6 -30 -16 0 -16 C30 -16 60 -6 60 34 Z', C.dark), ellipse(0, 34, 22, 9, '#fff6b3', ' stroke-width="4"'));
}

function sandbag(x, y, s = 1, rot = 0) {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`, P('M-44 -18 C-50 -26 50 -26 44 -18 C54 -2 54 4 44 18 C30 26 -30 26 -44 18 C-54 6 -54 -6 -44 -18Z', '#d6b07a'), line('M-30 -6 C-10 2 10 2 30 -6', 4, '#a0794a'));
}

function wings(x, y, s = 1) {
  const wing = (dir) => P(`M0 0 C${dir * 40} -60 ${dir * 110} -70 ${dir * 140} -40 C${dir * 110} -34 ${dir * 116} -18 ${dir * 96} -8 C${dir * 110} 4 ${dir * 100} 22 ${dir * 74} 18 C${dir * 80} 32 ${dir * 50} 40 0 20 Z`, PAPER);
  return g(`translate(${x} ${y}) scale(${s})`, wing(1), wing(-1));
}

function parachute(x, y, s = 1, color = C.mint) {
  return g(`translate(${x} ${y}) scale(${s})`,
    P('M-110 0 C-110 -80 110 -80 110 0 C90 -14 74 -14 55 0 C36 -14 18 -14 0 0 C-18 -14 -36 -14 -55 0 C-74 -14 -90 -14 -110 0Z', color),
    line('M-55 0 C-30 -40 30 -40 55 0', 5, '#ffffff'), line('M-108 2 L-30 92', 4), line('M108 2 L30 92', 4), line('M0 0 V92', 4), line('M-55 2 L-14 92', 4), line('M55 2 L14 92', 4));
}

function flame(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    P('M0 -90 C30 -50 54 -30 46 10 C40 40 -40 40 -46 10 C-52 -24 -18 -40 -10 -70 C0 -50 10 -48 0 -90Z', C.orange),
    P('M0 -50 C18 -26 28 -10 22 10 C16 26 -16 26 -22 10 C-26 -6 -10 -20 0 -50Z', C.yellow, ' stroke-width="5"'));
}

function snowflake(x, y, s = 1) {
  let d = '';
  for (let i = 0; i < 6; i++) {
    const a = (i * Math.PI) / 3;
    const ex = Math.cos(a) * 22; const ey = Math.sin(a) * 22;
    d += `M0 0 L${ex.toFixed(1)} ${ey.toFixed(1)} `;
  }
  return g(`translate(${x} ${y}) scale(${s})`, line(d, 9, INK), line(d, 4, '#ffffff'));
}

function arrow(d, color = C.yellow, head = true) {
  return line(d, 16, INK) + line(d, 8, color);
}

function padlock(x, y, s = 1, open = true) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 76, 64, 12),
    open ? line('M-34 -10 V-50 C-34 -94 34 -94 34 -50 V-40', 16, C.steel) : line('M-34 -10 V-50 C-34 -94 34 -94 34 -50 V-10', 16, C.steel),
    open ? line('M-34 -10 V-50 C-34 -94 34 -94 34 -50 V-40', 6, '#c9d2e6') : '',
    rect(-56, -14, 112, 86, 14, C.gold),
    rect(-38, 8, 76, 30, 8, INK, ' stroke-width="3"'),
    text(0, 32, '7·3·1', C.mint, 24, ' stroke-width="0"'),
    shine('M-46 -6 h30 q-20 10 -24 40 h-6z', 0.45));
}

function radarScreen(x, y, r) {
  return g(`translate(${x} ${y})`,
    shadow(0, r + 10, r * 0.9, 12),
    circle(0, 0, r, '#0e3b2c'),
    circle(0, 0, r * 0.66, 'none', ' stroke="#42e3a1" stroke-width="3" opacity="0.6"'),
    circle(0, 0, r * 0.33, 'none', ' stroke="#42e3a1" stroke-width="3" opacity="0.6"'),
    `<path d="M0 0 L${r * 0.98} ${-r * 0.2} A${r} ${r} 0 0 0 ${r * 0.55} ${-r * 0.83} Z" fill="#42e3a1" opacity="0.45"/>`,
    line(`M0 0 L${r * 0.98} ${-r * 0.2}`, 5, '#7dffcb'),
    `<circle cx="${r * 0.45}" cy="${-r * 0.4}" r="9" fill="${C.red}"/>`, `<circle cx="${-r * 0.35}" cy="${r * 0.3}" r="7" fill="#7dffcb"/>`,
    circle(0, 0, r, 'none'));
}

function sonarArcs(x, y, n = 4, color = '#9fe6ff') {
  let out = '';
  for (let i = 1; i <= n; i++) out += `<path d="M${x - i * 34} ${y - i * 8} A${i * 36} ${i * 22} 0 0 1 ${x + i * 34} ${y - i * 8}" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round" opacity="${1 - i * 0.18}"/>`;
  return out;
}

function drone(x, y, s = 1) {
  const rotor = (rx) => ellipse(rx, -24, 30, 7, '#cfe4ff', ' stroke-width="4"') + line(`M${rx} -24 V-8`, 5);
  return g(`translate(${x} ${y}) scale(${s})`,
    `<path d="M-30 30 L-110 220 H110 L30 30Z" fill="#fff6b3" opacity="0.4"/>`,
    line('M-60 -8 H60', 9), rotor(-62), rotor(62), rect(-34, -12, 68, 40, 14, C.steel), circle(0, 12, 12, C.red, ' stroke-width="4"'));
}

function binoculars(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    rect(-60, -30, 50, 80, 18, C.dark), rect(10, -30, 50, 80, 18, C.dark), rect(-14, -16, 28, 30, 8, C.steel),
    circle(-35, 50, 22, '#9fd8ff'), circle(35, 50, 22, '#9fd8ff'), shine('M-48 40 q6 -10 16 -12 q-8 8 -10 18z', 0.8), shine('M22 40 q6 -10 16 -12 q-8 8 -10 18z', 0.8));
}

function crystalBall(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 92, 70, 12),
    P('M-60 92 L-40 50 H40 L60 92 Z', C.wood),
    circle(0, 0, 70, '#c9b6ff'),
    `<circle cx="0" cy="0" r="54" fill="#ffffff" opacity="0.25"/>`,
    chip(0, 34, 0.42, { face: 'chevron', noShadow: true }),
    shine('M-48 -24 C-42 -50 -14 -62 8 -60 C-18 -50 -36 -36 -42 -12Z', 0.75));
}

function folder(x, y, s = 1, rot = 0, stamp = 'TOP SECRET') {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`,
    P('M-90 -60 H-30 L-18 -46 H90 V70 H-90 Z', '#f2c66d'),
    P('M-90 -30 H90 V70 H-90 Z', '#ffd98a'),
    text(0, 30, stamp, C.red, 24, ' stroke-width="0" transform="rotate(-8)"'),
    `<rect x="-62" y="6" width="124" height="34" rx="6" fill="none" stroke="${C.red}" stroke-width="5" transform="rotate(-8)"/>`);
}

function paper(x, y, s = 1, rot = 0) {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`, rect(-28, -36, 56, 72, 6, PAPER, ' stroke-width="5"'), line('M-16 -18 H16', 5, '#c9c4d9'), line('M-16 -4 H16', 5, '#c9c4d9'), line('M-16 10 H8', 5, '#c9c4d9'));
}

function bell(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    P('M-62 40 C-60 -10 -46 -64 0 -64 C46 -64 60 -10 62 40 C72 46 72 58 62 60 H-62 C-72 58 -72 46 -62 40Z', C.gold),
    circle(0, 72, 14, C.gold), rect(-10, -82, 20, 20, 6, C.steel),
    shine('M-40 -30 C-34 -50 -20 -58 -6 -58 C-24 -46 -30 -30 -32 -10Z', 0.55),
    `<path d="M-96 -40 q-16 26 0 52" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round"/><path d="M96 -40 q16 26 0 52" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round"/>`);
}

function portal(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    ellipse(0, 0, 110, 40, '#2a1660'), ellipse(0, 0, 84, 30, C.purple, ' stroke-width="5"'), ellipse(0, 0, 56, 20, '#d4b8ff', ' stroke-width="5"'),
    sparkles([[-120, -60, 14, C.yellow], [120, -40, 12, C.white], [90, -90, 9, C.pink]]));
}

function barricade(x, y, s = 1) {
  const stripes = (bx, by) => {
    let out = '';
    for (let i = 0; i < 5; i++) out += `<path d="M${bx - 78 + i * 38} ${by - 16} l18 0 l-14 32 l-18 0z" fill="${C.red}"/>`;
    return out;
  };
  return g(`translate(${x} ${y}) scale(${s})`,
    shadow(0, 76, 120, 14),
    rect(-90, -40, 16, 116, 6, C.wood), rect(74, -40, 16, 116, 6, C.wood),
    rect(-110, -40, 220, 34, 8, PAPER), stripes(10, -23), rect(-110, -40, 220, 34, 8, 'none'),
    rect(-110, 10, 220, 34, 8, PAPER), stripes(10, 27), rect(-110, 10, 220, 34, 8, 'none'));
}

function cone(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`, rect(-36, 40, 72, 14, 5, C.orange), P('M-26 40 L-8 -50 H8 L26 40 Z', C.orange), P('M-19 6 L-13 -18 H13 L19 6Z', PAPER, ' stroke-width="4"'));
}

function swirl(x, y, s = 1, color = C.sand, dark = '#b98a3f') {
  return g(`translate(${x} ${y}) scale(${s})`,
    ellipse(0, 0, 130, 46, color),
    `<path d="M-90 0 C-80 -26 60 -30 80 -4 C90 12 40 24 0 20 C-30 18 -50 4 -30 -6 C-10 -14 30 -12 34 0" fill="none" stroke="${dark}" stroke-width="7" stroke-linecap="round"/>`);
}

function mine(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    ellipse(0, 18, 100, 26, '#6b8f3c'),
    P('M-64 10 C-64 -24 64 -24 64 10 Z', '#3a3a4a'), rect(-70, 4, 140, 16, 6, '#2d2a40'),
    circle(0, -22, 12, C.red, ' stroke-width="4"'),
    `<circle cx="0" cy="-22" r="26" fill="${C.red}" opacity="0.3"/>`,
    line('M-80 0 l-12 -18 M-60 -2 l-4 -22 M70 -2 l10 -20 M86 4 l18 -10', 5, '#4f7a2a'));
}

function ice(x, y, s = 1) {
  return g(`translate(${x} ${y}) scale(${s})`,
    poly([[-80, 40], [-90, -60], [-40, -120], [50, -128], [92, -70], [86, 40]], '#bfeaff', ' opacity="0.85"'),
    shine('M-70 -50 L-40 -110 L-20 -108 L-52 -40Z', 0.7), shine('M60 -100 L80 -70 L70 -60 L50 -94Z', 0.6));
}

function smokePuff(x, y, s = 1, fill = '#d9d4ee') {
  return g(`translate(${x} ${y}) scale(${s})`, P('M-50 20 C-74 18 -72 -16 -46 -16 C-44 -42 -6 -48 6 -26 C18 -46 52 -40 50 -14 C74 -14 74 20 50 22 Z', fill), shine('M-40 -8 C-38 -26 -16 -32 -4 -22 C-20 -22 -30 -16 -34 -4Z', 0.6));
}

function hand(x, y, s = 1, rot = 0, fill = '#ffd7b5') {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`,
    P('M-40 40 C-50 10 -46 -20 -30 -34 C-26 -50 -10 -50 -8 -36 C-6 -56 12 -56 14 -38 C18 -54 34 -50 34 -34 C40 -46 56 -40 52 -22 C50 10 44 30 30 46 Z', fill),
    rect(-46, 40, 84, 26, 8, C.blue));
}

function helmet(x, y, s = 1, fill = '#6b8f3c') {
  return g(`translate(${x} ${y}) scale(${s})`, P('M-50 10 C-50 -40 50 -40 50 10 Z', fill), rect(-60, 4, 120, 14, 7, fill), shine('M-34 -10 C-30 -26 -14 -32 0 -32 C-16 -24 -24 -16 -26 -4Z', 0.4));
}

function cup(x, y, s = 1, rot = 0, fill = C.red) {
  return g(`translate(${x} ${y}) rotate(${rot}) scale(${s})`, P('M-42 -50 H42 L56 50 H-56 Z', fill), rect(-62, 44, 124, 16, 8, fill), shine('M-30 -40 h12 l-6 80 h-12z', 0.4));
}

function confetti(list) {
  return list.map(([x, y, r, c]) => `<rect x="${x}" y="${y}" width="14" height="8" rx="2" fill="${c}" stroke="${INK}" stroke-width="2.5" transform="rotate(${r} ${x + 7} ${y + 4})"/>`).join('');
}

function badgeText(x, y, label, fill = C.mint, size = 34) {
  const w = label.length * size * 0.56 + 30;
  return g(`translate(${x} ${y}) rotate(-6)`, rect(-w / 2, -size * 0.8, w, size * 1.15, size * 0.5, fill), text(0, size * 0.18, label, C.white, size, ' stroke-width="6"'));
}

// --- Scenes -----------------------------------------------------------------------------------------

const SCENES = {
  // Clock
  time_extension: ['clock', () => hourglass(230, 175, 1.05) + badgeText(370, 90, '+20s', C.mint, 40) + sparkles([[100, 80, 16], [400, 250, 12], [90, 250, 10, C.yellow]])],
  time_squeeze: ['clock', () => clockFace(240, 182, 92, { rim: C.red }) + g('translate(240 182)', P('M-190 -60 H-120 V60 H-190 Z', C.steel), P('M120 -60 H190 V60 H120 Z', C.steel), rect(-210, -14, 30, 28, 6, C.wood), rect(180, -14, 30, 28, 6, C.wood)) + speedLines(150, 140, 3, 34, 30, '#fff', 0.9) + badgeText(372, 78, '-15s', C.red, 38)],
  quick_step: ['clock', () => boot(170, 196, 1.15, C.mint) + speedLines(100, 140, 4, 60, 26) + clockFace(350, 128, 62, { rim: C.blue }) + g('translate(350 128)', rect(-20, -26, 14, 52, 5, INK, ' stroke-width="2"'), rect(6, -26, 14, 52, 5, INK, ' stroke-width="2"'))],
  blitz: ['clock', () => clockFace(170, 190, 86, { rim: C.gold }) + clockFace(330, 190, 86, { rim: C.blue }) + bolt(250, 150, 1.35) + sparkles([[250, 40, 18, C.white], [80, 80, 10], [410, 70, 12]])],
  time_steal: ['clock', () => g('translate(140 230)', P('M-60 70 C-70 10 -40 -50 10 -60 C50 -64 70 -30 60 10 C54 40 30 60 10 70 Z', '#6b4f9c'), text(0, 30, '$', C.gold, 54)) + stopwatch(300, 196, 78, C.gold) + g('translate(300 170)', rect(-62, -18, 124, 34, 16, INK, ' stroke-width="3"'), circle(-24, -2, 9, C.white, ' stroke-width="2"'), circle(24, -2, 9, C.white, ' stroke-width="2"')) + badgeText(400, 74, '+10s', C.mint, 32) + badgeText(110, 90, '-10s', C.red, 30)],

  // Intel
  spy_card: ['intel', () => g('translate(200 200)', shadow(0, 140, 90, 14), P('M-80 140 C-80 40 -60 0 0 0 C60 0 80 40 80 140 Z', '#4a3c6e'), P('M-30 6 L0 60 L30 6 Z', PAPER, ' stroke-width="5"'), circle(0, -36, 42, '#ffd7b5'), rect(-46, -54, 92, 22, 10, INK, ' stroke-width="3"'), circle(-17, -44, 8, C.white, ' stroke-width="2"'), circle(17, -44, 8, C.white, ' stroke-width="2"'), P('M-70 -66 Q0 -140 70 -66 Z', INK, ' stroke-width="3"'), rect(-86, -74, 172, 16, 8, INK, ' stroke-width="3"')) + card(350, 150, 1.05, 12, { art: C.pink, icon: star(0, -26, 20, C.yellow, ' stroke-width="4"') })],
  insight: ['intel', () => crystalBall(240, 180, 1.2) + sparkles([[120, 90, 16, C.yellow], [360, 80, 14], [380, 230, 10, C.pink]])],
  intel_leak: ['intel', () => folder(220, 220, 1.1, -6) + paper(330, 110, 1.1, 18) + paper(390, 170, 0.9, -12) + paper(130, 90, 0.85, -22) + `<path d="M150 296 q4 14 0 22 q-4 -8 0 -22z" fill="#9fd8ff" stroke="${INK}" stroke-width="3"/><path d="M250 300 q5 16 0 26 q-5 -10 0 -26z" fill="#9fd8ff" stroke="${INK}" stroke-width="3"/>`],
  sonar_ping: ['intel', () => sonarArcs(240, 230, 4) + chip(240, 290, 0.95, { face: 'q', enemy: true }) + text(380, 90, 'PING!', C.yellow, 52)],
  spy_alarm: ['intel', () => bell(240, 160, 1.15) + chip(120, 300, 0.7, { face: 'spy', enemy: true, rot: -8 }) + text(380, 280, '!!', C.red, 70) + sparkles([[100, 70, 14, C.yellow], [400, 70, 12]])],
  recon_drone: ['intel', () => drone(240, 90, 1.1) + chip(240, 315, 0.9, { enemy: true, face: 'flag' }) + sparkles([[90, 80, 12], [400, 60, 14, C.yellow]])],
  scout_report: ['intel', () => binoculars(200, 170, 1.4) + g('translate(360 210) rotate(8)', rect(-58, -80, 116, 160, 12, C.wood), rect(-46, -64, 92, 136, 6, PAPER, ' stroke-width="4"'), rect(-20, -90, 40, 20, 6, C.steel), line('M-30 -36 H30', 5, '#c9c4d9'), line('M-30 -14 H24', 5, '#c9c4d9'), star(-24, 20, 12, C.red, ' stroke-width="3"'), star(0, 20, 12, C.gold, ' stroke-width="3"'), star(24, 20, 12, C.mint, ' stroke-width="3"'))],
  radar_sweep: ['intel', () => radarScreen(240, 180, 120) + g('translate(380 270)', line('M0 0 L-24 -70', 7), P('M-70 -100 C-40 -60 0 -60 20 -100 Z', C.steel)) + sparkles([[80, 70, 14, C.yellow]])],
  code_breaker: ['intel', () => padlock(240, 190, 1.4) + g('translate(380 110) rotate(35)', circle(0, 0, 22, C.gold), rect(16, -6, 70, 12, 5, C.gold), rect(64, 4, 10, 16, 3, C.gold), rect(44, 4, 10, 12, 3, C.gold)) + sparkles([[90, 80, 14], [110, 270, 10, C.yellow]])],
  interrogation: ['intel', () => lamp(240, 70, 1.1) + chip(240, 320, 1, { enemy: true, face: 'q' }) + `<path d="M296 200 q12 18 0 30 q-12 -12 0 -30z" fill="#9fd8ff" stroke="${INK}" stroke-width="4"/>`],
  flag_hunter: ['intel', () => g('translate(220 200) rotate(-6)', rect(-150, -100, 300, 200, 14, '#f4dfae'), `<path d="M-120 60 C-60 -40 0 80 60 -10 C80 -40 100 -40 110 -60" fill="none" stroke="${C.red}" stroke-width="7" stroke-dasharray="14 12" stroke-linecap="round"/>`, line('M96 -78 L124 -50 M124 -78 L96 -50', 10, C.red), P('M-150 -60 C-120 -80 -80 -50 -60 -100', 'none', ' stroke="#c9a46a" stroke-width="5"')) + magnifier(370, 150, 0.9, -30)],

  // Tactics
  retreat: ['tactics', () => chip(300, 290, 1.05, { face: 'chevron' }) + arrow('M220 150 C120 150 110 250 150 290', C.yellow) + P('M150 312 L124 270 L176 276 Z', C.yellow) + smokePuff(380, 300, 0.6) + smokePuff(410, 260, 0.45)],
  swap: ['tactics', () => chip(150, 300, 0.95, { face: 'star' }) + chip(330, 300, 0.95, { face: 'chevron', base: C.mint }) + arrow('M160 140 C200 70 280 70 320 140', C.yellow) + P('M330 156 L300 124 L346 116 Z', C.yellow) + arrow('M320 330 C280 360 200 360 160 330', C.pink)],
  rally_cry: ['tactics', () => megaphone(200, 170, 1.2) + `<path d="M300 100 q40 70 0 140 M340 76 q56 94 0 188" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round" opacity="0.85"/>` + text(380, 120, '!', C.yellow, 80) + sparkles([[80, 70, 14, C.yellow], [420, 290, 12]])],
  haste: ['tactics', () => speedLines(200, 150, 5, 140, 30) + wings(300, 236, 0.85) + chip(300, 310, 1.05, { face: 'up' }) + arrow('M70 330 H170', C.yellow) + P('M188 330 L162 312 V348 Z', C.yellow) + sparkles([[420, 90, 14, C.yellow], [120, 80, 10]])],
  smoke_screen: ['tactics', () => chip(150, 300, 0.75, { enemy: false }) + chip(250, 300, 0.75, {}) + chip(350, 300, 0.75, {}) + cloud(160, 220, 1.05, '#ebe7ff', 0.95) + cloud(320, 210, 1.15, '#ddd7f6', 0.95) + cloud(250, 120, 0.9, '#f5f2ff', 0.9)],
  double_march: ['tactics', () => chip(170, 300, 0.95, { face: 'chevron' }) + chip(320, 260, 0.95, { face: 'chevron', base: C.mint }) + `<g fill="#ffffff" opacity="0.8">${[[90, 330], [110, 300], [240, 300], [260, 270], [390, 230], [410, 200]].map(([x, y]) => `<ellipse cx="${x}" cy="${y}" rx="11" ry="16"/>`).join('')}</g>` + text(250, 100, 'x2', C.yellow, 70)],
  teleport: ['tactics', () => portal(150, 300, 1) + portal(350, 140, 0.8) + chip(350, 150, 0.8, { face: 'star' }) + arrow('M170 250 C200 180 260 160 300 160', C.white) + sparkles([[240, 60, 14, C.yellow], [420, 280, 12, C.pink]])],

  // Traps
  jammer: ['trap', () => g('translate(180 200)', line('M0 120 L-50 260 M0 120 L50 260 M-30 200 H30', 8), rect(-10, -30, 20, 150, 6, C.steel), circle(0, -40, 18, C.red)) + `<path d="M120 120 q60 -60 120 0 M100 90 q80 -90 160 0" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/>` + g('translate(350 150)', P('M-80 -60 H80 V40 H0 L-30 70 V40 H-80 Z', PAPER), line('M-30 -30 L30 20 M30 -30 L-30 20', 14, C.red))],
  roadblock: ['trap', () => barricade(230, 200, 1.05) + cone(400, 250, 0.9) + cone(70, 260, 0.75)],
  freeze: ['trap', () => chip(240, 290, 1.05, { enemy: true, face: 'q' }) + ice(240, 290, 1.2) + snowflake(110, 90, 1.2) + snowflake(390, 70, 1) + snowflake(400, 230, 0.8) + sparkles([[80, 220, 12]])],
  quicksand: ['trap', () => swirl(240, 290, 1.25) + chip(240, 300, 0.9, { enemy: true, face: 'q', rot: 12, noShadow: true }) + swirl(240, 312, 1.1, C.sand, '#b98a3f').replace('ellipse', 'ellipse') + `<path d="M150 296 C170 330 310 330 330 296" fill="${C.sand}" stroke="${INK}" stroke-width="${SW}"/>` + text(380, 110, 'GLUG!', C.yellow, 40)],
  chaos_order: ['trap', () => dice(180, 200, 1.4, -18, 5) + dice(320, 170, 1.2, 22, 3) + `<path d="M120 90 C180 30 300 30 360 90" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" opacity="0.85"/>` + text(250, 330, '?!', C.yellow, 64)],
  sabotage: ['trap', () => bomb(220, 210, 1.3) + g('translate(370 230) rotate(-30)', rect(-12, -10, 24, 110, 10, C.steel), P('M-36 -30 C-36 -70 36 -70 36 -30 L18 -30 L12 -50 H-12 L-18 -30Z', C.steel))],
  mine_field: ['trap', () => mine(240, 250, 1.3) + text(380, 110, 'BOOM?', C.yellow, 44) + sparkles([[100, 100, 12, C.yellow]])],
  counterspell: ['trap', () => `<circle cx="240" cy="190" r="140" fill="none" stroke="#fff" stroke-width="6" stroke-dasharray="18 12" opacity="0.8"/><circle cx="240" cy="190" r="112" fill="none" stroke="${C.yellow}" stroke-width="5" opacity="0.8"/>` + card(240, 190, 1.2, -8, { art: C.blue }) + line('M206 100 L236 170 L218 200 L262 280', 10, INK) + line('M206 100 L236 170 L218 200 L262 280', 4, C.white) + sparkles([[120, 80, 16, C.yellow], [380, 300, 14, C.pink], [370, 80, 12]])],

  // Support
  fortify: ['support', () => shield(240, 190, 1.25, C.blue) + arrow('M60 80 L150 140', C.red) + `<path d="M140 110 l30 30 l-34 6z" fill="${C.red}" stroke="${INK}" stroke-width="5"/>` + sparkles([[170, 140, 18, C.yellow], [380, 90, 12]])],
  trench: ['support', () => chip(240, 260, 1.05, { face: 'star' }) + helmet(240, 135, 0.8) + sandbag(150, 300, 1) + sandbag(240, 312, 1) + sandbag(330, 300, 1) + sandbag(195, 272, 0.9, -6) + sandbag(285, 272, 0.9, 6)],
  decoy: ['support', () => chip(240, 300, 1.05, { face: 'star', body: '#ffe9b0' }) + g('translate(240 180) rotate(-8)', P('M-70 -40 C-70 -80 70 -80 70 -40 C70 10 40 40 0 40 C-40 40 -70 10 -70 -40Z', PAPER), circle(-28, -30, 12, INK, ' stroke-width="2"'), circle(28, -30, 12, INK, ' stroke-width="2"'), line('M-26 6 C-10 20 10 20 26 6', 6), line('M70 -20 L120 40', 8, C.wood)) + text(390, 110, '?', C.purple, 70)],
  ceasefire: ['support', () => flagOnPole(230, 330, 1.25, PAPER, true) + g('translate(380 120)', P('M-40 10 C-20 -30 30 -30 40 0 C60 -4 70 6 60 14 C40 30 -20 34 -40 10Z', PAPER), circle(18, -6, 5, INK, ' stroke-width="1"'), P('M52 4 L72 0 L58 14Z', C.gold, ' stroke-width="3"'))],
  reinforcement: ['support', () => parachute(240, 110, 1, C.mint) + chip(240, 300, 0.85, { face: 'chevron' }) + badgeText(390, 260, '+1', C.mint, 44)],
  second_chance: ['support', () => wings(240, 230, 0.95) + chip(240, 300, 1, { face: 'star' }) + `<ellipse cx="240" cy="148" rx="46" ry="12" fill="none" stroke="${C.yellow}" stroke-width="10"/>` + P('M380 120 C380 96 412 92 420 112 C428 92 460 96 460 120 C460 150 420 170 420 176 C420 170 380 150 380 120Z', C.pink)],
  shuffle: ['support', () => cup(150, 240, 1, -6, C.red) + cup(330, 240, 1, 6, C.blue) + arrow('M170 110 C210 60 270 60 310 110', C.yellow) + arrow('M310 330 C270 360 210 360 170 330', C.yellow) + text(240, 300, '?', C.white, 60)],
  counter_intel: ['support', () => g('translate(240 250)', P('M-80 -10 H80 L66 90 H-66 Z', C.steel), line('M-60 10 H60 M-56 40 H56', 4, '#6c7894')) + folder(240, 200, 0.75, 8) + flame(200, 170, 0.9) + flame(270, 160, 1.1) + text(390, 100, 'POOF', C.yellow, 40)],
  promotion: ['support', () => chip(240, 300, 1.1, { face: 'chevron', badge: C.gold }) + arrow('M100 300 V150', C.mint) + P('M100 130 L74 168 H126 Z', C.mint) + star(380, 110, 34, C.yellow) + confetti([[120, 70, 20, C.pink], [330, 60, -30, C.blue], [410, 210, 40, C.mint], [80, 210, -10, C.yellow]])],
  recall: ['support', () => hand(140, 260, 1.3, 20) + card(340, 140, 0.95, 20, { art: C.mint }) + arrow('M300 230 C260 300 200 300 180 240', C.yellow) + P('M170 220 L160 260 L196 248 Z', C.yellow)],
};

let fontFace = '';

// The SVG is drawn as an image, which can't see the page's fonts: embed Lilita One in it.
function svgFor(id) {
  const [kind, draw] = SCENES[id];
  if (!fontFace) {
    const font = fs.readFileSync(path.join(ROOT, 'assets', 'fonts', 'LilitaOne-Regular.ttf')).toString('base64');
    fontFace = `<style>@font-face{font-family:'Lilita One';src:url(data:font/ttf;base64,${font}) format('truetype')}</style>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W * PX}" height="${H * PX}"><defs>${fontFace}</defs>${backdrop(kind)}${draw()}</svg>`;
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };
  const only = opt('--only') ? opt('--only').split(',') : null;
  const sheet = opt('--sheet');
  const ids = Object.keys(SCENES).filter((id) => !only || only.includes(id));
  fs.mkdirSync(OUT, { recursive: true });
  const font = fs.readFileSync(path.join(ROOT, 'assets', 'fonts', 'LilitaOne-Regular.ttf')).toString('base64');
  const puppeteer = require('puppeteer-core');
  const browser = await puppeteer.launch({ executablePath: BROWSER, headless: 'new' });
  const page = await browser.newPage();
  await page.setViewport({ width: W * PX, height: H * PX, deviceScaleFactor: 1 });
  await page.setContent(`<!DOCTYPE html><html><head><style>@font-face{font-family:'Lilita One';src:url(data:font/ttf;base64,${font})}html,body{margin:0;background:#000}</style></head><body><canvas id="c" width="${OUT_W}" height="${OUT_H}"></canvas></body></html>`);
  await page.evaluate(() => document.fonts.load("40px 'Lilita One'"));
  for (const id of ids) {
    const svg = svgFor(id);
    // Draw the SVG (with the embedded font available) onto a canvas and export WebP.
    const dataUrl = await page.evaluate(async (markup, w, h) => {
      const blob = new Blob([markup], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      const img = new Image();
      await new Promise((ok, fail) => { img.onload = ok; img.onerror = fail; img.src = url; });
      await new Promise((ok) => setTimeout(ok, 60)); // let the embedded font settle
      const canvas = document.getElementById('c');
      const ctx = canvas.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      ctx.clearRect(0, 0, w, h);
      ctx.drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(url);
      return canvas.toDataURL('image/webp', 0.88);
    }, svg, OUT_W, OUT_H);
    fs.writeFileSync(path.join(OUT, `${id}.webp`), Buffer.from(dataUrl.split(',')[1], 'base64'));
    console.log('wrote', id);
  }
  if (sheet) {
    // A contact sheet of every illustration, for review.
    const cols = 7;
    const cell = 224;
    const rows = Math.ceil(ids.length / cols);
    const imgs = ids.map((id) => `<figure style="margin:0;position:relative"><img src="data:image/webp;base64,${fs.readFileSync(path.join(OUT, id + '.webp')).toString('base64')}" width="${cell}" height="${cell * 0.75}"><figcaption style="position:absolute;left:4px;bottom:2px;font:bold 12px sans-serif;color:#fff;text-shadow:0 0 3px #000">${id}</figcaption></figure>`).join('');
    await page.setViewport({ width: cols * cell, height: Math.ceil(rows * cell * 0.75), deviceScaleFactor: 1 });
    await page.setContent(`<html><body style="margin:0;display:grid;grid-template-columns:repeat(${cols},${cell}px)">${imgs}</body></html>`);
    await page.screenshot({ path: sheet, fullPage: true });
    console.log('sheet', sheet);
  }
  await browser.close();
}

if (require.main === module) {
  main().catch((e) => { console.error(e); process.exit(1); });
}

module.exports = { SCENES, svgFor };
