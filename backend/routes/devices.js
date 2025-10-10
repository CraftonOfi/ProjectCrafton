const express = require('express');
const { authenticate } = require('../middleware');
const { PrismaClient } = require('@prisma/client');
const { sendPushToTokens } = require('../services/pushService');

const router = express.Router();
const prisma = new PrismaClient();

// POST /api/devices/register
// body: { token: string, platform?: 'android'|'ios'|'web' }
router.post('/register', authenticate, async (req, res) => {
  const { token, platform } = req.body || {};
  if (!token || typeof token !== 'string') {
    return res.status(400).json({ error: 'Token inválido' });
  }

  try {
    if (!Object.prototype.hasOwnProperty.call(prisma, 'deviceToken')) {
      return res.status(503).json({ error: 'DeviceToken no disponible. Ejecuta prisma generate en el servidor.' });
    }
    const existing = await prisma.deviceToken.findUnique({ where: { token } });
    let saved;
    if (existing) {
      saved = await prisma.deviceToken.update({
        where: { token },
        data: { userId: req.user.id, isActive: true, platform, lastSeenAt: new Date() },
      });
    } else {
      saved = await prisma.deviceToken.create({
        data: { token, userId: req.user.id, platform, isActive: true, lastSeenAt: new Date() },
      });
    }
    return res.json({ success: true, device: saved });
  } catch (err) {
    console.error('Error registrando token:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/devices/unregister
// body: { token: string }
router.post('/unregister', authenticate, async (req, res) => {
  const { token } = req.body || {};
  if (!token || typeof token !== 'string') {
    return res.status(400).json({ error: 'Token inválido' });
  }
  try {
    if (!Object.prototype.hasOwnProperty.call(prisma, 'deviceToken')) {
      return res.status(503).json({ error: 'DeviceToken no disponible. Ejecuta prisma generate en el servidor.' });
    }
    await prisma.deviceToken.updateMany({
      where: { token, userId: req.user.id },
      data: { isActive: false },
    });
    return res.json({ success: true });
  } catch (err) {
    console.error('Error dando de baja token:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/devices/test-push
// Envia un push de prueba al usuario autenticado
router.post('/test-push', authenticate, async (req, res) => {
  try {
    if (!Object.prototype.hasOwnProperty.call(prisma, 'deviceToken')) {
      return res.status(503).json({ error: 'DeviceToken no disponible. Ejecuta prisma generate en el servidor.' });
    }
    const tokens = await prisma.deviceToken.findMany({
      where: { userId: req.user.id, isActive: true },
      select: { token: true },
    });
    const list = tokens.map((t) => t.token);
    if (list.length === 0) return res.status(400).json({ error: 'No hay tokens activos' });
    const result = await sendPushToTokens(list, {
      title: 'Push de prueba',
      body: 'Tus notificaciones push están listas 🚀',
    }, { type: 'TEST' });
    return res.json({ success: true, result });
  } catch (err) {
    console.error('Error enviando push de prueba:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
