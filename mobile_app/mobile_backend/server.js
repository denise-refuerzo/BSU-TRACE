require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Neon PostgreSQL Connection Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false // Required for Neon serverless
  }
});

// Test DB Connection on Startup
pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring client', err.stack);
  }
  console.log('Successfully connected to Neon PostgreSQL database');
  release();
});

// ==========================================
// API ENDPOINTS
// ==========================================

/**
 * 1. LOGIN ENDPOINT
 * Route: POST /api/login
 * Description: Authenticates a user and returns their u_id and a_id (Role ID)
 */
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    // Note: "User" is in quotes because it is capitalized in the schema
    const result = await pool.query(
      'SELECT u_id, password, a_id FROM public."User" WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Verify password using bcrypt (matching your seed data format: $2b$10$...)
    const isMatch = await bcrypt.compare(password, user.password);
    
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Return the user ID and account ID for SessionManager role mapping
    res.status(200).json({
      u_id: user.u_id,
      a_id: user.a_id
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * 2. USER PROFILE ENDPOINT
 * Route: GET /api/users/:id
 * Description: Fetches detailed profile data for the ProfileScreen
 */
app.get('/api/users/:id', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      SELECT 
        u.u_id, 
        u.full_name, 
        u.uni_email, 
        u.faculty_id, 
        u.two_fa_enabled,
        a.account_type, 
        d.department_name
      FROM public."User" u
      JOIN public.account a ON u.a_id = a.a_id
      JOIN public.department d ON u.d_id = d.d_id
      WHERE u.u_id = $1
    `;

    const result = await pool.query(query, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json(result.rows[0]);

  } catch (error) {
    console.error('Profile Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * 3. DOCUMENTS LIST ENDPOINT
 * Route: GET /api/documents
 * Description: Fetches the live document feed for DocumentsScreen
 */
app.get('/api/documents', async (req, res) => {
  try {
    // Joins the document lifecycle tables to produce the format expected by the Flutter UI
    const query = `
      SELECT 
        i.title, 
        p.process_name AS form_type, 
        o.office_name AS origin_office, 
        s.current_status AS status, 
        pd.time_in AS created_at
      FROM public.initial_document i
      JOIN public.process_type p ON i.p_id = p.p_id
      JOIN public.processed_document pd ON i.ini_id = pd.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      JOIN public.offices o ON pd.current_office_id = o.o_id
      ORDER BY pd.time_in DESC
    `;

    const result = await pool.query(query);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Document Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// SERVER INITIALIZATION
// ==========================================

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`BSU-Trace API Server running on port ${PORT}`);
});