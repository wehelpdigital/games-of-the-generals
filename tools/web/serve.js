// Minimal static server for a web export: node tools/web/serve.js <dir> [port]
// <dir> holds play/index.html (the export), so the page loads at http://127.0.0.1:<port>/play/index.html.
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const port = parseInt(process.argv[3] || '8099', 10);
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.json': 'application/json',
};

http.createServer((req, res) => {
  let file = decodeURIComponent(req.url.split('?')[0]);
  if (file.endsWith('/')) file += 'index.html';
  const full = path.join(root, file);
  fs.readFile(full, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end();
      return;
    }
    res.writeHead(200, { 'Content-Type': types[path.extname(full)] || 'application/octet-stream', 'Cache-Control': 'max-age=3600' });
    res.end(req.method === 'HEAD' ? undefined : data);
  });
}).listen(port, () => console.log(`serving ${root} on http://127.0.0.1:${port}/play/index.html`));
