const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();
const { sendPushToTokens } = require('../services/pushService');
async function notify(userId, title, message, type = 'GENERAL') {
  try {
    await prisma.notification.create({
      data: { userId, title, message, type },
    });
    // Intentar enviar push si hay tokens activos
    const hasDeviceDelegate = prisma && Object.prototype.hasOwnProperty.call(prisma, 'deviceToken');
    if (hasDeviceDelegate) {
      const tokens = await prisma.deviceToken.findMany({
        where: { userId, isActive: true },
        select: { token: true },
      });
      const list = tokens.map((t) => t.token);
      if (list.length > 0) {
        // No bloquear el request si falla el envío; ejecutar en background
        sendPushToTokens(list, { title, body: message }, { type }).catch(() => {});
      }
    }
  } catch (e) {
    console.warn('[notify] failed', e.message);
  }
}

// Helpers de adaptación para que el backend entregue el shape que consume el móvil
const parseSpecifications = (raw) => {
  if (!raw) return {};
  try { return JSON.parse(raw); } catch (_) { return {}; }
};

const adaptResource = (resource) => {
  if (!resource) return null;
  const images = Array.isArray(resource.images)
    ? resource.images.map((i) => i.url).filter(Boolean)
    : [];
  return {
    id: resource.id,
    name: resource.name,
    description: resource.description ?? '',
    type: resource.type,
    pricePerHour: resource.pricePerHour ?? 0,
    location: resource.location ?? null,
    capacity: resource.capacity ?? null,
    specifications: parseSpecifications(resource.specifications),
    images,
    isActive: resource.isActive,
    createdAt: resource.createdAt,
    updatedAt: resource.updatedAt,
    ownerId: resource.ownerId ?? 0,
    // owner es opcional en el móvil; podemos omitirlo o incluir un resumen.
  };
};

// GET /api/bookings/admin/all - Listar todas las reservas (solo admin)
router.get('/admin/all', authenticate, requireAdmin, async (req, res) => {
  try {
    const { status, userId, resourceId, page = 1, limit = 20, search } = req.query;

    const where = {
      ...(status && { status }),
      ...(userId && { userId: parseInt(userId) }),
      ...(resourceId && { resourceId: parseInt(resourceId) }),
      ...(search && typeof search === 'string' && search.trim()
        ? {
            OR: [
              { user: { name: { contains: search } } },
              { user: { email: { contains: search } } },
              { resource: { name: { contains: search } } },
            ],
          }
        : {}),
    };

    const [rows, total] = await Promise.all([
      prisma.booking.findMany({
        where,
        include: {
          resource: { include: { images: { select: { url: true } } } },
          user: {
            select: {
              id: true,
              email: true,
              name: true,
              role: true,
              isActive: true,
              createdAt: true,
              updatedAt: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.booking.count({ where }),
    ]);

    const bookings = rows.map((b) => ({
      ...b,
      startTime: b.startDate,
      endTime: b.endDate,
      totalHours: b.totalHours,
      totalPrice: b.totalPrice,
      notes: b.notes,
      resource: adaptResource(b.resource),
    }));

    res.json({
      bookings,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error listando reservas admin:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/bookings - Obtener reservas del usuario
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, page = 1, limit = 10 } = req.query;

    const where = {
      userId: req.user.id,
      ...(status && { status })
    };

    let bookingsRaw = await prisma.booking.findMany({
      where,
      include: {
        resource: {
          include: {
            images: { select: { url: true } },
          }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * parseInt(limit),
      take: parseInt(limit)
    });

    // Adaptar nombres de campos (compatibilidad con frontend que espera startTime/endTime)
    let bookings = bookingsRaw.map(b => ({
      ...b,
      startTime: b.startDate,
      endTime: b.endDate,
      totalHours: b.totalHours,
      totalPrice: b.totalPrice,
      notes: b.notes,
      resource: adaptResource(b.resource),
    }));

    const total = await prisma.booking.count({ where });

    // Helper para derivar el estado dinámico de una reserva según el tiempo actual
    // Respeta cuando un admin marcó una reserva como IN_PROGRESS antes de hora
    // (no la "degrada" a CONFIRMED), pero la completa al finalizar.
    const deriveStatus = (bk) => {
      const now = new Date();
      const start = new Date(bk.startDate);
      const end = new Date(bk.endDate);

      // Estados terminales / finales no cambian
      if (['CANCELLED', 'REFUNDED', 'COMPLETED'].includes(bk.status)) return bk.status;

      // Si está marcada como en curso por admin, respetar hasta que termine
      if (bk.status === 'IN_PROGRESS') {
        if (now >= end) return 'COMPLETED';
        return 'IN_PROGRESS';
      }

      // Para PENDING/CONFIRMED derivar automáticamente
      if (now >= end) return 'COMPLETED';
      if (now >= start && now < end) return 'IN_PROGRESS';
      return 'CONFIRMED';
    };

    // Actualizar dinámicamente y persistir si cambió el estado
    const updates = [];
    bookings = await Promise.all(bookings.map(async (bk) => {
      const newStatus = deriveStatus(bk);
      if (newStatus !== bk.status) {
        try {
          const updated = await prisma.booking.update({
            where: { id: bk.id },
            data: { status: newStatus }
          });
          return { ...bk, status: updated.status };
        } catch (e) {
          console.warn('No se pudo actualizar estado dinámico booking', bk.id, e.message);
          return { ...bk, status: newStatus }; // devolver al menos el estado derivado
        }
      }
      return bk;
    }));

    res.json({
      bookings,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Error obteniendo reservas:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/bookings - Crear nueva reserva (auto-confirmada)
router.post('/', authenticate, async (req, res) => {
  try {
    const { resourceId, startTime, endTime, notes } = req.body;
    const numericResourceId = parseInt(resourceId);

    // Validar fechas
  const start = new Date(startTime);
  const end = new Date(endTime);
    const now = new Date();

    if (start <= now) {
      return res.status(400).json({
        error: 'La fecha de inicio debe ser futura'
      });
    }

    if (end <= start) {
      return res.status(400).json({
        error: 'La fecha de fin debe ser posterior al inicio'
      });
    }

    // Verificar que el recurso existe
    const resource = await prisma.resource.findUnique({
      where: { id: numericResourceId }
    });

    if (!resource || !resource.isActive) {
      return res.status(404).json({
        error: 'Recurso no encontrado o no disponible'
      });
    }

    // Verificar conflictos de horario
    const conflictingBookings = await prisma.booking.findMany({
      where: {
        resourceId: numericResourceId,
        status: { in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS'] },
        OR: [
          {
            startDate: { lte: start },
            endDate: { gt: start }
          },
          {
            startDate: { lt: end },
            endDate: { gte: end }
          },
          {
            startDate: { gte: start },
            endDate: { lte: end }
          }
        ]
      }
    });

    if (conflictingBookings.length > 0) {
      return res.status(409).json({
        error: 'Ya existe una reserva en este horario'
      });
    }

    // Calcular precio
    const totalHours = (end - start) / (1000 * 60 * 60);
    const totalPrice = totalHours * resource.pricePerHour;

    // Crear reserva auto-confirmada
    const bookingRaw = await prisma.booking.create({
      data: {
        userId: req.user.id,
        resourceId: numericResourceId,
  startDate: start,
  endDate: end,
        totalHours,
        totalPrice,
        notes,
        status: 'CONFIRMED'
      },
      include: {
        resource: {
          include: {
            images: { select: { url: true } },
          }
        }
      }
    });

    const booking = { 
      ...bookingRaw, 
      startTime: bookingRaw.startDate, 
      endTime: bookingRaw.endDate,
      totalHours: bookingRaw.totalHours,
      totalPrice: bookingRaw.totalPrice,
      notes: bookingRaw.notes,
      resource: adaptResource(bookingRaw.resource),
    };

    // Notificar creación de reserva
    notify(req.user.id, 'Reserva creada', `Tu reserva para ${resource.name} fue creada y confirmada.`, 'BOOKING_CONFIRMED');

    res.status(201).json({
      message: 'Reserva creada exitosamente',
      booking
    });

  } catch (error) {
    console.error('Error creando reserva:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// GET /api/bookings/:id - Obtener reserva específica
router.get('/:id', authenticate, async (req, res) => {
  try {
    let bookingRaw = await prisma.booking.findFirst({
      where: {
        id: parseInt(req.params.id),
        // Solo el propietario o un admin puede ver cualquier reserva
        ...(req.user.role === 'CLIENT' && { userId: req.user.id })
      },
      include: {
        resource: {
          include: { images: { select: { url: true } } }
        },
        user: {
          select: { id: true, name: true, email: true, role: true, isActive: true, createdAt: true, updatedAt: true }
        }
      }
    });

    if (!bookingRaw) {
      return res.status(404).json({
        error: 'Reserva no encontrada'
      });
    }

    let booking = { 
      ...bookingRaw, 
      startTime: bookingRaw.startDate, 
      endTime: bookingRaw.endDate,
      totalHours: bookingRaw.totalHours,
      totalPrice: bookingRaw.totalPrice,
      notes: bookingRaw.notes,
      resource: adaptResource(bookingRaw.resource),
    };

    // Derivar y persistir estado dinámico para la reserva individual
    const now = new Date();
    const start = new Date(booking.startDate);
    const end = new Date(booking.endDate);
    let newStatus = booking.status;
    if (!['CANCELLED', 'REFUNDED', 'COMPLETED'].includes(booking.status)) {
      if (booking.status === 'IN_PROGRESS') {
        newStatus = now >= end ? 'COMPLETED' : 'IN_PROGRESS';
      } else {
        if (now >= end) newStatus = 'COMPLETED';
        else if (now >= start && now < end) newStatus = 'IN_PROGRESS';
        else newStatus = 'CONFIRMED';
      }
    }
    if (newStatus !== booking.status) {
      try {
        const updated = await prisma.booking.update({
          where: { id: booking.id },
          data: { status: newStatus }
        });
        booking.status = updated.status;
      } catch (e) {
        console.warn('No se pudo persistir transición de estado booking', booking.id, e.message);
        booking.status = newStatus; // al menos reflejar dinámico
      }
    }

    res.json({ booking });

  } catch (error) {
    console.error('Error obteniendo reserva:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// PUT /api/bookings/:id/status - Actualizar estado de reserva (solo admin)
router.put('/:id/status', authenticate, requireAdmin, async (req, res) => {
  try {
    const { status } = req.body;

    const validStatuses = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'REFUNDED'];
    
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: 'Estado inválido'
      });
    }

    const bookingRaw = await prisma.booking.update({
      where: { id: parseInt(req.params.id) },
      data: { status },
      include: {
        resource: { include: { images: { select: { url: true } } } }
      }
    });

    const booking = {
      ...bookingRaw,
      startTime: bookingRaw.startDate,
      endTime: bookingRaw.endDate,
      totalHours: bookingRaw.totalHours,
      totalPrice: bookingRaw.totalPrice,
      notes: bookingRaw.notes,
      resource: adaptResource(bookingRaw.resource),
    };

    // Notificar al usuario
    const userId = bookingRaw.userId;
    let title = 'Reserva actualizada';
    let msg = `El estado de tu reserva #${bookingRaw.id} cambió a ${status}.`;
    if (status === 'CONFIRMED') { title = 'Reserva confirmada'; }
    if (status === 'IN_PROGRESS') { title = 'Reserva en curso'; }
    if (status === 'COMPLETED') { title = 'Reserva completada'; }
    if (status === 'CANCELLED') { title = 'Reserva cancelada'; }
    if (status === 'REFUNDED') { title = 'Reserva reembolsada'; }
    notify(userId, title, msg, 'GENERAL');

    res.json({
      message: 'Estado de reserva actualizado',
      booking,
    });

  } catch (error) {
    console.error('Error actualizando reserva:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/bookings/check-availability - Verificar disponibilidad de horario
router.post('/check-availability', authenticate, async (req, res) => {
  try {
    const { resourceId, startTime, endTime } = req.body;
    const numericResourceId = parseInt(resourceId);
  const start = new Date(startTime);
  const end = new Date(endTime);
    if (isNaN(numericResourceId) || !startTime || !endTime) {
      return res.status(400).json({ error: 'Parámetros inválidos' });
    }
    if (!(end > start)) {
      return res.status(422).json({ error: 'El rango horario es inválido' });
    }
    const now = new Date();
    if (start <= now) {
      return res.status(422).json({ error: 'La hora de inicio debe ser futura' });
    }

    console.log('[AVAILABILITY] resource', numericResourceId, 'start', start.toISOString(), 'end', end.toISOString());

    const conflicts = await prisma.booking.count({
      where: {
        resourceId: numericResourceId,
        status: { in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS'] },
        OR: [
          { startDate: { lte: start }, endDate: { gt: start } },
          { startDate: { lt: end }, endDate: { gte: end } },
          { startDate: { gte: start }, endDate: { lte: end } },
        ]
      }
    });
    if (conflicts > 0) {
      return res.status(409).json({ error: 'Conflicto de horario existente', available: false });
    }
    res.json({ available: true });
  } catch (error) {
    console.error('Error verificando disponibilidad:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/bookings/:id/cancel - Cancelar por el propietario (PENDING/CONFIRMED)
router.put('/:id/cancel', authenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
  const booking = await prisma.booking.findUnique({ where: { id } });
    if (!booking || booking.userId !== req.user.id) {
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }
    if (!['PENDING', 'CONFIRMED'].includes(booking.status)) {
      return res.status(400).json({ error: 'La reserva no puede cancelarse en este estado' });
    }

    const updated = await prisma.booking.update({
      where: { id },
      data: { status: 'CANCELLED' }
    });
    const adapted = { 
      ...updated, 
      startTime: updated.startDate, 
      endTime: updated.endDate,
      totalHours: updated.totalHours,
      totalPrice: updated.totalPrice,
      notes: updated.notes
    };
    res.json({ message: 'Reserva cancelada', booking: adapted });
  } catch (error) {
    console.error('Error cancelando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;