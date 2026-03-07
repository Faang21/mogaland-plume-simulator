/**
 * Mogaland Token Launch – Cloudflare Pages _worker.js (advanced mode)
 *
 * Deployed as dist/_worker.js by the build script, acting as a Cloudflare
 * Pages Function in advanced mode.  API routes are handled here; every other
 * request is forwarded to the Pages static-asset store via env.ASSETS.
 *
 * Routes
 *   GET /api/live-markets          – Trending pools on Base via GeckoTerminal
 *   GET /api/new-tokens            – Newest pools on Base via GeckoTerminal
 *   GET /api/token/:address        – Token detail (price, volume, liquidity)
 *   GET /api/ohlcv/:poolAddress    – OHLCV candles for a pool (for live chart)
 *   POST /api/login-history        – Record a user login event (stored in KV)
 *   GET /api/login-history/:addr   – Retrieve login history for an address
 *
 * All other paths → forwarded to static assets (Pages handles the response).
 *
 * NOTE: No private keys are stored or used here. All on-chain transactions
 * (buy/sell swaps) are signed client-side via the user's wallet (MetaMask /
 * WalletConnect). This worker is a CORS proxy only.
 */

const GECKO_BASE = 'https://api.geckoterminal.com/api/v2';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};
const ETH_ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
const DEFAULT_OHLCV_LIMIT = 24;
const MAX_OHLCV_LIMIT = 100;
// Max login history records stored per address
const MAX_HISTORY_PER_ADDRESS = 50;

/**
 * Fetch a GeckoTerminal endpoint and return a Response with CORS headers.
 * Adds the Accept header required by their API.
 */
async function proxyGecko(path, env) {
  const headers = { Accept: 'application/json;version=20230302' };
  if (env && env.GECKOTERMINAL_API_KEY) {
    headers['Authorization'] = `Bearer ${env.GECKOTERMINAL_API_KEY}`;
  }

  const upstreamRes = await fetch(`${GECKO_BASE}${path}`, { headers });
  if (!upstreamRes.ok) {
    return new Response(
      JSON.stringify({ error: `Upstream error: ${upstreamRes.status}` }),
      { status: upstreamRes.status, headers: CORS_HEADERS }
    );
  }
  const data = await upstreamRes.json();
  return new Response(JSON.stringify(data), { headers: CORS_HEADERS });
}

/**
 * Sanitize a wallet address key for safe KV storage.
 * Only lowercase hex addresses (0x…) or common login identifiers are allowed.
 */
function sanitizeKey(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const trimmed = raw.trim().toLowerCase().substring(0, 200);
  // Allow eth addresses, email-style keys, x-handle keys
  if (/^[a-z0-9@._:\-]{1,200}$/.test(trimmed)) return trimmed;
  return null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Pre-flight CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // ── GET /api/live-markets ──────────────────────────────────────────────
    // Trending pools on Base mainnet (price, volume, liquidity, price change)
    if (path === '/api/live-markets') {
      return proxyGecko('/networks/base/trending_pools?page=1&include=base_token,quote_token', env);
    }

    // ── GET /api/new-tokens ───────────────────────────────────────────────
    // Newest pools on Base mainnet – great for "just launched" feed
    if (path === '/api/new-tokens') {
      return proxyGecko('/networks/base/new_pools?page=1&include=base_token,quote_token', env);
    }

    // ── GET /api/token/:address ───────────────────────────────────────────
    // Token detail by contract address on Base
    const tokenMatch = path.match(/^\/api\/token\/([^/]+)$/);
    if (tokenMatch && ETH_ADDRESS_RE.test(tokenMatch[1])) {
      const address = tokenMatch[1].toLowerCase();
      return proxyGecko(`/networks/base/tokens/${address}?include=top_pools`, env);
    }

    // ── GET /api/ohlcv/:poolAddress ───────────────────────────────────────
    // 1-hour OHLCV candles for a Base pool (last 24 data points)
    const ohlcvMatch = path.match(/^\/api\/ohlcv\/([^/]+)$/);
    if (ohlcvMatch && ETH_ADDRESS_RE.test(ohlcvMatch[1])) {
      const poolAddr = ohlcvMatch[1].toLowerCase();
      const timeframe = url.searchParams.get('timeframe') || 'hour';
      const limitParam = parseInt(url.searchParams.get('limit') || String(DEFAULT_OHLCV_LIMIT), 10);
      const limit = Math.min(isNaN(limitParam) ? DEFAULT_OHLCV_LIMIT : limitParam, MAX_OHLCV_LIMIT);
      return proxyGecko(
        `/networks/base/pools/${poolAddr}/ohlcv/${timeframe}?limit=${limit}&currency=usd`,
        env
      );
    }

    // ── POST /api/login-history ───────────────────────────────────────────
    // Record a login event.  Body: { address, method, timestamp, userAgent, network }
    // Stored in KV under key "login:<sanitized_address>" as a JSON array.
    if (path === '/api/login-history' && request.method === 'POST') {
      if (!env.LOGIN_HISTORY) {
        return new Response(JSON.stringify({ ok: false, error: 'KV not configured' }), { status: 503, headers: CORS_HEADERS });
      }
      let body;
      try {
        body = await request.json();
      } catch {
        return new Response(JSON.stringify({ ok: false, error: 'Invalid JSON' }), { status: 400, headers: CORS_HEADERS });
      }

      const rawAddr = body.address || 'anonymous';
      const key = sanitizeKey(rawAddr) ? `login:${sanitizeKey(rawAddr)}` : 'login:anonymous';
      const method = typeof body.method === 'string' ? body.method.substring(0, 50) : 'unknown';
      const network = typeof body.network === 'string' ? body.network.substring(0, 50) : 'unknown';
      const userAgent = typeof body.userAgent === 'string' ? body.userAgent.substring(0, 200) : '';
      const timestamp = typeof body.timestamp === 'string' ? body.timestamp.substring(0, 30) : new Date().toISOString();

      const record = { method, network, timestamp, userAgent };

      // Load existing history, prepend new record, trim to max length
      let history = [];
      const existing = await env.LOGIN_HISTORY.get(key);
      if (existing) {
        try { history = JSON.parse(existing); } catch { history = []; }
        if (!Array.isArray(history)) history = [];
      }
      history.unshift(record);
      if (history.length > MAX_HISTORY_PER_ADDRESS) history = history.slice(0, MAX_HISTORY_PER_ADDRESS);

      await env.LOGIN_HISTORY.put(key, JSON.stringify(history));

      return new Response(JSON.stringify({ ok: true }), { headers: CORS_HEADERS });
    }

    // ── GET /api/login-history/:address ──────────────────────────────────
    // Retrieve stored login history for an address (most recent first).
    const loginHistoryMatch = path.match(/^\/api\/login-history\/([^/]+)$/);
    if (loginHistoryMatch && request.method === 'GET') {
      if (!env.LOGIN_HISTORY) {
        return new Response(JSON.stringify({ ok: false, error: 'KV not configured' }), { status: 503, headers: CORS_HEADERS });
      }
      const rawAddr = loginHistoryMatch[1];
      const safeAddr = sanitizeKey(rawAddr);
      if (!safeAddr) {
        return new Response(JSON.stringify({ ok: false, error: 'Invalid address' }), { status: 400, headers: CORS_HEADERS });
      }
      const stored = await env.LOGIN_HISTORY.get(`login:${safeAddr}`);
      let history = [];
      if (stored) {
        try { history = JSON.parse(stored); } catch { history = []; }
        if (!Array.isArray(history)) history = [];
      }
      return new Response(JSON.stringify({ ok: true, address: safeAddr, history }), { headers: CORS_HEADERS });
    }

    // ── All other requests → static assets ───────────────────────────────
    // In Pages advanced mode env.ASSETS serves the static files from dist/
    return env.ASSETS.fetch(request);
  },
};
