import express, { Request, Response, NextFunction } from 'express';
import cookieParser from 'cookie-parser';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import crypto from 'crypto';
import path from 'path';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function log(level: 'info' | 'warn' | 'error', event: string, meta: Record<string, unknown> = {}): void {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      service: 'admin',
      event,
      ...meta,
    }),
  );
}

const app = express();
app.use(express.json());
app.use(cookieParser());

app.use((req: Request, res: Response, next: NextFunction): void => {
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

const JWT_SECRET    = requireEnv('ADMIN_JWT_SECRET');
const ADMIN_USER    = requireEnv('ADMIN_USERNAME');
const ADMIN_PASS    = requireEnv('ADMIN_PASSWORD');
const DB_PASS       = requireEnv('DB_PASSWORD');
const DB_HOST       = process.env.DB_HOST          || 'db';
const DB_PORT       = parseInt(process.env.DB_PORT || '5432', 10);
const DB_USER       = process.env.DB_USER          || 'retail_user';
const APP_VERSION   = process.env.APP_VERSION      || 'unknown';
const COOKIE_SECURE = process.env.COOKIE_SECURE    === 'true';
const dbSsl         = process.env.DB_SSLMODE       === 'require' ? { rejectUnauthorized: false } : undefined;

const catalogDb = new Pool({ host: DB_HOST, port: DB_PORT, database: 'catalogdb', user: DB_USER, password: DB_PASS, ssl: dbSsl });
const ordersDb  = new Pool({ host: DB_HOST, port: DB_PORT, database: 'orders',    user: DB_USER, password: DB_PASS, ssl: dbSsl });

// ── Auth middleware ────────────────────────────────────────────────────────

function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const token = req.cookies?.token as string | undefined;
  if (!token) { res.status(401).json({ error: 'Unauthorized' }); return; }
  try {
    jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// ── Auth routes ────────────────────────────────────────────────────────────

app.post('/auth/login', (req: Request, res: Response): void => {
  const { username = '', password = '' } = req.body as { username?: string; password?: string };

  // Pad buffers to same length before timing-safe compare to avoid length leak
  const pad = (a: Buffer, b: Buffer): [Buffer, Buffer] => {
    const len = Math.max(a.length, b.length);
    return [Buffer.concat([a, Buffer.alloc(len - a.length)]),
            Buffer.concat([b, Buffer.alloc(len - b.length)])];
  };

  const [u1, u2] = pad(Buffer.from(username), Buffer.from(ADMIN_USER));
  const [p1, p2] = pad(Buffer.from(password), Buffer.from(ADMIN_PASS));

  const userOk = crypto.timingSafeEqual(u1, u2) && username.length === ADMIN_USER.length;
  const passOk = crypto.timingSafeEqual(p1, p2) && password.length === ADMIN_PASS.length;

  if (!userOk || !passOk) {
    log('warn', 'auth_login_failed', { ip: req.ip, username });
    res.status(401).json({ error: 'Invalid credentials' });
    return;
  }

  const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '8h' });
  res.cookie('token', token, {
    httpOnly: true,
    secure: COOKIE_SECURE,
    sameSite: 'strict',
    maxAge: 8 * 3600 * 1000,
  });
  log('info', 'auth_login_success', { ip: req.ip, username });
  res.json({ ok: true });
});

app.post('/auth/logout', (_req: Request, res: Response): void => {
  res.clearCookie('token');
  res.json({ ok: true });
});

app.get('/auth/me', requireAuth, (_req: Request, res: Response): void => {
  res.json({ ok: true });
});

// ── Products CRUD ──────────────────────────────────────────────────────────

app.get('/admin/api/products', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rows } = await catalogDb.query(`
      SELECT p.id, p.name, p.description, p.price,
             COALESCE(array_agg(pt.tag_name) FILTER (WHERE pt.tag_name IS NOT NULL), '{}') AS tags
      FROM products p
      LEFT JOIN product_tags pt ON p.id = pt.product_id
      GROUP BY p.id
      ORDER BY p.name
    `);
    res.json(rows);
  } catch (err) {
    log('error', 'db_query_error', { path: req.originalUrl, error: (err as Error).message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/admin/api/products', requireAuth, async (req: Request, res: Response): Promise<void> => {
  const { name, description, price } = req.body as { name?: string; description?: string; price?: number };
  if (!name || price === undefined) { res.status(400).json({ error: 'name and price are required' }); return; }
  const id = crypto.randomUUID().replace(/-/g, '').slice(0, 26).toUpperCase();
  try {
    await catalogDb.query(
      'INSERT INTO products (id, name, description, price) VALUES ($1, $2, $3, $4)',
      [id, name.trim(), (description || '').trim(), price],
    );
    res.status(201).json({ id, name, description, price });
  } catch (err) {
    log('error', 'db_query_error', { path: req.originalUrl, error: (err as Error).message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/admin/api/products/:id', requireAuth, async (req: Request, res: Response): Promise<void> => {
  const { name, description, price } = req.body as { name?: string; description?: string; price?: number };
  if (!name || price === undefined) { res.status(400).json({ error: 'name and price are required' }); return; }
  try {
    const { rowCount } = await catalogDb.query(
      'UPDATE products SET name=$1, description=$2, price=$3 WHERE id=$4',
      [name.trim(), (description || '').trim(), price, req.params.id],
    );
    if (!rowCount) { res.status(404).json({ error: 'Product not found' }); return; }
    res.json({ ok: true });
  } catch (err) {
    log('error', 'db_query_error', { path: req.originalUrl, error: (err as Error).message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/admin/api/products/:id', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    await catalogDb.query('DELETE FROM product_tags WHERE product_id = $1', [req.params.id]);
    await catalogDb.query('DELETE FROM products WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (err) {
    log('error', 'db_query_error', { path: req.originalUrl, error: (err as Error).message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Orders (read-only) ─────────────────────────────────────────────────────

app.get('/admin/api/orders', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rows } = await ordersDb.query(`
      SELECT o.id, o.created_at, o.first_name, o.last_name, o.email,
             o.address1, o.city, o.state, o.zip_code,
             COALESCE(
               json_agg(
                 json_build_object(
                   'productId', oi.product_id,
                   'name',      oi.name,
                   'quantity',  oi.quantity,
                   'unitCost',  oi.unit_cost,
                   'totalCost', oi.total_cost
                 )
               ) FILTER (WHERE oi.id IS NOT NULL), '[]'
             ) AS items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      GROUP BY o.id
      ORDER BY o.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    log('error', 'db_query_error', { path: req.originalUrl, error: (err as Error).message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Static + health ────────────────────────────────────────────────────────

app.get('/health', (_req: Request, res: Response): void => {
  res.json({ status: 'ok', service: 'admin', version: APP_VERSION });
});

app.use(express.static(path.join(__dirname, '../public')));
app.get('*', (_req: Request, res: Response): void => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

const port = parseInt(process.env.PORT || '8080', 10);
app.listen(port, () => log('info', 'server_started', { port, version: APP_VERSION }));
