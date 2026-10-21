// Stamps a web export with a build version, so browsers and the CDN fetch the new engine files
// after a deploy (see BUILD_STAMP in web/shell.src.html). Run it after every export:
//   node tools/web/stamp_build.js ../games-of-the-generals-web/public/play
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
if (!dir) {
  console.error('usage: node tools/web/stamp_build.js <export dir containing index.html>');
  process.exit(1);
}
const hash = crypto.createHash('sha256');
for (const file of ['index.pck', 'index.wasm', 'index.js']) {
  hash.update(fs.readFileSync(path.join(dir, file)));
}
const stamp = hash.digest('hex').slice(0, 16);
const htmlPath = path.join(dir, 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
if (!html.includes("'__SALPAKAN_BUILD__'")) {
  console.error('index.html has no BUILD_STAMP placeholder (already stamped, or an old shell).');
  process.exit(1);
}
fs.writeFileSync(htmlPath, html.replace("'__SALPAKAN_BUILD__'", `'${stamp}'`));
console.log(`stamped ${htmlPath} with build ${stamp}`);
