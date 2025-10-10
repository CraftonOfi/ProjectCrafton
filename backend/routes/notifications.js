const express = require('express');
const { authenticate } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// GET /api/notifications - Lista notificaciones del usuario autenticado
// Query:
//  - unreadOnly=true|false
//  - page, limit
router.get('/', authenticate, async (req, res) => {
  try {
    const { unreadOnly, page = 1, limit = 20 } = req.query;
    const where = {
      userId: req.user.id,
      ...(String(unreadOnly).toLowerCase() === 'true' ? { read: false } : {}),
    };

    const [rows, total] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.notification.count({ where }),
    ]);

    const notifications = rows.map((n) => ({ ...n }));
    res.json({
      notifications,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error listando notificaciones:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/notifications/:id/read - Marcar una notificación como leída
router.put('/:id/read', authenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const notif = await prisma.notification.findUnique({ where: { id } });
    if (!notif || notif.userId !== req.user.id) {
      return res.status(404).json({ error: 'Notificación no encontrada' });
    }
    const updated = await prisma.notification.update({
      where: { id },
      data: { read: true },
    });
    res.json({ message: 'Notificación marcada como leída', notification: updated });
  } catch (error) {
    console.error('Error marcando notificación:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/notifications/read-all - Marcar todas como leídas
router.put('/read-all', authenticate, async (req, res) => {
  try {
    const result = await prisma.notification.updateMany({
      where: { userId: req.user.id, read: false },
      data: { read: true },
    });
    res.json({ message: 'Notificaciones marcadas como leídas', updated: result.count });
  } catch (error) {
    console.error('Error marcando todas las notificaciones:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
