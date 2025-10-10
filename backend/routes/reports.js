const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// GET /api/reports/admin/summary - KPIs y métricas básicas (solo admin)
router.get('/admin/summary', authenticate, requireAdmin, async (req, res) => {
  try {
    const now = new Date();
    const since30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const since180 = new Date(now.getTime() - 180 * 24 * 60 * 60 * 1000);
    const since365 = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);

    // Normalizar estados de reservas de forma liviana antes del resumen.
    // 1) Marcar como COMPLETED todas las que ya terminaron y no estén en estado final.
    // 2) Marcar como IN_PROGRESS las que están corriendo ahora y no estén canceladas/refundadas/completadas.
    try {
      await Promise.all([
        prisma.booking.updateMany({
          where: {
            endDate: { lt: now },
            status: { in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS'] },
          },
          data: { status: 'COMPLETED' },
        }),
        prisma.booking.updateMany({
          where: {
            startDate: { lte: now },
            endDate: { gt: now },
            status: { in: ['PENDING', 'CONFIRMED'] },
          },
          data: { status: 'IN_PROGRESS' },
        }),
      ]);
    } catch (normErr) {
      // No bloquear el resumen si falla la normalización.
      console.warn('No se pudo normalizar estados de reservas:', normErr.message);
    }

    // Usuarios
    const [totalUsers, activeUsers] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { isActive: true } }),
    ]);

    // Bookings por estado
    const bookingsByStatus = await prisma.booking.groupBy({
      by: ['status'],
      _count: true,
    });
    const bookingsTotal = await prisma.booking.count();

    // Bookings últimos periodos
    const [bookingsLast30, bookingsLast180, bookingsLast365] = await Promise.all([
      prisma.booking.count({ where: { createdAt: { gte: since30 } } }),
      prisma.booking.count({ where: { createdAt: { gte: since180 } } }),
      prisma.booking.count({ where: { createdAt: { gte: since365 } } }),
    ]);

    // Pagos e ingresos
    const paymentsByStatus = await prisma.payment.groupBy({
      by: ['status'],
      _sum: { amount: true },
      _count: true,
    });

    const completedPayments = await prisma.payment.findMany({
      where: { status: 'COMPLETED' },
      select: { amount: true },
    });
    const revenueTotal = completedPayments.reduce((a, p) => a + (p.amount || 0), 0);

    const last30Payments = await prisma.payment.findMany({
      where: { status: 'COMPLETED', createdAt: { gte: since30 } },
      select: { amount: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    // Agregar por día (YYYY-MM-DD)
    const byDay = {};
    for (const p of last30Payments) {
      const d = new Date(p.createdAt);
      const key = d.toISOString().slice(0, 10);
      byDay[key] = (byDay[key] || 0) + (p.amount || 0);
    }
    // Construir serie de 30 días
    let series = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = d.toISOString().slice(0, 10);
      series.push({ date: key, amount: +(byDay[key] || 0).toFixed(2) });
    }
    const revenue30 = series.reduce((a, x) => a + x.amount, 0);

    // Ingresos últimos 6 meses y 12 meses
    const [payments180, payments365] = await Promise.all([
      prisma.payment.findMany({
        where: { status: 'COMPLETED', createdAt: { gte: since180 } },
        select: { amount: true },
      }),
      prisma.payment.findMany({
        where: { status: 'COMPLETED', createdAt: { gte: since365 } },
        select: { amount: true },
      }),
    ]);
    const revenue180 = payments180.reduce((a, p) => a + (p.amount || 0), 0);
    const revenue365 = payments365.reduce((a, p) => a + (p.amount || 0), 0);

    // Fallback de ingresos desde reservas COMPLETED (si aún no hay pagos)
    const completedBookingsAll = await prisma.booking.findMany({
      where: { status: 'COMPLETED' },
      select: { totalPrice: true },
    });
    const bookingRevenueTotal = completedBookingsAll.reduce(
      (a, b) => a + (b.totalPrice || 0),
      0,
    );

    const last30CompletedBookings = await prisma.booking.findMany({
      where: { status: 'COMPLETED', createdAt: { gte: since30 } },
      select: { totalPrice: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    // Serie por día desde reservas (sólo si no hay pagos completos)
    if (revenueTotal === 0 && last30Payments.length === 0 && last30CompletedBookings.length > 0) {
      const byDayBookings = {};
      for (const b of last30CompletedBookings) {
        const d = new Date(b.createdAt);
        const key = d.toISOString().slice(0, 10);
        byDayBookings[key] = (byDayBookings[key] || 0) + (b.totalPrice || 0);
      }
      series = [];
      for (let i = 29; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
        const key = d.toISOString().slice(0, 10);
        series.push({ date: key, amount: +(byDayBookings[key] || 0).toFixed(2) });
      }
    }

    // Recalcular revenue30 en base a la serie final (ya sea de pagos o de reservas)
    const revenue30Final = series.reduce((a, x) => a + x.amount, 0);

    // Top recursos por nº de reservas (top 5)
    const topResourcesRaw = await prisma.booking.groupBy({
      by: ['resourceId'],
      _count: true,
      orderBy: { _count: { resourceId: 'desc' } },
      take: 5,
    });
    const resourceIds = topResourcesRaw.map(r => r.resourceId);
    const resources = await prisma.resource.findMany({
      where: { id: { in: resourceIds } },
      select: { id: true, name: true, type: true },
    });
    const resourcesMap = Object.fromEntries(resources.map(r => [r.id, r]));
    const topResources = topResourcesRaw.map(r => ({
      resourceId: r.resourceId,
      name: resourcesMap[r.resourceId]?.name || `Recurso ${r.resourceId}`,
      type: resourcesMap[r.resourceId]?.type || 'UNKNOWN',
      count: r._count,
    }));

    res.json({
      users: { total: totalUsers, active: activeUsers },
      bookings: {
        total: bookingsTotal,
        last30Days: bookingsLast30,
        last180Days: bookingsLast180,
        last365Days: bookingsLast365,
        byStatus: bookingsByStatus.reduce((acc, b) => {
          acc[b.status] = b._count;
          return acc;
        }, {}),
      },
      payments: {
        byStatus: paymentsByStatus.reduce((acc, p) => {
          acc[p.status] = { count: p._count, amount: +(p._sum.amount || 0).toFixed(2) };
          return acc;
        }, {}),
        revenueTotal: +(revenueTotal > 0 ? revenueTotal : bookingRevenueTotal).toFixed(2),
        revenueFromPayments: +revenueTotal.toFixed(2),
        revenueFromBookingsCompleted: +bookingRevenueTotal.toFixed(2),
  revenueLast30Days: +revenue30Final.toFixed(2),
        revenueLast180Days: +revenue180.toFixed(2),
        revenueLast365Days: +revenue365.toFixed(2),
        seriesLast30Days: series,
      },
      topResources,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error generando resumen admin:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/reports/admin/range?days=30 - Métricas para un rango dinámico (solo admin)
router.get('/admin/range', authenticate, requireAdmin, async (req, res) => {
  try {
    const days = Math.max(1, Math.min(365, parseInt(req.query.days || '30', 10)));
    const now = new Date();
    const since = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

    // Normalización ligera como en summary (no bloquear si falla)
    try {
      await Promise.all([
        prisma.booking.updateMany({
          where: {
            endDate: { lt: now },
            status: { in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS'] },
          },
          data: { status: 'COMPLETED' },
        }),
        prisma.booking.updateMany({
          where: {
            startDate: { lte: now },
            endDate: { gt: now },
            status: { in: ['PENDING', 'CONFIRMED'] },
          },
          data: { status: 'IN_PROGRESS' },
        }),
      ]);
    } catch (_) {}

    // Bookings en rango
    const [bookingsInRange, bookingsByStatusInRange] = await Promise.all([
      prisma.booking.count({ where: { createdAt: { gte: since } } }),
      prisma.booking.groupBy({
        by: ['status'],
        _count: true,
        where: { createdAt: { gte: since } },
      }),
    ]);

    // Revenue en rango (pagos COMPLETED)
    const paymentsInRange = await prisma.payment.findMany({
      where: { status: 'COMPLETED', createdAt: { gte: since } },
      select: { amount: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    const byDay = {};
    for (const p of paymentsInRange) {
      const d = new Date(p.createdAt);
      const key = d.toISOString().slice(0, 10);
      byDay[key] = (byDay[key] || 0) + (p.amount || 0);
    }
    let series = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = d.toISOString().slice(0, 10);
      series.push({ date: key, amount: +(byDay[key] || 0).toFixed(2) });
    }

    // Fallback a reservas COMPLETED en rango si no hay pagos en rango
    if (paymentsInRange.length === 0) {
      const bookingsCompletedInRange = await prisma.booking.findMany({
        where: { status: 'COMPLETED', createdAt: { gte: since } },
        select: { totalPrice: true, createdAt: true },
        orderBy: { createdAt: 'asc' },
      });
      const byDayBk = {};
      for (const b of bookingsCompletedInRange) {
        const d = new Date(b.createdAt);
        const key = d.toISOString().slice(0, 10);
        byDayBk[key] = (byDayBk[key] || 0) + (b.totalPrice || 0);
      }
      series = [];
      for (let i = days - 1; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
        const key = d.toISOString().slice(0, 10);
        series.push({ date: key, amount: +(byDayBk[key] || 0).toFixed(2) });
      }
    }

    const revenueInRange = series.reduce((a, x) => a + x.amount, 0);

    res.json({
      days,
      bookings: {
        count: bookingsInRange,
        byStatus: bookingsByStatusInRange.reduce((acc, b) => {
          acc[b.status] = b._count;
          return acc;
        }, {}),
      },
      payments: {
        revenue: +revenueInRange.toFixed(2),
        series,
      },
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error generando rango admin:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
