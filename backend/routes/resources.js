const express = require('express');
const { authenticate, requireAdmin } = require('../middleware');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// GET /api/resources - filtros avanzados: types[], locations[], minPrice, maxPrice, search, sort
router.get('/', async (req, res) => {
  const baseWhere = { isActive: true };
  const startTs = Date.now();
  try {
    const { type, types, location, locations, search, minPrice, maxPrice, sort, page = 1, limit = 20 } = req.query;

    // Debug log (no PII): incoming raw query
    console.log('[resources:list] query params', {
      q: req.query,
    });

    // Normalización de tipos (single o múltiple)
    const collectedTypes = new Set();
    const addType = (t) => {
      if (!t) return;
      const up = String(t).toUpperCase();
      if (up === 'STORAGESPACE') collectedTypes.add('STORAGE_SPACE');
      else if (up === 'LASERMACHINE') collectedTypes.add('LASER_MACHINE');
      else if (['STORAGE_SPACE','LASER_MACHINE'].includes(up)) collectedTypes.add(up);
    };
    addType(type);
    if (types) {
      if (Array.isArray(types)) types.forEach(addType);
      else if (typeof types === 'string') types.split(',').forEach(addType);
    }

    // Normalización de ubicaciones (single o múltiple)
    const collectedLocations = new Set();
    const addLocation = (loc) => {
      if (!loc) return;
      const trimmed = String(loc).trim();
      if (trimmed.length) collectedLocations.add(trimmed);
    };
    addLocation(location);
    if (locations) {
      if (Array.isArray(locations)) locations.forEach(addLocation);
      else if (typeof locations === 'string') locations.split(',').forEach(addLocation);
    }

    const priceFilters = [];
    const minP = parseFloat(minPrice);
    const maxP = parseFloat(maxPrice);
    if (!isNaN(minP)) priceFilters.push({ pricePerHour: { gte: minP } });
    if (!isNaN(maxP)) priceFilters.push({ pricePerHour: { lte: maxP } });

    // Construir where incremental
    let where = { ...baseWhere };
    if (collectedTypes.size) {
      where.type = { in: Array.from(collectedTypes) };
    }
    // Nota: SQLite (dev) no soporta 'mode: "insensitive"' en Prisma. Para compatibilidad
    // simplificamos usando búsqueda contains directa (case-sensitive) y más abajo añadimos
    // un filtrado manual insensible si se requiere. Para ambientes con Postgres se puede
    // reintroducir la opción de case-insensitive.
    if (collectedLocations.size === 1) {
      const only = Array.from(collectedLocations)[0];
      where.location = { contains: only }; // sin mode
    } else if (collectedLocations.size > 1) {
      const ors = Array.from(collectedLocations).map(l => ({
        location: { contains: l }
      }));
      if (ors.length) {
        where.AND = [ ...(where.AND || []), { OR: ors } ];
      }
    }

    if (priceFilters.length) {
      where.AND = [ ...(where.AND || []), ...priceFilters ];
    }

    if (search && typeof search === 'string' && search.trim()) {
      const term = search.trim();
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            { name: { contains: term } },
            { description: { contains: term } },
            { location: { contains: term } },
          ]
        }
      ];
    }

    // Ordenamiento: sort=price_asc | price_desc | created_desc | created_asc (default created_desc)
    let orderBy = { createdAt: 'desc' };
    if (typeof sort === 'string') {
      const s = sort.toLowerCase();
      if (s === 'price_asc') orderBy = { pricePerHour: 'asc' };
      else if (s === 'price_desc') orderBy = { pricePerHour: 'desc' };
      else if (s === 'created_asc') orderBy = { createdAt: 'asc' };
      else if (s === 'created_desc') orderBy = { createdAt: 'desc' };
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    let resources, total;
    try {
      [resources, total] = await Promise.all([
        prisma.resource.findMany({
          where,
          include: {
            owner: { select: { id: true, name: true, email: true, role: true } },
            images: true,
            _count: { select: { bookings: true } }
          },
          orderBy,
          skip,
          take
        }),
        prisma.resource.count({ where })
      ]);
    } catch (prismaErr) {
      console.error('[resources:list] Prisma query failed', {
        message: prismaErr.message,
        code: prismaErr.code,
        where,
        orderBy,
        page,
        limit
      });
      throw prismaErr;
    }

    const mapped = resources.map(r => ({
      id: r.id.toString(),
      name: r.name,
      description: r.description ?? '',
      type: r.type, // ya viene como STORAGE_SPACE / LASER_MACHINE
      pricePerHour: r.pricePerHour ?? 0,
      location: r.location,
      capacity: r.capacity,
      specifications: safeParseJSON(r.specifications),
      images: r.images.map(img => img.url),
      isActive: r.isActive,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      ownerId: r.ownerId?.toString() ?? '0',
      owner: r.owner ? {
        id: r.owner.id,
        email: r.owner.email,
        name: r.owner.name,
        role: r.owner.role,
        isActive: true,
        phone: null,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt
      } : null
    }));

    const durationMs = Date.now() - startTs;
    console.log('[resources:list] success', { count: mapped.length, total, durationMs, where, orderBy });
    res.json({
      resources: mapped,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('[resources:list] error', {
      message: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: 'Error interno del servidor', detail: error.message });
  }
});

// GET /api/resources/:id - Obtener recurso específico
router.get('/:id', async (req, res) => {
  try {
    const resource = await prisma.resource.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        owner: { select: { id: true, name: true, email: true, role: true } },
        images: true
      }
    });

    if (!resource || !resource.isActive) {
      return res.status(404).json({ error: 'Recurso no encontrado' });
    }

    const mapped = {
      id: resource.id.toString(),
      name: resource.name,
      description: resource.description ?? '',
      type: resource.type,
      pricePerHour: resource.pricePerHour ?? 0,
      location: resource.location,
      capacity: resource.capacity,
      specifications: safeParseJSON(resource.specifications),
      images: resource.images.map(i => i.url),
      isActive: resource.isActive,
      createdAt: resource.createdAt,
      updatedAt: resource.updatedAt,
      ownerId: resource.ownerId?.toString() ?? '0',
      owner: resource.owner ? {
        id: resource.owner.id,
        email: resource.owner.email,
        name: resource.owner.name,
        role: resource.owner.role,
        isActive: true,
        phone: null,
        createdAt: resource.createdAt,
        updatedAt: resource.updatedAt
      } : null
    };

    res.json({ resource: mapped });
  } catch (error) {
    console.error('Error obteniendo recurso:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/resources - Crear nuevo recurso (solo admin)
router.post('/', authenticate, requireAdmin, async (req, res) => {
  try {
    let { name, description, type, pricePerHour, location, capacity, specifications, images } = req.body;

    // Normalizar tipo recibido (por si viene STORAGESPACE, LASERMACHINE)
    if (typeof type === 'string') {
      const t = type.toUpperCase();
      if (t === 'STORAGESPACE') type = 'STORAGE_SPACE';
      else if (t === 'LASERMACHINE') type = 'LASER_MACHINE';
    }

    const created = await prisma.resource.create({
      data: {
        name,
        description,
        type,
        pricePerHour: pricePerHour ?? 0,
        location,
        capacity,
        specifications: typeof specifications === 'string' ? specifications : JSON.stringify(specifications || {}),
        ownerId: req.user.id
      },
      include: { owner: { select: { id: true, name: true, email: true, role: true } }, images: true }
    });

    // Insertar imágenes si vienen
    if (Array.isArray(images) && images.length) {
      await prisma.resourceImage.createMany({
        data: images.map(url => ({ url, resourceId: created.id }))
      });
    }

    const withImages = await prisma.resource.findUnique({
      where: { id: created.id },
      include: { owner: { select: { id: true, name: true, email: true, role: true } }, images: true }
    });

    const mapped = {
      id: withImages.id.toString(),
      name: withImages.name,
      description: withImages.description ?? '',
      type: withImages.type,
      pricePerHour: withImages.pricePerHour ?? 0,
      location: withImages.location,
      capacity: withImages.capacity,
      specifications: safeParseJSON(withImages.specifications),
      images: withImages.images.map(i => i.url),
      isActive: withImages.isActive,
      createdAt: withImages.createdAt,
      updatedAt: withImages.updatedAt,
      ownerId: withImages.ownerId?.toString() ?? '0',
      owner: withImages.owner ? {
        id: withImages.owner.id,
        email: withImages.owner.email,
        name: withImages.owner.name,
        role: withImages.owner.role,
        isActive: true,
        phone: null,
        createdAt: withImages.createdAt,
        updatedAt: withImages.updatedAt
      } : null
    };

    res.status(201).json({ message: 'Recurso creado exitosamente', resource: mapped });
  } catch (error) {
    console.error('Error creando recurso:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Helper parse JSON seguro
function safeParseJSON(str) {
  try {
    if (!str) return {};
    if (typeof str === 'object') return str; // ya parseado
    return JSON.parse(str);
  } catch {
    return {};
  }
}

module.exports = router;