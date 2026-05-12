require('dotenv').config();

const app = require('./app');
const { connectDatabase } = require('./config/db');

const port = process.env.PORT || 3000;

async function start() {
  try {
    await connectDatabase(process.env.MONGO_URI);
    app.listen(port, () => {
      console.log(`Todo API listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}

start();
