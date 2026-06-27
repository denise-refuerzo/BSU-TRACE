const { Pool } = require('pg');
require('dotenv').config();

// Access the Connection String directly from Neon dashboard dashboard properties
const connectionString = process.env.DATABASE_URL;

const pool = new Pool({
  connectionString: connectionString,
  ssl: {
    rejectUnauthorized: false, // Bypasses unauthorized local certificate errors safely
  },
});

pool.on('connect', () => {
  console.log('📡 Connected successfully to Serverless Neon PostgreSQL Instance!');
});

module.exports = pool;