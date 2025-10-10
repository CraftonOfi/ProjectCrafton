const express = require('express');
const router = express.Router();

// GET /api/health - Simple health/status endpoint
router.get('/', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

module.exports = router;
