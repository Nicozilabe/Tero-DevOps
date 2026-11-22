import express from 'express';
import path from 'path';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();

const APP_VERSION  = process.env.APP_VERSION || 'unknown';
const CATALOG_URL  = process.env.RETAIL_UI_ENDPOINTS_CATALOG  || 'http://catalog:8080';
const CARTS_URL    = process.env.RETAIL_UI_ENDPOINTS_CARTS    || 'http://carts:8080';
const CHECKOUT_URL = process.env.RETAIL_UI_ENDPOINTS_CHECKOUT || 'http://checkout:8080';
const ORDERS_URL   = process.env.RETAIL_UI_ENDPOINTS_ORDERS   || 'http://orders:8080';

function log(level: 'info' | 'warn' | 'error', event: string, meta: Record<string, unknown> = {}): void {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      service: 'ui',
      event,
      ...meta,
    }),
  );
}

app.use((req, res, next) => {
  if (req.path === '/health') {
    next();
    return;
  }
  const startAt = process.hrtime();
  res.on('finish', () => {
    const diff = process.hrtime(startAt);
    const durationMs = diff[0] * 1e3 + diff[1] * 1e-6;
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
    log(level, 'http_request', {
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      duration_ms: Number(durationMs.toFixed(2)),
    });
  });
  next();
});

// Express strips the mount path before the proxy sees it.
// pathRewrite re-adds the service prefix, stripping trailing slash on bare paths.
const rewrite = (prefix: string) => (p: string) => prefix + (p === '/' ? '' : p);

app.use('/api/catalog',  createProxyMiddleware({ target: CATALOG_URL,  changeOrigin: true, pathRewrite: rewrite('/catalog') }));
app.use('/api/carts',    createProxyMiddleware({ target: CARTS_URL,    changeOrigin: true, pathRewrite: rewrite('/carts') }));
app.use('/api/checkout', createProxyMiddleware({ target: CHECKOUT_URL, changeOrigin: true, pathRewrite: rewrite('/checkout') }));
app.use('/api/orders',   createProxyMiddleware({ target: ORDERS_URL,   changeOrigin: true, pathRewrite: rewrite('/orders') }));

app.use(express.static(path.join(__dirname, '../public')));

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'ui', version: APP_VERSION }));

const port = parseInt(process.env.PORT || '8080', 10);
app.listen(port, () => log('info', 'server_started', { port, version: APP_VERSION }));
