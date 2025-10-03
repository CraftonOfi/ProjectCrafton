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
