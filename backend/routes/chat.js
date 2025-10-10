const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');
const { body, validationResult } = require('express-validator');
const { sendPushToTokens } = require('../services/pushService');
const { emitToUser } = require('../realtime');

const router = express.Router();
const prisma = new PrismaClient();

// Helper: send in-app notif + push to recipient
async function notifyMessage(toUserId, fromUserName, preview) {
  try {
    const title = `Nuevo mensaje de ${fromUserName}`;
    const message = preview;
    await prisma.notification.create({ data: { userId: toUserId, title, message, type: 'CHAT_MESSAGE' } });
    if (Object.prototype.hasOwnProperty.call(prisma, 'deviceToken')) {
      const tokens = await prisma.deviceToken.findMany({ where: { userId: toUserId, isActive: true }, select: { token: true } });
      const list = tokens.map(t => t.token);
      if (list.length) sendPushToTokens(list, { title, body: message }, { type: 'CHAT_MESSAGE' }).catch(() => {});
    }
  } catch (e) {
    console.warn('[chat.notifyMessage] failed', e.message);
  }
}

// GET /api/chat/threads - list conversation threads
router.get('/threads', authenticate, async (req, res) => {
  try {
    const me = req.user;
    // For admins: list distinct users who have messaged or been messaged
    // For clients: return single thread with any admin (if exists) based on last message counterpart
    const isAdmin = ['ADMIN', 'SUPER_ADMIN'].includes(me.role);

    if (isAdmin) {
      // Group by counterpart user (parametrizado)
      const rows = await prisma.$queryRaw`
        SELECT u.id, u.name, u.email,
               MAX(m.createdAt) as lastMessageAt,
               SUM(CASE WHEN m.toUserId = ${me.id} AND m.read = 0 THEN 1 ELSE 0 END) as unread
        FROM messages m
        JOIN users u ON (CASE WHEN m.fromUserId = ${me.id} THEN m.toUserId ELSE m.fromUserId END) = u.id
        WHERE (m.fromUserId = ${me.id} OR m.toUserId = ${me.id})
        GROUP BY u.id, u.name, u.email
        ORDER BY (lastMessageAt IS NULL), lastMessageAt DESC;
      `;
      return res.json({ threads: rows });
    }

    // Client: find last counterpart admin
    const last = await prisma.message.findFirst({
      where: {
        OR: [ { fromUserId: me.id }, { toUserId: me.id } ],
      },
      orderBy: { createdAt: 'desc' }
    });
    let counterpart = null;
    if (last) {
      const id = last.fromUserId === me.id ? last.toUserId : last.fromUserId;
      counterpart = await prisma.user.findUnique({ where: { id }, select: { id: true, name: true, email: true, role: true } });
    } else {
      // fallback: any admin
      counterpart = await prisma.user.findFirst({ where: { role: { in: ['ADMIN','SUPER_ADMIN'] }, isActive: true }, select: { id: true, name: true, email: true, role: true } });
    }
    const threads = counterpart ? [{
      id: counterpart.id,
      name: counterpart.name,
      email: counterpart.email,
      role: counterpart.role,
      lastMessageAt: null,
      unread: await prisma.message.count({ where: { toUserId: me.id, fromUserId: counterpart.id, read: false } }),
    }] : [];
    return res.json({ threads });
  } catch (e) {
    console.error('[chat.threads] error', e);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/chat/messages?userId=<counterpartId>&page=&limit=&since=
router.get('/messages', authenticate, async (req, res) => {
  try {
    const me = req.user;
    const userId = Number.parseInt(req.query.userId);
    if (!userId || Number.isNaN(userId) || userId <= 0) {
      return res.status(400).json({ error: 'userId requerido' });
    }
    const page = Math.max(1, Number.parseInt(req.query.page || '1'));
    const limit = Math.max(1, Math.min(100, Number.parseInt(req.query.limit || '30')));
    let since = null;
    if (req.query.since) {
      const d = new Date(req.query.since);
      if (!Number.isNaN(d.getTime())) since = d;
    }

    // Authorization: admin can access any; client can only access conversations with admins and themselves
    const counterpart = await prisma.user.findUnique({ where: { id: userId } });
    const meIsAdmin = ['ADMIN','SUPER_ADMIN'].includes(me.role);
    if (!meIsAdmin && (!counterpart || !['ADMIN','SUPER_ADMIN'].includes(counterpart.role))) {
      return res.status(403).json({ error: 'No autorizado' });
    }

    const where = {
      OR: [
        { fromUserId: me.id, toUserId: userId },
        { fromUserId: userId, toUserId: me.id }
      ],
      ...(since ? { createdAt: { gt: since } } : {}),
    };
    const total = await prisma.message.count({ where });
    const messages = await prisma.message.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
      include: { attachments: true },
    });
    // return ascending to display naturally
    messages.reverse();
    res.json({
      messages,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) }
    });
  } catch (e) {
    console.error('[chat.messages] error', e);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/chat/messages { toUserId?, message, bookingId? }
// Validaciones de entrada para envío de mensajes
const sendMessageValidation = [
  body('message')
    .isString().withMessage('Mensaje requerido')
    .trim()
    .isLength({ min: 1, max: 2000 }).withMessage('El mensaje debe tener entre 1 y 2000 caracteres'),
  body('toUserId')
    .optional()
    .isInt({ gt: 0 }).withMessage('toUserId inválido'),
  body('bookingId')
    .optional()
    .isInt({ gt: 0 }).withMessage('bookingId inválido'),
  body('attachments')
    .optional()
    .isArray({ max: 5 }).withMessage('attachments debe ser un arreglo de hasta 5 elementos'),
  body('attachments.*.url')
    .optional()
    .isString().isLength({ min: 5, max: 2048 }).withMessage('URL inválida'),
  body('attachments.*.type')
    .optional()
    .isString().isLength({ min: 3, max: 100 }).withMessage('type inválido'),
];

router.post('/messages', authenticate, sendMessageValidation, async (req, res) => {
  try {
    const me = req.user;
    let { toUserId, message, bookingId, attachments } = req.body || {};
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Error de validación',
        details: errors.array()
      });
    }

    if (!toUserId) {
      // Send to first available admin if not specified
      const admin = await prisma.user.findFirst({ where: { role: { in: ['ADMIN','SUPER_ADMIN'] }, isActive: true } });
      if (!admin) return res.status(400).json({ error: 'No hay administradores disponibles' });
      toUserId = admin.id;
    }

    // If me is client and toUser is not admin -> forbid
    const toUser = await prisma.user.findUnique({ where: { id: toUserId } });
    const meIsAdmin = ['ADMIN','SUPER_ADMIN'].includes(me.role);
    const toIsAdmin = !!toUser && ['ADMIN','SUPER_ADMIN'].includes(toUser.role);
    if (!meIsAdmin && !toIsAdmin) {
      return res.status(403).json({ error: 'Solo se permite chatear con administradores' });
    }

    const created = await prisma.message.create({
      data: {
        fromUserId: me.id,
        toUserId,
        body: message,
        bookingId: bookingId ? parseInt(bookingId) : null
      }
    });

    // Adjuntos (URLs pre-subidas a almacenamiento)
    if (Array.isArray(attachments) && attachments.length) {
      const safe = attachments
        .filter(a => a && typeof a.url === 'string')
        .slice(0, 5)
        .map(a => ({ messageId: created.id, url: a.url, type: a.type || null }));
      if (safe.length) {
        await prisma.messageAttachment.createMany({ data: safe });
      }
    }

    // Notify recipient
    await notifyMessage(toUserId, me.name || 'Usuario', message.slice(0, 140));

    // Emitir evento en tiempo real
    try {
      emitToUser(toUserId, 'chat:new_message', { message: created });
    } catch (_) {}

    const result = await prisma.message.findUnique({
      where: { id: created.id },
      include: { attachments: true },
    });
    res.status(201).json({ message: result });
  } catch (e) {
    console.error('[chat.send] error', e);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/chat/messages/:id/read
router.put('/messages/:id/read', authenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const msg = await prisma.message.findUnique({ where: { id } });
    if (!msg || msg.toUserId !== req.user.id) return res.status(404).json({ error: 'Mensaje no encontrado' });
    const updated = await prisma.message.update({ where: { id }, data: { read: true } });
    res.json({ message: updated });
  } catch (e) {
    console.error('[chat.read] error', e);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
