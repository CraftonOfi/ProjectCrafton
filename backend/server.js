const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const pino = require('pino');
const pinoHttp = require('pino-http');
const { randomUUID } = require('crypto');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();
const client = require('prom-client');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Importar rutas
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const resourceRoutes = require('./routes/resources');
const bookingRoutes = require('./routes/bookings');
const paymentRoutes = require('./routes/payments');
const healthRoutes = require('./routes/health');
const notificationRoutes = require('./routes/notifications');
const deviceRoutes = require('./routes/devices');
const chatRoutes = require('./routes/chat');
const reportsRoutes = require('./routes/reports');
const { setupBookingCron } = require('./services/bookingCron');

const app = express();
function normalizePinoLevel(lvl) {
  const allowed = new Set(['fatal','error','warn','info','debug','trace','silent']);
  const input = String(lvl || '').toLowerCase();
  if (allowed.has(input)) return input;
  if (['dev','combined','common','short','tiny'].includes(input)) return 'info';
  return 'info';
}
const logger = pino({ level: normalizePinoLevel(process.env.LOG_LEVEL) });
app.use(pinoHttp({
  logger,
  genReqId: (req, res) => req.headers['x-request-id'] || randomUUID(),
  customSuccessMessage: function (req, res) {
    return `REQ OK ${req.method} ${req.url}`;
  },
  customErrorMessage: function (req, res, err) {
    return `REQ ERR ${req.method} ${req.url} - ${err.message}`;
  },
}));
const DESIRED_PORT = parseInt(process.env.PORT, 10) || 3001;

// Middlewares de seguridad
app.use(helmet());
app.use(compression());
const morganFormat = process.env.MORGAN_FORMAT || 'combined';
app.use(morgan(morganFormat));

// CORS para desarrollo: permite cualquier puerto local de Flutter Web
app.use(cors({
  origin: (origin, callback) => {
    const allowList = (process.env.CORS_ORIGIN || '').split(',').filter(Boolean);
    const isLocal = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin || '');
    const isAllowed = allowList.includes(origin || '');
    const isDev = process.env.NODE_ENV !== 'production';
    if (!origin || (isDev && isLocal) || isAllowed) {
      callback(null, true);
    } else {
      callback(new Error('No permitido por CORS'));
    }
  },
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100, // máximo 100 requests por IP
  message: 'Demasiadas solicitudes, intenta de nuevo en 15 minutos'
});
app.use('/api/', limiter);

// Middleware para parsing JSON
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rutas principales
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/resources', resourceRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/health', healthRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/reports', reportsRoutes);

// Ruta de salud del servidor
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  });
});

// Métricas Prometheus
client.collectDefaultMetrics();
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', client.register.contentType);
    res.end(await client.register.metrics());
  } catch (e) {
    res.status(500).end(e.message);
  }
});

// Liveness simple
app.get('/live', (req, res) => res.status(200).send('OK'));

// Readiness: comprueba DB
app.get('/ready', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).send('READY');
  } catch (e) {
    res.status(503).send('NOT_READY');
  }
});

// Ruta raíz
app.get('/', (req, res) => {
  res.json({
    message: 'API Sistema de Alquiler - Espacios y Máquinas',
    version: '1.0.0',
    docs: '/api/docs',
    health: '/health'
  });
});

// Middleware de manejo de errores
app.use((err, req, res, next) => {
  req.log?.error({ err }, 'unhandled_error');
  
  // Error de validación de Prisma
  if (err.code === 'P2002') {
    return res.status(400).json({
      error: 'Este registro ya existe',
      details: err.meta
    });
  }

  // Error de JWT
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Token inválido'
    });
  }

  // Error de validación
  if (err.errors && Array.isArray(err.errors)) {
    return res.status(400).json({
      error: 'Error de validación',
      details: err.errors.map(e => ({
        field: e.param,
        message: e.msg
      }))
    });
  }

  // Error genérico
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' 
      ? 'Error interno del servidor' 
      : err.message
  });
});

// Ruta no encontrada
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada',
    path: req.originalUrl
  });
});

// Iniciar servidor con reintentos si el puerto está en uso
function startServer(port, attemptsLeft = 5) {
  const http = require('http');
  const server = http.createServer(app);

  // Inicializar Socket.IO (chat en tiempo real)
  try {
    const { initRealtime } = require('./realtime');
    initRealtime(server);
  } catch (e) {
    console.warn('Realtime no inicializado:', e.message);
  }

  server.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${port}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV}`);
    console.log(`🔗 Health check: http://localhost:${port}/health`);
    console.log(`🌐 CORS configurado para orígenes locales dinámicos y los definidos en CORS_ORIGIN`);
  });

  server.on('error', (err) => {
    if (err && err.code === 'EADDRINUSE' && attemptsLeft > 0) {
      const nextPort = port + 1;
      console.warn(`⚠️  Puerto ${port} en uso. Reintentando en ${nextPort}... (${attemptsLeft - 1} intentos restantes)`);
      setTimeout(() => startServer(nextPort, attemptsLeft - 1), 200);
    } else {
      console.error('No se pudo iniciar el servidor:', err);
      process.exit(1);
    }
  });
}

startServer(DESIRED_PORT);

// Iniciar cron de reservas
try { setupBookingCron(console); } catch (_) {}