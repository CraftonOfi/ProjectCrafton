const cron = require('node-cron');
const { PrismaClient } = require('@prisma/client');
const { sendPushToTokens } = require('./pushService');

function setupBookingCron(logger) {
  const prisma = new PrismaClient();

  // Ejecuta cada 15 minutos
  cron.schedule('*/15 * * * *', async () => {
    try {
      const now = new Date();
      // Marcar IN_PROGRESS
      await prisma.booking.updateMany({
        where: { status: 'CONFIRMED', startDate: { lte: now }, endDate: { gt: now } },
        data: { status: 'IN_PROGRESS' },
      });
      // Marcar COMPLETED
      await prisma.booking.updateMany({
        where: { status: { in: ['CONFIRMED','IN_PROGRESS'] }, endDate: { lte: now } },
        data: { status: 'COMPLETED' },
      });

      // Recordatorio 24h antes
      const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const upcoming = await prisma.booking.findMany({
        where: {
          status: 'CONFIRMED',
          startDate: { gte: now, lte: in24h },
        },
        select: { id: true, userId: true },
      });
      for (const b of upcoming) {
        try {
          await prisma.notification.create({
            data: { userId: b.userId, title: 'Recordatorio de reserva', message: `Tu reserva #${b.id} inicia pronto`, type: 'BOOKING_REMINDER' },
          });
          const tokens = await prisma.deviceToken.findMany({ where: { userId: b.userId, isActive: true }, select: { token: true } });
          const list = tokens.map(t => t.token);
          if (list.length) await sendPushToTokens(list, { title: 'Recordatorio de reserva', body: `Tu reserva #${b.id} inicia pronto` }, { type: 'BOOKING_REMINDER', bookingId: String(b.id) });
        } catch (_) {}
      }

      logger?.info?.('booking cron tick');
    } catch (e) {
      logger?.error?.({ err: e }, 'booking cron error');
    }
  });
}

module.exports = { setupBookingCron };


