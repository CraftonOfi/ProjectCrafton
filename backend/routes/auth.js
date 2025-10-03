// ...existing code...
// ...existing code...
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
// POST /api/auth/create-demo
router.post('/create-demo', async (req, res) => {
  try {
    const demoEmail = 'demo@example.com';
    const demoPassword = await bcrypt.hash('demo123', 12);

    // Verificar si ya existe
    let user = await prisma.user.findUnique({ where: { email: demoEmail } });

    if (user) {
      // Si existe, lo activamos
      user = await prisma.user.update({
        where: { email: demoEmail },
        data: { isActive: true }
      });
      return res.json({ message: 'Usuario demo activado', user });
    }

    // Si no existe, lo creamos
    user = await prisma.user.create({
      data: {
        email: demoEmail,
        password: demoPassword,
        name: 'Demo User',
        phone: null,
        role: 'CLIENT',
        isActive: true
      },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true
      }
    });
    res.json({ message: 'Usuario demo creado', user });
  } catch (error) {
    res.status(500).json({ error: 'Error creando usuario demo', details: error.message });
  } finally {
    await prisma.$disconnect();
  }
});
const prisma = new PrismaClient();

// Función para generar JWT
const generateToken = (userId, role) => {
  return jwt.sign(
    { userId, role },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
};

// Validaciones
const registerValidation = [
  body('email')
    .isEmail()
    .withMessage('Email inválido')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 6 })
    .withMessage('La contraseña debe tener al menos 6 caracteres'),
  body('name')
    .trim()
    .isLength({ min: 2 })
    .withMessage('El nombre debe tener al menos 2 caracteres'),
  body('phone')
    .optional()
    .isMobilePhone('es-ES')
    .withMessage('Número de teléfono inválido'),
  body('role')
    .optional()
    .isIn(['CLIENT', 'ADMIN', 'SUPER_ADMIN'])
    .withMessage('Rol inválido')
];

const loginValidation = [
  body('email')
    .isEmail()
    .withMessage('Email inválido')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('La contraseña es requerida')
];

// POST /api/auth/register
router.post('/register', registerValidation, async (req, res) => {
  try {
    // Validar entrada
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Error de validación',
        details: errors.array()
      });
    }

  const { email, password, name, phone } = req.body;
  // Permitir rol dinámico pero validado
  let role = req.body.role || "CLIENT";

    // Verificar si el usuario ya existe
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.status(400).json({
        error: 'El usuario ya existe con este email'
      });
    }

    // Hash de la contraseña
    const hashedPassword = await bcrypt.hash(password, 12);

    // Crear usuario
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name,
        phone,
        role
      },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        createdAt: true
      }
    });

    // Generar token
    const token = generateToken(user.id, user.role);

    res.status(201).json({
      message: 'Usuario creado exitosamente',
      user,
      token
    });

  } catch (error) {
    console.error('Error en registro:', error);
    // Prisma error de validación
    if (error.code === 'P2002') {
      return res.status(400).json({
        error: 'Ya existe un usuario con ese email',
        details: error.meta
      });
    }
    res.status(500).json({
      error: 'Error interno del servidor',
      details: error.message
    });
  } finally {
    await prisma.$disconnect();
  }
});

// POST /api/auth/login
router.post('/login', loginValidation, async (req, res) => {
  try {
    // Validar entrada
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Error de validación',
        details: errors.array()
      });
    }

    const { email, password } = req.body;

    // Buscar usuario
    const user = await prisma.user.findUnique({
      where: { email }
    });

    if (!user) {
      return res.status(401).json({
        error: 'Credenciales inválidas'
      });
    }

    // Verificar si el usuario está activo
    if (!user.isActive) {
      return res.status(401).json({
        error: 'Cuenta desactivada. Contacta con soporte.'
      });
    }

    // Verificar contraseña
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Credenciales inválidas'
      });
    }

    // Generar token
    const token = generateToken(user.id, user.role);

    // Respuesta sin contraseña
    const { password: _, ...userWithoutPassword } = user;

    res.json({
      message: 'Login exitoso',
      user: userWithoutPassword,
      token
    });

  } catch (error) {
    console.error('Error en login:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/auth/verify-token
router.post('/verify-token', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        error: 'Token requerido'
      });
    }

    // Verificar token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Buscar usuario actualizado
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true,
        updatedAt: true
      }
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'Token inválido o usuario inactivo'
      });
    }

    res.json({
      valid: true,
      user
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token inválido o expirado'
      });
    }

    console.error('Error verificando token:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/auth/change-password
router.post('/change-password', async (req, res) => {
  try {
    const { token, currentPassword, newPassword } = req.body;

    // Validar token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Validar nueva contraseña
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({
        error: 'La nueva contraseña debe tener al menos 6 caracteres'
      });
    }

    // Buscar usuario
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId }
    });

    if (!user) {
      return res.status(404).json({
        error: 'Usuario no encontrado'
      });
    }

    // Verificar contraseña actual
    const isCurrentPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isCurrentPasswordValid) {
      return res.status(401).json({
        error: 'Contraseña actual incorrecta'
      });
    }

    // Hash de la nueva contraseña
    const hashedNewPassword = await bcrypt.hash(newPassword, 12);

    // Actualizar contraseña
    await prisma.user.update({
      where: { id: user.id },
      data: { password: hashedNewPassword }
    });

    res.json({
      message: 'Contraseña actualizada exitosamente'
    });

  } catch (error) {
    console.error('Error cambiando contraseña:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

module.exports = router;