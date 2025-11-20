const express = require('express');

function createServer() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ service: 'payments', status: 'ok' });
  });

  app.get('/api/payments', (_req, res) => {
    res.json({ data: [{'id': 'pay-2001', 'status': 'CAPTURED', 'amount': 129.99}, {'id': 'pay-2002', 'status': 'DECLINED', 'amount': 18.0}] });
  });

  return app;
}

if (require.main === module) {
  const port = process.env.PORT || 8080;
  createServer().listen(port, () => {
    console.log('[payments] listening on port', port);
  });
}

module.exports = { createServer };
