const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const BUILD_DIR = path.join(__dirname, 'build', 'web');

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

// Patch flutter_bootstrap.js to use local CanvasKit instead of CDN.
// This ensures the app renders correctly in Replit's proxied iframe environment.
function patchBootstrap() {
  const bootstrapPath = path.join(BUILD_DIR, 'flutter_bootstrap.js');
  if (!fs.existsSync(bootstrapPath)) return;
  let content = fs.readFileSync(bootstrapPath, 'utf8');
  if (content.includes('"useLocalCanvasKit":true')) return; // already patched
  content = content.replace(
    /"engineRevision":"([^"]+)","builds"/,
    '"engineRevision":"$1","useLocalCanvasKit":true,"builds"'
  );
  fs.writeFileSync(bootstrapPath, content, 'utf8');
  console.log('Patched flutter_bootstrap.js to use local CanvasKit.');
}

patchBootstrap();

const server = http.createServer((req, res) => {
  let urlPath = req.url.split('?')[0];
  let filePath = path.join(BUILD_DIR, urlPath === '/' ? 'index.html' : urlPath);

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(BUILD_DIR, 'index.html');
  }

  const ext = path.extname(filePath);
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  const headers = { 'Content-Type': contentType };

  if (ext === '.html' || filePath.endsWith('flutter_service_worker.js')) {
    headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
    headers['Pragma'] = 'no-cache';
    headers['Expires'] = '0';
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, headers);
      res.end('Not found');
      return;
    }
    res.writeHead(200, headers);
    res.end(data);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Serving Flutter web app on http://0.0.0.0:${PORT}`);
});
