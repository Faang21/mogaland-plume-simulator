#!/usr/bin/env node
/**
 * fetch-logo.js
 * ─────────────
 * Downloads the official Mogaland logo from GitHub CDN and writes it to
 * favicon.png, apple-touch-icon.png, and favicon.svg so the browser tab
 * shows the correct logo instead of the default Porkbun favicon.
 *
 * Run automatically during `npm run build` before files are copied to dist/.
 * If the download fails (network error or HTTP error) the existing favicon
 * files are kept unchanged so the build never breaks.
 */

'use strict';

const https = require('https');
const http  = require('http');
const fs    = require('fs');
const path  = require('path');

const LOGO_URL = 'https://github.com/user-attachments/assets/88e000d5-d27e-4446-973f-8fb18b662a42';

const ROOT        = path.join(__dirname, '..');
const FAVICON_PNG = path.join(ROOT, 'favicon.png');
const FAVICON_SVG = path.join(ROOT, 'favicon.svg');
const TOUCH_ICON  = path.join(ROOT, 'apple-touch-icon.png');

/**
 * Follows up to `maxRedirects` HTTP/HTTPS redirects and resolves with the
 * final response body as a Buffer, or rejects on error / non-2xx status.
 */
function fetchBuffer(url, maxRedirects = 5) {
  return new Promise(function (resolve, reject) {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.get(url, { timeout: 20000 }, function (res) {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        if (maxRedirects <= 0) {
          return reject(new Error('Too many redirects'));
        }
        return resolve(fetchBuffer(res.headers.location, maxRedirects - 1));
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return reject(new Error('HTTP ' + res.statusCode + ' for ' + url));
      }
      const chunks = [];
      res.on('data', function (c) { chunks.push(c); });
      res.on('end',  function ()  { resolve(Buffer.concat(chunks)); });
      res.on('error', reject);
    });
    req.on('error', reject);
    req.on('timeout', function () {
      req.destroy();
      reject(new Error('Request timed out'));
    });
  });
}

/** Returns true when `buf` starts with the 8-byte PNG magic number. */
function isPNG(buf) {
  return buf.length > 8 &&
    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47 &&
    buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a;
}

/**
 * Builds a minimal SVG that embeds the logo PNG as a base64 data URI.
 * This ensures the SVG favicon (which has higher browser priority than PNG)
 * also shows the correct logo.
 */
function buildSVGFromPNG(pngBuf) {
  const b64 = pngBuf.toString('base64');
  return [
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">',
    '  <image href="data:image/png;base64,' + b64 + '"',
    '         x="0" y="0" width="100" height="100"',
    '         preserveAspectRatio="xMidYMid meet"/>',
    '</svg>'
  ].join('\n');
}

(async function main() {
  console.log('[fetch-logo] Downloading Mogaland logo from GitHub CDN…');

  let logoBuf;
  try {
    logoBuf = await fetchBuffer(LOGO_URL);
  } catch (err) {
    console.warn('[fetch-logo] Download failed – keeping existing favicon files.');
    console.warn('[fetch-logo] Error:', err.message);
    return;
  }

  if (!isPNG(logoBuf)) {
    console.warn('[fetch-logo] Downloaded data is not a valid PNG – keeping existing favicon files.');
    return;
  }

  console.log('[fetch-logo] Downloaded', logoBuf.length, 'bytes – writing favicon files…');

  fs.writeFileSync(FAVICON_PNG, logoBuf);
  console.log('[fetch-logo] Wrote', FAVICON_PNG);

  fs.writeFileSync(TOUCH_ICON, logoBuf);
  console.log('[fetch-logo] Wrote', TOUCH_ICON);

  const svgContent = buildSVGFromPNG(logoBuf);
  fs.writeFileSync(FAVICON_SVG, svgContent, 'utf8');
  console.log('[fetch-logo] Wrote', FAVICON_SVG);

  console.log('[fetch-logo] Done.');
})();
