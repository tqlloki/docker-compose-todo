const os = require('os');
const express = require('express');
const todoRoutes = require('./routes/todo.routes');

const app = express();

app.use(express.json());

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} slot=${process.env.APP_SLOT || 'unknown'} ${req.method} ${req.originalUrl}`);
  next();
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    slot: process.env.APP_SLOT || 'unknown',
    hostname: os.hostname(),
    version: process.env.APP_VERSION || process.env.IMAGE_NAME || 'local',
  });
});

app.use('/todos', todoRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.use((error, req, res, next) => {
  if (error.name === 'ValidationError') {
    return res.status(400).json({ message: error.message });
  }

  console.error(error);
  return res.status(500).json({ message: 'Internal server error' });
});

module.exports = app;
