// Browser checks for the web build, in headless Edge/Chrome with the real GPU (puppeteer-core).
//   node tools/web/checks.js flow  <url>   loader time, first-click latency, match start, FPS, stalls
//   node tools/web/checks.js login <url>   title -> Log in -> type -> dashboard (LOGIN_USER / LOGIN_PASS)
//   node tools/web/checks.js sweep <url>   every cosmetic once (?sweep=1) on software GL; counts shader failures
//   node tools/web/checks.js phone <url>   iPhone emulation: tap the login fields, type, log in (LOGIN_USER / LOGIN_PASS)
// <url> is the page, e.g. http://127.0.0.1:8099/play/index.html (serve an export with tools/web/serve.js) or
// the live site. BROWSER overrides the Edge path. Coordinates assume the 1280x720 title and login layouts.
const puppeteer = require('puppeteer-core');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const BROWSER = process.env.BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const GPU = ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist'];

async function open(url, { args = GPU, phone = false } = {}) {
  const browser = await puppeteer.launch({ executablePath: BROWSER, headless: 'new', args });
  const page = await browser.newPage();
  if (phone) {
    await page.emulate(puppeteer.KnownDevices['iPhone 13']);
  } else {
    await page.setViewport({ width: 1280, height: 720 });
  }
  page.perf = [];
  page.on('console', (m) => {
    const t = m.text();
    if (t.startsWith('PERF ')) page.perf.push(JSON.parse(t.slice(5)));
  });
  await page.evaluateOnNewDocument(() => {
    window.__lt = [];
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) window.__lt.push(Math.round(e.duration));
    }).observe({ type: 'longtask', buffered: true });
  });
  const started = Date.now();
  await page.goto(url + (url.includes('?') ? '&' : '?') + 'perf=1', { waitUntil: 'load', timeout: 120000 });
  for (let i = 0; i < 2400; i++) {
    const state = await page.evaluate(() => {
      const status = document.getElementById('status');
      if (!status) return 'gone';
      return status.classList.contains('done') ? 'done' : 'up';
    });
    if (state !== 'up') break;
    await sleep(50);
  }
  page.loaderMs = Date.now() - started;
  return { browser, page };
}

async function waitScreen(page, name, ms = 6000) {
  const started = Date.now();
  while (Date.now() - started < ms) {
    if (await page.evaluate(() => window.__screen) === name) return Date.now() - started;
    await sleep(10);
  }
  return -1;
}

const checks = {
  async flow(url) {
    const { browser, page } = await open(url);
    console.log(`loader lifted after ${page.loaderMs} ms`);
    await page.mouse.click(640, 461); // Play vs AI
    console.log(`first click (Play vs AI) answered in ${await waitScreen(page, 'ai_setup', 5000)} ms`);
    await sleep(800);
    await page.mouse.click(688, 252); // Rookie
    await sleep(1200);
    await page.evaluate(() => window.__lt.splice(0));
    await page.mouse.click(795, 643); // Start
    console.log(`Start -> match in ${await waitScreen(page, 'hud', 10000)} ms`);
    await sleep(2500);
    await page.mouse.click(1178, 273); // Ready!
    await sleep(5000);
    page.perf.length = 0;
    await sleep(6000);
    const rows = page.perf.filter((r) => r.screen === 'hud');
    const stalls = (await page.evaluate(() => window.__lt.splice(0))).filter((d) => d > 200);
    const avg = (k) => (rows.reduce((a, b) => a + b[k], 0) / Math.max(1, rows.length)).toFixed(1);
    console.log(`match: fps=${avg('fps')} worst=${Math.max(0, ...rows.map((r) => r.worst_ms))} ms draws=${avg('draw_calls')}; stalls over 200 ms: ${JSON.stringify(stalls)}`);
    await browser.close();
  },

  async login(url) {
    const { browser, page } = await open(url);
    page.on('response', (r) => {
      if (r.status() >= 400) console.log('[http]', r.status(), r.request().method(), r.url());
    });
    await page.mouse.click(1205, 47); // Log in
    if (await waitScreen(page, 'auth', 3000) < 0) throw new Error('The Log in button did not open the login screen.');
    await page.mouse.click(640, 285);
    await page.keyboard.type(process.env.LOGIN_USER || '', { delay: 25 });
    await page.mouse.click(640, 356);
    await page.keyboard.type(process.env.LOGIN_PASS || '', { delay: 25 });
    await page.mouse.click(640, 431);
    const ms = await waitScreen(page, 'dashboard', 10000);
    console.log(ms >= 0 ? `logged in: dashboard after ${ms} ms` : 'LOGIN FAILED: no dashboard');
    await browser.close();
    if (ms < 0) process.exit(1);
  },

  async sweep(url) {
    const sweepUrl = url + (url.includes('?') ? '&' : '?') + 'sweep=1';
    const { browser, page } = await open(sweepUrl, { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    let last = '';
    const fails = [];
    page.on('console', (m) => {
      const t = m.text();
      if (t.startsWith('SWEEP ')) last = t;
      if (/compilation failed|Failed to compile/i.test(t)) fails.push(`${last} :: ${t.slice(0, 200)}`);
    });
    for (let i = 0; i < 120 && !/done/.test(last); i++) await sleep(5000);
    console.log(`${last || 'the sweep did not finish'}; shader failures: ${fails.length}`);
    fails.slice(0, 10).forEach((f) => console.log(' ', f));
    await browser.close();
    if (fails.length) process.exit(1);
  },

  async phone(url) {
    const { browser, page } = await open(url, { phone: true });
    await page.touchscreen.tap(321, 42); // Log in (iPhone 13 portrait title)
    if (await waitScreen(page, 'auth', 3000) < 0) throw new Error('Log in did not open the login screen.');
    await sleep(500);
    await page.touchscreen.tap(194, 351); // Username field
    await sleep(500);
    const active = await page.evaluate(() => `${document.activeElement.tagName}/${document.activeElement.type}`);
    console.log(`after tapping the username field the focused element is ${active} (an INPUT opens the phone keyboard)`);
    await page.keyboard.type(process.env.LOGIN_USER || '', { delay: 30 });
    await page.touchscreen.tap(194, 416); // Password field
    await sleep(500);
    await page.keyboard.type(process.env.LOGIN_PASS || '', { delay: 30 });
    await page.touchscreen.tap(194, 488); // Log in button
    const ms = await waitScreen(page, 'dashboard', 10000);
    console.log(ms >= 0 ? `phone login: dashboard after ${ms} ms` : 'PHONE LOGIN FAILED: no dashboard');
    await browser.close();
    if (ms < 0) process.exit(1);
  },
};

const [command, url] = process.argv.slice(2);
if (!checks[command] || !url) {
  console.log('usage: node tools/web/checks.js flow|login|sweep|phone <url>');
  process.exit(2);
}
checks[command](url).catch((e) => {
  console.error(e.message);
  process.exit(1);
});
