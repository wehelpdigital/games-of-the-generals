// Rasterises the generated logo SVGs (see generate_logo.js) with headless Edge/Chrome, so the
// PNGs match the browser loader exactly.
//
//   node tools/brand/render_png.js [--web <games-of-the-generals-web>/public] [--preview <dir>]
//
// Writes assets/brand/layers/*.png (GameLogo pieces, 1.5× logo space), assets/brand/src/logo.png and
// assets/brand/splash.png (Godot boot splash); with --web also brand/* icons and favicon.ico for
// the website. Needs puppeteer-core on NODE_PATH and Edge (or set BROWSER to a Chrome binary).

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const ROOT = path.resolve(__dirname, '..', '..');
const SRC = path.join(ROOT, 'assets/brand/src');
const BROWSER = process.env.BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const LAYER_SCALE = 1.5;

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };
const webPublic = opt('--web');
const preview = opt('--preview');

function svgSize(svg) {
  const m = svg.match(/viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"/);
  return { w: Number(m[3]), h: Number(m[4]) };
}

async function render(page, svg, width, height, out, background = 'transparent', fit = 1) {
  // The SVG is drawn centred at `fit` of the canvas width (splash images need padding).
  const size = svgSize(svg);
  const drawW = width * fit;
  const drawH = (drawW * size.h) / size.w;
  const sized = svg.replace(/<svg([^>]*?) width="[\d.]+" height="[\d.]+"/, '<svg$1').replace('<svg', `<svg width="${drawW}" height="${drawH}"`);
  await page.setViewport({ width, height, deviceScaleFactor: 1 });
  await page.setContent(`<!DOCTYPE html><html><head><style>html,body{margin:0;width:${width}px;height:${height}px;background:${background};overflow:hidden}`
    + `body{display:flex;align-items:center;justify-content:center}svg{display:block}</style></head><body>${sized}</body></html>`);
  await page.screenshot({ path: out, omitBackground: background === 'transparent', clip: { x: 0, y: 0, width, height } });
  console.log('wrote', path.relative(ROOT, out), `${width}x${height}`);
}

// ICO with PNG payloads (Vista+), enough for favicons.
function writeIco(pngs, out) {
  const header = Buffer.alloc(6 + pngs.length * 16);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(pngs.length, 4);
  let offset = header.length;
  pngs.forEach(({ size, data }, i) => {
    const e = 6 + i * 16;
    header.writeUInt8(size >= 256 ? 0 : size, e); header.writeUInt8(size >= 256 ? 0 : size, e + 1);
    header.writeUInt8(0, e + 2); header.writeUInt8(0, e + 3);
    header.writeUInt16LE(1, e + 4); header.writeUInt16LE(32, e + 6);
    header.writeUInt32LE(data.length, e + 8); header.writeUInt32LE(offset, e + 12);
    offset += data.length;
  });
  fs.writeFileSync(out, Buffer.concat([header, ...pngs.map((p) => p.data)]));
  console.log('wrote', out);
}

(async () => {
  const browser = await puppeteer.launch({ executablePath: BROWSER, headless: 'new' });
  const page = await browser.newPage();
  const read = (f) => fs.readFileSync(path.join(SRC, f), 'utf8');

  const layerOut = path.join(ROOT, 'assets/brand/layers');
  fs.mkdirSync(layerOut, { recursive: true });
  for (const name of ['shield', 'star', 'wordmark', 'ribbon', 'sparkle']) {
    const svg = read(`layers/${name}.svg`);
    const { w, h } = svgSize(svg);
    await render(page, svg, Math.round(w * LAYER_SCALE), Math.round(h * LAYER_SCALE), path.join(layerOut, `${name}.png`));
  }
  const logo = read('logo.svg');
  await render(page, logo, 1000, 720, path.join(SRC, 'logo.png'));
  // Boot splash: square with padding, drawn over the splash colour with "Keep" stretch.
  await render(page, logo, 1536, 1536, path.join(ROOT, 'assets/brand/splash.png'), 'transparent', 0.62);

  if (preview) {
    fs.mkdirSync(preview, { recursive: true });
    await render(page, logo, 1000, 720, path.join(preview, 'logo_dark.png'), 'radial-gradient(#4a2f94,#1d1736)');
    await render(page, logo, 1000, 720, path.join(preview, 'logo_light.png'), '#f1d6b8');
    await render(page, fs.readFileSync(path.join(ROOT, 'icon.svg'), 'utf8'), 256, 256, path.join(preview, 'icon_chrome.png'));
    await render(page, read('emblem.svg'), 400, 400, path.join(preview, 'emblem.png'));
  }

  if (webPublic) {
    const out = path.join(webPublic, 'brand');
    fs.mkdirSync(out, { recursive: true });
    fs.copyFileSync(path.join(SRC, 'logo.svg'), path.join(out, 'logo.svg'));
    fs.copyFileSync(path.join(SRC, 'emblem.svg'), path.join(out, 'emblem.svg'));
    await render(page, logo, 800, 576, path.join(out, 'logo.png'));
    await render(page, logo, 1600, 1152, path.join(out, 'logo@2x.png'));
    const icon = fs.readFileSync(path.join(ROOT, 'icon.svg'), 'utf8');
    for (const size of [180, 192, 512]) {
      await render(page, icon, size, size, path.join(out, `icon-${size}.png`));
    }
    // Social preview card.
    await render(page, logo, 1200, 630, path.join(out, 'og-image.png'), 'radial-gradient(ellipse 120% 90% at 50% 30%, #4a2f94 0%, #2c2166 48%, #1d1736 100%)', 0.62);
    const icoPngs = [];
    for (const size of [16, 32, 48]) {
      const file = path.join(out, `favicon-${size}.png`);
      await render(page, icon, size, size, file);
      icoPngs.push({ size, data: fs.readFileSync(file) });
      fs.unlinkSync(file);
    }
    writeIco(icoPngs, path.join(webPublic, 'favicon.ico'));
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
