const express = require('express');

function createServer() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ service: 'users', status: 'ok' });
  });

  app.get('/api/users', (_req, res) => {
    res.json({ data: [{'id': 'usr-3001', 'name': 'Alice'}, {'id': 'usr-3002', 'name': 'Bob'}] });
  });

  return app;
}

if (require.main === module) {
  const port = process.env.PORT || 8080;
  createServer().listen(port, () => {
    console.log('[users] listening on port', port);
  });
}

module.exports = { createServer };
