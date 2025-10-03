const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// Importar rutas
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const resourceRoutes = require('./routes/resources');
const bookingRoutes = require('./routes/bookings');
const paymentRoutes = require('./routes/payments');

const app = express();
const PORT = process.env.PORT || 3001;

// Middlewares de seguridad
app.use(helmet());
app.use(compression());
app.use(morgan('combined'));

// CORS para desarrollo: permite cualquier puerto local de Flutter Web
app.use(cors({
  origin: (origin, callback) => {
    // Permitir cualquier localhost/127.0.0.1 con cualquier puerto
    if (!origin ||
      /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin) ||
      (process.env.CORS_ORIGIN?.split(',').includes(origin))
    ) {
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

// Ruta de salud del servidor
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  });
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
  console.error(err.stack);
  
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

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`🌐 CORS configurado para orígenes locales dinámicos y los definidos en CORS_ORIGIN`);
});