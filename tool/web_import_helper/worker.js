// Recipe Box "web import helper" — a tiny Cloudflare Worker (free plan) that lets the
// web app (PWA) read recipe pages. Browsers block web apps from reading other sites
// directly; this worker fetches the page and adds the header that allows it.
//
// Setup (about 5 minutes, free):
//  1. Sign up at https://dash.cloudflare.com  → Workers & Pages → Create → "Hello World" worker.
//  2. Name it e.g. "recipe-helper", click Deploy, then "Edit code", paste this whole file, Deploy.
//  3. Copy its address (https://recipe-helper.<you>.workers.dev) into Recipe Box ▸ Settings ▸ Web import helper.
//
// Only your GitHub Pages site may use it (change ALLOWED_ORIGIN if your address differs).
const ALLOWED_ORIGIN = 'https://pacogeist.github.io';

export default {
  async fetch(request) {
    const origin = request.headers.get('Origin') || '';
    const cors = {
      'Access-Control-Allow-Origin': origin === ALLOWED_ORIGIN ? origin : ALLOWED_ORIGIN,
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Vary': 'Origin',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    const target = new URL(request.url).searchParams.get('url');
    if (!target || !/^https?:\/\//i.test(target)) {
      return new Response('Missing ?url=', { status: 400, headers: cors });
    }
    const res = await fetch(target, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      redirect: 'follow',
    });
    const headers = new Headers(cors);
    headers.set('Content-Type', res.headers.get('Content-Type') || 'application/octet-stream');
    return new Response(res.body, { status: res.status, headers });
  },
};
