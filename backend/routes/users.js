const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const sharp = require('sharp');

// GET /api/users/profile - Obtener perfil del usuario autenticado
router.get('/profile', authenticate, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        createdAt: true,
        updatedAt: true,
        bookings: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            resource: {
              select: { name: true, type: true }
            },
            payments: true
          }
        }
      }
    });

    res.json({
      user,
      stats: {
        totalBookings: user.bookings.length
      }
    });

  } catch (error) {
    console.error('Error obteniendo perfil:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// PUT /api/users/profile - Actualizar perfil
router.put('/profile', authenticate, async (req, res) => {
  try {
    const { name, phone } = req.body;

    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: { name, phone },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        updatedAt: true
      }
    });

    res.json({
      message: 'Perfil actualizado exitosamente',
      user: updatedUser
    });

  } catch (error) {
    console.error('Error actualizando perfil:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/users/avatar - Subir avatar seguro (re-encode)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 3 * 1024 * 1024 }, // 3MB
});

router.post('/avatar', authenticate, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Archivo requerido' });

    const uploadsDir = path.join(process.cwd(), 'uploads');
    if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

    // Re-encode con sharp para eliminar metadatos y payloads
    const outFile = path.join(uploadsDir, `avatar_${req.user.id}.jpg`);
    await sharp(req.file.buffer)
      .rotate() // auto-orient
      .resize(512, 512, { fit: 'cover' })
      .jpeg({ quality: 82, chromaSubsampling: '4:2:0' })
      .toFile(outFile);

    // Guardar URL relativa en el usuario si existe el campo
    let updatedUser = null;
    try {
      updatedUser = await prisma.user.update({
        where: { id: req.user.id },
        data: { avatarUrl: `/uploads/${path.basename(outFile)}` },
        select: { id: true, email: true, name: true, phone: true, role: true, updatedAt: true }
      });
    } catch (_) {
      // Si avatarUrl no existe en el esquema, devolvemos solo la ruta
    }

    res.json({
      message: 'Avatar actualizado',
      avatarUrl: `/uploads/${path.basename(outFile)}`,
      ...(updatedUser ? { user: updatedUser } : {}),
    });
  } catch (e) {
    console.error('Error subiendo avatar:', e);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/users - Listar usuarios (solo admin)
router.get('/', authenticate, requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 10, search } = req.query;

    const where = search ? {
      OR: [
        { name: { contains: search } },
        { email: { contains: search } }
      ]
    } : {};

    const users = await prisma.user.findMany({
      where,
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true,
        _count: {
          bookings: true
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * parseInt(limit),
      take: parseInt(limit)
    });

    const total = await prisma.user.count({ where });

    res.json({
      users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Error listando usuarios:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

module.exports = router;