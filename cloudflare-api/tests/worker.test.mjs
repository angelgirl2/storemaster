import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const env = { APP_NAME: 'StoreMaster API test', DB: {}, FILES: {} };

test('health endpoint is live without PostgreSQL/Railway/VPS', async () => {
  const response = await worker.fetch(new Request('https://example.workers.dev/health'), env);
  assert.equal(response.status, 200);
  const value = await response.json();
  assert.equal(value.status, 'ok');
  assert.equal(value.service, 'StoreMaster API test');
});

test('public server time returns epoch milliseconds', async () => {
  const response = await worker.fetch(new Request('https://example.workers.dev/api/v1/public/time'), env);
  assert.equal(response.status, 200);
  const value = await response.json();
  assert.equal(typeof value.serverTime, 'number');
  assert.ok(value.serverTime > 1700000000000);
});

test('unsupported API route returns JSON 404 and CORS headers', async () => {
  const request = new Request('https://example.workers.dev/api/v1/not-real', { headers: { Origin: 'https://client.example' } });
  const response = await worker.fetch(request, env);
  assert.equal(response.status, 404);
  assert.equal(response.headers.get('access-control-allow-origin'), 'https://client.example');
  assert.equal((await response.json()).message, 'مسیر پشتیبانی نمی‌شود: GET /api/v1/not-real');
});
