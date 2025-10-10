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

// GET /api/resources/admin - Listar recursos (incluyendo inactivos) solo admin
router.get('/admin', authenticate, requireAdmin, async (req, res) => {
  const startTs = Date.now();
  try {
    const { status = 'active', type, types, location, locations, search, minPrice, maxPrice, sort, page = 1, limit = 20 } = req.query;

    // where base según status
    let where = {};
    if (String(status).toLowerCase() === 'active') where.isActive = true;
    else if (String(status).toLowerCase() === 'inactive') where.isActive = false;
    // 'all' => sin filtro de isActive

    // Reutilizar normalizaciones del handler público
    const normalizeTypes = (t) => {
      const up = String(t).toUpperCase();
      if (up === 'STORAGESPACE') return 'STORAGE_SPACE';
      if (up === 'LASERMACHINE') return 'LASER_MACHINE';
      if (['STORAGE_SPACE','LASER_MACHINE'].includes(up)) return up;
      return undefined;
    };
    const collectedTypes = new Set();
    if (type) { const t = normalizeTypes(type); if (t) collectedTypes.add(t); }
    if (types) {
      const arr = Array.isArray(types) ? types : String(types).split(',');
      arr.forEach((t) => { const n = normalizeTypes(t); if (n) collectedTypes.add(n); });
    }
    if (collectedTypes.size) where.type = { in: Array.from(collectedTypes) };

    const collectedLocations = new Set();
    const addLoc = (loc) => { if (!loc) return; const s = String(loc).trim(); if (s) collectedLocations.add(s); };
    addLoc(location);
    if (locations) {
      const arr = Array.isArray(locations) ? locations : String(locations).split(',');
      arr.forEach(addLoc);
    }
    if (collectedLocations.size === 1) {
      where.location = { contains: Array.from(collectedLocations)[0] };
    } else if (collectedLocations.size > 1) {
      where.AND = [ ...(where.AND || []), { OR: Array.from(collectedLocations).map(l => ({ location: { contains: l } })) } ];
    }

    const priceFilters = [];
    const minP = parseFloat(minPrice);
    const maxP = parseFloat(maxPrice);
    if (!isNaN(minP)) priceFilters.push({ pricePerHour: { gte: minP } });
    if (!isNaN(maxP)) priceFilters.push({ pricePerHour: { lte: maxP } });
    if (priceFilters.length) where.AND = [ ...(where.AND || []), ...priceFilters ];

    if (search && typeof search === 'string' && search.trim()) {
      const term = search.trim();
      where.AND = [ ...(where.AND || []), { OR: [ { name: { contains: term } }, { description: { contains: term } }, { location: { contains: term } } ] } ];
    }

    let orderBy = { createdAt: 'desc' };
    if (typeof sort === 'string') {
      const s = sort.toLowerCase();
      if (s === 'price_asc') orderBy = { pricePerHour: 'asc' };
      else if (s === 'price_desc') orderBy = { pricePerHour: 'desc' };
      else if (s === 'created_asc') orderBy = { createdAt: 'asc' };
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    const [resources, total] = await Promise.all([
      prisma.resource.findMany({
        where,
        include: { owner: { select: { id: true, name: true, email: true, role: true } }, images: true, _count: { select: { bookings: true } } },
        orderBy,
        skip,
        take,
      }),
      prisma.resource.count({ where }),
    ]);

    const mapped = resources.map(r => ({
      id: r.id.toString(),
      name: r.name,
      description: r.description ?? '',
      type: r.type,
      pricePerHour: r.pricePerHour ?? 0,
      location: r.location,
      capacity: r.capacity,
      specifications: safeParseJSON(r.specifications),
      images: r.images.map(img => img.url),
      isActive: r.isActive,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      ownerId: r.ownerId?.toString() ?? '0',
      owner: r.owner ? { id: r.owner.id, email: r.owner.email, name: r.owner.name, role: r.owner.role, isActive: true, phone: null, createdAt: r.createdAt, updatedAt: r.updatedAt } : null,
    }));

    const durationMs = Date.now() - startTs;
    console.log('[resources:admin] success', { count: mapped.length, total, durationMs, where, orderBy });
    res.json({
      resources: mapped,
      pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / parseInt(limit)) }
    });
  } catch (error) {
    console.error('[resources:admin] error', error);
    res.status(500).json({ error: 'Error interno del servidor' });
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

// PUT /api/resources/:id - Actualizar recurso (solo admin)
router.put('/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const {
      name,
      description,
      pricePerHour,
      location,
      capacity,
      specifications,
      images,
      isActive,
    } = req.body;

    // Build update data
    const data = {};
    if (typeof name === 'string') data.name = name;
    if (typeof description === 'string') data.description = description;
    if (typeof pricePerHour === 'number') data.pricePerHour = pricePerHour;
    if (typeof location === 'string') data.location = location;
    if (typeof capacity === 'string') data.capacity = capacity;
    if (typeof isActive === 'boolean') data.isActive = isActive;
    if (typeof specifications !== 'undefined') {
      data.specifications = typeof specifications === 'string'
        ? specifications
        : JSON.stringify(specifications || {});
    }

    // Update main resource
    await prisma.resource.update({ where: { id }, data });

    // Replace images if provided
    if (Array.isArray(images)) {
      await prisma.resourceImage.deleteMany({ where: { resourceId: id } });
      if (images.length) {
        await prisma.resourceImage.createMany({
          data: images.map(url => ({ url, resourceId: id }))
        });
      }
    }

    const updated = await prisma.resource.findUnique({
      where: { id },
      include: { owner: { select: { id: true, name: true, email: true, role: true } }, images: true }
    });

    if (!updated) return res.status(404).json({ error: 'Recurso no encontrado' });

    const mapped = {
      id: updated.id.toString(),
      name: updated.name,
      description: updated.description ?? '',
      type: updated.type,
      pricePerHour: updated.pricePerHour ?? 0,
      location: updated.location,
      capacity: updated.capacity,
      specifications: safeParseJSON(updated.specifications),
      images: updated.images.map(i => i.url),
      isActive: updated.isActive,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
      ownerId: updated.ownerId?.toString() ?? '0',
      owner: updated.owner ? {
        id: updated.owner.id,
        email: updated.owner.email,
        name: updated.owner.name,
        role: updated.owner.role,
        isActive: true,
        phone: null,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt
      } : null
    };

    res.json({ message: 'Recurso actualizado exitosamente', resource: mapped });
  } catch (error) {
    console.error('Error actualizando recurso:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// DELETE /api/resources/:id - Desactivar recurso (soft delete) (solo admin)
router.delete('/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const existing = await prisma.resource.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: 'Recurso no encontrado' });

    const updated = await prisma.resource.update({
      where: { id },
      data: { isActive: false }
    });

    res.json({ message: 'Recurso desactivado exitosamente', id: updated.id.toString() });
  } catch (error) {
    console.error('Error eliminando recurso:', error);
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