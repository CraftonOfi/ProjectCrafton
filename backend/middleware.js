const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

// Middleware para verificar autenticación
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Token de acceso requerido en el header Authorization' });
    }
    const token = authHeader.split(' ')[1];
    if (!token || token.length < 10) {
      return res.status(401).json({ error: 'Token malformado o vacío' });
    }
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (err) {
      return res.status(401).json({ error: 'Token inválido o expirado' });
    }
    // Buscar usuario
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isActive: true
      }
    });
    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'Usuario no encontrado o inactivo' });
    }
    req.user = user;
    next();
  } catch (error) {
    console.error('Error en autenticación:', error);
    res.status(500).json({ error: 'Error interno del servidor', details: error.message });
  } finally {
    await prisma.$disconnect();
  }
};

// Middleware para verificar roles específicos
/**
 * Middleware para autorizar roles específicos
 * Uso: authorize('ADMIN', 'SUPER_ADMIN')
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'No autenticado' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'No tienes permisos para realizar esta acción' });
    }
    next();
  };
};

// Middleware específico para administradores
/** Middleware para rutas solo de administradores */
const requireAdmin = authorize('ADMIN', 'SUPER_ADMIN');

/** Middleware para rutas solo de super administradores */
const requireSuperAdmin = authorize('SUPER_ADMIN');

module.exports = {
  authenticate,
  authorize,
  requireAdmin,
  requireSuperAdmin
};