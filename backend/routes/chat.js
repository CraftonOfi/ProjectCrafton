const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');
const { body, validationResult } = require('express-validator');
const { sendPushToTokens } = require('../services/pushService');
const { emitToUser } = require('../realtime');

const router = express.Router();
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
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
      // Construimos threads desde los últimos mensajes, incluyendo preview y estado relativo a mí
      const recent = await prisma.message.findMany({
        where: {
          OR: [ { fromUserId: me.id }, { toUserId: me.id } ]
        },
        orderBy: { createdAt: 'desc' },
        take: 200,
        select: { id: true, fromUserId: true, toUserId: true, createdAt: true, read: true, body: true }
      });

      const latestByCounterpart = new Map(); // counterpartId -> last message
      const unreadByCounterpart = new Map(); // counterpartId -> count

      for (const m of recent) {
        const counterpartId = m.fromUserId === me.id ? m.toUserId : m.fromUserId;
        if (!latestByCounterpart.has(counterpartId)) {
          latestByCounterpart.set(counterpartId, m);
        }
        if (m.toUserId === me.id && !m.read) {
          unreadByCounterpart.set(counterpartId, (unreadByCounterpart.get(counterpartId) || 0) + 1);
        }
      }

      const ids = Array.from(latestByCounterpart.keys());
      const users = ids.length
        ? await prisma.user.findMany({
            where: { id: { in: ids } },
            select: { id: true, name: true, email: true, role: true }
          })
        : [];
      const threads = users
        .map(u => ({
          id: u.id,
          name: u.name,
          email: u.email,
          role: u.role,
          lastMessageAt: (latestByCounterpart.get(u.id) || {}).createdAt || null,
          lastMessagePreview: (latestByCounterpart.get(u.id) || {}).body || '',
          lastMessageDirection: (() => {
            const m = latestByCounterpart.get(u.id);
            if (!m) return null;
            return m.fromUserId === me.id ? 'out' : 'in';
          })(),
          lastMessageStatus: (() => {
            const m = latestByCounterpart.get(u.id);
            if (!m) return null;
            // Para mensajes salientes: read ? 'read' : 'sent'
            if (m.fromUserId === me.id) return m.read ? 'read' : 'sent';
            // Para entrantes, si existen no leídos contarlos, si no, 'received'
            return (unreadByCounterpart.get(u.id) || 0) > 0 ? 'unread' : 'received';
          })(),
          unread: unreadByCounterpart.get(u.id) || 0,
        }))
        .sort((a, b) => {
          const aTime = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0;
          const bTime = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0;
          return bTime - aTime;
        });
      return res.json({ threads });
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
    // Fallback seguro
    res.json({ threads: [] });
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
    // Marcar como leídos los que van hacia mí en el rango retornado
    await prisma.message.updateMany({
      where: { ...where, toUserId: me.id, read: false },
      data: { read: true }
    });
    // return ascending to display naturally
    messages.reverse();
    res.json({
      messages,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) }
    });
  } catch (e) {
    console.error('[chat.messages] error', e);
    // Respuesta segura para evitar romper la UI si hay un problema puntual
    const page = 1, limit = 30;
    res.status(200).json({ messages: [], pagination: { page, limit, total: 0, pages: 1 } });
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

// POST /api/chat/upload - subir archivo de chat (imagen/pdf) con limpieza
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });
router.post('/upload', authenticate, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Archivo requerido' });
    const mime = req.file.mimetype || '';
    const isImage = mime.startsWith('image/');
    const uploadsDir = path.join(process.cwd(), 'uploads');
    if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

    let filename;
    if (isImage) {
      filename = `chat_${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`;
      await sharp(req.file.buffer)
        .rotate()
        .resize(1600, 1600, { fit: 'inside' })
        .jpeg({ quality: 82, chromaSubsampling: '4:2:0' })
        .toFile(path.join(uploadsDir, filename));
    } else {
      // Para no imágenes, guardamos como binario directo con extensión segura
      const safeExt = mime === 'application/pdf' ? 'pdf' : 'bin';
      filename = `chat_${Date.now()}_${Math.random().toString(36).slice(2)}.${safeExt}`;
      fs.writeFileSync(path.join(uploadsDir, filename), req.file.buffer);
    }

    return res.json({ url: `/uploads/${filename}`, type: isImage ? 'image/jpeg' : mime });
  } catch (e) {
    console.error('[chat.upload] error', e);
    res.status(500).json({ error: 'Error subiendo archivo' });
  }
});

module.exports = router;
