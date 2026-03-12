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
 *   GET /api/user-data/:address    – Load persisted user data from KV
 *   PUT /api/user-data/:address    – Save persisted user data to KV
 *
 * All other paths → forwarded to static assets (Pages handles the response).
 *
 * NOTE: No private keys are stored or used here. All on-chain transactions
 * (buy/sell swaps) are signed client-side via the user's wallet (MetaMask /
 * WalletConnect). This worker is a CORS proxy only.
 *
 * KV Namespaces (bind via Cloudflare dashboard or wrangler.toml):
 *   LOGIN_HISTORY_KV – login history records
 *   USER_DATA_KV     – per-user portfolio / staking data
 */

const GECKO_BASE          = 'https://api.geckoterminal.com/api/v2';
const TWITTER_OAUTH_BASE  = 'https://api.twitter.com/2/oauth2'; // token exchange endpoint
const TWITTER_API_BASE    = 'https://api.twitter.com/2';        // v2 REST endpoints
const TWITTER_CLIENT_ID   = 'OE85S0o0eDlLQ2lRWlIycEkyOGM6MTpjaQ';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};
const ETH_ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
const DEFAULT_OHLCV_LIMIT = 24;
const MAX_OHLCV_LIMIT = 100;
// User-data KV entry TTL: 180 days
const USER_DATA_TTL = 60 * 60 * 24 * 180;
// Maximum allowed size for a user-data payload (256 KB)
const USER_DATA_MAX_BYTES = 256 * 1024;
// Maximum login-history method string length
const METHOD_MAX_LEN = 50;
// Cache-Control TTLs for proxied market data (seconds)
const CACHE_TTL_MARKETS = 60;   // trending / new pools: refresh every 60 s
const CACHE_TTL_TOKEN   = 120;  // token detail: refresh every 2 min
const CACHE_TTL_OHLCV   = 30;   // OHLCV candles: refresh every 30 s

/**
 * Fetch a GeckoTerminal endpoint and return a Response with CORS headers.
 * Adds the Accept header required by their API.
 * @param {string} path  GeckoTerminal API path
 * @param {object} env   Worker env bindings
 * @param {number} [cacheTtl=60]  Cache-Control max-age in seconds
 */
async function proxyGecko(path, env, cacheTtl = CACHE_TTL_MARKETS) {
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
  return new Response(JSON.stringify(data), {
    headers: {
      ...CORS_HEADERS,
      'Cache-Control': `public, max-age=${cacheTtl}, s-maxage=${cacheTtl}`,
    },
  });
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
      return proxyGecko('/networks/base/trending_pools?page=1&include=base_token,quote_token', env, CACHE_TTL_MARKETS);
    }

    // ── GET /api/new-tokens ───────────────────────────────────────────────
    // Newest pools on Base mainnet – great for "just launched" feed
    if (path === '/api/new-tokens') {
      return proxyGecko('/networks/base/new_pools?page=1&include=base_token,quote_token', env, CACHE_TTL_MARKETS);
    }

    // ── GET /api/token/:address ───────────────────────────────────────────
    // Token detail by contract address on Base
    const tokenMatch = path.match(/^\/api\/token\/([^/]+)$/);
    if (tokenMatch && ETH_ADDRESS_RE.test(tokenMatch[1])) {
      const address = tokenMatch[1].toLowerCase();
      return proxyGecko(`/networks/base/tokens/${address}?include=top_pools`, env, CACHE_TTL_TOKEN);
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
        env,
        CACHE_TTL_OHLCV,
      );
    }

    // ── POST /api/login-history ───────────────────────────────────────────
    // Records a login event. Uses LOGIN_HISTORY_KV when the KV namespace is
    // bound via the Cloudflare dashboard; gracefully no-ops when it is not.
    // This avoids the need for a [[kv_namespaces]] placeholder in wrangler.toml.
    if (path === '/api/login-history' && request.method === 'POST') {
      try {
        const body = await request.json();
        const { address, method } = body || {};
        if (!method || typeof method !== 'string') {
          return new Response(JSON.stringify({ error: 'method is required' }), { status: 400, headers: CORS_HEADERS });
        }
        // Sanitise address: must be a 0x hex string if provided
        const safeAddress = ETH_ADDRESS_RE.test(address) ? address.toLowerCase() : null;
        const entry = { method: String(method).slice(0, METHOD_MAX_LEN), address: safeAddress, ts: Date.now() };

        if (env.LOGIN_HISTORY_KV) {
          // KV key per wallet address (or 'email'/'x' for non-wallet logins)
          const kvKey = safeAddress || `method:${entry.method.toLowerCase()}`;
          const existing = await env.LOGIN_HISTORY_KV.get(kvKey, { type: 'json' });
          const history = Array.isArray(existing) ? existing : [];
          history.unshift(entry);
          await env.LOGIN_HISTORY_KV.put(kvKey, JSON.stringify(history.slice(0, 20)), { expirationTtl: 60 * 60 * 24 * 90 });
        }

        return new Response(JSON.stringify({ ok: true }), { headers: CORS_HEADERS });
      } catch (err) {
        console.error('[login-history] Error:', err);
        return new Response(JSON.stringify({ error: 'Bad request' }), { status: 400, headers: CORS_HEADERS });
      }
    }

    // ── GET /api/user-data/:address ───────────────────────────────────────
    // Load persisted user portfolio / staking data from KV.
    // Falls back gracefully when USER_DATA_KV namespace is not configured.
    const userDataMatch = path.match(/^\/api\/user-data\/([^/]+)$/);
    if (userDataMatch && request.method === 'GET') {
      const rawAddr = userDataMatch[1];
      // Accept real 0x addresses and pseudo-addresses (40+ hex chars)
      if (!ETH_ADDRESS_RE.test(rawAddr) && !/^0x[0-9a-f]{40,}$/i.test(rawAddr)) {
        return new Response(JSON.stringify({ error: 'Invalid address' }), { status: 400, headers: CORS_HEADERS });
      }
      const addr = rawAddr.toLowerCase();
      if (!env.USER_DATA_KV) {
        return new Response(JSON.stringify({ ok: true, data: null, kvUnavailable: true }), { headers: CORS_HEADERS });
      }
      try {
        const stored = await env.USER_DATA_KV.get(addr, { type: 'json' });
        return new Response(JSON.stringify({ ok: true, data: stored || null }), { headers: CORS_HEADERS });
      } catch (err) {
        console.error('[user-data GET] KV error:', err);
        return new Response(JSON.stringify({ error: 'KV read failed' }), { status: 500, headers: CORS_HEADERS });
      }
    }

    // ── PUT /api/user-data/:address ───────────────────────────────────────
    // Save persisted user portfolio / staking data to KV.
    // Falls back gracefully when USER_DATA_KV namespace is not configured.
    if (userDataMatch && request.method === 'PUT') {
      const rawAddr = userDataMatch[1];
      if (!ETH_ADDRESS_RE.test(rawAddr) && !/^0x[0-9a-f]{40,}$/i.test(rawAddr)) {
        return new Response(JSON.stringify({ error: 'Invalid address' }), { status: 400, headers: CORS_HEADERS });
      }
      const addr = rawAddr.toLowerCase();
      if (!env.USER_DATA_KV) {
        return new Response(JSON.stringify({ ok: true, kvUnavailable: true }), { headers: CORS_HEADERS });
      }
      try {
        const body = await request.text();
        if (body.length > USER_DATA_MAX_BYTES) {
          return new Response(JSON.stringify({ error: 'Payload too large' }), { status: 413, headers: CORS_HEADERS });
        }
        // Validate JSON before storing
        JSON.parse(body);
        await env.USER_DATA_KV.put(addr, body, { expirationTtl: USER_DATA_TTL });
        return new Response(JSON.stringify({ ok: true }), { headers: CORS_HEADERS });
      } catch (err) {
        console.error('[user-data PUT] Error:', err);
        return new Response(JSON.stringify({ error: 'Save failed' }), { status: 500, headers: CORS_HEADERS });
      }
    }

    // ── POST /api/twitter/token ───────────────────────────────────────────
    // Proxy Twitter OAuth 2.0 PKCE token exchange.
    // Body: { code, code_verifier, redirect_uri }
    if (path === '/api/twitter/token' && request.method === 'POST') {
      try {
        const body = await request.json();
        const { code, code_verifier, redirect_uri } = body || {};
        if (!code || !code_verifier || !redirect_uri) {
          return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400, headers: CORS_HEADERS });
        }
        const params = new URLSearchParams({
          grant_type: 'authorization_code',
          code: String(code),
          redirect_uri: String(redirect_uri),
          code_verifier: String(code_verifier),
          client_id: TWITTER_CLIENT_ID,
        });
        const twitterRes = await fetch(`${TWITTER_OAUTH_BASE}/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: params.toString(),
        });
        const raw = await twitterRes.json();
        // Only forward the fields the client needs; never relay raw error details
        const data = twitterRes.ok
          ? { access_token: raw.access_token, token_type: raw.token_type, scope: raw.scope }
          : { error: raw.error || 'token_exchange_error', error_description: raw.error_description || 'Token exchange failed' };
        return new Response(JSON.stringify(data), { status: twitterRes.status, headers: CORS_HEADERS });
      } catch (err) {
        console.error('[twitter/token] Error:', err);
        return new Response(JSON.stringify({ error: 'Token exchange failed' }), { status: 500, headers: CORS_HEADERS });
      }
    }

    // ── GET /api/twitter/me ───────────────────────────────────────────────
    // Proxy Twitter v2 /users/me with a Bearer token from the client.
    if (path === '/api/twitter/me' && request.method === 'GET') {
      const auth = request.headers.get('Authorization');
      if (!auth || !auth.startsWith('Bearer ')) {
        return new Response(JSON.stringify({ error: 'Missing Bearer token' }), { status: 401, headers: CORS_HEADERS });
      }
      try {
        const twitterRes = await fetch(
          `${TWITTER_API_BASE}/users/me?user.fields=name,username,profile_image_url`,
          { headers: { Authorization: auth } },
        );
        const raw = await twitterRes.json();
        // Only forward the public user fields the client needs
        const data = twitterRes.ok && raw.data
          ? { data: { id: raw.data.id, name: raw.data.name, username: raw.data.username, profile_image_url: raw.data.profile_image_url } }
          : { error: raw.error || 'user_lookup_error' };
        return new Response(JSON.stringify(data), { status: twitterRes.status, headers: CORS_HEADERS });
      } catch (err) {
        console.error('[twitter/me] Error:', err);
        return new Response(JSON.stringify({ error: 'User lookup failed' }), { status: 500, headers: CORS_HEADERS });
      }
    }

    // ── All other requests → static assets ───────────────────────────────
    // In Pages advanced mode env.ASSETS serves the static files from dist/
    return env.ASSETS.fetch(request);
  },
};
