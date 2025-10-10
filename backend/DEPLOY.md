# Backend Deployment Guide

This document explains how to deploy the Rental API (Node + Express + Prisma).

## 1) Prerequisites
- Node.js 18+
- A database (SQLite for dev; Postgres/MySQL recommended in production)
- A process manager (PM2) or container runtime

## 2) Environment variables
Copy `.env.example` to `.env` and set values:

- PORT: default 3001
- NODE_ENV: production
- JWT_SECRET: long, random string
- DATABASE_URL: your DB connection string
- CORS_ORIGIN: comma-separated allowed origins (frontend domains)
- LOG_LEVEL: morgan format, e.g. `combined` (prod) or `dev` (dev)
- FCM_SERVER_KEY: (optional) Firebase Cloud Messaging server key if you want push notifications

## 3) Install & build
```bash
npm install
```

## 4) Database migrations
Run Prisma migrations in the target environment:
```bash
# Dev (SQLite)
npm run migrate

# Or for a specific database set DATABASE_URL in .env and run migrate
```

Recent schema additions:
- DeviceToken model (stores user device tokens for push). If upgrading, run migrations to create the `device_tokens` table.

Optional: inspect the DB with Prisma Studio:
```bash
npm run studio
```

## 5) Run in production
Using PM2:
```bash
# Install pm2 globally (once)
npm install -g pm2

# Start app
pm2 start server.js --name rental-api

# Persist across reboots (Linux)
pm2 startup
pm2 save
```

Or without PM2:
```bash
NODE_ENV=production node server.js
```

## 6) Health check
- Health endpoint: `GET /health`
- API base path: `/api`

## 7) CORS
The server allows local origins by default for development. For production, set `CORS_ORIGIN` to your trusted origins (comma-separated). Example:
```
CORS_ORIGIN=https://app.example.com,https://admin.example.com
```

## 8) Logs
- Uses `morgan`. Configure via `LOG_LEVEL` env (`combined`, `common`, `dev`, etc.).

## 9) Troubleshooting
- 401 Invalid Token: ensure Authorization: Bearer <JWT> is being sent
- 409 Booking conflicts: ensure requested window has no overlap
- DB path issues (SQLite): check that `DATABASE_URL` points to a writeable path
- CORS blocked: confirm origin is included in `CORS_ORIGIN`

## 10) Push notifications
- Set `FCM_SERVER_KEY` in `.env` to enable sending pushes via Firebase (legacy HTTP API).
- Register tokens from clients at:
	- POST `/api/devices/register` { token, platform? }
	- POST `/api/devices/unregister` { token }
	- POST `/api/devices/test-push` — sends a test push to all active tokens of the authenticated user
- Booking events create in-app notifications and will attempt to send pushes if tokens exist.

---
Happy shipping!
