// Builds the Salpakan Tactics! logo from code: a cel-shaded shield with a faceted general's star,
// an arched "SALPAKAN" wordmark (Lilita One, OFL, converted to paths) and a tilted "TACTICS!"
// ribbon, all with ink outlines and a die-cut paper rim.
//
// Writes:
//   assets/brand/src/logo.svg, emblem.svg     static vector logo / emblem (not imported by Godot)
//   assets/brand/src/layers/*.svg              pieces GameLogo animates separately
//   assets/brand/src/layout.json               where each layer sits in the 1000×720 logo space
//   icon.svg                                   app icon (kept simple so Godot's ThorVG renders it)
//   web/shell.html                             web/shell.src.html + the animated inline logo + font
//
// Then run render_png.js to rasterise the PNGs. Needs opentype.js on NODE_PATH (see README.md).

const fs = require('fs');
const path = require('path');
const opentype = require('opentype.js');

const ROOT = path.resolve(__dirname, '..', '..');
const font = opentype.loadSync(path.join(ROOT, 'assets/fonts/LilitaOne-Regular.ttf'));

const C = {
  ink: '#1d1736', paper: '#fff8ec', pink: '#ff4f8b', blue: '#3d8bff', yellow: '#ffcf3f',
  mint: '#27c98f', gold: '#ffb703', purple: '#8b5cf6',
};
const VIEW = { w: 1000, h: 720 };
const INK_W = 14;          // Ink outline width of shapes.
const RIM = 18;            // Extra width of the paper rim around the ink.
const r2 = (n) => Math.round(n * 100) / 100;

// --- Geometry --------------------------------------------------------------------------------

const SHIELD = 'M 500 30 C 560 30 612 48 656 74 Q 668 81 668 96 L 668 192 '
  + 'C 668 282 600 340 500 376 C 400 340 332 282 332 192 L 332 96 Q 332 81 344 74 C 388 48 440 30 500 30 Z';
const STAR = { cx: 500, cy: 196, outer: 104, inner: 46 };

function starPoints({ cx, cy, outer, inner }) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (Math.PI * i) / 5;
    const r = i % 2 === 0 ? outer : inner;
    pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
  }
  return pts;
}

function sparklePath(x, y, s) {
  const k = s * 0.18;
  return `M ${x} ${y - s} Q ${x + k} ${y - k} ${x + s} ${y} Q ${x + k} ${y + k} ${x} ${y + s} `
    + `Q ${x - k} ${y + k} ${x - s} ${y} Q ${x - k} ${y - k} ${x} ${y - s} Z`;
}

const SPARKLES = [
  { x: 286, y: 92, s: 36, color: C.mint, delay: 0.2 },
  { x: 718, y: 132, s: 30, color: C.yellow, delay: 0.9 },
  { x: 690, y: 42, s: 20, color: C.paper, delay: 1.5 },
  { x: 270, y: 238, s: 21, color: C.pink, delay: 2.1 },
  { x: 918, y: 292, s: 25, color: C.paper, delay: 1.2 },
  { x: 74, y: 300, s: 23, color: C.yellow, delay: 0.6 },
];

// Lays a word out along a gentle arch; each letter gets its own transform so it can animate alone.
function layoutWord(text, size, tracking, centerX, baseY, arch) {
  const glyphs = font.stringToGlyphs(text);
  const scale = size / font.unitsPerEm;
  const offsets = [];
  let pen = 0;
  glyphs.forEach((g, i) => {
    offsets.push(pen);
    pen += g.advanceWidth * scale;
    if (i < glyphs.length - 1) pen += font.getKerningValue(g, glyphs[i + 1]) * scale + tracking;
  });
  const last = glyphs[glyphs.length - 1];
  const width = offsets[offsets.length - 1] + last.advanceWidth * scale;
  const startX = centerX - width / 2;
  const half = width / 2;
  return glyphs.map((g, i) => {
    const p = g.getPath(0, 0, size);
    const bb = p.getBoundingBox();
    const lx = (bb.x1 + bb.x2) / 2;
    const ly = (bb.y1 + bb.y2) / 2;
    const x = startX + offsets[i];
    const u = (x + lx - centerX) / half;
    const dy = -arch * (1 - u * u);
    const angle = (Math.atan((2 * arch * u) / half) * 180) / Math.PI;
    const transform = `translate(${r2(x)} ${r2(baseY + dy)}) rotate(${r2(angle)} ${r2(lx)} ${r2(ly)})`;
    // Bounding box after the transform (corners rotated about the letter centre).
    const rad = (angle * Math.PI) / 180;
    const corners = [[bb.x1, bb.y1], [bb.x2, bb.y1], [bb.x1, bb.y2], [bb.x2, bb.y2]].map(([px, py]) => {
      const rx = px - lx; const ry = py - ly;
      return [x + lx + rx * Math.cos(rad) - ry * Math.sin(rad), baseY + dy + ly + rx * Math.sin(rad) + ry * Math.cos(rad)];
    });
    return { d: p.toPathData(2), transform, corners };
  });
}

const WORD = layoutWord('SALPAKAN', 182, 6, 500, 512, 18);
const RIBBON_TEXT = layoutWord('TACTICS!', 92, 7, 0, 0, 0);
const RIBBON = (() => {
  const xs = RIBBON_TEXT.flatMap((l) => l.corners.map((c) => c[0]));
  const textW = Math.max(...xs) - Math.min(...xs);
  const w = textW + 116;
  const h = 104;
  return { cx: 500, cy: 586, w, h, angle: -4 };
})();

function bboxOf(points, pad) {
  const xs = points.map((p) => p[0]);
  const ys = points.map((p) => p[1]);
  return { x: Math.floor(Math.min(...xs) - pad), y: Math.floor(Math.min(...ys) - pad),
    w: Math.ceil(Math.max(...xs) - Math.min(...xs) + pad * 2), h: Math.ceil(Math.max(...ys) - Math.min(...ys) + pad * 2) };
}

// --- SVG pieces -------------------------------------------------------------------------------

function defs(prefix = '') {
  const p = prefix;
  return `<linearGradient id="${p}shield" x1="0" y1="30" x2="0" y2="376" gradientUnits="userSpaceOnUse">`
    + `<stop offset="0" stop-color="#6cb2ff"/><stop offset="1" stop-color="#2a63d8"/></linearGradient>`
    + `<linearGradient id="${p}word" x1="0" y1="0" x2="0" y2="1">`
    + `<stop offset="0" stop-color="#fff4a8"/><stop offset="0.38" stop-color="#ffd53f"/><stop offset="1" stop-color="#ffa600"/></linearGradient>`
    + `<linearGradient id="${p}ribbon" x1="0" y1="-52" x2="0" y2="52" gradientUnits="userSpaceOnUse">`
    + `<stop offset="0" stop-color="#ff86b2"/><stop offset="1" stop-color="#ff3f7f"/></linearGradient>`
    + `<clipPath id="${p}shield-clip"><path d="${SHIELD}"/></clipPath>`;
}

function shieldGroup(p = '') {
  return `<g class="shield">`
    + `<path d="${SHIELD}" transform="translate(0 10)" fill="${C.ink}" stroke="${C.ink}" stroke-width="${INK_W + RIM}" stroke-linejoin="round" opacity="0.45"/>`
    + `<path d="${SHIELD}" fill="${C.paper}" stroke="${C.paper}" stroke-width="${INK_W + RIM}" stroke-linejoin="round"/>`
    + `<path d="${SHIELD}" fill="url(#${p}shield)"/>`
    + `<g clip-path="url(#${p}shield-clip)">`
    + `<rect x="500" y="20" width="200" height="380" fill="#173f9e" opacity="0.28"/>`
    + `<ellipse cx="410" cy="104" rx="70" ry="26" transform="rotate(-24 410 104)" fill="#ffffff" opacity="0.32"/>`
    + `</g>`
    + `<path d="${SHIELD}" transform="translate(500 196) scale(0.83) translate(-500 -196)" fill="none" stroke="#ffffff" stroke-opacity="0.38" stroke-width="7" stroke-linejoin="round"/>`
    + `<path d="${SHIELD}" fill="none" stroke="${C.ink}" stroke-width="${INK_W}" stroke-linejoin="round"/>`
    + `</g>`;
}

function starGroup() {
  const pts = starPoints(STAR);
  const poly = pts.map((p) => `${r2(p[0])},${r2(p[1])}`).join(' ');
  let facets = '';
  for (let i = 0; i < 10; i++) {
    const a = pts[i]; const b = pts[(i + 1) % 10];
    // Each arm is split along its spine: the left half catches the light.
    const light = i % 2 === 1;
    facets += `<polygon points="${STAR.cx},${STAR.cy} ${r2(a[0])},${r2(a[1])} ${r2(b[0])},${r2(b[1])}" fill="${light ? '#ffe36a' : '#ffad0a'}" stroke="${light ? '#ffe36a' : '#ffad0a'}" stroke-width="0.8" stroke-linejoin="round"/>`;
  }
  return `<g class="star">`
    + `<polygon points="${poly}" transform="translate(0 7)" fill="${C.ink}" stroke="${C.ink}" stroke-width="${INK_W}" stroke-linejoin="round" opacity="0.4"/>`
    + facets
    + `<polygon points="${poly}" fill="none" stroke="${C.ink}" stroke-width="${INK_W}" stroke-linejoin="round"/>`
    + `<ellipse cx="474" cy="150" rx="8" ry="19" transform="rotate(28 474 150)" fill="#ffffff" opacity="0.9"/>`
    + `<circle cx="462" cy="176" r="5" fill="#ffffff" opacity="0.8"/>`
    + `</g>`;
}

function letterLayer(cls, attrs, offset = '') {
  return `<g class="${cls}"${offset ? ` transform="${offset}"` : ''}>`
    + WORD.map((l, i) => `<g transform="${l.transform}"><path class="ltr" style="--i:${i}" d="${l.d}" ${attrs}/></g>`).join('')
    + `</g>`;
}

function wordGroup(p = '', shine = false) {
  let out = `<g class="word">`
    + letterLayer('w-shadow', `fill="${C.ink}" stroke="${C.ink}" stroke-width="${26 + RIM}" stroke-linejoin="round" opacity="0.45"`, 'translate(0 12)')
    + letterLayer('w-rim', `fill="${C.paper}" stroke="${C.paper}" stroke-width="${26 + RIM}" stroke-linejoin="round"`)
    + letterLayer('w-ink', `fill="${C.ink}" stroke="${C.ink}" stroke-width="26" stroke-linejoin="round"`)
    + letterLayer('w-drop', `fill="#e07b00"`, 'translate(0 7)')
    + letterLayer('w-fill', `fill="url(#${p}word)"`);
  if (shine) {
    out += `<clipPath id="${p}word-clip">${WORD.map((l) => `<path d="${l.d}" transform="${l.transform}"/>`).join('')}</clipPath>`
      + `<g clip-path="url(#${p}word-clip)"><rect class="shine" x="-260" y="330" width="90" height="220" fill="#ffffff" opacity="0.75" transform="skewX(-22)"/>`
      + `<rect class="shine shine-thin" x="-140" y="330" width="22" height="220" fill="#ffffff" opacity="0.6" transform="skewX(-22)"/></g>`;
  }
  return out + `</g>`;
}

function ribbonGroup(p = '') {
  const { w, h } = RIBBON;
  const x0 = -w / 2; const y0 = -h / 2;
  const tailW = 92; const tailDrop = 34; const tailH = h * 0.82; const tuck = 44;
  const tail = (side) => {
    const s = side; // -1 left, +1 right
    const inner = s * (w / 2 - tuck);
    const outer = s * (w / 2 + tailW);
    const notch = s * (w / 2 + tailW - 30);
    const ty = y0 + tailDrop;
    return `M ${r2(inner)} ${r2(ty)} L ${r2(outer)} ${r2(ty)} L ${r2(notch)} ${r2(ty + tailH / 2)} L ${r2(outer)} ${r2(ty + tailH)} L ${r2(inner)} ${r2(ty + tailH)} Z`;
  };
  const fold = (side) => {
    const s = side;
    const ty = y0 + tailDrop;
    return `M ${r2(s * (w / 2))} ${r2(y0 + h)} L ${r2(s * (w / 2 - tuck))} ${r2(ty + tailH)} L ${r2(s * (w / 2 - tuck))} ${r2(y0 + h)} Z`;
  };
  const band = `M ${r2(x0 + 16)} ${r2(y0)} L ${r2(-x0 - 16)} ${r2(y0)} Q ${r2(-x0)} ${r2(y0)} ${r2(-x0)} ${r2(y0 + 16)} L ${r2(-x0)} ${r2(y0 + h - 16)} `
    + `Q ${r2(-x0)} ${r2(y0 + h)} ${r2(-x0 - 16)} ${r2(y0 + h)} L ${r2(x0 + 16)} ${r2(y0 + h)} Q ${r2(x0)} ${r2(y0 + h)} ${r2(x0)} ${r2(y0 + h - 16)} `
    + `L ${r2(x0)} ${r2(y0 + 16)} Q ${r2(x0)} ${r2(y0)} ${r2(x0 + 16)} ${r2(y0)} Z`;
  const outline = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" stroke="${C.ink}" stroke-width="12" stroke-linejoin="round"${extra}/>`;
  const rim = (d) => `<path d="${d}" fill="${C.paper}" stroke="${C.paper}" stroke-width="${12 + RIM}" stroke-linejoin="round"/>`;
  const shadow = (d) => `<path d="${d}" transform="translate(0 10)" fill="${C.ink}" stroke="${C.ink}" stroke-width="${12 + RIM}" stroke-linejoin="round" opacity="0.45"/>`;
  const text = RIBBON_TEXT.map((l) => `<g transform="${l.transform}"><path d="${l.d}"/></g>`).join('');
  const textBox = bboxOf(RIBBON_TEXT.flatMap((l) => l.corners), 0);
  const tx = -(textBox.x + textBox.w / 2);
  const ty = -(textBox.y + textBox.h / 2);
  return `<g transform="translate(${RIBBON.cx} ${RIBBON.cy}) rotate(${RIBBON.angle})"><g class="ribbon">`
    + shadow(tail(-1)) + shadow(tail(1)) + shadow(band)
    + rim(tail(-1)) + rim(tail(1)) + rim(band)
    + outline(tail(-1), '#d42f6a') + outline(tail(1), '#d42f6a')
    + `<path d="${fold(-1)}" fill="#8e1d48" stroke="${C.ink}" stroke-width="8" stroke-linejoin="round"/>`
    + `<path d="${fold(1)}" fill="#8e1d48" stroke="${C.ink}" stroke-width="8" stroke-linejoin="round"/>`
    + outline(band, `url(#${p}ribbon)`)
    + `<path d="M ${r2(x0 + 22)} ${r2(y0 + 14)} L ${r2(-x0 - 22)} ${r2(y0 + 14)}" stroke="#ffffff" stroke-opacity="0.45" stroke-width="7" stroke-linecap="round"/>`
    + `<g transform="translate(${r2(tx)} ${r2(ty + 4)})">`
    + [2, 4, 6].map((dy) => `<g fill="${C.ink}" stroke="${C.ink}" stroke-width="18" stroke-linejoin="round" transform="translate(0 ${dy})">${text}</g>`).join('')
    + `<g fill="${C.ink}" stroke="${C.ink}" stroke-width="18" stroke-linejoin="round">${text}</g>`
    + `<g fill="#ffffff">${text}</g>`
    + `</g></g></g>`;
}

function sparkleGroup() {
  return SPARKLES.map((s) => {
    const d = sparklePath(s.x, s.y, s.s);
    return `<path class="spark" style="--d:${s.delay}s" d="${d}" fill="${s.color}" stroke="${C.ink}" stroke-width="5" stroke-linejoin="round"/>`;
  }).join('');
}

function svgDoc(viewBox, body, extra = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}"${extra}>${body}</svg>\n`;
}

// --- Outputs ----------------------------------------------------------------------------------

const srcDir = path.join(ROOT, 'assets/brand/src');
const layerDir = path.join(srcDir, 'layers');
fs.mkdirSync(layerDir, { recursive: true });

const fullBody = `<defs>${defs()}</defs>${shieldGroup()}${starGroup()}${wordGroup()}${ribbonGroup()}${sparkleGroup()}`;
fs.writeFileSync(path.join(srcDir, 'logo.svg'), svgDoc(`0 0 ${VIEW.w} ${VIEW.h}`, fullBody, ` width="${VIEW.w}" height="${VIEW.h}"`));

// Layer boxes (logo space), padded for rims, shadows and ink.
const shieldBox = { x: 312, y: 10, w: 376, h: 392 };
const starPts = starPoints(STAR);
const starBox = bboxOf(starPts, 16);
starBox.h += 8;
const wordBox = bboxOf(WORD.flatMap((l) => l.corners), (26 + RIM) / 2 + 4);
wordBox.h += 12;
const ribbonCorners = (() => {
  const { w, h, cx, cy, angle } = RIBBON;
  const hw = w / 2 + 92; const hh = h / 2 + 34;
  const rad = (angle * Math.PI) / 180;
  return [[-hw, -hh], [hw, -hh], [-hw, hh + 10], [hw, hh + 10]].map(([x, y]) => [cx + x * Math.cos(rad) - y * Math.sin(rad), cy + x * Math.sin(rad) + y * Math.cos(rad)]);
})();
const ribbonBox = bboxOf(ribbonCorners, 22);
const sparkBox = { x: -40, y: -40, w: 80, h: 80 };

const layers = {
  shield: { box: shieldBox, body: `<defs>${defs()}</defs>${shieldGroup()}` },
  star: { box: starBox, body: starGroup() },
  wordmark: { box: wordBox, body: `<defs>${defs()}</defs>${wordGroup()}` },
  ribbon: { box: ribbonBox, body: `<defs>${defs()}</defs>${ribbonGroup()}` },
};
const layout = { view: VIEW, star_center: [STAR.cx, STAR.cy], layers: {}, sparkles: SPARKLES.map((s) => ({ x: s.x, y: s.y, size: s.s, color: s.color })) };
for (const [name, { box, body }] of Object.entries(layers)) {
  fs.writeFileSync(path.join(layerDir, `${name}.svg`), svgDoc(`${box.x} ${box.y} ${box.w} ${box.h}`, body, ` width="${box.w}" height="${box.h}"`));
  layout.layers[name] = box;
}
// One white sparkle; GameLogo tints and scales copies of it.
fs.writeFileSync(path.join(layerDir, 'sparkle.svg'), svgDoc(`${sparkBox.x} ${sparkBox.y} ${sparkBox.w} ${sparkBox.h}`,
  `<path d="${sparklePath(0, 0, 32)}" fill="#ffffff" stroke="${C.ink}" stroke-width="5" stroke-linejoin="round"/>`, ` width="${sparkBox.w}" height="${sparkBox.h}"`));
layout.layers.sparkle = { ...sparkBox, base_size: 32 };
fs.writeFileSync(path.join(srcDir, 'layout.json'), `${JSON.stringify(layout, null, 2)}\n`);

// Emblem alone (square), for icons and avatars.
const emblemBody = `<defs>${defs()}</defs>${shieldGroup()}${starGroup()}`;
fs.writeFileSync(path.join(srcDir, 'emblem.svg'), svgDoc('300 4 400 400', emblemBody, ' width="400" height="400"'));

// App icon: the emblem on a night-purple tile. No clip paths or opacity groups (ThorVG-safe).
const iconStar = starPoints({ cx: 128, cy: 120, outer: 60, inner: 26.5 });
const iconShield = 'M 128 26 C 162 26 192 36 217 51 Q 224 55 224 64 L 224 118 C 224 170 185 203 128 224 C 71 203 32 170 32 118 L 32 64 Q 32 55 39 51 C 64 36 94 26 128 26 Z';
let iconFacets = '';
for (let i = 0; i < 10; i++) {
  const a = iconStar[i]; const b = iconStar[(i + 1) % 10];
  const light = i % 2 === 1;
  iconFacets += `<polygon points="128,120 ${r2(a[0])},${r2(a[1])} ${r2(b[0])},${r2(b[1])}" fill="${light ? '#ffe36a' : '#ffad0a'}"/>`;
}
const iconPoly = iconStar.map((p) => `${r2(p[0])},${r2(p[1])}`).join(' ');
const icon = `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <!-- Salpakan Tactics! app icon (generated by tools/brand/generate_logo.js): the shield-and-star emblem on a night-purple tile. -->
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="256" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#4a35a6"/><stop offset="1" stop-color="#1d1736"/></linearGradient>
    <linearGradient id="shield" x1="0" y1="26" x2="0" y2="224" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#6cb2ff"/><stop offset="1" stop-color="#2a63d8"/></linearGradient>
  </defs>
  <rect x="4" y="4" width="248" height="248" rx="56" fill="url(#tile)"/>
  <rect x="10" y="10" width="236" height="236" rx="50" fill="none" stroke="#ffffff" stroke-opacity="0.12" stroke-width="4"/>
  <path d="${iconShield}" transform="translate(0 7)" fill="#0d0a1f" stroke="#0d0a1f" stroke-width="22" stroke-linejoin="round" fill-opacity="0.6" stroke-opacity="0.6"/>
  <path d="${iconShield}" fill="${C.paper}" stroke="${C.paper}" stroke-width="22" stroke-linejoin="round"/>
  <path d="${iconShield}" fill="url(#shield)" stroke="${C.ink}" stroke-width="9" stroke-linejoin="round"/>
  <path d="M 128 26 C 162 26 192 36 217 51 Q 224 55 224 64 L 224 118 C 224 170 185 203 128 224 Z" fill="#173f9e" fill-opacity="0.28"/>
  <path d="${iconShield}" fill="none" stroke="${C.ink}" stroke-width="9" stroke-linejoin="round"/>
  <ellipse cx="78" cy="68" rx="34" ry="12" transform="rotate(-24 78 68)" fill="#ffffff" fill-opacity="0.32"/>
  <polygon points="${iconPoly}" transform="translate(0 5)" fill="#0d0a1f" fill-opacity="0.4" stroke="#0d0a1f" stroke-opacity="0.4" stroke-width="9" stroke-linejoin="round"/>
  ${iconFacets}
  <polygon points="${iconPoly}" fill="none" stroke="${C.ink}" stroke-width="9" stroke-linejoin="round"/>
  <ellipse cx="113" cy="93" rx="5" ry="11" transform="rotate(28 113 93)" fill="#ffffff" fill-opacity="0.9"/>
</svg>
`;
fs.writeFileSync(path.join(ROOT, 'icon.svg'), icon);

// Animated inline logo for the web loader.
const animated = `<svg id="logo" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${VIEW.w} ${VIEW.h}" role="img" aria-label="Salpakan Tactics!">`
  + `<defs>${defs('l-')}</defs>`
  + `<g class="emblem">${shieldGroup('l-')}${starGroup()}</g>`
  + wordGroup('l-', true)
  + ribbonGroup('l-')
  + `<g class="sparks">${sparkleGroup()}</g>`
  + `</svg>`;
const shellSrc = fs.readFileSync(path.join(ROOT, 'web/shell.src.html'), 'utf8');
const fontB64 = fs.readFileSync(path.join(ROOT, 'assets/fonts/LilitaOne-Regular.ttf')).toString('base64');
const shell = shellSrc
  .replace('<!--@LOGO@-->', animated)
  .replace('/*@FONT@*/', `url(data:font/ttf;base64,${fontB64}) format('truetype')`);
fs.writeFileSync(path.join(ROOT, 'web/shell.html'), shell);

console.log('layout', JSON.stringify(layout.layers));
console.log('shell.html', shell.length, 'bytes');
