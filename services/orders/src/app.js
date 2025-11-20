const express = require('express');

function createServer() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ service: 'orders', status: 'ok' });
  });

  app.get('/api/orders', (_req, res) => {
    res.json({ data: [{'id': 'ord-1001', 'status': 'PENDING', 'total': 129.99}, {'id': 'ord-1002', 'status': 'SHIPPED', 'total': 54.5}] });
  });

  return app;
}

if (require.main === module) {
  const port = process.env.PORT || 8080;
  createServer().listen(port, () => {
    console.log('[orders] listening on port', port);
  });
}

module.exports = { createServer };
