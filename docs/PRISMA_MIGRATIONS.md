# Prisma Migrations

## Migración a Postgres

1. Actualiza `datasource db` en `backend/prisma/schema.prisma`:

```
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

2. Establece `DATABASE_URL` con formato:

```
postgresql://USER:PASSWORD@HOST:PORT/DBNAME?schema=public
```

3. Ejecuta migraciones:

```
npm run generate
npm run migrate
```

4. Verifica índices:
- `messages`: `@@index([toUserId, read])` y `@@index([fromUserId, toUserId, createdAt])`
- `refresh_tokens`: índices por `userId` y `expiresAt`

5. Revisa datos existentes: migra desde SQLite si aplica (dump/import).

# Prisma Migrations & Dev DB

This project uses Prisma with SQLite for development.

## Apply migrations

1. Install deps (if needed):
   - Node.js LTS and npm
   - `npm ci` in `backend/`
2. Generate Prisma client:
   - In `backend/`: `npx prisma generate`
3. Apply existing migrations:
   - `npx prisma migrate deploy`

## Create a new migration

- Update `backend/prisma/schema.prisma`.
- Run:
  - `npx prisma migrate dev --name <meaningful_name>`
- This updates the dev database and creates a new folder under `backend/prisma/migrations/`.

## Useful commands

- Inspect DB in studio:
  - `npx prisma studio`
- Reset dev DB (danger: wipes data):
  - `npx prisma migrate reset`

## Troubleshooting

- SQLite limitations: case-insensitive contains/ilike are limited; prefer client-side post-filtering when necessary.
- If migrations are out of sync:
  - Ensure `migration_lock.toml` is not corrupted.
  - Run `prisma generate` again after changing schema.
- If `dev.db` is missing:
  - Run `prisma migrate dev` to create it.
