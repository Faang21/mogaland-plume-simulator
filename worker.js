/**
 * Mogaland Token Launch – Cloudflare Worker
 *
 * Routes
 *   GET /api/live-markets          – Trending pools on Base via GeckoTerminal
 *   GET /api/new-tokens            – Newest pools on Base via GeckoTerminal
 *   GET /api/token/:address        – Token detail (price, volume, liquidity)
 *   GET /api/ohlcv/:poolAddress    – OHLCV candles for a pool (for live chart)
 *
 * All other paths → 404.
 *
 * NOTE: No private keys are stored or used here. All on-chain transactions
 * (buy/sell swaps) are signed client-side via the user's wallet (MetaMask /
 * WalletConnect). This worker is a CORS proxy only.
 */

const GECKO_BASE = 'https://api.geckoterminal.com/api/v2';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

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
    const tokenMatch = path.match(/^\/api\/token\/(0x[0-9a-fA-F]{40})$/);
    if (tokenMatch) {
      const address = tokenMatch[1].toLowerCase();
      return proxyGecko(`/networks/base/tokens/${address}?include=top_pools`, env);
    }

    // ── GET /api/ohlcv/:poolAddress ───────────────────────────────────────
    // 1-hour OHLCV candles for a Base pool (last 24 data points)
    const ohlcvMatch = path.match(/^\/api\/ohlcv\/(0x[0-9a-fA-F]{40})$/);
    if (ohlcvMatch) {
      const poolAddr = ohlcvMatch[1].toLowerCase();
      const timeframe = url.searchParams.get('timeframe') || 'hour';
      const limit = Math.min(parseInt(url.searchParams.get('limit') || '24', 10), 100);
      return proxyGecko(
        `/networks/base/pools/${poolAddr}/ohlcv/${timeframe}?limit=${limit}&currency=usd`,
        env
      );
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: CORS_HEADERS,
    });
  },
};
