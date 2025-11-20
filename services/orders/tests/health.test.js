const test = require('node:test');
const assert = require('node:assert');
const request = require('supertest');
const { createServer } = require('../src/app');

test('health endpoint returns ok for orders', async () => {
  const app = createServer();
  const res = await request(app).get('/health');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.service, 'orders');
});

test('GET /api/orders returns payload array', async () => {
  const app = createServer();
  const res = await request(app).get('/api/orders');
  assert.strictEqual(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  assert.ok(res.body.data.length > 0);
});
