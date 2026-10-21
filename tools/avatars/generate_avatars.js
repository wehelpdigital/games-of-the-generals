// Draws the default player avatars: cute, original toon portraits (chibi soldiers and animals in
// uniform) with ink outlines and the game's palette, rendered by headless Edge/Chrome into
// assets/avatars/<id>.webp. AvatarView shows one (picked from the username) when a player has no
// profile photo; it crops them round, so every face stays inside the centre circle.
//
//   NODE_PATH=<dir with puppeteer-core> node tools/avatars/generate_avatars.js [--only id,id] [--sheet out.png]
//
// Set BROWSER to a Chrome binary if Edge isn't at its default path.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'assets', 'avatars');
const BROWSER = process.env.BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const S = 256; // drawing space
const OUT_PX = 256;

const INK = '#1d1736';
const C = {
  pink: '#ff4f8b', blue: '#3d8bff', yellow: '#ffcf3f', mint: '#27c98f', purple: '#8b5cf6', red: '#ff5a5f',
  gold: '#ffb703', orange: '#ff8a3d', sky: '#7cc4ff', white: '#ffffff', green: '#4caf50', olive: '#6f8f3a',
  khaki: '#c9b27a', navy: '#2c3e7a', steel: '#9aa7c2', brown: '#7a5233', tan: '#d9a46c', cream: '#fff3dc',
  grey: '#b9c2d6', dark: '#3a3358', black: '#2a2440', blush: '#ff8fae',
};
const SKIN = ['#ffd9b8', '#f5c193', '#d99a6c', '#a86b45'];
const SW = 6; // ink stroke width

// --- SVG primitives -----------------------------------------------------------------------------

const has = (extra, attr) => new RegExp('(^|\\s)' + attr + '=').test(extra);
const ink = (extra = '') => `${has(extra, 'stroke') ? '' : `stroke="${INK}" `}${has(extra, 'stroke-width') ? '' : `stroke-width="${SW}" `}stroke-linejoin="round" stroke-linecap="round"${extra}`;
const P = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" ${ink(extra)}/>`;
const line = (d, w = SW, color = INK) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const circle = (cx, cy, r, fill, extra = '') => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" ${ink(extra)}/>`;
const ellipse = (cx, cy, rx, ry, fill, extra = '') => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" ${ink(extra)}/>`;
const rect = (x, y, w, h, r, fill, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" ${ink(extra)}/>`;
const shine = (d, a = 0.5) => `<path d="${d}" fill="#ffffff" opacity="${a}"/>`;
const noInk = ' stroke="none"';

function starPts(cx, cy, r1, r2, n = 5, rot = -90) {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 === 0 ? r1 : r2;
    const a = ((rot + (i * 180) / n) * Math.PI) / 180;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(1)},${(cy + Math.sin(a) * r).toFixed(1)}`);
  }
  return pts.join(' ');
}
const star = (cx, cy, r, fill = C.yellow, sw = 4) => `<polygon points="${starPts(cx, cy, r, r * 0.45)}" fill="${fill}" ${ink(` stroke-width="${sw}"`)}/>`;

// --- Shared parts -------------------------------------------------------------------------------

// Backdrop: a flat colour, a soft light behind the head and a few confetti dots.
function backdrop(color, accent) {
  const dots = [[38, 52, 7], [214, 46, 5], [30, 150, 4], [226, 132, 6], [62, 94, 3], [196, 92, 3]]
    .map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${accent}" opacity="0.55"/>`).join('');
  return `<defs><radialGradient id="light" cx="0.5" cy="0.45" r="0.5"><stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient></defs>`
    + `<rect width="${S}" height="${S}" fill="${color}"/><rect width="${S}" height="${S}" fill="url(#light)"/>${dots}`;
}

// Shoulders in a uniform, with a collar of `collar` colour and an optional badge.
function shoulders(color, collar = null, badge = '') {
  let out = P(`M34 262 C36 214 78 196 128 196 C178 196 220 214 222 262 Z`, color);
  out += shine('M64 226 C78 210 98 204 116 202 C100 210 84 220 74 236 Z', 0.25);
  if (collar) {
    out += P('M100 198 L128 232 L156 198 C146 196 110 196 100 198 Z', collar);
  }
  return out + badge;
}

// A round face with ears, at the centre of the portrait.
function humanHead(skin, cy = 134) {
  return circle(66, cy + 6, 13, skin) + circle(190, cy + 6, 13, skin) + circle(128, cy, 62, skin)
    + shine(`M86 ${cy - 30} C96 ${cy - 48} 116 ${cy - 56} 136 ${cy - 56} C116 ${cy - 46} 102 ${cy - 36} 94 ${cy - 22} Z`, 0.35);
}

// Big shiny eyes, blush and a little mouth. mood: smile | grin | smirk | open.
function face(cy = 140, o = {}) {
  const ex = o.spread || 26;
  const ey = cy + (o.eyeDrop || 0);
  const eye = (x) => ellipse(x, ey, o.eyeRx || 9, o.eyeRy || 12, INK, ' stroke-width="0"')
    + circle(x + 3, ey - 5, 4, '#ffffff', noInk) + circle(x - 3, ey + 4, 1.8, '#ffffff', noInk);
  let out = eye(128 - ex) + eye(128 + ex);
  if (!o.noBlush) {
    out += ellipse(128 - ex - 14, ey + 18, 11, 6, C.blush, ' stroke="none" opacity="0.55"')
      + ellipse(128 + ex + 14, ey + 18, 11, 6, C.blush, ' stroke="none" opacity="0.55"');
  }
  const my = ey + 24;
  switch (o.mood || 'smile') {
    case 'grin':
      out += P(`M114 ${my} Q128 ${my + 18} 142 ${my} Z`, '#ff6f8f', ' stroke-width="5"');
      break;
    case 'smirk':
      out += line(`M118 ${my + 4} Q132 ${my + 10} 142 ${my - 2}`, 5);
      break;
    case 'open':
      out += ellipse(128, my + 4, 7, 8, '#ff6f8f', ' stroke-width="5"');
      break;
    default:
      out += line(`M117 ${my} Q128 ${my + 10} 139 ${my}`, 5);
  }
  return out;
}

// Hair fringe peeking under a hat.
const fringe = (color, cy = 134) => P(`M70 ${cy - 14} C78 ${cy - 46} 178 ${cy - 46} 186 ${cy - 14} C176 ${cy - 24} 160 ${cy - 22} 150 ${cy - 30} C140 ${cy - 20} 118 ${cy - 20} 106 ${cy - 30} C96 ${cy - 22} 80 ${cy - 24} 70 ${cy - 14} Z`, color);

// --- Headgear -----------------------------------------------------------------------------------

const helmet = (color, emblem = '') => P('M58 122 C58 62 198 62 198 122 C198 130 194 134 188 134 L68 134 C62 134 58 130 58 122 Z', color)
  + P('M50 128 C70 136 186 136 206 128 C210 138 200 146 188 146 L68 146 C56 146 46 138 50 128 Z', color)
  + shine('M76 92 C90 74 112 68 132 68 C112 76 96 88 88 104 Z', 0.35) + emblem;

const peakedCap = (crown, band, peak = C.black, badge = '', dy = 0) => `<g transform="translate(0 ${dy})">` + P('M54 108 C54 64 202 64 202 108 L186 120 L70 120 Z', crown)
  + rect(68, 108, 120, 18, 6, band) + P('M64 124 C90 142 166 142 192 124 C190 134 170 146 128 146 C86 146 66 134 64 124 Z', peak)
  + shine('M74 92 C88 76 112 70 130 70 C110 78 94 88 86 100 Z', 0.3) + badge + '</g>';

const beret = (color, pin = C.gold) => P('M58 112 C40 92 70 56 128 58 C188 56 214 84 196 108 C176 102 98 100 58 112 Z', color)
  + line('M64 108 C110 98 160 98 194 104', 5) + circle(170, 82, 8, pin, ' stroke-width="4"') + circle(126, 58, 6, color, ' stroke-width="4"');

// --- The portraits ------------------------------------------------------------------------------
// Each returns the SVG body; keep the head inside the central circle (radius ~120 around 128,128).

const AVATARS = {
  rookie_helmet: () => backdrop(C.mint, C.yellow) + shoulders(C.olive, C.khaki)
    + humanHead(SKIN[0]) + face(144) + helmet(C.olive, star(128, 92, 13)),

  officer_cap: () => backdrop(C.sky, C.white) + shoulders(C.navy, C.white, star(104, 228, 8) + star(152, 228, 8))
    + humanHead(SKIN[1]) + fringe(C.brown) + face(144, { mood: 'grin' })
    + peakedCap(C.navy, C.gold, C.black, star(128, 116, 9, C.gold), -4),

  red_beret: () => backdrop(C.yellow, C.pink) + shoulders(C.khaki, C.olive)
    + humanHead(SKIN[2]) + fringe(C.black, 136) + face(146, { mood: 'smirk' }) + beret(C.red),

  general_mustache: () => backdrop(C.purple, C.gold) + shoulders(C.dark, C.gold, star(92, 226, 7) + star(110, 222, 7) + star(146, 222, 7) + star(164, 226, 7))
    + humanHead(SKIN[0]) + face(144)
    + P('M98 170 C108 160 120 164 128 170 C136 164 148 160 158 170 C146 176 136 174 128 172 C120 174 110 176 98 170 Z', C.grey)
    + peakedCap(C.dark, C.gold, C.black, star(116, 116, 7) + star(140, 116, 7), -6),

  ninja: () => backdrop(C.dark, C.pink) + shoulders(C.black, C.dark)
    + circle(128, 134, 64, C.black) + rect(68, 120, 120, 40, 20, SKIN[1], ' stroke-width="5"')
    + face(140, { noBlush: true, mood: 'none', spread: 24 })
    + P('M60 112 C90 100 166 100 196 112 L196 124 C166 114 90 114 60 124 Z', C.red)
    + P('M196 112 L222 100 L216 120 L230 126 L198 124 Z', C.red),

  pirate: () => backdrop(C.blue, C.yellow) + shoulders(C.red, C.cream)
    + humanHead(SKIN[2]) + face(146, { mood: 'grin' })
    + ellipse(102, 146, 14, 13, INK, ' stroke-width="0"') + line('M70 120 L118 150 M110 140 L186 108', 4)
    + P('M48 112 C70 70 186 70 208 112 C186 100 168 98 128 104 C88 98 70 100 48 112 Z', C.black)
    + P('M70 104 C70 66 186 66 186 104 Z', C.black) + circle(128, 84, 10, C.white, ' stroke-width="4"')
    + line('M122 84 h12 M128 78 v12', 3),

  samurai: () => backdrop(C.red, C.cream) + shoulders(C.navy, C.red)
    + humanHead(SKIN[0]) + face(146, { mood: 'smirk' })
    + P('M56 120 C56 60 200 60 200 120 L188 126 L68 126 Z', C.navy)
    + P('M48 122 L208 122 L196 142 L60 142 Z', C.navy)
    + P('M100 74 L84 34 L118 66 Z', C.gold, ' stroke-width="5"') + P('M156 74 L172 34 L138 66 Z', C.gold, ' stroke-width="5"')
    + circle(128, 92, 11, C.gold, ' stroke-width="5"'),

  spy: () => backdrop(C.dark, C.sky) + shoulders(C.khaki, C.brown)
    + humanHead(SKIN[1]) + face(146, { mood: 'smirk' })
    + rect(88, 132, 34, 22, 8, INK) + rect(134, 132, 34, 22, 8, INK) + line('M122 140 h12', 5)
    + shine('M94 136 l10 0 l-6 10 z', 0.6) + shine('M140 136 l10 0 l-6 10 z', 0.6)
    + P('M46 114 C66 104 190 104 210 114 C204 124 52 124 46 114 Z', C.brown)
    + P('M74 112 C74 62 182 62 182 112 Z', C.brown) + rect(76, 96, 104, 12, 4, C.black),

  pilot: () => backdrop(C.sky, C.white) + shoulders(C.brown, C.cream)
    + P('M90 196 C110 214 146 214 166 196 L170 214 C146 230 110 230 86 214 Z', C.white)
    + humanHead(SKIN[3]) + face(148, { mood: 'grin' })
    + P('M62 132 C56 62 200 62 194 132 L180 128 C178 96 78 96 76 128 Z', C.brown)
    + circle(104, 102, 18, C.sky, ' stroke-width="6"') + circle(152, 102, 18, C.sky, ' stroke-width="6"')
    + line('M122 102 h12', 6) + shine('M96 96 a8 8 0 0 1 10 -6 z', 0.7) + shine('M144 96 a8 8 0 0 1 10 -6 z', 0.7),

  knight: () => backdrop(C.gold, C.white) + shoulders(C.steel, C.grey)
    + P('M60 130 C60 56 196 56 196 130 L196 176 C180 192 76 192 60 176 Z', C.steel)
    + rect(80, 112, 96, 56, 26, SKIN[0], ' stroke-width="5"') + face(140, { spread: 22 })
    + P('M128 52 C140 26 170 22 182 36 C164 34 150 44 140 60 Z', C.red)
    + line('M128 58 v8', 6),

  medic: () => backdrop(C.cream, C.mint) + shoulders(C.white, C.mint, rect(118, 214, 20, 20, 4, C.mint, ' stroke-width="4"'))
    + humanHead(SKIN[2]) + fringe(C.brown) + face(146)
    + P('M66 112 C66 70 190 70 190 112 Z', C.white) + rect(62, 108, 132, 16, 7, C.white)
    + P('M122 82 h12 v10 h10 v12 h-10 v10 h-12 v-10 h-10 v-12 h10 Z', C.mint, ' stroke-width="4"'),

  engineer: () => backdrop(C.orange, C.yellow) + shoulders(C.blue, C.orange)
    + humanHead(SKIN[1]) + face(146, { mood: 'grin' })
    + P('M60 116 C60 64 196 64 196 116 Z', C.yellow) + rect(48, 112, 160, 16, 8, C.yellow)
    + rect(118, 66, 20, 48, 8, C.yellow) + shine('M76 98 C88 82 106 74 120 72 C104 82 92 92 86 106 Z', 0.45),

  cat_trooper: () => backdrop(C.pink, C.white) + shoulders(C.olive, C.khaki)
    + P('M70 112 L60 54 L104 84 Z', C.orange) + P('M186 112 L196 54 L152 84 Z', C.orange)
    + circle(128, 136, 64, C.orange) + P('M96 112 l10 18 M128 104 v20 M160 112 l-10 18', C.orange, ' stroke-width="5"')
    + face(144) + P('M122 162 l6 6 l6 -6 z', C.pink, ' stroke-width="4"')
    + line('M70 160 L42 154 M70 168 L44 172 M186 160 L214 154 M186 168 L212 172', 4)
    + helmet(C.olive, star(128, 92, 12)),

  dog_scout: () => backdrop(C.yellow, C.blue) + shoulders(C.navy, C.yellow)
    + ellipse(70, 130, 18, 34, C.brown) + ellipse(186, 130, 18, 34, C.brown)
    + circle(128, 136, 62, C.tan) + ellipse(128, 166, 30, 22, C.cream) + ellipse(128, 154, 10, 7, INK, ' stroke-width="0"')
    + face(138, { mood: 'open', eyeDrop: 0 }) + beret(C.navy, C.yellow),

  bear_captain: () => backdrop(C.blue, C.cream) + shoulders(C.navy, C.white, star(128, 228, 9))
    + circle(76, 88, 20, C.brown) + circle(180, 88, 20, C.brown) + circle(128, 136, 64, C.brown)
    + ellipse(128, 164, 26, 20, C.tan) + ellipse(128, 154, 10, 7, INK, ' stroke-width="0"')
    + face(140, { mood: 'smile' }) + peakedCap(C.white, C.navy, C.navy, star(128, 116, 8, C.gold), -8),

  panda_ninja: () => backdrop(C.mint, C.white) + shoulders(C.black, C.red)
    + circle(78, 84, 20, C.black) + circle(178, 84, 20, C.black) + circle(128, 136, 64, C.white)
    + ellipse(100, 140, 18, 22, C.black, ' stroke-width="0"') + ellipse(156, 140, 18, 22, C.black, ' stroke-width="0"')
    + circle(102, 140, 8, '#ffffff', noInk) + circle(154, 140, 8, '#ffffff', noInk) + circle(104, 141, 5, INK, noInk) + circle(152, 141, 5, INK, noInk)
    + ellipse(128, 162, 9, 6, INK, ' stroke-width="0"') + line('M120 172 Q128 178 136 172', 4)
    + P('M62 108 C94 96 162 96 194 108 L194 120 C162 110 94 110 62 120 Z', C.red)
    + P('M194 110 L220 96 L214 116 L228 124 L196 120 Z', C.red),

  fox_pilot: () => backdrop(C.sky, C.orange) + shoulders(C.brown, C.cream)
    + P('M70 118 L62 48 L112 86 Z', C.orange) + P('M186 118 L194 48 L144 86 Z', C.orange)
    + P('M64 132 C64 84 192 84 192 132 C192 168 160 192 128 192 C96 192 64 168 64 132 Z', C.orange)
    + P('M84 150 C100 156 112 170 128 192 C144 170 156 156 172 150 C160 186 96 186 84 150 Z', C.cream)
    + face(146, { mood: 'smirk' }) + ellipse(128, 170, 8, 6, INK, ' stroke-width="0"')
    + circle(102, 104, 16, C.sky, ' stroke-width="6"') + circle(154, 104, 16, C.sky, ' stroke-width="6"') + line('M118 104 h20', 6)
    + line('M86 104 C76 96 70 96 64 100 M170 104 C180 96 186 96 192 100', 6),

  owl_general: () => backdrop(C.purple, C.yellow) + shoulders(C.dark, C.gold, star(108, 226, 7) + star(148, 226, 7))
    + P('M66 120 L70 70 L98 96 Z', C.brown) + P('M190 120 L186 70 L158 96 Z', C.brown)
    + circle(128, 138, 64, C.brown) + circle(102, 138, 22, C.cream) + circle(154, 138, 22, C.cream)
    + face(138, { noBlush: true, spread: 26, eyeRx: 10, eyeRy: 11, mood: 'none' })
    + P('M120 156 L128 172 L136 156 Z', C.orange, ' stroke-width="4"')
    + peakedCap(C.dark, C.gold, C.black, star(128, 116, 8), -18),

  frog_ranger: () => backdrop(C.green, C.yellow) + shoulders(C.olive, C.khaki)
    + circle(94, 92, 24, C.green) + circle(162, 92, 24, C.green)
    + P('M58 150 C58 102 198 102 198 150 C198 184 166 196 128 196 C90 196 58 184 58 150 Z', C.green)
    + circle(94, 92, 12, '#ffffff', ' stroke-width="0"') + circle(162, 92, 12, '#ffffff', ' stroke-width="0"')
    + circle(96, 94, 7, INK, noInk) + circle(160, 94, 7, INK, noInk) + circle(98, 90, 3, '#ffffff', noInk) + circle(162, 90, 3, '#ffffff', noInk)
    + line('M100 160 Q128 178 156 160', 5) + ellipse(84, 158, 11, 6, C.blush, ' stroke="none" opacity="0.55"') + ellipse(172, 158, 11, 6, C.blush, ' stroke="none" opacity="0.55"')
    + P('M120 64 C126 44 140 40 150 48 C140 50 132 58 128 70 Z', C.olive, ' stroke-width="5"'),

  carabao: () => backdrop(C.khaki, C.mint) + shoulders(C.red, C.yellow)
    + P('M62 104 C30 98 20 70 34 52 C40 74 58 82 78 86 Z', C.cream) + P('M194 104 C226 98 236 70 222 52 C216 74 198 82 178 86 Z', C.cream)
    + ellipse(66, 120, 16, 10, C.steel) + ellipse(190, 120, 16, 10, C.steel)
    + circle(128, 136, 60, C.steel) + ellipse(128, 168, 34, 22, C.grey)
    + circle(116, 168, 5, INK, noInk) + circle(140, 168, 5, INK, noInk) + face(134, { mood: 'none' })
    + P('M64 96 C96 86 160 86 192 96 L188 110 C158 102 98 102 68 110 Z', C.red),

  tarsier: () => backdrop(C.cream, C.orange) + shoulders(C.khaki, C.olive)
    + ellipse(70, 104, 22, 28, C.tan) + ellipse(186, 104, 22, 28, C.tan) + ellipse(70, 104, 11, 16, C.pink, ' stroke-width="4"') + ellipse(186, 104, 11, 16, C.pink, ' stroke-width="4"')
    + circle(128, 140, 60, C.tan)
    + circle(102, 138, 23, C.yellow) + circle(154, 138, 23, C.yellow) + circle(102, 138, 14, INK, noInk) + circle(154, 138, 14, INK, noInk)
    + circle(107, 132, 5, '#ffffff', noInk) + circle(159, 132, 5, '#ffffff', noInk)
    + P('M124 164 l4 5 l4 -5 z', C.pink, ' stroke-width="3"') + line('M120 174 Q128 179 136 174', 4)
    + P('M98 84 C98 62 158 62 158 84 Z', C.olive) + rect(92, 80, 72, 10, 5, C.olive),

  eagle_ace: () => backdrop(C.blue, C.white) + shoulders(C.brown, C.cream)
    + P('M70 92 L48 66 L86 76 L84 52 L110 76 L128 48 L146 76 L172 52 L170 76 L208 66 L186 92 Z', C.brown)
    + circle(128, 134, 60, C.cream) + P('M78 120 C88 98 112 92 128 98 C144 92 168 98 178 120 C160 112 96 112 78 120 Z', C.brown, ' stroke-width="5"')
    + face(136, { noBlush: true, mood: 'none' })
    + P('M112 152 C116 140 140 140 144 152 C144 170 132 182 128 186 C120 172 112 166 112 152 Z', C.yellow, ' stroke-width="5"')
    + P('M64 200 C90 188 112 196 128 210 C144 196 166 188 192 200 L188 214 C162 206 144 210 128 224 C112 210 94 206 68 214 Z', C.white),

  penguin_sailor: () => backdrop(C.sky, C.white) + shoulders(C.navy, C.white)
    + circle(128, 138, 64, C.black) + P('M80 150 C80 112 176 112 176 150 C176 180 156 194 128 194 C100 194 80 180 80 150 Z', C.white, ' stroke-width="5"')
    + face(146) + P('M116 160 L128 172 L140 160 Z', C.orange, ' stroke-width="4"')
    + P('M70 98 C70 78 186 78 186 98 L186 110 L70 110 Z', C.white) + rect(66, 104, 124, 14, 6, C.navy)
    + line('M170 104 L190 128', 5, C.navy),

  bunny_scout: () => backdrop(C.pink, C.yellow) + shoulders(C.khaki, C.red)
    + P('M90 104 C72 52 80 18 98 20 C114 22 116 64 112 100 Z', C.white) + P('M166 104 C184 52 176 18 158 20 C142 22 140 64 144 100 Z', C.white)
    + P('M96 92 C88 58 92 34 98 34 C106 36 106 66 104 90 Z', C.pink, ' stroke-width="3"') + P('M160 92 C168 58 164 34 158 34 C150 36 150 66 152 90 Z', C.pink, ' stroke-width="3"')
    + circle(128, 140, 60, C.white) + face(146) + P('M123 162 l5 5 l5 -5 z', C.pink, ' stroke-width="3"')
    + P('M58 118 C58 106 198 106 198 118 C190 126 66 126 58 118 Z', C.khaki) + P('M88 112 C92 84 164 84 168 112 Z', C.khaki)
    + P('M124 84 l4 -12 l4 12 z', C.red, ' stroke-width="4"'),
};

function svgFor(id) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${S} ${S}" width="${OUT_PX * 2}" height="${OUT_PX * 2}">${AVATARS[id]()}</svg>`;
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };
  const only = opt('--only') ? opt('--only').split(',') : null;
  const sheet = opt('--sheet');
  const ids = Object.keys(AVATARS).filter((id) => !only || only.includes(id));
  fs.mkdirSync(OUT, { recursive: true });
  const puppeteer = require('puppeteer-core');
  const browser = await puppeteer.launch({ executablePath: BROWSER, headless: 'new' });
  const page = await browser.newPage();
  await page.setViewport({ width: 800, height: 800, deviceScaleFactor: 1 });
  await page.setContent(`<!DOCTYPE html><html><body style="margin:0"><canvas id="c" width="${OUT_PX}" height="${OUT_PX}"></canvas></body></html>`);
  for (const id of ids) {
    const dataUrl = await page.evaluate(async (markup, px) => {
      const blob = new Blob([markup], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      const img = new Image();
      await new Promise((ok, fail) => { img.onload = ok; img.onerror = fail; img.src = url; });
      const canvas = document.getElementById('c');
      const ctx = canvas.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      ctx.clearRect(0, 0, px, px);
      ctx.drawImage(img, 0, 0, px, px);
      URL.revokeObjectURL(url);
      return canvas.toDataURL('image/webp', 0.9);
    }, svgFor(id), OUT_PX);
    fs.writeFileSync(path.join(OUT, `${id}.webp`), Buffer.from(dataUrl.split(',')[1], 'base64'));
    console.log('wrote', id);
  }
  if (sheet) {
    // Contact sheet, cropped round like the game shows them.
    const cell = 160;
    const cols = 6;
    const imgs = ids.map((id) => `<figure style="margin:8px;text-align:center;font:bold 12px sans-serif"><img src="data:image/webp;base64,${fs.readFileSync(path.join(OUT, id + '.webp')).toString('base64')}" width="${cell}" height="${cell}" style="border-radius:50%;border:5px solid #1d1736"><figcaption>${id}</figcaption></figure>`).join('');
    await page.setViewport({ width: cols * (cell + 26), height: 600, deviceScaleFactor: 1 });
    await page.setContent(`<html><body style="margin:0;background:#f1d6b8;display:grid;grid-template-columns:repeat(${cols},${cell + 26}px)">${imgs}</body></html>`);
    await page.screenshot({ path: sheet, fullPage: true });
    console.log('sheet', sheet);
  }
  await browser.close();
}

if (require.main === module) {
  main().catch((e) => { console.error(e); process.exit(1); });
}

module.exports = { AVATARS };
