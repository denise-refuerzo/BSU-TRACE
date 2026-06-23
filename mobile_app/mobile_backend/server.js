require('dotenv').config(); // Loads environment variables from a .env file locally
const express = require('express');
const bcrypt = require('bcrypt'); // Make sure to run: npm install bcrypt
const { Pool } = require('pg');   // Make sure to run: npm install pg

const app = express();

// Middleware to parse incoming JSON requests from Flutter
app.use(express.json());

// Set up the Neon PostgreSQL connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { 
    rejectUnauthorized: false // Required by Neon
  }
});

// Test the database connection on startup
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Failed to connect to Neon Database:', err.message);
  } else {
    console.log('✅ Connected to Neon Database successfully at:', res.rows[0].now);
  }
});

// --- BSU-TRACE LOGIN ENDPOINT ---
// Your Flutter config maps AppConfig.baseUrl to '/api', so the route is '/api/login'
app.post('/api/login', async (req, res) => {
  const { username, password, role } = req.body;

  try {
    // 1. Look up the user by username OR university email
    const userQuery = await pool.query(
      'SELECT * FROM public."User" WHERE username = $1 OR uni_email = $1',
      [username]
    );

    // If no matching username/email is found
    if (userQuery.rows.length === 0) {
      return res.status(401).json({ error: 'User not found in the system.' });
    }

    const user = userQuery.rows[0];

    // 2. Compare the plain-text password typed in Flutter against the Neon bcrypt hash
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect password.' });
    }

    // 3. Verify the role selected in the app matches the account's a_id
    const roleMap = {
      'user': 1,
      'processor': 2,
      'signee': 3,
      'admin': 4,
      'ictAdmin': 5
    };
    
    if (user.a_id !== roleMap[role]) {
      return res.status(403).json({ error: 'Unauthorized role selected for this account.' });
    }

    // 4. Success! Send the account data back to Flutter
    return res.status(200).json({
      message: 'Login successful',
      a_id: user.a_id,
      u_id: user.u_id,
      full_name: user.full_name
    });

  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'Internal server error occurred.' });
  }
});

// Start the server (Render provides the PORT dynamically, otherwise fallback to 3000 locally)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 BSU-Trace API Server running on port ${PORT}`);
});