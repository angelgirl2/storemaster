// Store Master API failover proxy for Cloudflare Workers.
// Railway is preferred until it fails. Once traffic is moved to the VPS,
// failover remains sticky until an operator explicitly confirms recovery.
// Both API origins MUST point at the same authoritative PostgreSQL database
// (or a properly promoted/reconciled replica) before production failover is safe.

const healthCache = new Map();
const HEALTH_TTL_MS = 5000;
const HEALTH_TIMEOUT_MS = 3500;
const SAFE_METHODS = new Set(['GET', 'HEAD']);
const FAILURE_STATUSES = new Set([502, 503, 504]);

function normalizeOrigin(value) {
  const raw = (value || '').trim();
  if (!raw) return '';
  const url = new URL(raw);
  if (url.protocol !== 'https:') throw new Error('API origins must use HTTPS');
  if (url.pathname !== '/' || url.username || url.password || url.search || url.hash) throw new Error('API origin must be a plain HTTPS origin URL');
  return url.origin;
}

async function originHealthy(origin, force = false) {
  if (!origin) return false;
  const cached = healthCache.get(origin);
  if (!force && cached && Date.now() - cached.checkedAt < HEALTH_TTL_MS) return cached.healthy;
  let healthy = false;
  let timeout;
  try {
    const controller = new AbortController();
    timeout = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);
    const response = await fetch(`${origin}/health/ready`, {
      method: 'GET',
      headers: { 'cache-control': 'no-cache' },
      signal: controller.signal,
      cf: { cacheTtl: 0, cacheEverything: false },
    });
    healthy = response.ok;
    await response.arrayBuffer().catch(() => {});
  } catch (_) {
    healthy = false;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
  healthCache.set(origin, { healthy, checkedAt: Date.now() });
  return healthy;
}

function addProxyHeaders(headers, origin, fallback) {
  const out = new Headers(headers);
  out.set('x-storemaster-origin', origin);
  out.set('x-storemaster-failover', fallback ? 'fallback' : 'primary');
  out.delete('host');
  out.delete('content-length');
  return out;
}

async function forward(request, origin, isFallback) {
  const target = new URL(request.url);
  const base = new URL(origin);
  target.protocol = base.protocol;
  target.hostname = base.hostname;
  target.port = base.port;
  target.username = base.username;
  target.password = base.password;
  target.search = new URL(request.url).search;
  const headers = addProxyHeaders(request.headers, origin, isFallback);
  const init = { method: request.method, headers, redirect: 'manual' };
  if (!SAFE_METHODS.has(request.method)) init.body = await request.clone().arrayBuffer();
  return fetch(new Request(target.toString(), init));
}

async function stateRequest(env, path, body) {
  if (!env.FAILOVER_STATE) throw new Error('FAILOVER_STATE durable object binding is missing');
  const id = env.FAILOVER_STATE.idFromName('storemaster-api-global-state');
  const stub = env.FAILOVER_STATE.get(id);
  const response = await stub.fetch(`https://failover-state.internal${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Failover state storage returned ${response.status}`);
  return response.json();
}

async function getMode(env) {
  const result = await stateRequest(env, '/mode');
  return result.mode === 'fallback' ? 'fallback' : 'primary';
}

async function switchToFallback(env, reason) {
  // Durable Object enforces a one-way automatic transition. Recovery is manual.
  return stateRequest(env, '/mode', { mode: 'fallback', reason: String(reason || 'primary_unavailable').slice(0, 200) });
}

async function resetToPrimary(env) {
  return stateRequest(env, '/mode', { mode: 'primary', reason: 'operator_confirmed_recovery' });
}

function controlAuthorized(request, env) {
  const expected = String(env.FAILOVER_CONTROL_KEY || '');
  const supplied = request.headers.get('x-failover-control-key') || '';
  if (expected.length < 32 || supplied.length !== expected.length) return false;
  // Avoid early-return string comparison for the shared control secret.
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) {
    mismatch |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  }
  return mismatch === 0;
}

function upstreamUnavailable(message, status = 503) {
  return Response.json({ status: 'upstream_unavailable', message }, {
    status,
    headers: { 'Retry-After': '10', 'Cache-Control': 'no-store' },
  });
}

async function handleOps(request, env, pathname, primary, fallback) {
  if (!controlAuthorized(request, env)) return Response.json({ message: 'Unauthorized' }, { status: 401 });
  if (pathname === '/__ops/failover/status' && request.method === 'GET') {
    const mode = await getMode(env);
    const [primaryHealthy, fallbackHealthy] = await Promise.all([
      originHealthy(primary, true), originHealthy(fallback, true),
    ]);
    return Response.json({ mode, primaryHealthy, fallbackHealthy, automaticFailback: false });
  }
  if (pathname === '/__ops/failover/reset-primary' && request.method === 'POST') {
    let input;
    try { input = await request.json(); } catch (_) { input = null; }
    if (input?.databaseReconciled !== true) {
      return Response.json({ message: 'Confirm databaseReconciled=true only after the primary data has been reconciled.' }, { status: 400 });
    }
    if (!await originHealthy(primary, true)) {
      return Response.json({ message: 'Primary API is not healthy; failover mode was not reset.' }, { status: 409 });
    }
    await resetToPrimary(env);
    return Response.json({ success: true, mode: 'primary' });
  }
  return Response.json({ message: 'Not found' }, { status: 404 });
}

export default {
  async fetch(request, env) {
    const requestUrl = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization,Content-Type,X-Admin-Key,X-Ticket-Access,X-Failover-Control-Key',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    let primary;
    let fallback;
    try {
      primary = normalizeOrigin(env.PRIMARY_API_ORIGIN);
      fallback = normalizeOrigin(env.FALLBACK_API_ORIGIN);
    } catch (_) {
      return Response.json({ status: 'configuration_error', message: 'Invalid API origin configuration.' }, { status: 500 });
    }
    if (!primary && !fallback) {
      return Response.json({ status: 'configuration_error', message: 'Set PRIMARY_API_ORIGIN or FALLBACK_API_ORIGIN.' }, { status: 500 });
    }
    if (!env.FAILOVER_STATE) {
      return Response.json({ status: 'configuration_error', message: 'FAILOVER_STATE durable object binding is missing.' }, { status: 500 });
    }
    if (String(env.FAILOVER_CONTROL_KEY || '').length < 32) {
      return Response.json({ status: 'configuration_error', message: 'FAILOVER_CONTROL_KEY must be configured as a Worker secret with at least 32 characters.' }, { status: 500 });
    }

    if (requestUrl.pathname.startsWith('/__ops/')) {
      try { return await handleOps(request, env, requestUrl.pathname, primary, fallback); }
      catch (_) { return Response.json({ status: 'state_error', message: 'Failover state is unavailable.' }, { status: 503 }); }
    }

    let mode;
    try { mode = await getMode(env); }
    catch (_) { return Response.json({ status: 'state_error', message: 'Failover state is unavailable.' }, { status: 503 }); }

    // Once automatic failover occurs, NEVER silently return to a recovered Railway
    // instance: it may have stale data. Operator must reconcile the DB and reset mode.
    if (mode === 'fallback') {
      if (!fallback || !await originHealthy(fallback)) {
        return upstreamUnavailable('VPS fallback is unavailable while failover mode is active. Automatic failback is disabled to prevent split-brain data.');
      }
      try {
        const response = await forward(request, fallback, true);
        if (FAILURE_STATUSES.has(response.status)) {
          healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
          return upstreamUnavailable('VPS fallback returned a gateway/unavailable response. Failover remains active.');
        }
        const headers = new Headers(response.headers);
        headers.set('x-storemaster-served-by', 'fallback');
        headers.set('cache-control', 'no-store');
        return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
      } catch (_) {
        healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
        return upstreamUnavailable('VPS fallback request failed. Failover remains active.');
      }
    }

    if (!primary || !await originHealthy(primary)) {
      if (fallback && await originHealthy(fallback)) {
        await switchToFallback(env, 'primary_health_check_failed');
        // Health-check failure happens before forwarding this request, so even writes
        // can safely be sent to fallback. Never replay a write after an actual primary
        // request was attempted (handled in the catch/HTTP-failure paths below).
        try {
          const response = await forward(request, fallback, true);
          if (FAILURE_STATUSES.has(response.status)) {
            healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
            return upstreamUnavailable('VPS fallback returned a gateway/unavailable response. Failover remains active.');
          }
          const headers = new Headers(response.headers);
          headers.set('x-storemaster-served-by', 'fallback');
          headers.set('cache-control', 'no-store');
          return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
        } catch (_) {
          return upstreamUnavailable('Both API origins are unavailable.');
        }
      }
      return upstreamUnavailable('Primary API is unavailable and the VPS fallback is not healthy.');
    }

    try {
      const response = await forward(request, primary, false);
      if (FAILURE_STATUSES.has(response.status)) {
        healthCache.set(primary, { healthy: false, checkedAt: Date.now() });
        if (fallback && await originHealthy(fallback)) {
          await switchToFallback(env, `primary_http_${response.status}`);
          if (SAFE_METHODS.has(request.method)) {
            try {
              const fallbackResponse = await forward(request, fallback, true);
              if (!FAILURE_STATUSES.has(fallbackResponse.status)) {
                const headers = new Headers(fallbackResponse.headers);
                headers.set('x-storemaster-served-by', 'fallback');
                headers.set('cache-control', 'no-store');
                return new Response(fallbackResponse.body, { status: fallbackResponse.status, statusText: fallbackResponse.statusText, headers });
              }
              healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
              return upstreamUnavailable('Both the primary and VPS APIs returned gateway/unavailable responses.');
            } catch (_) {
              healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
              return upstreamUnavailable('The VPS fallback request failed.');
            }
          }
        }
      }
      const headers = new Headers(response.headers);
      headers.set('x-storemaster-served-by', 'primary');
      headers.set('cache-control', 'no-store');
      return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
    } catch (_) {
      healthCache.set(primary, { healthy: false, checkedAt: Date.now() });
      if (fallback && await originHealthy(fallback)) {
        await switchToFallback(env, 'primary_connection_failed');
        if (SAFE_METHODS.has(request.method)) {
          try {
            const response = await forward(request, fallback, true);
            if (FAILURE_STATUSES.has(response.status)) {
              healthCache.set(fallback, { healthy: false, checkedAt: Date.now() });
              return upstreamUnavailable('Both the primary and VPS APIs are unavailable.');
            }
            const headers = new Headers(response.headers);
            headers.set('x-storemaster-served-by', 'fallback');
            headers.set('cache-control', 'no-store');
            return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
          } catch (_) { healthCache.set(fallback, { healthy: false, checkedAt: Date.now() }); }
        }
      }
      return upstreamUnavailable('Primary API request failed. If it was a write, check its result before retrying.');
    }
  },
};

// Cloudflare Durable Object. Its storage is persistent and globally authoritative
// for the failover mode; automatic transitions can only move primary -> fallback.
export class FailoverState {
  constructor(state) { this.state = state; }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== '/mode') return new Response('Not found', { status: 404 });
    if (request.method === 'GET') {
      const mode = await this.state.storage.get('mode') || 'primary';
      const reason = await this.state.storage.get('reason') || 'initial';
      const changedAt = await this.state.storage.get('changedAt') || null;
      return Response.json({ mode, reason, changedAt });
    }
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const input = await request.json().catch(() => ({}));
    const requested = input?.mode;
    const current = await this.state.storage.get('mode') || 'primary';
    if (requested === 'fallback') {
      await this.state.storage.put('mode', 'fallback');
      await this.state.storage.put('reason', String(input.reason || 'primary_unavailable').slice(0, 200));
      await this.state.storage.put('changedAt', new Date().toISOString());
    } else if (requested === 'primary') {
      // The worker calls this only after the authenticated manual reset endpoint.
      await this.state.storage.put('mode', 'primary');
      await this.state.storage.put('reason', String(input.reason || 'operator_reset').slice(0, 200));
      await this.state.storage.put('changedAt', new Date().toISOString());
    } else {
      return Response.json({ message: 'Invalid mode' }, { status: 400 });
    }
    return Response.json({ mode: await this.state.storage.get('mode'), previousMode: current });
  }
}
