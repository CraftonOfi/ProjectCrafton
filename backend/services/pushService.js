const https = require('https');
const { GoogleAuth } = require('google-auth-library');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Enviar notificaciones push usando FCM (Legacy HTTP)
// Requiere FCM_SERVER_KEY en el .env. Si no está configurado, hace no-op.
function sendPushToTokens(tokens = [], notification = {}, data = {}) {
  if (!Array.isArray(tokens) || tokens.length === 0) {
    return Promise.resolve({ skipped: true, reason: 'no tokens' });
  }

  // Preferir FCM HTTP v1 si está configurado el proyecto
  if (process.env.GOOGLE_FCM_PROJECT_ID) {
    return sendV1(tokens, notification, data);
  }

  // Fallback a Legacy si no hay config v1
  const serverKey = process.env.FCM_SERVER_KEY;
  if (serverKey) {
    return sendLegacy(tokens, notification, data, serverKey);
  }
  return Promise.resolve({ skipped: true, reason: 'No FCM configuration' });
}

async function sendV1(tokens = [], notification = {}, data = {}) {
  try {
    const projectId = process.env.GOOGLE_FCM_PROJECT_ID;
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const client = await auth.getClient();
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const invalidTokens = [];
    const results = [];

    for (const token of tokens) {
      const payload = {
        message: {
          token,
          notification: notification,
          data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        },
      };
      try {
        const res = await client.request({
          url,
          method: 'POST',
          data: payload,
        });
        results.push({ token, status: res.status, body: res.data });
      } catch (e) {
        const msg = e?.response?.data?.error?.message || e.message || '';
        if (/UNREGISTERED|NOT_FOUND|INVALID_ARGUMENT/i.test(msg)) {
          invalidTokens.push(token);
        }
        results.push({ token, error: msg });
      }
    }

    if (invalidTokens.length) {
      try {
        await prisma.deviceToken.updateMany({
          where: { token: { in: invalidTokens } },
          data: { isActive: false },
        });
      } catch (_) {}
    }

    return { status: 'ok', results, invalidTokens };
  } catch (e) {
    return { status: 'error', error: e.message };
  }
}

function sendLegacy(tokens = [], notification = {}, data = {}, serverKey) {
  const payload = JSON.stringify({
    registration_ids: tokens,
    notification,
    data,
    priority: 'high',
  });
  const options = {
    hostname: 'fcm.googleapis.com',
    path: '/fcm/send',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${serverKey}`,
      'Content-Length': Buffer.byteLength(payload),
    },
  };
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', async () => {
        let parsed = {};
        try { parsed = JSON.parse(body || '{}'); } catch (_) {}
        // Marcar tokens inválidos
        const results = parsed.results || [];
        const invalid = [];
        results.forEach((r, idx) => {
          const err = r && (r.error || r.message);
          if (err && /NotRegistered|InvalidRegistration|MismatchSenderId/i.test(err)) {
            invalid.push(tokens[idx]);
          }
        });
        if (invalid.length) {
          try { await prisma.deviceToken.updateMany({ where: { token: { in: invalid } }, data: { isActive: false } }); } catch (_) {}
        }
        resolve({ statusCode: res.statusCode, body: parsed, invalid });
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

module.exports = {
  sendPushToTokens,
};
