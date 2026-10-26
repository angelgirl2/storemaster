import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const response = (status, body = '') => new Response(body, { status, headers: { 'content-type': 'application/json' } });
const oldFetch = globalThis.fetch;

function durableObjectNamespace(initialMode = 'primary') {
  let mode = initialMode;
  const state = {
    idFromName: name => name,
    get: () => ({
      fetch: async (input, init = {}) => {
        const request = input instanceof Request ? input : new Request(input, init);
        const url = new URL(request.url);
        if (request.method === 'GET' && url.pathname === '/mode') return Response.json({ mode });
        if (request.method === 'POST' && url.pathname === '/mode') {
          const payload = await request.json();
          const previousMode = mode;
          if (payload.mode === 'fallback') mode = 'fallback';
          else if (payload.mode === 'primary') mode = 'primary';
          else return response(400);
          return Response.json({ mode, previousMode });
        }
        return response(404);
      },
    }),
  };
  return { namespace: state, getMode: () => mode };
}
function env(primary, fallback, extra = {}) {
  return { PRIMARY_API_ORIGIN: primary, FALLBACK_API_ORIGIN: fallback,
    FAILOVER_CONTROL_KEY: 'test-control-key-at-least-32-chars-long', ...extra };
}

 test('routes to VPS when Railway health check fails and latches fallback mode', async () => {
  const seen = [];
  const state = durableObjectNamespace();
  globalThis.fetch = async input => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    seen.push(url.toString());
    if (url.hostname === 'primary-unhealthy.example' && url.pathname === '/health/ready') return response(503);
    if (url.hostname === 'fallback-healthy.example' && url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    if (url.hostname === 'fallback-healthy.example' && url.pathname === '/api/v1/public/time') return response(200, '{"status":"fallback"}');
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
      ...env('https://primary-unhealthy.example', 'https://fallback-healthy.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 200);
    assert.equal(result.headers.get('x-storemaster-served-by'), 'fallback');
    assert.match(await result.text(), /fallback/);
    assert.equal(state.getMode(), 'fallback');
    assert.ok(seen.some(x => x.startsWith('https://fallback-healthy.example/api/v1/public/time')));
  } finally { globalThis.fetch = oldFetch; }
});

test('routes a write to fallback when primary health check fails before the request is sent', async () => {
  const writes = [];
  const state = durableObjectNamespace();
  globalThis.fetch = async input => {
    const req = input instanceof Request ? input : new Request(input);
    const url = new URL(req.url);
    if (url.hostname === 'primary-write-offline.example' && url.pathname === '/health/ready') return response(503);
    if (url.hostname === 'fallback-write-healthy.example' && url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    if (req.method === 'POST' && url.pathname === '/api/v1/licenses/activate') {
      writes.push(url.hostname);
      return response(200, '{"success":true}');
    }
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/licenses/activate', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{"licenseId":"x"}',
    }), {
      ...env('https://primary-write-offline.example', 'https://fallback-write-healthy.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 200);
    assert.deepEqual(writes, ['fallback-write-healthy.example']);
    assert.equal(state.getMode(), 'fallback');
  } finally { globalThis.fetch = oldFetch; }
});

test('retries a GET on fallback after primary gateway error and latches fallback mode', async () => {
  const seen = [];
  const state = durableObjectNamespace();
  globalThis.fetch = async input => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    seen.push(url.toString());
    if (url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    if (url.hostname === 'primary-get-failure.example') return response(502, 'gateway error');
    if (url.hostname === 'fallback-get-ok.example') return response(200, '{"result":"ok"}');
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/public/pricing'), {
      ...env('https://primary-get-failure.example', 'https://fallback-get-ok.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 200);
    assert.equal(result.headers.get('x-storemaster-served-by'), 'fallback');
    assert.equal(state.getMode(), 'fallback');
    assert.ok(seen.some(x => x.includes('primary-get-failure.example/api/v1/public/pricing')));
    assert.ok(seen.some(x => x.includes('fallback-get-ok.example/api/v1/public/pricing')));
  } finally { globalThis.fetch = oldFetch; }
});

test('does not replay a write after primary returns a gateway response', async () => {
  const writes = [];
  const state = durableObjectNamespace();
  globalThis.fetch = async input => {
    const req = input instanceof Request ? input : new Request(input);
    const url = new URL(req.url);
    if (url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    if (req.method === 'POST' && url.pathname === '/api/v1/licenses/activate') {
      writes.push(url.hostname);
      return response(503, '{"status":"unavailable"}');
    }
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/licenses/activate', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{"licenseId":"x"}',
    }), {
      ...env('https://primary-write-response.example', 'https://fallback-write-response.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 503);
    assert.deepEqual(writes, ['primary-write-response.example']);
    assert.equal(state.getMode(), 'fallback');
  } finally { globalThis.fetch = oldFetch; }
});

test('does not automatically fail back when Railway recovers after fallback is latched', async () => {
  const state = durableObjectNamespace('fallback');
  const seen = [];
  globalThis.fetch = async input => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    seen.push(url.hostname + url.pathname);
    if (url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    if (url.hostname === 'fallback-sticky.example' && url.pathname === '/api/v1/public/time') return response(200, '{"origin":"vps"}');
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
      ...env('https://primary-recovered.example', 'https://fallback-sticky.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 200);
    assert.equal(result.headers.get('x-storemaster-served-by'), 'fallback');
    assert.ok(seen.every(value => !value.startsWith('primary-recovered.example/api/v1/public/time')));
  } finally { globalThis.fetch = oldFetch; }
});

test('manual failback requires admin key, database reconciliation confirmation and healthy primary', async () => {
  const state = durableObjectNamespace('fallback');
  globalThis.fetch = async input => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    if (url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    return response(200, '{}');
  };
  try {
    const base = {
      ...env('https://primary-reset.example', 'https://fallback-reset.example'), FAILOVER_STATE: state.namespace,
    };
    const unauthorized = await worker.fetch(new Request('https://api.test.example/__ops/failover/reset-primary', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{"databaseReconciled":true}',
    }), base);
    assert.equal(unauthorized.status, 401);

    const notConfirmed = await worker.fetch(new Request('https://api.test.example/__ops/failover/reset-primary', {
      method: 'POST', headers: { 'content-type': 'application/json', 'x-failover-control-key': base.FAILOVER_CONTROL_KEY }, body: '{"databaseReconciled":false}',
    }), base);
    assert.equal(notConfirmed.status, 400);
    assert.equal(state.getMode(), 'fallback');

    const reset = await worker.fetch(new Request('https://api.test.example/__ops/failover/reset-primary', {
      method: 'POST', headers: { 'content-type': 'application/json', 'x-failover-control-key': base.FAILOVER_CONTROL_KEY }, body: '{"databaseReconciled":true}',
    }), base);
    assert.equal(reset.status, 200);
    assert.equal(state.getMode(), 'primary');
  } finally { globalThis.fetch = oldFetch; }
});


test('rejects HTTP origins and missing failover controls before sending user traffic', async () => {
  const state = durableObjectNamespace();
  const httpOrigin = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
    ...env('http://insecure-origin.example', 'https://fallback-secure.example'), FAILOVER_STATE: state.namespace,
  });
  assert.equal(httpOrigin.status, 500);
  assert.match(await httpOrigin.text(), /configuration_error/);

  const originWithPath = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
    ...env('https://primary-secure.example/api', 'https://fallback-secure.example'), FAILOVER_STATE: state.namespace,
  });
  assert.equal(originWithPath.status, 500);
  assert.match(await originWithPath.text(), /configuration_error/);

  const missingSecret = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
    PRIMARY_API_ORIGIN: 'https://primary-secure.example',
    FALLBACK_API_ORIGIN: 'https://fallback-secure.example',
    FAILOVER_STATE: state.namespace,
  });
  assert.equal(missingSecret.status, 500);
  assert.match(await missingSecret.text(), /FAILOVER_CONTROL_KEY/);
});

test('does not automatically fail back to a healthy Railway origin if VPS is unhealthy after failover', async () => {
  const state = durableObjectNamespace('fallback');
  const forwarded = [];
  globalThis.fetch = async input => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    forwarded.push(url.hostname + url.pathname);
    if (url.hostname === 'fallback-down.example' && url.pathname === '/health/ready') return response(503);
    if (url.hostname === 'primary-healthy-but-not-reconciled.example' && url.pathname === '/health/ready') return response(200, '{"status":"ready"}');
    return response(500);
  };
  try {
    const result = await worker.fetch(new Request('https://api.test.example/api/v1/public/time'), {
      ...env('https://primary-healthy-but-not-reconciled.example', 'https://fallback-down.example'), FAILOVER_STATE: state.namespace,
    });
    assert.equal(result.status, 503);
    assert.ok(forwarded.every(value => !value.startsWith('primary-healthy-but-not-reconciled.example/api/v1/public/time')));
  } finally { globalThis.fetch = oldFetch; }
});
