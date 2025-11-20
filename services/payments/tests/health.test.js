const test = require('node:test');
const assert = require('node:assert');
const request = require('supertest');
const { createServer } = require('../src/app');

test('health endpoint returns ok for payments', async () => {
  const app = createServer();
  const res = await request(app).get('/health');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.service, 'payments');
});

test('GET /api/payments returns payload array', async () => {
  const app = createServer();
  const res = await request(app).get('/api/payments');
  assert.strictEqual(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  assert.ok(res.body.data.length > 0);
});
