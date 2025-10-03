const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// GET /api/payments - Obtener pagos del usuario
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, page = 1, limit = 10 } = req.query;

    const where = {
      userId: req.user.id,
      ...(status && { status })
    };

    const payments = await prisma.payment.findMany({
      where,
      include: {
        booking: {
          include: {
            resource: {
              select: {
                id: true,
                name: true,
                type: true
              }
            }
          }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * parseInt(limit),
      take: parseInt(limit)
    });

    const total = await prisma.payment.count({ where });

    res.json({
      payments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Error obteniendo pagos:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/payments/create-intent - Crear Payment Intent de Stripe
router.post('/create-intent', authenticate, async (req, res) => {
  try {
    const { bookingId } = req.body;

    // Verificar que la reserva existe y pertenece al usuario
    const booking = await prisma.booking.findFirst({
      where: {
        id: bookingId,
        userId: req.user.id,
        status: 'PENDING'
      }
    });

    if (!booking) {
      return res.status(404).json({
        error: 'Reserva no encontrada o ya procesada'
      });
    }

    // TODO: Integrar con Stripe cuando tengas las keys
    // const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    // const paymentIntent = await stripe.paymentIntents.create({
    //   amount: Math.round(booking.totalPrice * 100), // Stripe usa centavos
    //   currency: 'eur',
    //   metadata: {
    //     bookingId: booking.id,
    //     userId: req.user.id
    //   }
    // });

    // Por ahora, simular respuesta de Stripe
    const mockPaymentIntent = {
      id: `pi_mock_${Date.now()}`,
      client_secret: `pi_mock_${Date.now()}_secret_mock`,
      amount: Math.round(booking.totalPrice * 100),
      currency: 'eur',
      status: 'requires_payment_method'
    };

    // Crear registro de pago pendiente
    const payment = await prisma.payment.create({
      data: {
        userId: req.user.id,
        bookingId: booking.id,
        amount: booking.totalPrice,
        currency: 'EUR',
        status: 'PENDING',
        stripePaymentId: mockPaymentIntent.id
      }
    });

    res.json({
      clientSecret: mockPaymentIntent.client_secret,
      payment: payment
    });

  } catch (error) {
    console.error('Error creando Payment Intent:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// POST /api/payments/confirm - Confirmar pago (webhook de Stripe o simulado)
router.post('/confirm', authenticate, async (req, res) => {
  try {
    const { paymentIntentId } = req.body;

    // Buscar el pago por el ID de Stripe
    const payment = await prisma.payment.findFirst({
      where: {
        stripePaymentId: paymentIntentId,
        userId: req.user.id
      },
      include: {
        booking: true
      }
    });

    if (!payment) {
      return res.status(404).json({
        error: 'Pago no encontrado'
      });
    }

    if (payment.status === 'COMPLETED') {
      return res.status(400).json({
        error: 'El pago ya fue confirmado'
      });
    }

    // Actualizar pago y reserva en una transacción
    const result = await prisma.$transaction(async (tx) => {
      // Actualizar estado del pago
      const updatedPayment = await tx.payment.update({
        where: { id: payment.id },
        data: { status: 'COMPLETED' }
      });

      // Actualizar estado de la reserva
      const updatedBooking = await tx.booking.update({
        where: { id: payment.bookingId },
        data: { status: 'CONFIRMED' }
      });

      return { payment: updatedPayment, booking: updatedBooking };
    });

    res.json({
      message: 'Pago confirmado exitosamente',
      payment: result.payment,
      booking: result.booking
    });

  } catch (error) {
    console.error('Error confirmando pago:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// GET /api/payments/:id - Obtener pago específico
router.get('/:id', authenticate, async (req, res) => {
  try {
    const payment = await prisma.payment.findFirst({
      where: {
        id: req.params.id,
        // Solo el propietario o un admin pueden ver el pago
        ...(req.user.role === 'CLIENT' && { userId: req.user.id })
      },
      include: {
        booking: {
          include: {
            resource: {
              select: {
                id: true,
                name: true,
                type: true,
                location: true
              }
            }
          }
        },
        user: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    });

    if (!payment) {
      return res.status(404).json({
        error: 'Pago no encontrado'
      });
    }

    res.json({ payment });

  } catch (error) {
    console.error('Error obteniendo pago:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

// GET /api/payments/admin/all - Listar todos los pagos (solo admin)
router.get('/admin/all', authenticate, requireAdmin, async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;

    const where = status ? { status } : {};

    const payments = await prisma.payment.findMany({
      where,
      include: {
        user: {
          select: { id: true, name: true, email: true }
        },
        booking: {
          include: {
            resource: {
              select: { id: true, name: true, type: true }
            }
          }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * parseInt(limit),
      take: parseInt(limit)
    });

    const total = await prisma.payment.count({ where });

    // Calcular estadísticas
    const stats = await prisma.payment.groupBy({
      by: ['status'],
      _sum: { amount: true },
      _count: true
    });

    res.json({
      payments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      },
      stats
    });

  } catch (error) {
    console.error('Error listando pagos (admin):', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
});

module.exports = router;