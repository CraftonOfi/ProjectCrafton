## Guía de Despliegue (Backend)

Esta guía resume variables de entorno, comandos y endpoints clave para operar el backend con tiempo real, métricas y notificaciones push.

### 1) Prerrequisitos
- Node.js 18+
- Base de datos (SQLite para dev; Postgres recomendado en producción)
- PM2 o Docker/Compose

### 2) Variables de entorno (.env)
- PORT: puerto de escucha (por defecto 3001)
- NODE_ENV: `production` | `development`
- JWT_SECRET: cadena aleatoria segura
- DATABASE_URL: URL de conexión (en prod: Postgres)
- CORS_ORIGIN: orígenes permitidos separados por coma (obligatorio en prod)
- LOG_LEVEL: nivel de logs pino (`info`, `warn`, `error`, `debug`)
- GOOGLE_FCM_PROJECT_ID: ID del proyecto Firebase (FCM HTTP v1)
- GOOGLE_APPLICATION_CREDENTIALS: ruta al JSON de cuenta de servicio (FCM v1)
- FCM_SERVER_KEY: opcional (fallback Legacy si no hay v1)

Opcionales (si aplica pagos):
- STRIPE_*

### 3) Instalación y migraciones
```bash
npm ci
npm run generate
npm run migrate
```

Prisma Studio (opcional):
```bash
npm run studio
```

### 4) Ejecución en producción
- PM2:
```bash
npm install -g pm2
pm2 start server.js --name rental-api
pm2 startup && pm2 save
```

- Docker Compose:
```bash
docker compose up -d --build
```

La imagen usa healthchecks con `/live` y `/ready`.

### 5) Observabilidad y salud
- Liveness: `GET /live`
- Readiness (DB): `GET /ready`
- Health info: `GET /health`
- Métricas Prometheus: `GET /metrics`

### 6) CORS
En desarrollo se permiten `localhost`. En producción, configura `CORS_ORIGIN` con tus dominios:
```
CORS_ORIGIN=https://app.example.com,https://admin.example.com
```

### 7) Logs
Logs estructurados con `pino-http` y `requestId`. Controla el nivel con `LOG_LEVEL`.

### 8) Tiempo real (Socket.IO)
- Autenticación por JWT en handshake (`auth.token` o `Authorization: Bearer <JWT>`)
- Salas por usuario: `user:{userId}`
- Evento de ejemplo: `chat:new_message`

### 9) Autenticación y Refresh Tokens
- Login devuelve `token` (JWT) y `refreshToken` (30 días)
- Refrescar: `POST /api/auth/refresh` { refreshToken }
- Revocar todos: `POST /api/auth/logout-all-devices`

### 10) Notificaciones Push (FCM)
- Preferido: HTTP v1 con `GOOGLE_FCM_PROJECT_ID` + `GOOGLE_APPLICATION_CREDENTIALS`
- Fallback a Legacy si existe `FCM_SERVER_KEY`
- Tokens inválidos se marcan como inactivos automáticamente

Registro/gestión de tokens desde el cliente:
- `POST /api/devices/register` { token, platform? }
- `POST /api/devices/unregister` { token }

### 11) Reservas (cron)
Tarea cada 15 min:
- Cambia estados a `IN_PROGRESS`/`COMPLETED` según fechas
- Envía recordatorios 24h antes del inicio

### 12) Migración a Postgres
Ver `docs/PRISMA_MIGRATIONS.md` para cambiar `provider`, `DATABASE_URL` e índices.

### 13) Troubleshooting
- 401: revisa `Authorization: Bearer <JWT>`
- CORS: confirma que el origen está en `CORS_ORIGIN`
- DB: valida `DATABASE_URL` y `/ready`
- Push: verifica `GOOGLE_FCM_PROJECT_ID` y credenciales
- Realtime: valida token de handshake y acceso a `/socket.io`


